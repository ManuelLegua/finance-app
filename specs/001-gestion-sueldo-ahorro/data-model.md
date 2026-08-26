# Phase 1 — Modelo de datos: Gestión de sueldo, gasto real, deudas y ahorro

**Feature**: 001-gestion-sueldo-ahorro | **Fecha**: 2026-08-26

Deriva de las *Key Entities* de [spec.md](./spec.md) y de las decisiones D2–D5 de [research.md](./research.md). Distingue tres planos: **valores** (tipos transversales sin identidad), **entidades persistidas** (lo que hay en SQLite) y **derivados** (lo que el dominio calcula y nunca se guarda).

---

## 1. Valores (`lib/core/`)

### `Dinero`

Envuelve un `int centavos`. Inmutable.

| Miembro | Descripción |
|---|---|
| `centavos` | Entero con signo. Único estado. |
| `Dinero.cero`, `Dinero.deCentavos(int)`, `Dinero.deSoles(int, int)` | Constructores. No existe constructor desde `double`. |
| `+`, `-`, `unary-` | Aritmética entera exacta. |
| `porPuntosBase(int bp)` | `centavos * bp / 10000` con redondeo half-up entero. Base del ahorro por porcentaje. |
| `<`, `<=`, `>`, `>=`, `compareTo` | Orden total. |
| `esCero`, `esNegativo`, `esPositivo` | Predicados usados por las reglas de déficit. |
| `abs()` | Magnitud, para expresar faltantes y excesos en positivo. |

**Invariantes**: nunca se construye desde `double`; ninguna operación devuelve `double`. Los montos guardados por el usuario son `>= 0` (FR-005); los derivados (disponible, diferencia) pueden ser negativos.

### `Mes`

| Miembro | Descripción |
|---|---|
| `anio`, `mes` (1–12) | Componentes. |
| `ordinal` | `anio * 12 + (mes - 1)`. Clave de persistencia y base de la aritmética (D5). |
| `Mes.deOrdinal(int)`, `Mes.deFecha(DateTime)`, `Mes.actual()` | Constructores. |
| `siguiente`, `anterior`, `mas(int n)`, `diferencia(Mes otro)` | Aritmética de meses. |
| `compareTo`, `==`, `hashCode` | Orden cronológico = orden numérico del ordinal. |

**Invariante**: `1 <= mes <= 12`; se valida al construir.

### Enumeraciones

| Enum | Valores | Persistencia |
|---|---|---|
| `Categoria` | `tarjetaCredito`, `departamento`, `servicios`, `pasajes`, `comida`, `otros` (FR-003) | `TEXT` con el slug (`tarjeta_credito`, …). Conjunto cerrado: un slug desconocido al leer es un error de datos, no un valor nuevo. |
| `TipoTarjeta` | `debito`, `credito` (FR-059) | `TEXT` (`debito` \| `credito`). |
| `TipoObligacion` | `fija`, `variable` (FR-004) | `TEXT` (`fija` \| `variable`). |
| `ReglaAhorro` | `porcentajeIngreso`, `remanente` (FR-031) | `TEXT` (`porcentaje` \| `remanente`). |

### `FormatoSoles`

`String formatear(Dinero)` → `S/ 1,234.56`: signo, símbolo `S/`, separador de miles `,`, separador decimal `.`, siempre dos decimales (FR-048). Opera sobre el entero, sin `double` (D2). Soporta hasta siete cifras enteras sin desbordar (edge case "montos grandes").

---

## 2. Entidades persistidas

### `Ingreso`
Un ingreso por mes (Assumption "un ingreso por mes"). La ausencia de fila **no** es cero: significa "mes sin ingreso registrado" (FR-001, escenario 4 de la HU2).

| Campo | Tipo | Reglas |
|---|---|---|
| `mes` | `Mes` (PK) | Identifica la fila. |
| `monto` | `Dinero` | `> 0` al guardar. |

### `Obligacion`
Partida presupuestada del mes (FR-002).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int` | Autoincremental. |
| `mes` | `Mes` | A qué mes pertenece. |
| `nombre` | `String` | No vacío. |
| `categoria` | `Categoria` | |
| `monto` | `Dinero` | `> 0` (FR-005). |
| `tipo` | `TipoObligacion` | `fija` habilita la precarga del mes siguiente (FR-006). |

**Nota**: no se registran obligaciones en la categoría `tarjetaCredito` a mano; ese compromiso lo derivan las deudas (Assumption "las deudas son la fuente de la categoría tarjeta de crédito"). La UI lo impide; el dominio lo trata como dato inconsistente si aparece.

### `Transaccion`
Gasto real (FR-007). Es el registro de la realidad, frente a la obligación que es la previsión.

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int` | Autoincremental. |
| `fecha` | `DateTime` (solo fecha, sin hora) | Determina el mes: `Mes.deFecha(fecha)` (FR-008). |
| `mesOrdinal` | `int` | **Derivado de `fecha`**, persistido solo como índice de consulta. Nunca se edita por separado. |
| `categoria` | `Categoria` | Puede no tener presupuesto en el mes (FR-012). |
| `monto` | `Dinero` | `> 0`. |
| `descripcion` | `String` | Corta; puede quedar vacía. |

### `Tarjeta`
Medio de pago (FR-059). Las de crédito agrupan deudas para consolidar el compromiso mensual (FR-017).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int` | Autoincremental. |
| `nombre` | `String` | No vacío, único. Ej. "BCP Visa Clásica". |
| `entidad` | `String` | Entidad emisora. Se elige de `EntidadesPeru` (ver abajo) o se escribe libremente (FR-060). |
| `tipo` | `TipoTarjeta` | `debito` \| `credito`. Solo `credito` admite deudas en cuotas (FR-061). |

**`EntidadesPeru`**: lista constante en `lib/dominio/modelos/entidades.dart` con los emisores peruanos habituales — BCP, Interbank, BBVA, Scotiabank, Banco Falabella, Banco Ripley, Banco Pichincha, BanBif, Mibanco, Banco de la Nación, Caja Arequipa, Caja Huancayo, Oh! (SIP), Yape, Plin. **No se consulta ninguna API**: no existe un endpoint público confiable para el Perú (la SBS y el BCRP publican portales web, no servicios para desarrolladores) y el conjunto cambia muy rara vez. Vive en el código, funciona sin conexión y respeta el Principio I.

**No se almacenan tasas de interés, TEA ni comisiones.** Ver Assumption "Sin tasas de interés" y FR-024.

### `Deuda`
Compra financiada en cuotas (FR-015). **No genera filas por cuota** (D3).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int` | Autoincremental. |
| `descripcion` | `String` | No vacía. |
| `tarjetaId` | `int` | FK → `tarjeta.id`. |
| `cuotaMensual` | `Dinero` | `> 0`. Es el monto que informa el banco; la app no calcula intereses (FR-024). |
| `numCuotas` | `int` | `>= 1` (edge case "deuda de una sola cuota"). |
| `mesInicio` | `Mes` | Primer mes que aporta cuota. Puede ser futuro (FR-020). |
| `mesSaldadaAnticipada` | `Mes?` | `null` mientras siga vigente. Al fijarse, cesan las cuotas de ese mes en adelante y el saldo pasa a cero (FR-021). |

### `AporteAhorro`
Dinero efectivamente apartado (FR-038).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int` | Autoincremental. |
| `fecha` | `DateTime` (solo fecha) | Determina el mes del aporte. |
| `mesOrdinal` | `int` | Derivado de `fecha`, persistido como índice. |
| `monto` | `Dinero` | `> 0`. Puede exceder el disponible (FR-042). |

### `Configuracion`
Fila única (`id = 1`) con los ajustes de la app. La **regla** de ahorro es global; la meta no.

| Campo | Tipo | Reglas |
|---|---|---|
| `regla` | `ReglaAhorro` | FR-031. |
| `porcentajeBp` | `int` | Puntos base, `0..10000`. Solo aplica con `porcentajeIngreso` (FR-032). |
| `diasGraciaCierre` | `int` | Días desde el inicio del mes durante los que aún se puede registrar en el mes anterior. `0..28`, por defecto `5` (FR-055). |

### `MetaAhorro`
Meta propia de un mes (FR-035). La ausencia de fila significa "mes sin meta fijada", y entonces no hay veredicto de progreso (edge case "meta no fijada"). Un mes pasado conserva la meta que regía entonces, no la vigente hoy (FR-054).

| Campo | Tipo | Reglas |
|---|---|---|
| `mes` | `Mes` (PK) | Identifica la fila. |
| `monto` | `Dinero` | `> 0` al guardar. |

Al abrir un mes sin meta, la app **propone** la del último mes que tuvo una, sin guardarla hasta que el usuario confirme (FR-053). Es el mismo criterio que la precarga de obligaciones fijas: nunca escribir en silencio.

---

## 3. Derivados (calculados, nunca persistidos)

### `ResumenMes` (FR-025 – FR-030)

| Campo | Fórmula |
|---|---|
| `ingreso` | Monto del `Ingreso` del mes, o ausente. |
| `totalComprometido` | Σ obligaciones del mes + Σ cuotas vigentes del mes (D3). |
| `gastoRealTotal` | Σ transacciones del mes. |
| `disponibleProyectado` | `ingreso - totalComprometido` (FR-026). |
| `disponibleReal` | `ingreso - gastoRealTotal` (FR-027). |
| `enDeficit` | `totalComprometido > ingreso`. Cero exacto **no** es déficit (FR-030). |
| `faltante` | `(ingreso - totalComprometido).abs()` cuando `enDeficit`, si no cero. |
| `ingresoRegistrado` | `false` si no hay fila de ingreso: la UI pide registrarlo en vez de mostrar ceros (HU2, escenario 4). |

### `LineaCategoria` (FR-010 – FR-012, FR-044 – FR-047)

Una por categoría con presupuesto o gasto en el mes; las que no tienen ni uno ni otro se omiten (FR-047).

| Campo | Fórmula |
|---|---|
| `categoria` | |
| `presupuestado` | Σ obligaciones de esa categoría + cuotas vigentes si es `tarjetaCredito`. |
| `gastado` | Σ transacciones de esa categoría en el mes. |
| `diferencia` | `presupuestado - gastado`; negativa = sobregiro. |
| `sobregirada` | `gastado > presupuestado` y hay presupuesto (FR-011). |
| `noPresupuestada` | `presupuestado == 0` y `gastado > 0` (FR-012). |
| `pesoIngresoBp` | Peso sobre el ingreso en puntos base, entero (FR-045). |

**Invariante verificable**: Σ `gastado` de todas las líneas == `ResumenMes.gastoRealTotal`, exacto al centavo (FR-046). Se garantiza porque todo es suma entera.

### `EstadoDeuda` (FR-018 – FR-022)

Se calcula respecto de un mes de referencia `mesRef` (normalmente el mes en curso).

| Campo | Fórmula |
|---|---|
| `cuotasPagadas` | `mesRef - mesInicio`, acotado a `0..numCuotas` (D4). Cero si está saldada anticipadamente antes de empezar. |
| `cuotasRestantes` | `numCuotas - cuotasPagadas`, o `0` si saldada. |
| `saldoPendiente` | `cuotaMensual * cuotasRestantes`, o `Dinero.cero` si saldada (FR-021). |
| `mesUltimaCuota` | `mesInicio.mas(numCuotas - 1)`. |
| `estado` | `futura` \| `vigente` \| `saldada` (ver §4). |
| `aportaCuotaA(Mes m)` | `mesInicio <= m <= mesUltimaCuota` y (`mesSaldadaAnticipada == null` o `m < mesSaldadaAnticipada`). |

### `PanoramaDeuda` (FR-022)

Agregado de todas las deudas: `totalAdeudado` (Σ saldos pendientes, incluidas las de inicio futuro — FR-020), `compromisoMensual` (Σ cuotas vigentes del mes en curso), `mesLibreDeDeudas` (máximo `mesUltimaCuota` entre las no saldadas; ausente si no hay deudas activas, y entonces la vista comunica el estado libre de deuda).

### `SugerenciaAhorro` (FR-033, FR-034, FR-037)

| Campo | Fórmula |
|---|---|
| `montoSugerido` | Según `regla`: `ingreso.porPuntosBase(porcentajeBp)` o `disponibleProyectado`. |
| `montoAlcanzable` | `min(montoSugerido, disponibleProyectado)`, nunca negativo (FR-034). |
| `excedeDisponible` | `montoSugerido > disponibleProyectado`. |
| `noCorresponde` | `true` en déficit: se suprime la sugerencia (FR-037). También si no hay ingreso registrado. |

### `ProgresoAhorro` (FR-035, FR-036, FR-039 – FR-043, FR-054)

| Campo | Fórmula |
|---|---|
| `ahorradoMes` | Σ aportes del mes (FR-039). |
| `meta` | La `MetaAhorro` **de ese mes**, o `null` si el mes no tiene meta. |
| `pendiente` / `excedente` | `meta - ahorradoMes` según el signo (FR-040). |
| `metaAlcanzable` | `meta <= disponibleProyectado` (FR-035). |
| `recorteNecesario` | `meta - disponibleProyectado` cuando no es alcanzable (FR-036). |
| `acumuladoHistorico` | Σ de todos los aportes de todos los meses (FR-041). |
| `historialPorMes` | Un renglón por mes registrado con **su propia meta** y lo ahorrado; los meses sin aportes figuran con `S/ 0.00`, no como meta cumplida (FR-043); los meses sin meta figuran sin veredicto (FR-054). |

### `EstadoCierre` (FR-052, FR-055 – FR-058)

Derivado de la fecha de hoy y de `Configuracion.diasGraciaCierre`. Ningún dato de cierre se persiste: el estado de un mes se calcula.

| Campo | Fórmula |
|---|---|
| `abierto` | El mes es el mes en curso. Se puede crear, editar y eliminar libremente. |
| `enGracia` | El mes es el anterior al actual **y** el día de hoy es `<= diasGraciaCierre`. Se puede **registrar**, no editar ni eliminar (FR-055). |
| `cerrado` | Cualquier otro mes pasado. Solo lectura absoluta (FR-052). |
| `motivo` | Texto explícito de por qué no se puede modificar, para mostrar sin depender del color (FR-058). |

**Inmutabilidad de lo registrado en gracia** (FR-056): una transacción o aporte cuyo mes no es el mes en curso queda inmutable en el instante en que se guarda. No hace falta una marca en la fila: se deduce comparando el mes del registro con el mes actual.

**Excepción por deudas** (FR-057): editar una `Deuda` está siempre permitido y recalcula las cuotas derivadas de todos los meses, cerrados incluidos. No es una edición del mes: la cuota nunca fue un dato del mes, siempre fue un derivado de la deuda (D3). Es la única vía de corrección sobre un mes cerrado.

### `PropuestaMeta` (FR-053)

Al abrir un mes sin meta: `montoPropuesto` = meta del último mes anterior que tuvo una, o `null` si ninguno la tuvo. Es una sugerencia para el formulario, nunca una escritura.

---

## 4. Transiciones de estado

### Deuda, respecto de un mes de referencia

```
                         mesRef < mesInicio
        [ futura ] ─────────────────────────────┐
             │                                  │  no aporta al presupuesto del mes,
             │ llega mesInicio                  │  sí al total adeudado (FR-020)
             ▼                                  │
        [ vigente ] ◄───────────────────────────┘
             │  aporta cuotaMensual a cada mes en [mesInicio, mesUltimaCuota]
             │
     ┌───────┴────────────────────────┐
     │ pasa mesUltimaCuota            │ el usuario la marca saldada
     ▼                                ▼
[ saldada por término ]        [ saldada anticipadamente ]
  FR-019: deja de aportar        FR-021: cesan las cuotas desde
  cuotas al mes siguiente        mesSaldadaAnticipada; saldo = 0
```

Ambos estados finales dejan `saldoPendiente = Dinero.cero` y `aportaCuotaA(m) = false` para todo mes posterior. La diferencia es solo informativa (cuántas cuotas llegaron a pagarse).

### Mes

`sin datos` → `con ingreso` → `presupuestado` → `en seguimiento` (hay transacciones). No es una máquina de estados persistida: se infiere de qué filas existen. Al abrir un mes sin datos, la app ofrece precargar las obligaciones fijas del anterior (FR-006) y carga las cuotas vigentes sin preguntar (edge case "mes sin datos").

---

## 5. Esquema SQLite (versión 1)

`PRAGMA user_version = 1`. Todos los montos son enteros de centavos; todos los meses, ordinales enteros (D5).

```sql
CREATE TABLE ingreso (
  mes_ordinal     INTEGER PRIMARY KEY,
  monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
);

CREATE TABLE obligacion (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  mes_ordinal     INTEGER NOT NULL,
  nombre          TEXT    NOT NULL CHECK (length(trim(nombre)) > 0),
  categoria       TEXT    NOT NULL,
  monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0),
  tipo            TEXT    NOT NULL CHECK (tipo IN ('fija','variable'))
);
CREATE INDEX idx_obligacion_mes ON obligacion(mes_ordinal);

CREATE TABLE transaccion (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha           TEXT    NOT NULL,           -- 'YYYY-MM-DD'
  mes_ordinal     INTEGER NOT NULL,           -- derivado de fecha
  categoria       TEXT    NOT NULL,
  monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0),
  descripcion     TEXT    NOT NULL DEFAULT ''
);
CREATE INDEX idx_transaccion_mes ON transaccion(mes_ordinal, fecha DESC);

CREATE TABLE tarjeta (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre   TEXT NOT NULL UNIQUE CHECK (length(trim(nombre)) > 0),
  entidad  TEXT NOT NULL CHECK (length(trim(entidad)) > 0),
  tipo     TEXT NOT NULL CHECK (tipo IN ('debito','credito'))
);

CREATE TABLE deuda (
  id                       INTEGER PRIMARY KEY AUTOINCREMENT,
  descripcion              TEXT    NOT NULL CHECK (length(trim(descripcion)) > 0),
  tarjeta_id               INTEGER NOT NULL REFERENCES tarjeta(id),
  cuota_centavos           INTEGER NOT NULL CHECK (cuota_centavos > 0),
  num_cuotas               INTEGER NOT NULL CHECK (num_cuotas >= 1),
  mes_inicio_ordinal       INTEGER NOT NULL,
  mes_saldada_ordinal      INTEGER                  -- NULL mientras siga vigente
);
CREATE INDEX idx_deuda_tarjeta ON deuda(tarjeta_id);

CREATE TABLE aporte_ahorro (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha           TEXT    NOT NULL,           -- 'YYYY-MM-DD'
  mes_ordinal     INTEGER NOT NULL,
  monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
);
CREATE INDEX idx_aporte_mes ON aporte_ahorro(mes_ordinal);

CREATE TABLE configuracion (
  id                   INTEGER PRIMARY KEY CHECK (id = 1),
  regla                TEXT    NOT NULL CHECK (regla IN ('porcentaje','remanente')),
  porcentaje_bp        INTEGER NOT NULL DEFAULT 2000 CHECK (porcentaje_bp BETWEEN 0 AND 10000),
  dias_gracia_cierre   INTEGER NOT NULL DEFAULT 5   CHECK (dias_gracia_cierre BETWEEN 0 AND 28)
);

CREATE TABLE meta_ahorro (
  mes_ordinal     INTEGER PRIMARY KEY,          -- sin fila = mes sin meta fijada
  monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
);
```

`PRAGMA foreign_keys = ON` en cada apertura de conexión (SQLite no lo activa por defecto).

**Convenciones**:
- Los `CHECK` duplican a propósito validaciones que el dominio ya aplica: son la última línea contra datos corruptos, no el mecanismo de validación de cara al usuario. Los mensajes que ve el usuario los produce el dominio (FR-005).
- `mes_ordinal` en `transaccion` y `aporte_ahorro` se calcula al escribir a partir de `fecha`; ninguna ruta de escritura los deja divergir.

---

## 6. Trazabilidad requisito → modelo

| Grupo de requisitos | Dónde se resuelve |
|---|---|
| FR-001 – FR-006 (ingreso y presupuesto) | `Ingreso`, `Obligacion`, precarga de fijas |
| FR-007 – FR-014 (gasto real) | `Transaccion`, `LineaCategoria` |
| FR-015 – FR-024 (deudas) | `Deuda`, `EstadoDeuda`, `PanoramaDeuda` |
| FR-025 – FR-030 (resumen y déficit) | `ResumenMes` |
| FR-031 – FR-043, FR-053, FR-054 (ahorro) | `Configuracion`, `MetaAhorro`, `AporteAhorro`, `SugerenciaAhorro`, `ProgresoAhorro`, `PropuestaMeta` |
| FR-044 – FR-047 (desglose) | `LineaCategoria` |
| FR-048 – FR-051 (presentación y persistencia) | `Dinero`, `FormatoSoles`, esquema §5, migraciones (D10) |
| FR-052, FR-055 – FR-058 (cierre de meses) | `EstadoCierre`, `Configuracion.diasGraciaCierre` |
| FR-059 – FR-061 (tarjetas) | `Tarjeta`, `TipoTarjeta`, `EntidadesPeru` |
