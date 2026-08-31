# Phase 0 — Research: Cobros parciales de ingreso

**Feature**: 003-cobros-parciales-ingreso | **Fecha**: 2026-08-30

**Depende de**: 001-gestion-sueldo-ahorro (`Dinero`, `Mes`, `EstadoMes`, `AporteAhorro` como patrón a seguir) y de la constitución v2.0.0.

---

## D-C1 — `CobroIngreso` es un par (fecha, monto), sin nombre ni etiqueta

**Decisión**: `CobroIngreso` replica exactamente la forma de `AporteAhorro` (spec 001) — `id`, `fecha` (`DateTime`, solo fecha) y `monto` (`Dinero`), con `mes` derivado de `fecha` vía `Mes.deFecha`. Sin campo de descripción ni de tipo ("quincena", "fin de mes").

**Rationale**: la propia spec lo pide explícitamente en *Assumptions* — "no se agrega un campo de descripción porque ningún escenario lo pide" — y ya existe un modelo idéntico en forma y en reglas (`AporteAhorro`) que resuelve el mismo problema: "un monto de dinero que ocurrió en una fecha, agrupado por mes". Copiar su forma en vez de inventar una nueva mantiene el mismo lenguaje en toda la app: quien entienda `AporteAhorro` entiende `CobroIngreso` sin releer nada.

**Alternativas consideradas**:
- **Un campo `etiqueta` opcional** ("quincena", "fin de mes"): rechazado por Principio V — ningún acceptance scenario ni edge case de la spec lo pide, y agregar un campo nunca usado es la clase de especulación que YAGNI descarta.
- **Reutilizar `AporteAhorro` con un flag `esIngreso`**: rechazado — mezclaría dos entidades de dominio distinto (lo que entra vs. lo que se aparta) en una tabla y un modelo, lo que obligaría a filtrar por flag en cada consulta y perdería la garantía de tipos de tener una clase por concepto.

---

## D-C2 — Migración v2→v3: aditiva, sin borrar `ingreso`

**Decisión**: el paso de migración crea `cobro_ingreso` y copia cada fila de `ingreso` como un `CobroIngreso` con fecha el primer día de ese mes (`Assumptions` de la spec), vía una única sentencia `INSERT INTO ... SELECT` en SQL puro (sin recorrer filas desde Dart):

```sql
INSERT INTO cobro_ingreso (fecha, mes_ordinal, monto_centavos)
SELECT
  printf('%04d-%02d-01', mes_ordinal / 12, mes_ordinal % 12 + 1),
  mes_ordinal,
  monto_centavos
FROM ingreso;
```

La tabla `ingreso` **no se borra** después de copiar sus datos. Queda en el esquema, sin que ninguna ruta de la app vuelva a leerla ni escribirla.

**Rationale**: `migraciones.dart` ya documenta la regla en su propio comentario — "nunca borra ni recrea tablas con datos" — precisamente porque la spec no tiene backup ni exportación (D14... o el equivalente de esta feature: sin respaldo, todo lo irreversible es definitivo). Esa regla no distingue entre "tabla que la app sigue usando" y "tabla que la app dejó de usar": borrar `ingreso` después de copiarla sería tan irreversible como borrarla antes, y el único beneficio sería una fila menos en `esquema.dart`. El riesgo (un `INSERT ... SELECT` con un error sutil, detectado después de que el `DROP TABLE` ya corrió) no tiene contrapartida que lo justifique.

**Por qué SQL puro y no un recorrido en Dart**: todas las migraciones anteriores (`v1→v2` de 002) son listas de sentencias SQL aplicadas con `conexion.execute()`, sin lógica Dart intermedia. La transformación fecha-desde-`mes_ordinal` es aritmética simple (`anio = mes_ordinal / 12`, `mes = mes_ordinal % 12 + 1`) que SQLite resuelve con `printf`, así que no hace falta romper ese patrón ni añadir una ruta de migración distinta a la que ya existe y ya está probada.

**Alternativas consideradas**:
- **Borrar `ingreso` tras copiarla**: rechazada por el argumento de arriba — cero beneficio, riesgo real.
- **Migrar sin fecha, dejando `fecha` nula**: rechazada — `CobroIngreso.fecha` es `DateTime` no nulo (D-C1, mismo contrato que `AporteAhorro`); inventar un sentinel rompería el invariante del tipo para un solo caso de origen.
- **Migración procedural en Dart** (leer filas de `ingreso`, componer `CobroIngreso` uno por uno, insertar): funciona igual, pero introduce una segunda forma de migrar sin necesidad — la aritmética cabe entera en SQL.

---

## D-C3 — El total del mes sigue siendo derivado, ahora por una función pura nueva

**Decisión**: `totalIngreso(List<CobroIngreso> cobros) -> Dinero?` en `lib/dominio/calculos/ingreso.dart`. `null` si `cobros` está vacía; si no, la suma entera de los montos. `EstadoMes.ingreso` pasa de ser un campo cacheado que se lee del repositorio a un getter que llama a esta función sobre `_cobros` — mismo patrón que ya usan `cuotasVigentes` (deriva de `_deudas` vía `compromisoDeudasEnMes`) y `desglose` (deriva de `_transacciones`).

**Rationale**: es el mismo principio que ya rige las deudas en cuotas (D3 de 001) — "el presupuesto de un mes es un derivado, no un dato guardado directamente" — aplicado ahora al ingreso. Guardar el total en paralelo a los cobros individuales crearía dos verdades que se pueden desincronizar (corregir un cobro sin recalcular el total, o viceversa); derivarlo en cada lectura lo vuelve imposible por construcción, al mismo costo: sumar dos o tres `Dinero` es aritmética trivial frente a lo que ya hace `EstadoMes.cargar()`.

**Garantía que hereda de FR-005**: `totalIngreso([])` es `null`, no `Dinero.cero` — la misma distinción que ya existía entre "ingreso sin registrar" y "sueldo de S/ 0.00" en la spec 001, ahora expresada como "lista vacía" en vez de "fila ausente".

**Alternativas consideradas**:
- **Guardar el total en una columna de `configuracion` o de una tabla `resumen_mes`**: rechazada — reintroduce la duplicación que D3 ya evitó para las deudas; cada corrección de un cobro tendría que acordarse de actualizar el total en dos lugares.
- **Calcular el total en SQL con `SUM()`** (como hace `RepositorioAhorro.acumuladoHistorico()` para el total histórico): descartada para *este* total específico porque `EstadoMes` ya carga la lista completa de cobros del mes para mostrarla (US2, FR-008) — pedirle a SQL la suma aparte sería una segunda consulta redundante para un dato que la lista ya alcanza para derivar en Dart.

---

## D-C4 — La regla de cierre se aplica igual que a `Transaccion`

**Decisión**: `EstadoMes.agregarCobro`/`actualizarCobro` pasan por `_escribir(..., tipo: TipoEscritura.crear|modificar, mesAfectado: cobro.mes)`, exactamente como `agregarTransaccion`/`actualizarTransaccion`. `eliminarCobro(int id)` sigue el mismo patrón que `eliminarTransaccion`/`eliminarObligacion`: sin `mesAfectado` explícito, evaluado contra el mes actualmente abierto (`_mes`) — la asimetría ya existe en el código de 001 y no es parte del alcance de esta feature corregirla.

**Rationale**: FR-006 pide "la misma regla de cierre de meses que a los gastos reales (FR-052, FR-055, FR-056 de la spec 001)" en términos explícitos — no hay lugar para una regla nueva, solo para reusar la que ya existe en `EstadoMes._escribir` y `cierre_mes.dart`. Escribir un cobro directo a un repositorio (como hacía `EstadoPendientes.confirmar()` antes de corregirse en la spec 002) repetiría exactamente el bug que esa corrección eliminó: una ruta de escritura que se salta la regla de cierre porque no pasa por `EstadoMes`.

**Alternativas consideradas**: ninguna — es una aplicación directa de un patrón ya establecido y corregido una vez; introducir una variante nueva sería el tipo de inconsistencia que la spec pide evitar explícitamente.

---

## D-C5 — `RepositorioIngreso`, `RepositorioIngresoSqlite` y el modelo `Ingreso` se eliminan

**Decisión**: no quedan como código muerto ni deprecado — se borran junto con sus dobles y pruebas, reemplazados por `RepositorioCobrosIngreso`/`RepositorioCobrosIngresoSqlite`/`CobroIngreso`.

**Rationale**: revisando el uso actual, la clase `Ingreso` (`lib/dominio/modelos/ingreso.dart`) no tiene ningún consumidor real fuera de su propio archivo — el repositorio y la UI ya trabajan con `Dinero?`/`Mes` directamente, no con instancias de `Ingreso`. `RepositorioIngreso.mesesConIngreso()` tampoco se llama desde ningún lugar de la app, solo desde sus propias pruebas. Mantenerlos "por si acaso" junto a la nueva `RepositorioCobrosIngreso` sería exactamente la clase de duplicación que el Principio V descarta: dos formas de preguntar por el ingreso de un mes, una de ellas ya rota tras la migración (seguiría leyendo la tabla `ingreso`, que deja de recibir escrituras nuevas desde el día de esta feature).

**Alternativas consideradas**:
- **Dejarlos como capa de compatibilidad**: rechazada — no hay ningún llamador que los necesite, así que "compatibilidad" no protege nada real, solo agrega superficie a mantener.

---

## D-C6 — `RepositorioMeses` cambia su fuente de `ingreso` a `cobro_ingreso`

**Decisión**: la consulta `UNION` de `RepositorioMesesSqlite` (`mesesRegistrados`/`tieneDatos`, que sostiene el selector de mes y la detección de "mes nuevo" para la precarga de obligaciones, FR-006 de 001) cambia su primera rama de `SELECT mes_ordinal FROM ingreso` a `SELECT mes_ordinal FROM cobro_ingreso`.

**Rationale**: tras D-C2, `ingreso` deja de recibir escrituras nuevas — seguir consultándola ahí haría que un mes con cobros nuevos (pero sin fila legada en `ingreso`) no contara como "mes con datos" para el selector, mientras que un mes migrado seguiría apareciendo por su fila vieja. La consulta tiene que mirar la tabla que de verdad se escribe desde ahora.

**Alternativas consideradas**: **consultar ambas tablas con `UNION`** (mantener `ingreso` también en la fuente): rechazada — cualquier mes migrado ya tiene su equivalente en `cobro_ingreso` gracias a D-C2, así que sumar `ingreso` a la unión no aporta ningún mes que `cobro_ingreso` no cubra ya, solo mantiene una dependencia de una tabla que el resto del plan trata como abandonada.
