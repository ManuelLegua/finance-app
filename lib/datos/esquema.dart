/// DDL de la base de datos local. Ver `data-model.md` §5.
///
/// Dos convenciones que atraviesan todo el esquema:
///
///  - **Los montos son `INTEGER` de centavos, jamás `REAL`** (Principio II).
///  - **Los meses son ordinales enteros** `anio * 12 + (mes - 1)` (D5), lo
///    que hace que el orden cronológico sea el orden numérico y que la
///    aritmética de vigencia de cuotas sea suma y resta.
///
/// Los `CHECK` duplican a propósito validaciones que el dominio ya aplica:
/// son la última línea contra datos corruptos, no el mecanismo de validación
/// de cara al usuario. Los mensajes que el usuario lee los produce el dominio.
abstract final class Esquema {
  /// Versión actual. Cada cambio incrementa esto y agrega un paso en
  /// `migraciones.dart`.
  static const int version = 2;

  static const List<String> creacion = <String>[
    _ingreso,
    _obligacion,
    _indiceObligacionMes,
    _transaccion,
    _indiceTransaccionMes,
    _tarjeta,
    _deuda,
    _indiceDeudaTarjeta,
    _aporteAhorro,
    _indiceAporteMes,
    _metaAhorro,
    _configuracion,
    consumoPendiente,
    indicePendienteNotificacion,
    indicePendienteFecha,
    comercioCategoria,
    notificacionDiagnostico,
    indiceDiagnosticoFecha,
  ];

  static const String _ingreso = '''
    CREATE TABLE ingreso (
      mes_ordinal     INTEGER PRIMARY KEY,
      monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
    )
  ''';

  static const String _obligacion = '''
    CREATE TABLE obligacion (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      mes_ordinal     INTEGER NOT NULL,
      nombre          TEXT    NOT NULL CHECK (length(trim(nombre)) > 0),
      categoria       TEXT    NOT NULL,
      monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0),
      tipo            TEXT    NOT NULL CHECK (tipo IN ('fija','variable'))
    )
  ''';

  static const String _indiceObligacionMes =
      'CREATE INDEX idx_obligacion_mes ON obligacion(mes_ordinal)';

  /// `mes_ordinal` se deriva de `fecha` en toda ruta de escritura; existe
  /// como columna para poder indexar las consultas por mes (FR-008).
  static const String _transaccion = '''
    CREATE TABLE transaccion (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha           TEXT    NOT NULL,
      mes_ordinal     INTEGER NOT NULL,
      categoria       TEXT    NOT NULL,
      monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0),
      descripcion     TEXT    NOT NULL DEFAULT ''
    )
  ''';

  static const String _indiceTransaccionMes =
      'CREATE INDEX idx_transaccion_mes ON transaccion(mes_ordinal, fecha DESC)';

  static const String _tarjeta = '''
    CREATE TABLE tarjeta (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      nombre   TEXT NOT NULL UNIQUE CHECK (length(trim(nombre)) > 0),
      entidad  TEXT NOT NULL CHECK (length(trim(entidad)) > 0),
      tipo     TEXT NOT NULL CHECK (tipo IN ('debito','credito'))
    )
  ''';

  /// **No existe tabla de cuotas** (D3). Las cuotas de cada mes se derivan de
  /// estas filas. Crear una tabla de cuotas rompería el recálculo retroactivo
  /// que exige FR-023.
  static const String _deuda = '''
    CREATE TABLE deuda (
      id                   INTEGER PRIMARY KEY AUTOINCREMENT,
      descripcion          TEXT    NOT NULL CHECK (length(trim(descripcion)) > 0),
      tarjeta_id           INTEGER NOT NULL REFERENCES tarjeta(id),
      cuota_centavos       INTEGER NOT NULL CHECK (cuota_centavos > 0),
      num_cuotas           INTEGER NOT NULL CHECK (num_cuotas >= 1),
      mes_inicio_ordinal   INTEGER NOT NULL,
      mes_saldada_ordinal  INTEGER
    )
  ''';

  static const String _indiceDeudaTarjeta =
      'CREATE INDEX idx_deuda_tarjeta ON deuda(tarjeta_id)';

  static const String _aporteAhorro = '''
    CREATE TABLE aporte_ahorro (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      fecha           TEXT    NOT NULL,
      mes_ordinal     INTEGER NOT NULL,
      monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
    )
  ''';

  static const String _indiceAporteMes =
      'CREATE INDEX idx_aporte_mes ON aporte_ahorro(mes_ordinal)';

  /// La meta es por mes, no global (D12). La ausencia de fila significa "mes
  /// sin meta fijada", que es distinto de "meta en cero".
  static const String _metaAhorro = '''
    CREATE TABLE meta_ahorro (
      mes_ordinal     INTEGER PRIMARY KEY,
      monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
    )
  ''';

  static const String _configuracion = '''
    CREATE TABLE configuracion (
      id                              INTEGER PRIMARY KEY CHECK (id = 1),
      regla                           TEXT    NOT NULL CHECK (regla IN ('porcentaje','remanente')),
      porcentaje_bp                   INTEGER NOT NULL DEFAULT 2000
                                        CHECK (porcentaje_bp BETWEEN 0 AND 10000),
      dias_gracia_cierre              INTEGER NOT NULL DEFAULT 5
                                        CHECK (dias_gracia_cierre BETWEEN 0 AND 28),
      captura_notificaciones_activa   INTEGER NOT NULL DEFAULT 0
                                        CHECK (captura_notificaciones_activa IN (0, 1))
    )
  ''';

  // --- Spec 002: captura de notificaciones bancarias. Ver data-model.md §4. ---

  /// `origen_paquete` no lleva `CHECK ... IN (...)`: la lista de orígenes
  /// reconocidos es datos, no un enum cerrado (D-N10) — un `CHECK` fijo
  /// forzaría una migración cada vez que se agregue un banco, justo lo que
  /// ese diseño busca evitar.
  ///
  /// Público (sin `_`), a diferencia del resto del esquema: `Migraciones` lo
  /// reutiliza para el paso que sube una base ya existente de la versión 1
  /// a la 2, y duplicar el DDL a mano en dos archivos es exactamente el tipo
  /// de cosa que se desincroniza sin que nadie lo note.
  static const String consumoPendiente = '''
    CREATE TABLE consumo_pendiente (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      origen_paquete      TEXT    NOT NULL CHECK (length(trim(origen_paquete)) > 0),
      notificacion_id     TEXT    NOT NULL,
      monto_centavos      INTEGER NOT NULL CHECK (monto_centavos > 0),
      comercio            TEXT    NOT NULL,
      fecha               TEXT    NOT NULL,
      categoria_propuesta TEXT,
      capturado_en        TEXT    NOT NULL
    )
  ''';

  /// Sostiene la deduplicación (D-N5): un mismo origen + notificación nunca
  /// produce una segunda fila.
  static const String indicePendienteNotificacion =
      'CREATE UNIQUE INDEX idx_pendiente_notificacion '
      'ON consumo_pendiente(origen_paquete, notificacion_id)';

  static const String indicePendienteFecha =
      'CREATE INDEX idx_pendiente_fecha ON consumo_pendiente(fecha DESC)';

  static const String comercioCategoria = '''
    CREATE TABLE comercio_categoria (
      comercio_normalizado TEXT PRIMARY KEY,
      categoria             TEXT NOT NULL,
      actualizado_en        TEXT NOT NULL
    )
  ''';

  static const String notificacionDiagnostico = '''
    CREATE TABLE notificacion_diagnostico (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      origen_paquete TEXT NOT NULL CHECK (length(trim(origen_paquete)) > 0),
      motivo         TEXT NOT NULL CHECK (motivo IN ('formato_no_reconocido','monto_ilegible','moneda_extranjera')),
      texto_crudo    TEXT NOT NULL,
      fecha          TEXT NOT NULL
    )
  ''';

  static const String indiceDiagnosticoFecha =
      'CREATE INDEX idx_diagnostico_fecha ON notificacion_diagnostico(fecha DESC)';

  /// Solo para el paso de migración v1→v2 (`migraciones.dart`): una base
  /// nueva ya crea `configuracion` con la columna incluida (arriba).
  static const String alterConfiguracionCaptura =
      'ALTER TABLE configuracion '
      'ADD COLUMN captura_notificaciones_activa INTEGER NOT NULL DEFAULT 0 '
      'CHECK (captura_notificaciones_activa IN (0, 1))';
}
