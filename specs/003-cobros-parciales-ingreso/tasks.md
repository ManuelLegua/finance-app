---

description: "Task list para 003-cobros-parciales-ingreso"
---

# Tasks: Cobros parciales de ingreso

**Input**: Documentos de diseño en `specs/003-cobros-parciales-ingreso/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: **SÍ se incluyen y no son opcionales** (Principio III de la constitución: las pruebas de reglas financieras son requisito de entrada, no un paso posterior). `totalIngreso` y la migración v2→v3 se prueban antes de implementarse.

**Organización**: agrupadas por historia de usuario, en el orden de prioridad de la spec (US1 es P1/MVP, US2 es P2, US3 es P3).

## Format: `[ID] [P?] [Story] Descripción`

- **[P]**: puede hacerse en paralelo (archivos distintos, sin dependencias pendientes).
- **[Story]**: a qué historia pertenece (US1…US3).
- Cada tarea indica la ruta exacta del archivo.

## Path Conventions

Mismo proyecto Flutter único de 001/002: código en `lib/`, pruebas en `test/`, ambos en la raíz del repositorio.

---

## Phase 1: Setup

**Sin tareas.** A diferencia de 002, esta feature no agrega dependencias ni estructura de directorios nueva: todo vive en carpetas que ya existen (`lib/dominio/modelos/`, `lib/dominio/repositorios/`, `lib/dominio/calculos/`, `lib/datos/repositorios/`, `lib/ui/estado/`, `lib/ui/pantallas/presupuesto/`).

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Propósito**: la entidad, el repositorio, el esquema y el cableado de `EstadoMes` de los que dependen las tres historias. Ninguna historia puede empezar hasta terminar esta fase, porque las tres operan sobre el mismo `EstadoMes.cobros`.

**⚠️ CRÍTICO**: esta fase deja la suite existente (fuera de esta feature) compilando y en verde otra vez — el cambio de firma de `EstadoMes` toca casi todos los tests de widget del proyecto, aunque no prueben ingreso.

- [X] T001 [P] Definir `CobroIngreso` en `lib/dominio/modelos/cobro_ingreso.dart` — mismo shape que `AporteAhorro`: `id`, `fecha` (`DateTime`, solo fecha), `monto` (`Dinero`), `mes` derivado vía `Mes.deFecha`, `copiarCon`, `==`/`hashCode`, `toString` — data-model.md §1
- [X] T002 [P] Escribir `test/dominio/ingreso_test.dart` **antes de implementar** `totalIngreso`: caso normal (dos cobros suman el total exacto), límite (`cobros` vacía → `null`, nunca `Dinero.cero`), adverso (la lista ya sin el cobro corregido no arrastra el monto viejo) — contracts/calculos.md
- [X] T003 Implementar `totalIngreso(List<CobroIngreso>)` en `lib/dominio/calculos/ingreso.dart` hasta que T002 pase
- [X] T004 [P] Definir la interfaz `RepositorioCobrosIngreso` en `lib/dominio/repositorios/repositorio_cobros_ingreso.dart` según contracts/repositorios.md (`porMes`, `insertar`, `actualizar`, `eliminar`; sin lógica de cierre ni de totales)
- [X] T005 [P] Escribir el DDL de `cobro_ingreso` en `lib/datos/esquema.dart` (subir `Esquema.version` a 3) y el paso de migración v2→v3 en `lib/datos/migraciones.dart`: crea la tabla y copia cada `ingreso` existente como un `CobroIngreso` con fecha el primer día de su mes, vía `INSERT INTO ... SELECT` con `printf` — sin borrar `ingreso` (D-C2) — DDL exacto en data-model.md §3 — **refinamiento sobre el plan**: `ingreso` se quitó de `Esquema.creacion` (una instalación nueva nunca la crea, va directo a `cobro_ingreso`); solo sigue existiendo en bases que ya la tenían de una versión anterior, intacta tras la migración. YAGNI: no tenía sentido crear en instalaciones nuevas una tabla que ningún código vuelve a leer.
- [X] T006 Escribir `test/datos/migracion_003_test.dart`: la migración crea `cobro_ingreso`, copia cada fila de `ingreso` con el monto y la fecha correctos (primer día del mes), **no borra `ingreso`** (verificar que sus filas siguen ahí, D-C2)
- [X] T007 Implementar `RepositorioCobrosIngresoSqlite` en `lib/datos/repositorios/repositorio_cobros_ingreso_sqlite.dart`: `porMes` ordena por fecha ascendente (FR-008); `actualizar` sin id lanza `ArgumentError`; `eliminar` de un id inexistente es no-op
- [X] T008 [P] Crear el doble en memoria `RepositorioCobrosIngresoEnMemoria` en `test/dobles/repositorios_en_memoria.dart`, con `errorEnLaProximaEscritura` (mismo patrón que `RepositorioTransaccionesEnMemoria`)
- [X] T009 Escribir `test/datos/repositorio_cobros_ingreso_test.dart` contra SQLite real, cubriendo las garantías de T007
- [X] T010 [P] Crear `test/builders/cobro_ingreso_builder.dart`, mismo patrón que `deuda_builder.dart`/`aporte_ahorro_builder.dart`
- [X] T011 Cambiar la fuente `ingreso` por `cobro_ingreso` en el `UNION` de `RepositorioMesesSqlite` (`lib/datos/repositorios/repositorio_meses_sqlite.dart`) — D-C6
- [X] T012 Crear `test/datos/repositorio_meses_test.dart` (no existía ninguna prueba de este repositorio): un mes con cobros pero sin fila legada en `ingreso` cuenta como "mes con datos" en `mesesRegistrados()`/`tieneDatos()`
- [X] T013 Eliminar `lib/dominio/modelos/ingreso.dart`, `lib/dominio/repositorios/repositorio_ingreso.dart`, `lib/datos/repositorios/repositorio_ingreso_sqlite.dart`, `RepositorioIngresoEnMemoria` (en `test/dobles/repositorios_en_memoria.dart`) y `test/datos/repositorio_ingreso_test.dart` — sin consumidores reales fuera de esta feature (D-C5)
- [X] T014 Reemplazar `repoIngreso`/`RepositorioIngreso` por `repoCobrosIngreso`/`RepositorioCobrosIngreso` en `EstadoMes` (`lib/ui/estado/estado_mes.dart`): el campo `_ingreso` pasa a ser `List<CobroIngreso> _cobros`, cargado en `cargar()` vía `porMes(_mes)`; el getter `ingreso` pasa a `totalIngreso(_cobros)`; nuevo getter `List<CobroIngreso> get cobros` (FR-008) — también se agregó `puedeEditarCobro(CobroIngreso)`, mismo patrón que `puedeEditarTransaccion`, usado en T030
- [X] T015 Actualizar `lib/main.dart`: `Provider<RepositorioCobrosIngreso>` en vez de `Provider<RepositorioIngreso>`, inyectado en `EstadoMes`
- [X] T016 Adaptar los sitios de prueba ya existentes (fuera de esta feature) que construyen `EstadoMes`, para que la suite compile y vuelva a estar en verde tras T014: `test/ui/cascaron_test.dart`, `test/ui/montos_grandes_test.dart` (además adapta sus siembras de ingreso a `CobroIngreso`), `test/ui/pantalla_ahorro_test.dart` (ídem), `test/ui/pantalla_desglose_test.dart`, `test/ui/pantalla_deudas_test.dart`, `test/ui/pantalla_resumen_test.dart` (ídem, con un helper `sembrarIngreso`), `test/ui/pantalla_transacciones_test.dart`, `test/ui/captura/estado_pendientes_test.dart`, `test/ui/captura/pantalla_pendientes_test.dart`, y la construcción de `EstadoMes` en `test/ui/pantalla_presupuesto_test.dart`

**Checkpoint**: el esquema soporta la feature completa, `EstadoMes` ya deriva el ingreso de sus cobros, y toda la suite existente vuelve a compilar y pasar. Ninguna historia tiene todavía forma de agregar un cobro desde la UI.

---

## Phase 3: User Story 1 — Registrar el sueldo en más de un cobro (P1) 🎯 MVP

**Goal**: el usuario anota cada cobro con su fecha y monto; el total que usa el resto de la app es la suma exacta.

**Independent Test**: registrar dos cobros en el mismo mes con fechas y montos distintos, y comprobar que el ingreso total (el que usa el resumen y la sugerencia de ahorro) es la suma exacta de ambos.

### Tests para US1 ⚠️

- [X] T017 [P] [US1] Ampliar `test/ui/estado_mes_test.dart` **antes de implementar**: `agregarCobro` en el mes en curso lo agrega y `estado.ingreso` refleja la suma de todos los cobros del mes; en un mes cerrado se rechaza antes de llegar al repositorio (mismo criterio que `agregarTransaccion`, con `mesAfectado: cobro.mes`) (FR-006)
- [X] T018 [P] [US1] Reescribir el grupo `ingreso` de `test/ui/pantalla_presupuesto_test.dart`: un mes sin cobros sigue pidiendo registrarlo (sin cambios), y con un cobro registrado la tarjeta muestra el total formateado

### Implementación para US1

- [X] T019 [US1] Agregar `agregarCobro(CobroIngreso)` en `EstadoMes` hasta que T017 pase: pasa por `_escribir(..., tipo: TipoEscritura.crear, mesAfectado: cobro.mes)`, igual que `agregarTransaccion` (FR-006)
- [X] T020 [US1] Convertir `lib/ui/pantallas/presupuesto/dialogo_ingreso.dart` en `formulario_cobro.dart`: monto + fecha (precargada en hoy, respetando la ventana de gracia vía `estado.admiteRegistrarEn`, mismo patrón que el formulario de un gasto) — devuelve un `CobroIngreso` sin guardar
- [X] T021 [US1] Ampliar `_TarjetaIngreso` en `pantalla_presupuesto.dart`: el botón de editar pasa a "agregar cobro", abre `FormularioCobro` y llama a `estado.agregarCobro`; el total mostrado sigue siendo `estado.ingreso` — **implementado junto con T025/T029** (el detalle de US2 y la edición de US3) en la misma reescritura de `_TarjetaIngreso`, ya que las tres historias tocan el mismo widget; las pruebas de cada historia sí se mantuvieron separadas por fase
- [X] T022 [US1] Escribir en `test/ui/pantalla_presupuesto_test.dart`: registrar dos cobros de fechas y montos distintos dentro del mismo mes deja el total como su suma exacta (FR-001, FR-003, Acceptance Scenario 1)
- [X] T023 [US1] Escribir en `test/ui/pantalla_resumen_test.dart`: con un único cobro, el disponible, el déficit y la sugerencia de ahorro dan el mismo resultado que con un `Ingreso` único de igual monto — cero diferencia de comportamiento (SC-003, Acceptance Scenario 2) — verificado reutilizando las pruebas ya existentes de esa pantalla (ahora sembradas vía `sembrarIngreso`/`CobroIngreso` en T016), que ya comprobaban exactamente ese comportamiento

**Checkpoint**: US1 funciona sola — el usuario puede registrar uno o varios cobros y el total en toda la app es correcto. Todavía no hay forma de ver el detalle ni de corregir un cobro puntual.

---

## Phase 4: User Story 2 — Ver el detalle de los cobros del mes (P2)

**Goal**: además del total, se ve la lista de cobros que lo componen, con su fecha.

**Independent Test**: registrar dos cobros y comprobar que la pantalla de presupuesto lista ambos por separado, con su fecha, además del total.

### Tests para US2 ⚠️

- [X] T024 [P] [US2] Ampliar `test/ui/pantalla_presupuesto_test.dart` **antes de implementar**: con dos cobros registrados, ambos aparecen listados con su fecha y monto, además del total (FR-008)

### Implementación para US2

- [X] T025 [US2] Ampliar `_TarjetaIngreso` hasta que T024 pase: lista cada `estado.cobros` con su fecha (`FormatoFecha.corta`) y monto debajo del total — mismo patrón visual que la lista de obligaciones de la propia pantalla (nueva clase `_FilaCobro`)

**Checkpoint**: US1 + US2 — se puede registrar y verificar el detalle de cada cobro, sin poder corregirlo todavía.

---

## Phase 5: User Story 3 — Corregir o eliminar un cobro puntual (P3)

**Goal**: corregir o borrar un cobro sin tener que volver a cargar los demás del mes.

**Independent Test**: editar el monto de uno de dos cobros y comprobar que el otro y el total se recalculan correctamente; eliminar uno deja el resto intacto; eliminar el único cobro del mes vuelve al estado "sin registrar".

### Tests para US3 ⚠️

- [X] T026 [P] [US3] Ampliar `test/ui/estado_mes_test.dart` **antes de implementar**: `actualizarCobro` corrige un cobro sin tocar los demás del mismo mes; `eliminarCobro` borra uno y dos deja el otro intacto; en un mes cerrado ambas se rechazan (`TipoEscritura.modificar`, sin ventana de gracia — FR-056)
- [X] T027 [P] [US3] Ampliar `test/ui/pantalla_presupuesto_test.dart`: corregir uno de dos cobros deja el otro sin cambios y el total recalculado (Acceptance Scenario 1); eliminar uno de dos deja el ingreso como el del restante, no en cero (Acceptance Scenario 2); eliminar el único cobro del mes vuelve a "ingreso sin registrar", no a S/ 0.00 (Acceptance Scenario 3)

### Implementación para US3

- [X] T028 [US3] Agregar `actualizarCobro(CobroIngreso)` y `eliminarCobro(int id)` en `EstadoMes` hasta que T026 pase: mismo patrón que `actualizarTransaccion`/`eliminarTransaccion` (`TipoEscritura.modificar`)
- [X] T029 [US3] Ampliar `_TarjetaIngreso`: cada fila de cobro es tocable para corregirla (abre `FormularioCobro` precargado) y tiene una acción para eliminarla con confirmación — mismo patrón que una fila de obligación en la misma pantalla (reutiliza el enum `AccionSobreObligacion`, sin crear uno nuevo solo para cobros)
- [X] T030 [US3] Verificar en la UI que un cobro de un mes cerrado (fuera de la ventana de gracia) no ofrece corregir ni eliminar — **ajuste sobre el plan**: en vez de `estado.admiteEditar` (que mira el mes actualmente abierto), se usó `estado.puedeEditarCobro(cobro)` (nuevo, T014), que mira el mes propio del cobro — mismo criterio exacto que ya usa `puedeEditarTransaccion` para las filas de gasto; usar `admiteEditar` habría sido inconsistente con ese precedente

**Checkpoint**: las tres historias funcionan de forma independiente. La spec 003 queda completa.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T031 [P] Verificar que `test/pureza_test.dart` sigue pasando con `lib/dominio/calculos/ingreso.dart` ya agregado (el directorio ya está vigilado, no hace falta ampliar la guarda)
- [X] T032 [P] Dejar `flutter analyze` sin issues y `dart format` aplicado a todo lo nuevo — 446 pruebas en verde
- [ ] T033 [MANUAL] Recorrer [quickstart.md](./quickstart.md) completo, incluida la validación de la migración desde una base con datos de 001/002
- [X] T034 [P] Actualizar `CLAUDE.md` con el estado de esta feature una vez completa

---

## Dependencies & Execution Order

### Dependencias de fase

- **Setup (F1)**: sin tareas.
- **Foundational (F2)**: sin dependencias externas. **Bloquea las tres historias** — sin `CobroIngreso`, el repositorio y el cableado de `EstadoMes`, ninguna historia tiene sobre qué escribir ni de dónde leer.
- **US1 (F3)**: depende solo de F2. Es el MVP (SC-001).
- **US2 (F4)**: depende de F2 y de que `EstadoMes.cobros` ya exista (F2, T014) — no depende de que US1 esté completa como historia, pero sin `agregarCobro` (US1) no hay nada que listar en la práctica.
- **US3 (F5)**: depende de F2 (`EstadoMes.cobros`) y, para tener algo que corregir o borrar, de que US1 ya permita agregar cobros.
- **Polish (F6)**: al final de las historias que se decidan entregar.

### Dentro de cada historia

Tests → modelos/estado → pantallas → prueba de widget, igual que 001/002.

### Oportunidades de paralelismo

- T001, T002, T004, T005, T008, T010 en Foundational (archivos distintos, sin dependencias entre sí).
- T017 y T018 en US1; T026 y T027 en US3 (tests de estado vs. tests de widget, archivos distintos).
- Con un solo desarrollador, [P] significa que el orden entre esas tareas es indiferente.

---

## Implementation Strategy

### MVP primero (US1)

1. Fase 1 — Setup (sin tareas)
2. Fase 2 — Foundational (T001–T016, crítica, bloquea todo)
3. Fase 3 — US1 (T017–T023)
4. **PARAR Y VALIDAR**: registrar dos cobros en un mes y confirmar que el total en Resumen y Presupuesto es la suma exacta (SC-001, SC-003).

### Entrega incremental

1. Setup + Foundational → base lista, suite existente en verde
2. + US1 → registrar el sueldo en uno o varios cobros, total correcto en toda la app — **MVP**
3. + US2 → se ve el detalle de cada cobro
4. + US3 → corregir o eliminar un cobro puntual sin recargar los demás
5. Fase 6 — Polish

Cada incremento deja la app usable y no rompe 001 ni 002.

---

## Notes

- Total: **34 tareas**. Setup: 0 · Foundational: 16 · US1: 7 · US2: 2 · US3: 5 · Polish: 4.
- La prueba de `totalIngreso` y de la migración v2→v3 no son opcionales: son requisito de entrada por constitución (Principio III).
- Commitear por tarea o por grupo coherente, referenciando el id de la tarea.
- Cualquier desviación de un principio se justifica por escrito en plan.md, no en silencio durante la implementación.
