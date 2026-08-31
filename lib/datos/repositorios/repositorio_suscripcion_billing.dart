import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/estado_suscripcion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_suscripcion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:sqflite/sqflite.dart';

/// Estado de la suscripción premium: caché en SQLite + Google Play Billing.
///
/// **Es el único punto de la app que habla con un servicio externo** (enmienda
/// al Principio I, v2.0.0). Todo el SDK `in_app_purchase` queda contenido acá:
/// ni el dominio ni la UI lo conocen, solo la interfaz
/// [RepositorioSuscripcion].
///
/// **Privacidad (FR-016)**: lo único que sale del dispositivo es el
/// identificador del producto y el token de compra que gestiona la propia
/// Billing Library. Ningún `Dinero`, `Deuda`, `Transaccion` ni `AporteAhorro`
/// entra en estas llamadas.
final class RepositorioSuscripcionBilling implements RepositorioSuscripcion {
  /// ID del producto de suscripción en Google Play Console.
  static const String idProducto = 'premium';

  static const String _tabla = 'suscripcion_premium';

  final Database _conexion;
  final InAppPurchase _tienda;

  /// La fecha entra inyectada, igual que en el resto del proyecto, para que
  /// las pruebas no dependan del reloj de la máquina.
  final DateTime Function() _ahora;

  RepositorioSuscripcionBilling(
    this._conexion, {
    InAppPurchase? tienda,
    DateTime Function()? ahora,
  }) : _tienda = tienda ?? InAppPurchase.instance,
       _ahora = ahora ?? DateTime.now;

  @override
  Future<EstadoSuscripcion> estadoCacheado() async {
    try {
      final filas = await _conexion.query(_tabla, where: 'id = 1', limit: 1);
      if (filas.isEmpty) {
        // La ausencia de fila **es** "nunca suscripto": no se siembra nada en
        // la migración para no escribir un dato que se puede derivar.
        return EstadoSuscripcion.nunca(ultimaVerificacion: _ahora());
      }
      return _desdeFila(filas.first);
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('el estado de la suscripción', causa);
    }
  }

  @override
  Future<EstadoSuscripcion> refrescar() async {
    final cacheado = await estadoCacheado();

    // Sin tienda disponible (sin conexión, sin Play Services, emulador sin
    // Google) no se falla: se sigue con lo último que se supo. Abrir una
    // pantalla premium nunca puede depender de la red.
    if (!await _tiendaDisponible()) return cacheado;

    try {
      final compra = await _compraVigente();
      return await _guardar(_situacionSegunCompra(compra, cacheado));
    } on Object {
      // Un fallo consultando a Google tampoco puede dejar al usuario sin
      // acceso a algo que ya pagó: se conserva el estado conocido.
      return cacheado;
    }
  }

  @override
  Future<List<OfertaSuscripcion>> ofertasDisponibles() async {
    if (!await _tiendaDisponible()) {
      // A diferencia de refrescar(), acá sí se falla: no hay nada útil que
      // cachear, y mostrar un precio viejo sería engañoso.
      throw ErrorPersistencia.alLeer(
        'los planes de suscripción',
        StateError('Google Play no está disponible'),
      );
    }

    final respuesta = await _tienda.queryProductDetails(<String>{idProducto});
    if (respuesta.error != null) {
      throw ErrorPersistencia.alLeer(
        'los planes de suscripción',
        StateError(respuesta.error!.message),
      );
    }

    final ofertas = <OfertaSuscripcion>[];
    for (final plan in PlanSuscripcion.values) {
      final detalle = _detalleDelPlan(respuesta.productDetails, plan);
      if (detalle == null) continue;
      ofertas.add(
        OfertaSuscripcion(
          plan: plan,
          precioFormateado: detalle.price,
          duracionPruebaDias: _diasDePrueba(_ofertaAndroid(detalle)),
        ),
      );
    }
    return ofertas;
  }

  @override
  Future<EstadoSuscripcion> comprar(PlanSuscripcion plan) async {
    final cacheado = await estadoCacheado();
    if (!await _tiendaDisponible()) return cacheado;

    final respuesta = await _tienda.queryProductDetails(<String>{idProducto});
    final detalle = _detalleDelPlan(respuesta.productDetails, plan);
    if (detalle == null) {
      throw ErrorPersistencia.alLeer(
        'el plan ${plan.etiqueta}',
        StateError('Google Play no ofrece el plan base "${plan.slug}"'),
      );
    }

    // La confirmación de la compra llega por el stream, no como retorno de
    // buyNonConsumable: se empieza a escuchar **antes** de lanzar el flujo
    // para no perderse el evento si Google responde de inmediato.
    final resultado = _tienda.purchaseStream
        .expand((compras) => compras)
        .firstWhere((compra) => compra.productID == idProducto);

    await _tienda.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: detalle),
    );

    final compra = await resultado;
    switch (compra.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // Acusar recibo es obligatorio: una compra sin confirmar dentro de
        // los tres días Google la reembolsa sola.
        if (compra.pendingCompletePurchase) {
          await _tienda.completePurchase(compra);
        }
        final enPrueba = _diasDePrueba(_ofertaAndroid(detalle)) > 0;
        return _guardar(
          EstadoSuscripcion(
            situacion: enPrueba
                ? SituacionSuscripcion.enPrueba
                : SituacionSuscripcion.activa,
            plan: plan,
            vigenteHasta: null,
            ultimaVerificacion: _ahora(),
          ),
        );
      case PurchaseStatus.canceled:
      case PurchaseStatus.error:
      case PurchaseStatus.pending:
        // Cancelar es un flujo esperado, no un error (FR-008); una compra
        // pendiente todavía no desbloquea nada.
        return cacheado;
    }
  }

  @override
  Future<EstadoSuscripcion> restaurar() async {
    final cacheado = await estadoCacheado();
    if (!await _tiendaDisponible()) return cacheado;

    try {
      // Exigido por la política de Google Play: una acción explícita que
      // recupere lo ya comprado con la cuenta activa (FR-014).
      await _tienda.restorePurchases();
      final compra = await _compraVigente();
      if (compra == null) {
        // Esta cuenta no tiene ninguna suscripción (FR-015). Comunicarlo es
        // de la UI; acá solo se refleja el hecho.
        return await _guardar(
          EstadoSuscripcion.nunca(ultimaVerificacion: _ahora()),
        );
      }
      return await _guardar(_situacionSegunCompra(compra, cacheado));
    } on Object catch (causa) {
      throw ErrorPersistencia.alLeer('las compras de esta cuenta', causa);
    }
  }

  Future<bool> _tiendaDisponible() async {
    try {
      return await _tienda.isAvailable();
    } on Object {
      return false;
    }
  }

  /// La compra vigente del producto premium, o `null` si la cuenta no tiene
  /// ninguna. Google solo devuelve suscripciones que siguen cubriendo al
  /// usuario, así que "no está" equivale a "ya no cubre".
  Future<PurchaseWrapper?> _compraVigente() async {
    final extension = _tienda
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final respuesta = await extension.queryPastPurchases();
    for (final compra in respuesta.pastPurchases) {
      final wrapper = compra.billingClientPurchase;
      if (!wrapper.products.contains(idProducto)) continue;
      if (wrapper.purchaseState != PurchaseStateWrapper.purchased) continue;
      return wrapper;
    }
    return null;
  }

  /// Traduce lo que informa Google a una [SituacionSuscripcion].
  ///
  /// **Dos límites conocidos de hacer esto solo desde el cliente**, sin un
  /// servidor que consulte la Play Developer API (que la constitución no
  /// permite montar):
  ///
  ///  - No se puede distinguir "en prueba gratis" de "activa" al refrescar:
  ///    `enPrueba` solo se fija en el momento de comprar, donde sí se sabe si
  ///    la oferta elegida traía una fase gratuita. Un refresco posterior la
  ///    reporta como `activa`, que es lo que efectivamente pasa al primer
  ///    cobro.
  ///  - Una suscripción cancelada pero con período todavía vigente se ve
  ///    igual que una activa (Google la sigue devolviendo). Se refleja como
  ///    `activa` a propósito: el usuario conserva el acceso hasta que termine
  ///    el período que pagó, y recién cuando Google deja de devolverla pasa a
  ///    `vencida`.
  EstadoSuscripcion _situacionSegunCompra(
    PurchaseWrapper? compra,
    EstadoSuscripcion cacheado,
  ) {
    if (compra != null) {
      return EstadoSuscripcion(
        // Un refresco no puede saber si sigue en prueba: si el caché ya decía
        // "en prueba", se respeta hasta que Google deje de reportar la compra.
        situacion: cacheado.situacion == SituacionSuscripcion.enPrueba
            ? SituacionSuscripcion.enPrueba
            : SituacionSuscripcion.activa,
        plan: cacheado.plan,
        vigenteHasta: cacheado.vigenteHasta,
        ultimaVerificacion: _ahora(),
      );
    }

    // Google no reporta ninguna compra: o nunca la hubo, o ya no cubre.
    return EstadoSuscripcion(
      situacion: cacheado.situacion == SituacionSuscripcion.nunca
          ? SituacionSuscripcion.nunca
          : SituacionSuscripcion.vencida,
      plan: cacheado.plan,
      vigenteHasta: cacheado.vigenteHasta,
      ultimaVerificacion: _ahora(),
    );
  }

  /// El `ProductDetails` correspondiente al plan base pedido.
  ///
  /// `queryProductDetails` devuelve **una entrada por oferta** (plan base ×
  /// oferta), no una por producto: por eso hay que buscar por `basePlanId`,
  /// que en Play Console se nombra igual que el slug del plan.
  ProductDetails? _detalleDelPlan(
    List<ProductDetails> detalles,
    PlanSuscripcion plan,
  ) {
    for (final detalle in detalles) {
      if (_ofertaAndroid(detalle)?.basePlanId == plan.slug) return detalle;
    }
    return null;
  }

  SubscriptionOfferDetailsWrapper? _ofertaAndroid(ProductDetails detalle) {
    if (detalle is! GooglePlayProductDetails) return null;
    final indice = detalle.subscriptionIndex;
    final ofertas = detalle.productDetails.subscriptionOfferDetails;
    if (indice == null || ofertas == null || indice >= ofertas.length) {
      return null;
    }
    return ofertas[indice];
  }

  /// Días de prueba gratis de una oferta: la fase de precio cero, si la hay
  /// (FR-006a).
  int _diasDePrueba(SubscriptionOfferDetailsWrapper? oferta) {
    if (oferta == null) return 0;
    for (final fase in oferta.pricingPhases) {
      if (fase.priceAmountMicros == 0) {
        return _diasDePeriodoIso(fase.billingPeriod);
      }
    }
    return 0;
  }

  /// Convierte un período ISO-8601 de facturación (`P1W`, `P1M`, `P1Y`) a
  /// días, solo para mostrarlo. Es una aproximación de calendario a
  /// propósito: no decide cobros ni vigencia, eso lo hace Google.
  static int _diasDePeriodoIso(String periodo) {
    final coincidencia = RegExp(r'^P(\d+)([DWMY])$').firstMatch(periodo);
    if (coincidencia == null) return 0;
    final cantidad = int.parse(coincidencia.group(1)!);
    return switch (coincidencia.group(2)!) {
      'D' => cantidad,
      'W' => cantidad * 7,
      'M' => cantidad * 30,
      'Y' => cantidad * 365,
      _ => 0,
    };
  }

  Future<EstadoSuscripcion> _guardar(EstadoSuscripcion estado) async {
    try {
      await _conexion.insert(_tabla, <String, Object?>{
        'id': 1,
        'situacion': estado.situacion.slug,
        'plan': estado.plan?.slug,
        'vigente_hasta': _comoFecha(estado.vigenteHasta),
        'ultima_verificacion': _comoFecha(estado.ultimaVerificacion)!,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return estado;
    } on Object catch (causa) {
      throw ErrorPersistencia.alGuardar('el estado de la suscripción', causa);
    }
  }

  static String? _comoFecha(DateTime? fecha) => fecha == null
      ? null
      : '${fecha.year.toString().padLeft(4, '0')}-'
            '${fecha.month.toString().padLeft(2, '0')}-'
            '${fecha.day.toString().padLeft(2, '0')}';

  static EstadoSuscripcion _desdeFila(Map<String, Object?> fila) {
    final plan = fila['plan'] as String?;
    final vigenteHasta = fila['vigente_hasta'] as String?;
    return EstadoSuscripcion(
      situacion: SituacionSuscripcion.desdeSlug(fila['situacion']! as String),
      plan: plan == null ? null : PlanSuscripcion.desdeSlug(plan),
      vigenteHasta: vigenteHasta == null ? null : DateTime.parse(vigenteHasta),
      ultimaVerificacion: DateTime.parse(
        fila['ultima_verificacion']! as String,
      ),
    );
  }
}
