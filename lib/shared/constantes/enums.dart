/// Conjuntos cerrados del dominio.
///
/// Cada valor lleva su `slug` de persistencia separado de su `etiqueta` de
/// interfaz: cambiar el texto que ve el usuario no debe reescribir la base de
/// datos, y renombrar un valor de Dart no debe corromper filas ya guardadas.
library;

/// Clasificación de obligaciones y transacciones (FR-003).
///
/// Conjunto cerrado: un slug desconocido al leer es un error de datos, no un
/// valor nuevo que haya que aceptar.
enum Categoria {
  tarjetaCredito('tarjeta_credito', 'Tarjeta de crédito'),
  departamento('departamento', 'Departamento'),
  servicios('servicios', 'Servicios'),
  pasajes('pasajes', 'Pasajes'),
  comida('comida', 'Comida'),
  otros('otros', 'Otros');

  const Categoria(this.slug, this.etiqueta);

  final String slug;
  final String etiqueta;

  /// Las categorías que el usuario puede elegir al crear una obligación.
  ///
  /// Excluye `tarjetaCredito`: ese compromiso lo derivan las deudas en cuotas.
  /// Registrarlo a mano duplicaría el monto en el presupuesto del mes.
  static List<Categoria> get presupuestables => values
      .where((categoria) => categoria != Categoria.tarjetaCredito)
      .toList();

  static Categoria desdeSlug(String slug) => values.firstWhere(
    (categoria) => categoria.slug == slug,
    orElse: () => throw ArgumentError.value(
      slug,
      'slug',
      'Categoría desconocida en la base de datos',
    ),
  );
}

/// Distingue una obligación de monto fijo de una estimación variable (FR-004).
///
/// Solo las fijas se proponen al precargar el mes siguiente (FR-006).
enum TipoObligacion {
  fija('fija', 'Fija'),
  variable('variable', 'Variable');

  const TipoObligacion(this.slug, this.etiqueta);

  final String slug;
  final String etiqueta;

  static TipoObligacion desdeSlug(String slug) => values.firstWhere(
    (tipo) => tipo.slug == slug,
    orElse: () => throw ArgumentError.value(
      slug,
      'slug',
      'Tipo de obligación desconocido en la base de datos',
    ),
  );
}

/// Cómo se calcula el ahorro sugerido del mes (FR-031).
enum ReglaAhorro {
  porcentajeIngreso('porcentaje', 'Porcentaje del ingreso'),
  remanente('remanente', 'Lo que sobre tras los compromisos');

  const ReglaAhorro(this.slug, this.etiqueta);

  final String slug;
  final String etiqueta;

  static ReglaAhorro desdeSlug(String slug) => values.firstWhere(
    (regla) => regla.slug == slug,
    orElse: () => throw ArgumentError.value(
      slug,
      'slug',
      'Regla de ahorro desconocida en la base de datos',
    ),
  );
}

/// Por qué una notificación de un origen reconocido no se pudo interpretar
/// (FR-017, FR-018, spec 002).
///
/// No incluye "no es un consumo": eso se ignora sin dejar rastro (FR-012), no
/// es un fallo de interpretación.
enum MotivoDiagnostico {
  formatoNoReconocido('formato_no_reconocido', 'Formato no reconocido'),
  montoIlegible('monto_ilegible', 'Monto ilegible'),
  monedaExtranjera('moneda_extranjera', 'Moneda extranjera');

  const MotivoDiagnostico(this.slug, this.etiqueta);

  final String slug;
  final String etiqueta;

  static MotivoDiagnostico desdeSlug(String slug) => values.firstWhere(
    (motivo) => motivo.slug == slug,
    orElse: () => throw ArgumentError.value(
      slug,
      'slug',
      'Motivo de diagnóstico desconocido en la base de datos',
    ),
  );
}

/// Plan de la suscripción premium (FR-006, spec 004).
///
/// Ambos planes desbloquean exactamente lo mismo: cambian la forma de pago,
/// no el alcance premium.
enum PlanSuscripcion {
  mensual('mensual', 'Mensual'),
  anual('anual', 'Anual');

  const PlanSuscripcion(this.slug, this.etiqueta);

  final String slug;
  final String etiqueta;

  static PlanSuscripcion desdeSlug(String slug) => values.firstWhere(
    (plan) => plan.slug == slug,
    orElse: () => throw ArgumentError.value(
      slug,
      'slug',
      'Plan de suscripción desconocido en la base de datos',
    ),
  );
}

/// En qué situación está la suscripción premium según Google Play (spec 004).
///
/// `enGracia` concede acceso a propósito: es Google Play, no la app, quien
/// decide cuánto dura el margen tras un cobro fallido (FR-013). La app solo
/// refleja el estado que le informa.
enum SituacionSuscripcion {
  nunca('nunca', 'Nunca suscripto'),
  enPrueba('en_prueba', 'En prueba gratis'),
  activa('activa', 'Activa'),
  enGracia('en_gracia', 'Pago pendiente (en gracia)'),
  vencida('vencida', 'Vencida'),
  cancelada('cancelada', 'Cancelada');

  const SituacionSuscripcion(this.slug, this.etiqueta);

  final String slug;
  final String etiqueta;

  static SituacionSuscripcion desdeSlug(String slug) => values.firstWhere(
    (situacion) => situacion.slug == slug,
    orElse: () => throw ArgumentError.value(
      slug,
      'slug',
      'Situación de suscripción desconocida en la base de datos',
    ),
  );
}

/// Tipo de tarjeta (FR-059).
///
/// Solo las de crédito admiten deudas en cuotas (FR-061).
enum TipoTarjeta {
  debito('debito', 'Débito'),
  credito('credito', 'Crédito');

  const TipoTarjeta(this.slug, this.etiqueta);

  final String slug;
  final String etiqueta;

  bool get admiteCuotas => this == TipoTarjeta.credito;

  static TipoTarjeta desdeSlug(String slug) => values.firstWhere(
    (tipo) => tipo.slug == slug,
    orElse: () => throw ArgumentError.value(
      slug,
      'slug',
      'Tipo de tarjeta desconocido en la base de datos',
    ),
  );
}
