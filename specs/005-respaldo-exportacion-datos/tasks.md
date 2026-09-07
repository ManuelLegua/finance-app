---

description: "Task list for feature implementation"
---

# Tasks: Respaldo y exportación de datos

**Input**: Design documents from `/specs/005-respaldo-exportacion-datos/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/repositorio-respaldo.md](./contracts/repositorio-respaldo.md)

**Tests**: incluidos y **obligatorios**. El Principio III de la constitución los exige como requisito de entrada, no como paso posterior: la prueba de `validarRespaldo` se escribe antes que su implementación. Además, casi todo lo delicado de esta feature —el intercambio de archivos, las migraciones al restaurar, el todo-o-nada— se puede probar sin emulador, porque `sqflite_common_ffi` corre SQLite real en Windows.

**Organization**: agrupadas por historia de usuario, para que cada una se pueda implementar y validar por separado.

## Format: `[ID] [P?] [Story] Descripción`

- **[P]**: se puede hacer en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: a qué historia pertenece (US1, US2, US3)
- **[MANUAL]**: necesita dispositivo o emulador; no se puede automatizar
- Cada tarea nombra el archivo exacto que toca

## Path Conventions

Mismo proyecto Flutter único de 001: código en `lib/`, pruebas en `test/`, ambos en la raíz del repositorio. Estructura completa en [plan.md](./plan.md).

**Nota sobre el esquema**: esta feature **no sube `Esquema.version`** ni agrega tablas. Es la primera del proyecto que no toca el esquema (D1 de research.md). Si alguna tarea parece pedir una migración, está mal entendida.

---

## Phase 1: Setup

**Purpose**: dejar disponibles las dos dependencias nuevas

- [ ] T001 Agregar `share_plus` y `file_picker` a `pubspec.yaml` con `flutter pub add`, y comprobar que la app sigue compilando en Android. Las versiones se fijan acá, no se inventaron en el plan (D5 de research.md)
- [ ] T002 [P] Verificar que ninguna de las dos dependencias abre conexiones de red ni introduce telemetría, y anotar el hallazgo al final de D5 en `specs/005-respaldo-exportacion-datos/research.md`. **Si alguna lo incumpliera, se cae la dependencia, no el Principio I**: la alternativa es el canal de plataforma escrito a mano

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Purpose**: el dominio, el contrato y la capacidad de `BaseDatos` que todas las historias necesitan

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta que esta fase esté completa

- [ ] T003 [P] Crear `lib/dominio/modelos/respaldo.dart` con `ResultadoValidacionRespaldo` (enum de cuatro valores: `valido`, `corrupto`, `noEsDeLaApp`, `deVersionMasNueva`), `InformeRespaldo` y `ArchivoRespaldo`, según data-model.md §1. Dart puro: sin `dart:io`, sin `sqflite`, sin Flutter
- [ ] T004 [P] Escribir `test/dominio/validacion_respaldo_test.dart` **antes de implementar** (Principio III): los cuatro veredictos, el caso límite (`versionDelArchivo == versionSoportada` y `== 1`, el mínimo válido) y el adverso (`0` y `versionSoportada + 1`). Fijar también el **orden de evaluación** de data-model.md §2, que es lo que decide qué motivo se reporta cuando falla más de una comprobación a la vez
- [ ] T005 Implementar `validarRespaldo(...)` en `lib/dominio/calculos/validacion_respaldo.dart` hasta que T004 pase. Recibe hechos ya averiguados (`integridadOk`, `tablasEsperadasPresentes`, `versionDelArchivo`, `versionSoportada`); no abre archivos ni consulta la base (D6)
- [ ] T006 [P] Definir la interfaz `RepositorioRespaldo` en `lib/dominio/repositorios/repositorio_respaldo.dart` con los tres métodos del contrato (`exportar`, `inspeccionar`, `restaurar`), documentando en cada uno la garantía que fija `contracts/repositorio-respaldo.md`
- [ ] T007 [P] Agregar `RepositorioRespaldoEnMemoria` a `test/dobles/repositorios_en_memoria.dart`, con puntos de control para simular un archivo válido, uno de cada motivo de rechazo, y un fallo a mitad del reemplazo
- [ ] T008 Ampliar `lib/datos/base_datos.dart` con lo que el intercambio de D3 necesita: exponer la ruta del archivo en uso y poder cerrar, reemplazar y reabrir. **Sigue habiendo un solo lugar que sabe abrir la base**: el repositorio usa esto, no reimplementa la apertura
- [ ] T009 Crear el andamiaje de pruebas con archivos reales en `test/datos/`: armar una base sembrada en un directorio temporal con `sqflite_common_ffi`, y poder construir una base con esquema **v3** para la prueba de migración de US2

**Checkpoint**: el dominio y el contrato están listos; las tres historias pueden empezar

---

## Phase 3: User Story 1 — Exportar un respaldo completo (P1) 🎯 MVP

**Goal**: el usuario saca una copia de sus datos a un archivo y decide qué hacer con él.

**Independent Test**: exportar con datos cargados y comprobar que el archivo generado contiene esos mismos datos. Tiene valor aunque US2 no exista todavía: ya hay una copia fuera del dispositivo.

### Tests para US1 ⚠️

- [ ] T010 [P] [US1] Escribir en `test/datos/respaldo_test.dart`: exportar produce un archivo que se puede abrir como base y que trae las mismas filas que la original (obligaciones, transacciones, deudas, aportes, cobros)
- [ ] T011 [P] [US1] Ampliar `test/datos/respaldo_test.dart`: exportar con la base recién creada y **sin ningún dato** genera igual un archivo válido, no falla (FR-012)
- [ ] T012 [P] [US1] Ampliar `test/datos/respaldo_test.dart`: en el archivo exportado, `suscripcion_premium` y `notificacion_diagnostico` están **vacías**, y todas las demás tablas conservan sus filas (FR-003, D4)
- [ ] T013 [P] [US1] Ampliar `test/datos/respaldo_test.dart`: exportar **no modifica la base viva** — las filas de las dos tablas vaciadas siguen intactas en el original después de exportar. Es la mitad fácil de olvidar de D4: se vacía la copia, nunca el original

### Implementación para US1

- [ ] T014 [US1] Implementar `exportar()` en `lib/datos/repositorios/repositorio_respaldo_sqlite.dart` hasta que T010–T013 pasen: `PRAGMA wal_checkpoint(TRUNCATE)`, copia del archivo a una ruta temporal privada, vaciado de las dos tablas **en la copia**, y nombre propuesto `finanzas-respaldo-AAAA-MM-DD.db`
- [ ] T015 [US1] Crear el `ChangeNotifier` `EstadoRespaldo` en `lib/ui/estado/estado_respaldo.dart` con las fases de exportación de data-model.md §4 (`inactivo → enCurso → completado | fallido`), delegando en `RepositorioRespaldo`
- [ ] T016 [US1] Crear `lib/ui/pantallas/ajustes/seccion_respaldo.dart` y montarla en `lib/ui/pantallas/ajustes/pantalla_ajustes.dart` bajo una sección propia. Es una sección más, no una pantalla nueva (Principio IV)
- [ ] T017 [US1] Entregar el archivo a la hoja de compartir de Android con `share_plus` desde la sección de Ajustes. **La app no elige destino ni lo sugiere** (FR-004, D5)
- [ ] T018 [US1] Confirmar con texto que la exportación terminó bien, e informar el fallo con claridad cuando ocurra, sin dejar un archivo a medio escribir (FR-005)
- [ ] T019 [MANUAL] [US1] Recorrer los pasos 1–3 de [quickstart.md](./quickstart.md) en un dispositivo: la hoja de compartir tiene que abrirse y el archivo tiene que poder salir del teléfono. Si no se puede sacar, la feature no cumple su propósito

**Checkpoint**: hay respaldo. Todavía no hay forma de volver a cargarlo.

---

## Phase 4: User Story 2 — Restaurar desde un respaldo (P2)

**Goal**: el usuario vuelve a cargar sus datos desde un archivo que exportó antes.

**Independent Test**: exportar, limpiar la app, restaurar, y comprobar que los datos vuelven idénticos.

### Tests para US2 ⚠️

- [ ] T020 [P] [US2] Escribir en `test/datos/respaldo_test.dart` el ida y vuelta completo: exportar, vaciar la base, restaurar, y comprobar que todas las tablas quedan como estaban (SC-001)
- [ ] T021 [P] [US2] Ampliar `test/datos/respaldo_test.dart`: un respaldo con esquema **v3** restaurado en la app v4 queda migrado y con sus datos intactos (FR-010). Es la prueba que justifica D1: si esto pasa sin código de migración nuevo, la decisión de formato era la correcta
- [ ] T022 [P] [US2] Ampliar `test/datos/respaldo_test.dart`: después de restaurar no quedan `-wal` ni `-shm` del archivo anterior. D3 marca este como el modo de fallo más fácil de pasar por alto, porque es corrupción silenciosa y no un error visible
- [ ] T023 [P] [US2] Ampliar `test/datos/respaldo_test.dart`: restaurar el mismo archivo dos veces seguidas deja el mismo resultado que restaurarlo una vez (edge case de la spec)
- [ ] T024 [P] [US2] Ampliar `test/datos/respaldo_test.dart`: un respaldo al que se le puso a mano una fila de `suscripcion_premium` **no** concede acceso premium al restaurarse (SC-004, D4)

### Implementación para US2

- [ ] T025 [US2] Implementar `inspeccionar(ruta)` en `lib/datos/repositorios/repositorio_respaldo_sqlite.dart`: copiar el candidato a una ruta temporal, abrirlo **sin `version:`** para no dispararle migraciones a un archivo que quizá se rechace, juntar los tres hechos y devolver el `InformeRespaldo` que arma `validarRespaldo` (D2)
- [ ] T026 [US2] Implementar el camino feliz de `restaurar(ruta)` con la secuencia de D3 hasta que T020–T023 pasen: cerrar, renombrar el actual a `finanzas.db.previo`, mover el candidato, borrar los sidecars huérfanos, reabrir (las migraciones corren solas) y recién ahí borrar el `.previo`
- [ ] T027 [US2] Descartar la fila de `suscripcion_premium` que venga en el archivo restaurado y volver a consultar el estado real contra Google Play (`EstadoSuscripcionPremium.refrescar()`), hasta que T024 pase. **El acceso premium nunca sale de un archivo local**
- [ ] T028 [US2] Agregar a `lib/ui/estado/estado_respaldo.dart` las fases de restauración de data-model.md §4, incluida `esperandoConfirmacion`, que es donde va a engancharse US3
- [ ] T029 [US2] Agregar la acción "Restaurar respaldo" en `lib/ui/pantallas/ajustes/seccion_respaldo.dart`, eligiendo el archivo con el selector del sistema (`file_picker` sobre Storage Access Framework, sin permisos de almacenamiento)
- [ ] T030 [MANUAL] [US2] Recorrer los pasos 4–5 de [quickstart.md](./quickstart.md) en un dispositivo: `adb shell pm clear`, restaurar el archivo del paso 2 y comprobar que el disponible del mes vuelve idéntico

**Checkpoint**: el ciclo completo funciona. Falta protegerlo de un error del usuario.

---

## Phase 5: User Story 3 — No perder datos actuales por restaurar por error (P3)

**Goal**: restaurar sobre datos existentes exige una confirmación explícita, y ningún archivo inválido deja las cosas peor que antes.

**Independent Test**: con datos ya cargados, iniciar una restauración y comprobar que se exige confirmación aparte y que cancelar deja todo intacto.

### Tests para US3 ⚠️

- [ ] T031 [P] [US3] Escribir `test/ui/respaldo_test.dart`: con datos ya cargados, elegir un archivo válido muestra el aviso de reemplazo y **no toca ningún dato** hasta que se confirme aparte (FR-007)
- [ ] T032 [P] [US3] Ampliar `test/ui/respaldo_test.dart`: cancelar desde el aviso no cambia nada — se verifica leyendo los repositorios, no mirando la pantalla
- [ ] T033 [P] [US3] Ampliar `test/ui/respaldo_test.dart`: los cuatro veredictos de `ResultadoValidacionRespaldo` producen mensajes distintos y reconocibles, y en los tres de rechazo los datos existentes quedan intactos (FR-009, SC-003)
- [ ] T034 [P] [US3] Ampliar `test/datos/respaldo_test.dart`: si el reemplazo falla a mitad de camino, la base queda como estaba **y abierta y usable** (FR-008). Se simula con el punto de control del doble de T007

### Implementación para US3

- [ ] T035 [US3] Agregar el aviso previo al reemplazo en `lib/ui/pantallas/ajustes/seccion_respaldo.dart`: dice con todas las letras que va a reemplazar todo lo actual, con ícono **y** texto siguiendo el patrón de `lib/shared/componentes/aviso_mes_cerrado.dart`, y exige una confirmación aparte
- [ ] T036 [US3] Producir el mensaje de rechazo a partir del enum con un `switch` **exhaustivo**, hasta que T033 pase: si mañana aparece un quinto motivo, esto deja de compilar en vez de mostrar un mensaje genérico
- [ ] T037 [US3] Implementar la vuelta atrás de `restaurar()` hasta que T034 pase: restituir `finanzas.db.previo` a su lugar y reabrir, ante un fallo en cualquier paso posterior al rename

**Checkpoint**: las tres historias funcionan. Restaurar deja de ser una operación peligrosa.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T038 [P] Corregir el comentario desactualizado de `lib/datos/migraciones.dart`, que hoy justifica la prohibición de migraciones destructivas diciendo que *"la spec descarta backup y exportación en esta versión"*. La prohibición sigue en pie —la constitución la exige igual— pero el motivo hay que reescribirlo: ahora existe respaldo, y aun así no se puede contar con que el usuario lo haya hecho
- [ ] T039 [P] Verificar que `test/pureza_test.dart` pasa con todo lo nuevo: `lib/dominio/modelos/respaldo.dart` y `lib/dominio/calculos/validacion_respaldo.dart` no importan `dart:io`, `sqflite` ni Flutter (D6)
- [ ] T040 [P] Revisar que ningún estado de esta feature (exportando, restaurando, motivo de rechazo, aviso de reemplazo) se comunique solo por color, siguiendo el patrón de `MarcaEstado`/`AvisoMesCerrado` de 001
- [ ] T041 [P] Dejar `flutter analyze` sin issues y `dart format` aplicado a todo lo nuevo
- [ ] T042 [MANUAL] Recorrer entero [quickstart.md](./quickstart.md), en particular los pasos 6–8: restaurar sobre datos existentes, rechazar un archivo cualquiera del teléfono, y comprobar que el premium no se hereda del archivo
- [ ] T043 [P] Actualizar `CLAUDE.md` con el estado de esta feature una vez completa

---

## Dependencies & Execution Order

### Dependencias de fase

- **Setup (Fase 1)**: sin dependencias.
- **Foundational (Fase 2)**: depende del Setup. **Bloquea las tres historias.**
- **US1 (Fase 3)**: depende de la Fase 2. Es el MVP: sin ella no hay archivo que restaurar.
- **US2 (Fase 4)**: depende de la Fase 2, y en la práctica de US1 — sus pruebas necesitan un archivo exportado de verdad.
- **US3 (Fase 5)**: depende de US2, porque protege la operación que US2 introduce.
- **Polish (Fase 6)**: depende de las historias que se quieran cerrar.

### Dentro de cada historia

- Las pruebas se escriben **antes** que la implementación y tienen que fallar primero. En T004/T005 no es una preferencia: es requisito de entrada del Principio III.
- Modelos antes que repositorio; repositorio antes que estado de UI; estado antes que pantalla.
- Las tareas `[MANUAL]` van siempre al final de su historia: necesitan lo demás funcionando.

### Oportunidades de paralelismo

- T003, T004, T006 y T007 tocan archivos distintos y pueden hacerse a la vez.
- Dentro de US1, las cuatro pruebas T010–T013 son independientes entre sí; lo mismo T020–T024 en US2 y T031–T034 en US3.
- Casi todo el Polish (T038–T041, T043) es paralelo.

---

## Implementation Strategy

### MVP primero (US1)

1. Fase 1 (Setup) + Fase 2 (Foundational).
2. Fase 3 (US1): exportar.
3. **PARAR Y VALIDAR**: sacar un archivo del teléfono de verdad (T019). Ya hay respaldo, aunque restaurarlo todavía sea manual.

### Entrega incremental

1. Setup + Foundational → base lista.
2. + US1 → el usuario puede sacar una copia (MVP).
3. + US2 → la copia sirve de verdad: se puede volver a cargar.
4. + US3 → restaurar deja de poder destruir datos por un toque equivocado.

---

## Notes

- El archivo de respaldo **es** el archivo SQLite (D1). Cualquier tarea que empiece a serializar tabla por tabla se salió del diseño.
- Lo que se vacía, se vacía **en la copia**, nunca en la base viva (D4). T013 existe para que eso no se rompa sin que nadie se entere.
- `restaurar` solo se llama después de que `inspeccionar` devolvió `valido` para ese mismo archivo, y con la confirmación del usuario de por medio (contrato + FR-007).
- Commits en español, con prefijo y referencia a la tarea que atienden.
