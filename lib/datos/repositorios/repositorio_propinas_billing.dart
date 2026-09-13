import 'dart:async';

import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/dominio/modelos/propina.dart';
import 'package:finanzas/dominio/repositorios/repositorio_propinas.dart';
import 'package:finanzas/shared/constantes/propinas.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Los montos de apoyo y la compra, contra Google Play Billing.
///
/// **Es el único punto de la app que habla con un servicio externo** (enmienda
/// al Principio I, v2.0.0). Todo el SDK `in_app_purchase` queda contenido acá:
/// ni el dominio ni la UI lo conocen, solo la interfaz [RepositorioPropinas].
///
/// **No guarda nada.** No hay tabla, no hay caché y no hay estado entre
/// llamadas (research.md D8): lo único que la app sabe de antemano son los
/// identificadores de `idsDePropina`.
///
/// **Privacidad (FR-009)**: lo único que sale del dispositivo es el
/// identificador del producto y el token de compra que gestiona la propia
/// Billing Library.
final class RepositorioPropinasBilling implements RepositorioPropinas {
  final InAppPurchase _tienda;

  RepositorioPropinasBilling({InAppPurchase? tienda})
    : _tienda = tienda ?? InAppPurchase.instance;

  @override
  Future<List<OfertaPropina>> ofertasDisponibles() async {
    if (!await _tiendaDisponible()) {
      throw ErrorPersistencia.alLeer(
        'los montos para apoyar',
        StateError('Google Play no está disponible'),
      );
    }

    // Antes que nada, cerrar lo que haya quedado abierto: una compra sin
    // consumir bloquea la siguiente y Google la reembolsa sola a los tres
    // días (FR-010).
    await _consumirPendientes();

    final respuesta = await _tienda.queryProductDetails(idsDePropina.toSet());
    if (respuesta.error != null) {
      throw ErrorPersistencia.alLeer(
        'los montos para apoyar',
        StateError(respuesta.error!.message),
      );
    }

    // Se recorre `idsDePropina` y no `respuesta.productDetails` para que el
    // orden en pantalla sea el que decide la app, no el que devuelva la
    // tienda. Un identificador que Play Console no reconozca no aparece, sin
    // romper nada.
    final ofertas = <OfertaPropina>[];
    for (final id in idsDePropina) {
      final detalle = _detalleDe(respuesta.productDetails, id);
      if (detalle == null) continue;
      ofertas.add(
        OfertaPropina(
          id: detalle.id,
          titulo: detalle.title,
          precioFormateado: detalle.price,
        ),
      );
    }
    return ofertas;
  }

  @override
  Future<ResultadoPropina> apoyar(OfertaPropina oferta) async {
    if (!await _tiendaDisponible()) return ResultadoPropina.fallida;

    // Se vuelve a pedir el detalle en vez de guardarlo de la consulta
    // anterior: así este repositorio no tiene estado que pueda quedar viejo,
    // y el costo es una llamada más justo después de que el usuario tocó un
    // botón.
    final respuesta = await _tienda.queryProductDetails(<String>{oferta.id});
    final detalle = _detalleDe(respuesta.productDetails, oferta.id);
    if (detalle == null) return ResultadoPropina.fallida;

    // La confirmación llega por el stream, no como retorno de la compra: se
    // empieza a escuchar **antes** de lanzar el flujo para no perderse el
    // evento si Google responde de inmediato.
    final confirmacion = _tienda.purchaseStream
        .expand((compras) => compras)
        .firstWhere((compra) => compra.productID == oferta.id);

    // **El `bool` que devuelve importa.** Si el flujo ni siquiera se lanza
    // —el producto ya está comprado sin consumir, el servicio se desconectó,
    // o ya hay un diálogo abierto— Google no emite nada por el stream, y
    // esperar esa confirmación colgaría la pantalla en "Confirmando…" con los
    // botones apagados, para siempre. Se corta acá.
    final seLanzo = await _tienda.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: detalle),
    );
    if (!seLanzo) {
      // La espera queda abandonada: si el stream se cierra sin coincidencia,
      // `firstWhere` lanza, y nadie estaría escuchando. `ignore()` es la forma
      // de decir "este error no le importa a nadie" sin que termine en la
      // consola como excepción sin capturar.
      confirmacion.ignore();
      return ResultadoPropina.fallida;
    }

    final compra = await confirmacion;
    switch (compra.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (compra.pendingCompletePurchase) {
          await _tienda.completePurchase(compra);
        }
        return ResultadoPropina.completada;
      case PurchaseStatus.pending:
        return ResultadoPropina.pendiente;
      case PurchaseStatus.canceled:
        // Cerrar el diálogo de Google es un flujo esperado, no un fallo
        // (FR-008).
        return ResultadoPropina.cancelada;
      case PurchaseStatus.error:
        // Ojo con este caso: el plugin también reescribe a `error` una compra
        // **ya cobrada** cuya consumición automática falló. No se puede
        // distinguir acá de un rechazo real, así que el mensaje que la
        // pantalla muestra evita prometer que no se cobró y se limita a
        // ofrecer reintentar. Al reintentar, `_consumirPendientes()` limpia
        // esa compra colgada antes de nada.
        return ResultadoPropina.fallida;
    }
  }

  Future<bool> _tiendaDisponible() async {
    try {
      return await _tienda.isAvailable();
    } on Object {
      return false;
    }
  }

  /// Consume las propinas que quedaron compradas pero sin consumir.
  ///
  /// **Por qué hace falta a mano**: `buyConsumable(autoConsume: true)` apunta
  /// el producto en una lista estática del plugin y lo consume cuando llega la
  /// confirmación. Esa lista vive en memoria, así que si la app se cerró entre
  /// el pago y la confirmación, nadie consume esa compra: queda ocupando el
  /// producto —impidiendo apoyar de nuevo con el mismo monto (FR-007)— hasta
  /// que Google la reembolsa sola.
  ///
  /// `queryPastPurchases` no devuelve productos ya consumidos, así que lo que
  /// aparezca acá es exactamente lo que quedó colgado. Consumir además acusa
  /// recibo, que es lo que exige FR-010.
  ///
  /// Un fallo consumiendo **no interrumpe** la consulta de montos: sería
  /// dejar al usuario sin poder apoyar por un problema que no es suyo.
  ///
  /// El `try` de adentro es por compra y no alrededor del bucle a propósito:
  /// una que no se pueda consumir —una pendiente de aprobación, por ejemplo—
  /// no tiene por qué dejar colgadas a las demás, que es justo lo que impide
  /// volver a apoyar con esos montos.
  Future<void> _consumirPendientes() async {
    final InAppPurchaseAndroidPlatformAddition extension;
    final List<GooglePlayPurchaseDetails> pendientes;
    try {
      extension = _tienda
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      pendientes = (await extension.queryPastPurchases()).pastPurchases;
    } on Object {
      return;
    }

    for (final compra in pendientes) {
      if (!idsDePropina.contains(compra.productID)) continue;
      try {
        await extension.consumePurchase(compra);
      } on Object {
        continue;
      }
    }
  }

  ProductDetails? _detalleDe(List<ProductDetails> detalles, String id) {
    for (final detalle in detalles) {
      if (detalle.id == id) return detalle;
    }
    return null;
  }
}
