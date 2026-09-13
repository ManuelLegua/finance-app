---

description: "Task list para 002-captura-notificaciones-bancarias"
---

# Tasks: Captura automática de consumos desde notificaciones bancarias

**Input**: Documentos de diseño en `specs/002-captura-notificaciones-bancarias/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Revisión 2026-08-30**: reemplaza la primera versión de este documento. El usuario pidió cubrir cualquier banco o billetera, no una lista fija de cuatro, sin que agregar uno nuevo exija código nuevo. Eso cambió la arquitectura de "un intérprete por banco" a "un único parser genérico + una lista de orígenes reconocidos" (research.md D-N2, D-N10, D-N11), y esta lista de tareas es más corta que la original en la fase que más se achicó: ya no hace falta un par "capturar + interpretar" por cada banco.

**Tests**: **SÍ se incluyen y no son opcionales**, igual que en 001 (Principio III). Con una salvedad propia de esta feature: el parser genérico **no puede probarse con texto inventado** — la spec afirma que no existe documentación pública del formato de ningún banco (research.md D-N9). Por eso, antes de escribir su prueba hay una tarea manual de "capturar notificaciones reales de una muestra de orígenes" que ningún agente puede completar sola. A diferencia de la primera versión de este documento, **esa tarea manual es una sola vez**, no una por banco.

**Organización**: agrupadas por historia de usuario, en el orden de prioridad de la spec (US1 y US2 son P1 y juntas forman el MVP; US3 es P2; US4 es P3).

## Format: `[ID] [P?] [Story] Descripción`

- **[P]**: puede hacerse en paralelo (archivos distintos, sin dependencias pendientes).
- **[Story]**: a qué historia pertenece (US1…US4).
- **[MANUAL]**: no se puede completar sin un dispositivo Android con apps bancarias reales instaladas — no es una tarea de código.
- Cada tarea indica la ruta exacta del archivo.

## Path Conventions

Mismo proyecto Flutter único de 001: código en `lib/`, pruebas en `test/`, ambos en la raíz del repositorio. Esta feature no crea una estructura nueva, extiende la de 001 (ver *Structure Decision* en plan.md).

---

## Phase 1: Setup

**Propósito**: dependencia nueva y andamiaje de directorios, sin lógica todavía.

- [X] T001 Agregar `flutter_notification_listener` con `flutter pub add flutter_notification_listener`, verificando en `pubspec.yaml` que quedó fijada la versión `^1.4.0`
- [X] T002 [P] Crear la estructura de directorios `lib/dominio/interpretes/`, `lib/datos/notificaciones/`, `lib/ui/pantallas/captura/`, `test/dominio/interpretes/fixtures/`, `test/ui/captura/` según plan.md
- [X] T003 Declarar en `android/app/src/main/AndroidManifest.xml` el `NotificationListenerService` (con `android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"` y su `intent-filter`) y un receptor para `BOOT_COMPLETED`, según D-N1 y D-N4 de research.md

**Checkpoint**: `flutter analyze` y `flutter test` corren limpios; el manifiesto está listo para que Android reconozca el servicio cuando exista.

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Propósito**: los tipos, la lista de orígenes reconocidos y el esquema de los que dependen las cuatro historias.

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta terminar esta fase.

- [X] T004 [P] Definir `MotivoDiagnostico` (`formatoNoReconocido`, `montoIlegible`, `monedaExtranjera`) en `lib/shared/constantes/enums.dart`, con el mismo patrón slug/etiqueta/`desdeSlug` que `Categoria`
- [X] T005 [P] Definir la clase `OrigenReconocido` (paquete Android + nombre para mostrar) y la constante `origenesReconocidos` en `lib/shared/constantes/origenes_reconocidos.dart`, sembrada con los 15 emisores de `EntidadesPeru` (001), que ya incluye Yape y Plin — el paquete Android real de cada uno queda pendiente de completar en T041, esta tarea solo arma la estructura y los nombres
- [X] T006 Escribir el DDL incremental en `lib/datos/esquema.dart` (subir `versionEsquema`) y el paso de migración correspondiente en `lib/datos/migraciones.dart`: las tablas `consumo_pendiente` (columna `origen_paquete` sin `CHECK` cerrado — D-N10 — con el índice único `(origen_paquete, notificacion_id)` que sostiene la deduplicación, D-N5), `comercio_categoria`, `notificacion_diagnostico`, y la columna `captura_notificaciones_activa` en `configuracion` — DDL exacto en data-model.md §4
- [X] T007 Escribir `test/datos/migracion_002_test.dart`: la migración crea las tres tablas y la columna nueva, preserva las filas ya existentes de 001, y `user_version` sube en uno
- [X] T008 [P] Extender `RepositorioConfiguracion` (interfaz en `lib/dominio/repositorios/`, implementación `Sqlite` y doble en memoria) con `capturaNotificacionesActiva` (`bool`, `false` por defecto)
- [X] T009 Ampliar `test/datos/base_datos_test.dart` (grupo "configuración por defecto" — no existe un archivo dedicado a este repositorio, los ajustes se prueban ahí desde 001): `capturaNotificacionesActiva` es `false` en una base nueva, se guarda y persiste igual que los días de gracia
- [X] T010 [P] ~~Ampliar `test/pureza_test.dart`~~ — no hizo falta tocar nada: `directoriosPuros` ya incluye `Directory('lib/dominio')` y lo recorre con `recursive: true` (`test/pureza_test.dart:47`), así que `lib/dominio/interpretes/` ya queda cubierto en cuanto tenga archivos, sin cambiar la guarda

**Checkpoint**: el esquema soporta la feature completa, la lista de orígenes existe (aunque sin paquetes reales todavía) y la guarda de pureza ya vigila el directorio nuevo.

---

## Phase 3: User Story 1 — Activar la captura y entender qué implica (P1)

**Goal**: el usuario entiende qué se va a leer, concede el permiso desde la app, y ve en todo momento el estado real de la captura — no lo que aceptó alguna vez.

**Independent Test**: recorrer la activación en un dispositivo limpio y verificar que el estado mostrado coincide con el permiso real del sistema, incluidos los casos de denegar y de revocar después (quickstart.md, pasos 1–2 y 6).

### Tests para US1 ⚠️

- [X] T011 [P] [US1] Escribir `test/dominio/estado_captura_test.dart` **antes de implementar**: `situacion` deriva en `sinPermiso`, `permisoRevocado`, `inactivaEnApp` o `activa` a partir de `permisoConcedido` + `activaEnApp`, sin caché; `origenesQueCubre` solo es `origenesReconocidos` cuando `situacion == activa`

### Implementación para US1

- [X] T012 [US1] Implementar el derivado `EstadoCaptura` en `lib/dominio/modelos/estado_captura.dart` hasta que T011 pase
- [X] T013 [US1] Definir la interfaz `ServicioEscuchaNotificaciones` en `lib/dominio/repositorios/` según contracts/repositorios.md
- [X] T014 [US1] Implementar `ServicioEscuchaNotificacionesAndroid` en `lib/datos/notificaciones/servicio_escucha.dart` envolviendo `flutter_notification_listener`: `permisoConcedido()`, `abrirAjustesDePermiso()` (FR-002), `activar()`/`desactivar()` (guardan `capturaNotificacionesActiva` y arrancan/detienen el servicio)
- [X] T015 [P] [US1] Crear un doble en memoria de `ServicioEscuchaNotificaciones` en `test/dobles/` para las pruebas de UI que no pueden tocar el plugin real
- [X] T016 [US1] Crear el `ChangeNotifier` (nombrado `EstadoCapturaNotificaciones` para no chocar con el derivado `EstadoCaptura` de `dominio/modelos/`, que exporta) en `lib/ui/estado/estado_captura.dart`: combina `RepositorioConfiguracion` y `ServicioEscuchaNotificaciones` en el `EstadoCaptura` de T012
- [X] T017 [US1] Construir `lib/ui/pantallas/captura/pantalla_activacion.dart`: explica qué se leerá y que nada sale del dispositivo antes de pedir el permiso (FR-001), dirige a los ajustes de Android (FR-002), muestra el estado real sin caché (FR-003) y el aviso cuando el permiso fue revocado (FR-004), con el interruptor para desactivar desde la app (FR-005) — la lista de orígenes reconocidos puede ser larga (15 al lanzar): mostrarla resumida ("15 bancos y billeteras") con un detalle expandible, no una lista plana que empuje el resto de la pantalla
- [X] T018 [US1] Enganchar la pantalla en el drawer de `lib/ui/cascaron.dart`, visible **solo si** `Platform.isAndroid` (D-N8, FR-007) — en cualquier otra plataforma ese destino no se agrega a la lista, no se muestra deshabilitado
- [X] T019 [US1] Escribir `test/ui/captura/pantalla_activacion_test.dart` con el doble de T015: los cuatro estados de FR-003/FR-004 se explican con texto (no solo un ícono), y el registro manual de gastos de 001 sigue disponible con la captura inactiva o denegada (FR-006)

**Checkpoint**: US1 funciona sola. El usuario puede activar, denegar, revocar y desactivar la captura, y siempre entiende en qué estado está — todavía sin ningún consumo capturado.

---

## Phase 4: User Story 2 — Confirmar un consumo capturado (P1) 🎯 MVP (junto con US1)

**Goal**: un consumo real llega como pendiente con monto, comercio y fecha ya llenos; el usuario lo confirma de un toque (o lo corrige, o lo descarta) y queda registrado en su mes — nunca en silencio.

**Independent Test**: simular notificaciones (quickstart.md) y, sobre una muestra real de al menos 3 orígenes, verificar que el pendiente generado tiene los datos correctos y que confirmarlo crea la transacción del mes correspondiente a su fecha.

### Bandeja de pendientes (con `ConsumoPendiente` de prueba — no depende todavía del parser genérico real)

- [X] T020 [P] [US2] Definir el modelo `ConsumoPendiente` en `lib/dominio/modelos/consumo_pendiente.dart` (campo `origenPaquete`, no un enum cerrado — D-N10) y el derivado `ResumenPendientes` en `lib/dominio/modelos/resumen_pendientes.dart`
- [X] T021 [P] [US2] Definir la interfaz `RepositorioPendientes` en `lib/dominio/repositorios/`, según contracts/repositorios.md
- [X] T022 [US2] Implementar `RepositorioPendientesSqlite` en `lib/datos/repositorios/`: `insertar` es un upsert silencioso sobre `(origenPaquete, notificacionId)` (D-N5, FR-015), y dos pendientes con distinto `notificacionId` se conservan aunque monto y comercio coincidan (FR-016)
- [X] T023 [P] [US2] Crear el doble en memoria `RepositorioPendientesEnMemoria` en `test/dobles/`
- [X] T024 [US2] Escribir `test/datos/repositorio_pendientes_test.dart` contra SQLite real: `todos()` ordena por fecha descendente (FR-021), la deduplicación de T022, y que `eliminar` no deja rastro (FR-025)
- [X] T025 [P] [US2] Escribir `test/ui/captura/estado_pendientes_test.dart` **antes de implementar**: `confirmar()` crea la `Transaccion` con la fecha del consumo, no la de hoy (FR-026), y borra el pendiente; `descartar()` borra sin crear transacción (FR-025); confirmar un pendiente sin `categoriaPropuesta` exige elegir categoría antes (FR-033)
- [X] T026 [US2] Implementar `EstadoPendientes` (`ChangeNotifier`) en `lib/ui/estado/estado_pendientes.dart` hasta que T025 pase, reutilizando `RepositorioTransacciones` de 001 para crear la transacción confirmada
- [X] T027 [US2] Construir `lib/ui/pantallas/captura/pantalla_pendientes.dart`: bandeja ordenada del más reciente al más antiguo (FR-021), con la cantidad y el monto que suman (FR-022) y un aviso — texto e ícono, no solo color — cuando la cantidad es inusualmente alta (FR-028)
- [X] T028 [US2] Construir `lib/ui/pantallas/captura/formulario_confirmar_pendiente.dart`: confirmar en una sola acción cuando ya trae categoría (FR-023), permitir corregir monto, descripción, fecha y categoría antes de confirmar (FR-024), y descartar (FR-025)
- [X] T029 [US2] Enganchar la bandeja en el cascarón (visible solo en Android, igual que T018) con la cantidad de pendientes como distintivo
- [X] T030 [US2] Escribir `test/ui/captura/pantalla_pendientes_test.dart`: orden, total, aviso de cantidad inusual, y que confirmar/corregir/descartar funcionan de punta a punta contra los dobles

### Diagnóstico (notificaciones que no se pudieron interpretar)

- [X] T031 [P] [US2] Definir el modelo `NotificacionDiagnostico` (campo `origenPaquete`) y la interfaz `RepositorioDiagnostico`, con su implementación `Sqlite` y doble en memoria
- [X] T032 [US2] Escribir `test/datos/repositorio_diagnostico_test.dart`: orden por fecha descendente, `vaciar()` borra todo (FR-018)
- [X] T033 [US2] Construir `lib/ui/pantallas/captura/pantalla_diagnostico.dart`: consultar y borrar el registro (FR-018), y `test/ui/captura/pantalla_diagnostico_test.dart`

### El parser genérico — bloqueado por una captura real de notificaciones, una sola vez (D-N9)

- [ ] T034 [MANUAL] [US2] Capturar notificaciones reales de **al menos 3 orígenes distintos y variados** (idealmente un banco tradicional, una billetera tipo Yape/Plin, y un emisor de tarjeta) — al menos 4 ejemplos por origen: consumo normal, dinero recibido/entrante, y si es posible un rechazo/extorno y una moneda extranjera — y documentarlas en `test/dominio/interpretes/fixtures/` (un `.md` por origen) — **requiere el teléfono con esas apps instaladas; ningún agente puede generar este insumo**. A diferencia de un intérprete por banco, **esta captura se hace una sola vez**, no repetida por cada uno de los 15 orígenes de `origenesReconocidos`
- [X] T035 [P] [US2] Escribir `test/shared/dinero_test.dart` (ampliar el existente) **antes de** T036: `Dinero.deTextoDecimal('45.00')` compone el mismo entero que `validarMonto`, sin pasar por `double` (D-N3) — el archivo existente ya vivía en `test/dominio/dinero_test.dart` (no `test/shared/`, porque `Dinero` se prueba junto al resto de tipos puros desde 001); se amplió ahí para no fragmentar las pruebas del mismo tipo en dos archivos
- [X] T036 [US2] Implementar `Dinero.deTextoDecimal` en `lib/shared/tipos/dinero.dart` hasta que T035 pase, y refactorizar `validarMonto` en `lib/dominio/calculos/presupuesto.dart` para reutilizarlo — las pruebas ya existentes de 001 (`test/dominio/presupuesto_test.dart`) siguen en verde sin cambios; de paso se eliminó una rama muerta (`int.tryParse(entera) == null`) que ya era inalcanzable antes del refactor, porque `entera` solo puede contener dígitos en ese punto
- [X] T037 [US2] Crear el contrato en `lib/dominio/interpretes/interprete.dart`: `ResultadoInterpretacion`, `ConsumoExtraido`, `NoEsConsumo`, `NoInterpretable` (contracts/interpretes.md) — solo los tipos, sin `interpretar()` todavía: esa función es T039, que sigue bloqueada por los fixtures de T034/T038
- [ ] T038 [US2] Escribir `test/dominio/interpretes/interprete_generico_test.dart` **antes de implementar**, contra los fixtures de T034: cada consumo normal de la muestra produce `ConsumoExtraido`; dinero entrante/rechazo/extorno producen `NoEsConsumo` por las palabras clave de D-N11 (FR-008b, FR-012, FR-013); moneda extranjera produce `NoInterpretable(monedaExtranjera)` (FR-014); un texto sin palabras clave de ninguna dirección, o con señales de ambas, produce `NoInterpretable(formatoNoReconocido)`, nunca un dato inventado (FR-017)
- [ ] T039 [US2] Implementar el parser genérico en `lib/dominio/interpretes/interprete.dart` hasta que T038 pase: extrae el monto con `Dinero.deTextoDecimal` (T036), clasifica la dirección por palabras clave (D-N11) antes de intentar extraer nada más, y toma el comercio del texto que sobra
- [ ] T040 [P] [US2] ~~Implementar `normalizarComercio` de forma mínima~~ — nunca se hizo por separado: T046 (US3) creó `lib/dominio/interpretes/normalizador_comercio.dart` directamente con el alcance completo, ver la nota en T046. Sigue sin marcar como `[X]` porque el parser de T039 (todavía bloqueado) es quien la va a consumir de verdad; no hay nada pendiente de esta tarea en sí

### Enganche con el sistema operativo

- [ ] T041 [MANUAL] [US2] Observar en un dispositivo real el `packageName` de cada origen de `origenesReconocidos` (T005) que el usuario tenga instalado, y completarlo en `lib/shared/constantes/origenes_reconocidos.dart` — mismo tipo de insumo manual que T034, pero más liviano (un identificador de paquete, no un formato de texto); los orígenes sin `packageName` verificado quedan filtrados/no escuchados hasta que se completen, sin romper nada
- [ ] T042 [US2] Implementar el callback headless en `lib/datos/notificaciones/callback_headless.dart` (`@pragma('vm:entry-point')`): filtra por los paquetes de `origenesReconocidos` (T041) — una notificación de un paquete no listado ni se procesa ni se guarda (edge case "app no reconocida en absoluto") —, interpreta con el parser de T039, y escribe un `ConsumoPendiente` o una `NotificacionDiagnostico` según el resultado; abre su propia conexión a la base, sin importar nada de `lib/ui/`
- [ ] T043 [US2] Configurar el arranque del servicio en modo *foreground* con una notificación persistente discreta (D-N4), y el receptor de `BOOT_COMPLETED` del manifiesto (T003) para reintentarlo tras un reinicio

**Checkpoint**: US1 + US2 son el MVP de esta spec. Un consumo real de cualquiera de los orígenes con `packageName` verificado se captura con la app cerrada, aparece en la bandeja, y confirmarlo lo deja como transacción del mes correcto.

---

## Phase 5: User Story 3 — Que la app aprenda mis categorías (P2)

**Goal**: confirmar un comercio con una categoría hace que la próxima vez llegue ya propuesta.

**Independent Test**: confirmar un consumo de un comercio con una categoría, y verificar que un consumo posterior del mismo comercio llega con esa categoría propuesta, y que cambiarla actualiza la asociación (quickstart.md, paso 5).

### Tests para US3 ⚠️

- [X] T044 [P] [US3] Escribir `test/dominio/normalizador_comercio_test.dart` **antes de ampliar** T040: mayúsculas, espacios y sufijos de sucursal normalizan igual (FR-032) — ejemplos reales de los fixtures de T034 si los hay, para no inventar formatos de comercio — **sin fixtures de T034 todavía**: se usaron ejemplos sintéticos claramente etiquetados como tales, y el alcance del reconocimiento de sucursal se restringió a patrones seguros (código numérico final, palabra "SUC"/"SUCURSAL") documentando en el propio código qué casos quedan fuera hasta tener notificaciones reales
- [X] T045 [P] [US3] Ampliar `test/ui/captura/estado_pendientes_test.dart`: confirmar un comercio nunca antes visto con una categoría guarda la asociación (FR-029); un consumo posterior del mismo comercio llega con `categoriaPropuesta` ya llena (FR-030); confirmarlo con una categoría distinta actualiza la asociación, no la duplica (FR-031)

### Implementación para US3

- [X] T046 [US3] Completar `normalizarComercio` en `lib/dominio/interpretes/normalizador_comercio.dart` hasta que T044 pase — reemplaza la versión mínima de T040, sin tocar su firma — **T040 nunca se había hecho** (quedó bloqueada junto al resto del parser genérico), así que esta tarea creó el archivo directamente con el alcance completo descrito arriba, sin pasar por una versión mínima intermedia que nadie más iba a consumir
- [X] T047 [P] [US3] Definir el modelo `AsociacionComercio` y la interfaz `RepositorioAsociaciones`, con su implementación `Sqlite` y doble en memoria, según contracts/repositorios.md
- [X] T048 [US3] Escribir `test/datos/repositorio_asociaciones_test.dart`: `asociar` sobre un comercio ya asociado reemplaza la categoría (FR-031); `categoriaDe` de un comercio nunca visto es `null`, no una categoría por defecto (FR-033)
- [X] T049 [US3] Ampliar `EstadoPendientes`/el callback headless (T042) para consultar `RepositorioAsociaciones.categoriaDe(normalizarComercio(comercio))` al generar cada pendiente, y para guardar la asociación en `confirmar()` hasta que T045 pase — **la parte del callback headless queda pendiente de T042** (bloqueado por T034/T041): la propuesta de categoría se resuelve en `EstadoPendientes.cargar()`, que es el punto no bloqueado por donde ya pasan todos los pendientes, reales o de prueba
- [X] T050 [US3] Construir `lib/ui/pantallas/captura/pantalla_asociaciones.dart`: listar, corregir y eliminar asociaciones aprendidas (FR-034)
- [X] T051 [US3] Escribir `test/ui/captura/pantalla_asociaciones_test.dart`

**Checkpoint**: con el uso, la mayoría de los pendientes llegan con categoría correcta ya propuesta (SC-003) y confirmarlos vuelve a ser un solo toque.

---

## Phase 6: User Story 4 — Distinguir consumos en cuotas (P3)

**Goal**: una compra grande en cuotas no distorsiona el mes: se registra como deuda de 001, no como un gasto único.

**Independent Test**: marcar un pendiente de monto alto como compra en cuotas, indicar número de cuotas y cuota mensual, y verificar que se crea una `Deuda` de 001 en vez de una `Transaccion`, y que el presupuesto del mes solo ve la cuota, no el total.

### Tests para US4 ⚠️

- [X] T052 [P] [US4] Ampliar `test/ui/captura/estado_pendientes_test.dart` **antes de implementar**: `confirmar()` con la marca "en cuotas" crea una `Deuda` vía `RepositorioDeudas` de 001 (número de cuotas y cuota mensual del formulario) y **no** crea una `Transaccion`; sin esa marca, el comportamiento es el de US2 sin cambios (FR-037)

### Implementación para US4

- [X] T053 [US4] Ampliar `formulario_confirmar_pendiente.dart` (T028): opción "fue en cuotas", con número de cuotas y cuota mensual, reutilizando los campos de `FormularioDeuda` de 001 (FR-035, FR-036) — a diferencia del diseño original, ya no hay forma de saber por el origen si "admite cuotas" (ese concepto era propio de un banco de tarjeta de crédito conocido de antemano): la opción se ofrece siempre y es el usuario quien decide si aplica, igual que ya elige corregir cualquier otro campo del pendiente — **con una salvedad sobre "siempre"**: si el usuario todavía no registró ninguna tarjeta de crédito (`EstadoTarjetas.deCredito` vacío), el interruptor ni se muestra, porque una `Deuda` exige `tarjetaId` (FR-061) y no hay nada que ofrecer para completarlo; es el mismo criterio que ya aplica `FormularioDeuda` de 001, extendido acá
- [X] T054 [US4] Ampliar `EstadoPendientes.confirmar()` (T026) hasta que T052 pase: bifurca a `RepositorioDeudas.insertar` o a `RepositorioTransacciones.insertar` según la marca del formulario
- [X] T055 [US4] Ampliar `test/ui/pantalla_deudas_test.dart` de 001: una deuda creada desde un pendiente aparece en Deudas igual que una creada a mano, y el presupuesto del mes muestra solo la cuota (FR-036, FR-037 verificado end-to-end)

**Checkpoint**: las cuatro historias funcionan de forma independiente. La spec 002 queda completa.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T056 [P] Verificar que `test/pureza_test.dart` sigue pasando con `lib/dominio/interpretes/` ya completo — pasa con lo que existe hoy (`normalizador_comercio.dart`); falta re-verificar cuando el parser genérico (T034–T043) aterrice, ya que ese directorio todavía no está "completo" en el sentido que describe la tarea original
- [X] T057 [P] Revisar que ningún estado de esta feature (permiso revocado, cantidad inusual de pendientes, notificación en diagnóstico) se comunique solo por color, siguiendo el mismo patrón de `MarcaEstado`/`AvisoMesCerrado` de 001 — activación, pendientes y asociaciones ya lo hacían bien (ícono + texto en cada caso); la revisión encontró que **`PantallaDiagnostico` nunca mostraba `EstadoDiagnostico.error`** (ni con color: no se mostraba nada) — corregido agregando `EstadoDiagnostico.limpiarError()` y el mismo `_BannerError` que ya usan el resto de las pantallas de la feature, con prueba de regresión
- [X] T058 [P] Dejar `flutter analyze` sin issues y `dart format` aplicado a todo lo nuevo — de paso, se sumó `errorEnLaProximaEscritura` a los dobles de diagnóstico y asociaciones (ya lo tenían pendientes/transacciones/etc.) y una prueba de "fallo al escribir se muestra, no se traga" en pendientes, asociaciones y diagnóstico — 420 pruebas en verde
- [X] T059 ~~Confirmar la licencia real de `flutter_notification_listener`~~ — resuelto al instalar la dependencia (T001): `LICENSE` en `.pub-cache` es Apache 2.0, coincide con lo que mostraba GitHub. El "unknown" de pub.dev era un problema de detección de esa página, no una ausencia real de licencia.
- [ ] T060 [MANUAL] Verificar en un dispositivo real, y en lo posible en un fabricante propenso a matar servicios en segundo plano (Samsung o Xiaomi, no el Pixel del emulador de referencia), que el servicio sobrevive un reinicio y que la exención de optimización de batería (D-N4) se puede conceder desde la propia app
- [ ] T061 [MANUAL] Recorrer entero [quickstart.md](./quickstart.md) en un dispositivo Android real, incluidos modo avión y reinicio del dispositivo
- [ ] T062 [P] Actualizar `CLAUDE.md` con el estado de esta feature una vez completa

---

## Dependencies & Execution Order

### Dependencias de fase

- **Setup (F1)**: sin dependencias.
- **Foundational (F2)**: depende de F1. **Bloquea las cuatro historias** — sin los enums, la lista de orígenes y el esquema no hay dónde guardar ni a qué prestarle atención.
- **US1 (F3)** y **US2 (F4)**: dependen solo de F2. Son el MVP y conviene entregarlas juntas — US2 sin US1 no tiene cómo activarse, y US1 sin US2 no captura nada.
- **US3 (F5)**: depende de F2 y de que `ConsumoPendiente`/`EstadoPendientes` ya existan (US2, T020–T030): la categoría propuesta se inyecta en el mismo punto donde se genera el pendiente.
- **US4 (F6)**: depende de F2 y de `formulario_confirmar_pendiente.dart`/`EstadoPendientes.confirmar()` (US2), y de `FormularioDeuda`/`RepositorioDeudas` de 001.
- **Polish (F7)**: al final de las historias que se decidan entregar.

### El bloqueo de D-N9 ya no se multiplica por banco

T034 y T041 están marcadas `[MANUAL]` porque ningún agente puede generarlas solo — hace falta un teléfono con apps bancarias reales instaladas. A diferencia de la primera versión de esta lista (una captura y un `packageName` por cada uno de los 15 orígenes), acá **T034 se hace una sola vez** con una muestra representativa, y **T041 es más liviana** (observar un identificador de paquete, no un formato de texto completo) y puede completarse de a poco — un origen sin `packageName` verificado simplemente no se escucha todavía, sin romper el resto. **US2 se puede completar en gran parte sin ninguna de las dos**: la bandeja, la confirmación y el diagnóstico (T020–T033) no dependen de que el parser ni la lista de paquetes existan.

### Dentro de cada historia

Pruebas → modelos → repositorios → estado → pantallas → prueba de widget, igual que 001.

### Oportunidades de paralelismo

- T002–T003 en Setup.
- T004, T005, T008, T010 en Foundational.
- T020, T021, T023, T025 (bandeja) pueden avanzar en paralelo con T034 (captura manual) — no dependen entre sí.
- Con un solo desarrollador, [P] significa que el orden entre esas tareas es indiferente.

---

## Implementation Strategy

### MVP primero (US1 + US2)

1. Fase 1 — Setup (T001–T003)
2. Fase 2 — Foundational (T004–T010, crítica, bloquea todo)
3. Fase 3 — US1 (T011–T019)
4. Fase 4 — US2 (T020–T043) — **empezar por T020–T033, que no dependen de ninguna captura manual**; en paralelo, juntar la muestra de T034 para no bloquear el resto
5. **PARAR Y VALIDAR**: al menos un origen capturando de punta a punta, con el resto de la bandeja ya funcionando.

### Entrega incremental

1. Setup + Foundational → base lista
2. + US1 → activación funcionando, sin capturar nada todavía
3. + US2 (bandeja/confirmación primero, parser genérico después) → **MVP**, validar con notificaciones reales de al menos 3 bancos distintos
4. + US3 → la categorización deja de pedirse a mano en la mayoría de los casos
5. + US4 → las compras grandes en cuotas dejan de distorsionar el mes
6. Fase 7 — Polish

Cada incremento deja la app usable y no rompe 001.

---

## Notes

- Total: **62 tareas** (4 de ellas `[MANUAL]`: T034, T041, T060 y T061). Setup: 3 · Foundational: 7 · US1: 9 · US2: 24 · US3: 8 · US4: 4 · Polish: 7.
- Las pruebas de reglas financieras y del parser genérico no son opcionales: son requisito de entrada por constitución, con la salvedad de D-N9.
- Commitear por tarea o por grupo coherente, referenciando el id de la tarea.
- Cualquier desviación de un principio se justifica por escrito en plan.md, no en silencio durante la implementación.

---

## Fase 9: Defectos encontrados el 2026-09-13 (D-N13)

**Propósito**: hoy la captura **no corre en ningún teléfono con Android 13 o
superior**. Estas tres son independientes del parser y del alcance: valen igual
si la feature sigue por notificaciones de Gmail (D-N12) o si se cierra.

- [X] T063 Pedir `POST_NOTIFICATIONS` antes de activar la captura, en el flujo de `PantallaActivacion`/`EstadoCapturaNotificaciones`. Sin ese permiso el servicio en primer plano no puede publicar su notificación obligatoria y Android lo mata con ANR, así que la captura nunca corre (D-N13.1). Incluye explicar para qué se pide, como ya se explica el de notificaciones (FR-001) — resuelto con `permission_handler` (D-N14): `activar()` lo pide primero y **no enciende nada si el usuario lo rechaza**, porque encenderla igual dejaría la pantalla diciendo "activa" con una captura que Android va a matar
- [X] T064 Evitar que desactivar la captura deje la feature inutilizable (D-N13.2): el plugin deshabilita el componente del servicio y Android revoca el acceso a notificaciones, dejando a la app fuera de la lista de ajustes adonde ella misma manda al usuario — resuelto en `abrirAjustesDePermiso()`, que arranca el servicio antes de abrir la pantalla: ese arranque es el que vuelve a habilitar el componente, así que la app figura en la lista cuando el usuario llega. No toca el interruptor de la app: pedir el permiso no es activar la captura
- [X] T065 Que `EstadoCaptura` no informe "activa" sin verificar que el servicio exista (D-N13.3) — resuelto con un tercer dato, `servicioCorriendo`, preguntado al sistema en cada carga, y una situación nueva `detenida` que se comunica como problema ("La captura dejó de funcionar... tus consumos no se están registrando") y ofrece reactivar ahí mismo, sin mandar a los ajustes de Android porque el permiso sigue concedido
- [ ] T066 [MANUAL] Capturar un **consumo con tarjeta** real con el instrumento de volcado, y anotarlo en `test/dominio/interpretes/fixtures/notificacion-gmail-capturada.md`. Es lo único que falta para cerrar T034 y para poder decidir D-N12: los tres correos capturados hasta ahora son movimientos entre cuentas, no consumos
- [ ] T067 Borrar el instrumento temporal de volcado (`lib/dominio/interpretes/volcado_notificacion.dart`, su prueba y el cuerpo de `callback_headless.dart`) una vez que T066 esté cerrada
