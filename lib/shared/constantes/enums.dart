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
  static List<Categoria> get presupuestables =>
      values.where((c) => c != Categoria.tarjetaCredito).toList();

  static Categoria desdeSlug(String slug) => values.firstWhere(
        (c) => c.slug == slug,
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
        (t) => t.slug == slug,
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
        (r) => r.slug == slug,
        orElse: () => throw ArgumentError.value(
          slug,
          'slug',
          'Regla de ahorro desconocida en la base de datos',
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
        (t) => t.slug == slug,
        orElse: () => throw ArgumentError.value(
          slug,
          'slug',
          'Tipo de tarjeta desconocido en la base de datos',
        ),
      );
}
