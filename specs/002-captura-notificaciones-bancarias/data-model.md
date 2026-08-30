# Phase 1 — Modelo de datos: Captura automática de consumos desde notificaciones bancarias

**Feature**: 002-captura-notificaciones-bancarias | **Fecha**: 2026-08-30

Deriva de las *Key Entities* de [spec.md](./spec.md) y de las decisiones D-N2, D-N3, D-N5, D-N6, D-N10 y D-N11 de [research.md](./research.md). Extiende el modelo de 001: un `ConsumoPendiente` confirmado se convierte en una `Transaccion` (o una `Deuda`, HU4) de esa especificación — esta feature no redefine esas entidades, solo agrega una antesala antes de que existan.

**Revisión 2026-08-30**: `OrigenCaptura` (enum cerrado de 4 valores) se reemplaza por `OrigenReconocido` (lista de datos, ampliable sin migración). Es el cambio que sigue a la decisión de un reconocimiento genérico en vez de un intérprete por banco (D-N2).

---

## 1. Valores nuevos (`lib/shared/constantes/`)

### `OrigenReconocido`

```dart
final class OrigenReconocido {
  final String paquete;   // p. ej. "com.bcp.bank.android" — a completar en implementación (D-N10)
  final String nombre;    // p. ej. "BCP" — el que ve el usuario
}

const List<OrigenReconocido> origenesReconocidos = [ /* ... */ ];
```

Conjunto **abierto por diseño** (FR-008a, D-N10): a diferencia de `Categoria` o `TipoTarjeta`, esto no es un `enum` — es una constante de datos sembrada con los 15 emisores de `EntidadesPeru` (001), que ya incluye Yape y Plin. Agregar un origen nuevo es agregar un elemento a esta lista, no una migración de esquema ni un tipo nuevo. Una notificación cuyo paquete no está en la lista nunca llega al parser genérico ni se guarda (edge case "app no reconocida en absoluto").

### `MotivoDiagnostico`

| Valor | Cuándo se usa |
|---|---|
| `formatoNoReconocido` | El origen es soportado pero el texto no coincide con ningún patrón conocido, o cambió (edge case "cambio de formato del banco"). |
| `montoIlegible` | Se reconoció que es un consumo, pero no se pudo extraer un monto válido. |
| `monedaExtranjera` | Se detectó una moneda distinta al sol (FR-014). |

No incluye "notificación que no es un consumo": esas se ignoran sin dejar rastro (FR-012), no son un fallo de interpretación.

---

## 2. Entidades persistidas

### `ConsumoPendiente`

Un consumo detectado y aún no confirmado (FR-020 a FR-028). Al confirmarse se convierte en `Transaccion` de 001 y la fila se borra; al descartarse, se borra sin dejar transacción.

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int` | Autoincremental. |
| `origenPaquete` | `String` | Paquete Android de la app de origen (FR-010) — clave hacia `OrigenReconocido.paquete`, no un enum cerrado. |
| `notificacionId` | `String` | Identificador nativo de la notificación de origen. Base de la deduplicación (D-N5, FR-015/FR-016) — **no** es una clave de negocio, solo evita duplicar la misma notificación reeditada. |
| `monto` | `Dinero` | `> 0`. Extraído sin pasar por `double` (D-N3). |
| `comercio` | `String` | Tal como lo informa el banco; el usuario puede corregirlo al confirmar. |
| `fecha` | `DateTime` | Fecha del consumo — la que lleva la `Transaccion` resultante (FR-026), no la de captura. |
| `categoriaPropuesta` | `Categoria?` | `null` si el comercio no tiene asociación aprendida (FR-033: confirmar exige elegir categoría en ese caso). |
| `capturadoEn` | `DateTime` | Cuándo llegó la notificación. Solo para ordenar y para "cantidad inusualmente alta" (FR-028); no se muestra como si fuera la fecha del gasto. |

**Invariante**: nunca existe sin haber pasado por el parser genérico (D-N2) y sin que su dirección se haya clasificado como saliente (D-N11) — no hay ruta de escritura que cree un pendiente con datos parciales (FR-017) ni con dinero entrante (FR-008b).

### `AsociacionComercio`

Vínculo aprendido comercio → categoría (FR-029 a FR-034).

| Campo | Tipo | Reglas |
|---|---|---|
| `comercioNormalizado` | `String` (PK) | Salida de `normalizarComercio()` (D-N7), no el texto crudo. |
| `categoria` | `Categoria` | |
| `actualizadoEn` | `DateTime` | Se reescribe cada vez que el usuario confirma ese comercio con una categoría distinta (FR-031). |

### `NotificacionDiagnostico`

Notificación de un origen soportado que no se pudo interpretar (FR-017, FR-018).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int` | Autoincremental. |
| `origenPaquete` | `String` | Igual que en `ConsumoPendiente` — el origen es sí reconocido (está en la lista), solo falló el texto puntual. |
| `motivo` | `MotivoDiagnostico` | |
| `textoCrudo` | `String` | El texto de la notificación, sin procesar. Es el único lugar de la app donde se guarda texto de notificación sin interpretar — consultable y borrable por el usuario (FR-018), nunca transmitido (FR-019). |
| `fecha` | `DateTime` | Cuándo llegó. |

### `Configuracion` (extiende la de 001)

| Campo nuevo | Tipo | Reglas |
|---|---|---|
| `capturaNotificacionesActiva` | `bool` | Interruptor de la app (FR-005), independiente del permiso del sistema — apagarlo no revoca el permiso de Android, solo hace que la app descarte lo que reciba. Por defecto `false`: la captura empieza inactiva hasta que el usuario la active a propósito (HU1). |

---

## 3. Derivados (nunca se guardan)

### `EstadoCaptura`

Combina el permiso real del sistema con el interruptor de la app — nunca se confía en "lo que el usuario aceptó antes" (FR-003).

| Campo | Descripción |
|---|---|
| `permisoConcedido` | Leído del sistema operativo en cada consulta, no cacheado. |
| `activaEnApp` | `configuracion.capturaNotificacionesActiva`. |
| `situacion` | Derivado: `sinPermiso` \| `permisoRevocado` (lo tuvo, ya no) \| `inactivaEnApp` \| `activa`. Cada uno tiene un texto explicativo, igual que `EstadoCierre` en 001 — ver contracts/repositorios.md. |
| `origenesQueCubre` | `origenesReconocidos` (D-N10) cuando `situacion == activa`; vacía en cualquier otro caso. Ya no es una lista fija de 4 — crece si se amplía `origenesReconocidos`. |

### `ResumenPendientes`

Lo que la bandeja muestra sin abrir cada fila (FR-022).

| Campo | Descripción |
|---|---|
| `cantidad` | `pendientes.length`. |
| `montoTotal` | Suma entera de `pendiente.monto`. |
| `esCantidadInusual` | `cantidad > umbral` (FR-028). El umbral es una constante de dominio, no configurable — no hay requisito que pida ajustarlo. |

---

## 4. Esquema SQL — migración incremental

Seguridad de 001 (D10): `onUpgrade` agrega tablas y columnas, nunca destruye. Este es el paso que sube `user_version` a la siguiente versión.

```sql
CREATE TABLE consumo_pendiente (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  origen_paquete      TEXT    NOT NULL CHECK (length(trim(origen_paquete)) > 0),
  notificacion_id     TEXT    NOT NULL,
  monto_centavos      INTEGER NOT NULL CHECK (monto_centavos > 0),
  comercio            TEXT    NOT NULL,
  fecha               TEXT    NOT NULL,
  categoria_propuesta TEXT,
  capturado_en        TEXT    NOT NULL
);

-- La deduplicación (D-N5) se apoya en esta unicidad: un mismo origen +
-- notificacion_id nunca produce una segunda fila.
CREATE UNIQUE INDEX idx_pendiente_notificacion
  ON consumo_pendiente(origen_paquete, notificacion_id);

CREATE INDEX idx_pendiente_fecha ON consumo_pendiente(fecha DESC);

CREATE TABLE comercio_categoria (
  comercio_normalizado TEXT PRIMARY KEY,
  categoria            TEXT NOT NULL,
  actualizado_en        TEXT NOT NULL
);

CREATE TABLE notificacion_diagnostico (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  origen_paquete TEXT NOT NULL CHECK (length(trim(origen_paquete)) > 0),
  motivo         TEXT NOT NULL CHECK (motivo IN ('formato_no_reconocido','monto_ilegible','moneda_extranjera')),
  texto_crudo    TEXT NOT NULL,
  fecha          TEXT NOT NULL
);

CREATE INDEX idx_diagnostico_fecha ON notificacion_diagnostico(fecha DESC);

ALTER TABLE configuracion
  ADD COLUMN captura_notificaciones_activa INTEGER NOT NULL DEFAULT 0
  CHECK (captura_notificaciones_activa IN (0, 1));
```

**Por qué `origen_paquete` ya no lleva un `CHECK ... IN (...)`**: con un enum cerrado de 4 bancos, restringir los valores en SQL documentaba la garantía. Con `OrigenReconocido` como lista de datos ampliable (D-N10), un `CHECK` fijo obligaría a una migración de esquema cada vez que se agregue un banco — exactamente lo que esta revisión busca evitar. La garantía de "solo orígenes reconocidos llegan a la base" la sostiene el filtro en `servicio_escucha.dart` antes de escribir, no una restricción de SQL.

**Por qué `notificacion_id` es `TEXT`**: el identificador que expone el plugin de Android no está garantizado como numérico (puede incluir el paquete o una clave compuesta). Guardarlo como texto evita una conversión que podría truncar o fallar silenciosamente.
