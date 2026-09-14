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

### El parser genérico — la decisión de alcance ya está tomada (D-N12)

> **Desbloqueado el 2026-09-13 de noche.** Este tramo estuvo frenado desde el
> 2026-08-30 y ya no lo está. **D-N12 está cerrada** —los consumos entran por
> correo, un origen se identifica por app **o** por remitente— y **T034 también**:
> G5 y G6 aportaron el consumo con tarjeta en soles que faltaba. Las pruebas de
> T038/T038a están escritas y en rojo contra el stub de `interpretar()`. **Lo
> único que queda es T039**, que ya no espera nada.

- [X] T034 [MANUAL] [US2] **Cerrada el 2026-09-13 de noche** con G5 y G6: dos consumos con Tarjeta de Crédito Sip **en soles** (`S/. 37.70` y `S/. 15.90`), capturados vía `adb logcat` con el teléfono conectado por Wi-Fi. Los dos cuerpos miden exactamente lo que el volcado declaró (667 y 665 caracteres), así que son capturas íntegras. Con esto la muestra cubre los cuatro casos que la tarea pedía —consumo normal en soles, dinero entrante, envío saliente y moneda extranjera— sobre tres orígenes distintos (BCP, Sip, Yape). Enunciado original: Capturar notificaciones reales de **al menos 3 orígenes distintos y variados** (idealmente un banco tradicional, una billetera tipo Yape/Plin, y un emisor de tarjeta) — al menos 4 ejemplos por origen: consumo normal, dinero recibido/entrante, y si es posible un rechazo/extorno y una moneda extranjera — y documentarlas en `test/dominio/interpretes/fixtures/` (un `.md` por origen) — **requiere el teléfono con esas apps instaladas; ningún agente puede generar este insumo**. A diferencia de un intérprete por banco, **esta captura se hace una sola vez**, no repetida por cada uno de los 15 orígenes de `origenesReconocidos` — **parcialmente cumplida al 2026-09-13**: `notificacion-gmail-capturada.md` tiene cuatro capturas reales hechas por la propia app (BCP entrante, Sip saliente, el resumen de grupo de Gmail y un consumo con tarjeta de crédito), más el push de Yape que dio su `packageName`. **Falta un solo caso**: un consumo con tarjeta **en soles**, porque el capturado vino en dólares y cae en FR-014. Sin él, T038 no puede probar el camino feliz — **pero ya no bloquea la decisión de alcance**, que cerró con D-N12 el 2026-09-13: lo capturado alcanzó para decidir por dónde entran los consumos y cómo tiene que leerlos el parser. Lo que falta es cobertura de prueba del camino feliz, no información de diseño
- [X] T035 [P] [US2] Escribir `test/shared/dinero_test.dart` (ampliar el existente) **antes de** T036: `Dinero.deTextoDecimal('45.00')` compone el mismo entero que `validarMonto`, sin pasar por `double` (D-N3) — el archivo existente ya vivía en `test/dominio/dinero_test.dart` (no `test/shared/`, porque `Dinero` se prueba junto al resto de tipos puros desde 001); se amplió ahí para no fragmentar las pruebas del mismo tipo en dos archivos
- [X] T036 [US2] Implementar `Dinero.deTextoDecimal` en `lib/shared/tipos/dinero.dart` hasta que T035 pase, y refactorizar `validarMonto` en `lib/dominio/calculos/presupuesto.dart` para reutilizarlo — las pruebas ya existentes de 001 (`test/dominio/presupuesto_test.dart`) siguen en verde sin cambios; de paso se eliminó una rama muerta (`int.tryParse(entera) == null`) que ya era inalcanzable antes del refactor, porque `entera` solo puede contener dígitos en ese punto
- [X] T037 [US2] Crear el contrato en `lib/dominio/interpretes/interprete.dart`: `ResultadoInterpretacion`, `ConsumoExtraido`, `NoEsConsumo`, `NoInterpretable` (contracts/interpretes.md) — solo los tipos, sin `interpretar()` todavía: esa función es T039, que sigue bloqueada por los fixtures de T034/T038
- [ ] T038 [US2] Escribir `test/dominio/interpretes/interprete_generico_test.dart` **antes de implementar**, contra los fixtures de T034: cada consumo normal de la muestra produce `ConsumoExtraido`; dinero entrante/rechazo/extorno producen `NoEsConsumo` por las palabras clave de D-N11 (FR-008b, FR-012, FR-013); moneda extranjera produce `NoInterpretable(monedaExtranjera)` (FR-014); un texto sin palabras clave de ninguna dirección, o con señales de ambas, produce `NoInterpretable(formatoNoReconocido)`, nunca un dato inventado (FR-017) — **el camino feliz de esta tarea espera el fixture en soles de T034**; todo lo demás se adelanta en T038a
- [X] T038a [US2] **Escrita, en rojo a propósito** (8 pruebas fallando contra el `UnimplementedError` de `interpretar()`, más 1 saltada que reserva el camino feliz de T034): la parte de T038 que los fixtures existentes sí cubren, en `test/dominio/interpretes/interprete_generico_test.dart`. Los cuerpos de correo viven en `fixtures/textos_capturados.dart`, **extraídos del `.md` por script y no tecleados**, para que la regla de D-N9 no se pierda al pasar el texto a Dart. Alcance original: la parte de T038 que los fixtures existentes sí cubren, contra G1–G4 de `notificacion-gmail-capturada.md` — G3 (yapeo recibido) produce `NoEsConsumo`; G4 (`$ 23.60`) produce `NoInterpretable(monedaExtranjera)` (FR-014), y es el primer texto real para esa prueba; el resumen de grupo se descarta por `evento.isGroup` y **no** por `textLines` (punto 2 de D-N12 — la regla vieja contaría el consumo dos veces, así que esta prueba existe para que no vuelva); leer el `bigText` entero de G4 produce `NoInterpretable(formatoNoReconocido)` mientras el pie del BCP no se recorte, y acotar hasta el primer renglón que empieza con `¿` lo vuelve interpretable (punto 3 de D-N12)
- [X] T039 [US2] **Hecho el 2026-09-13.** Las 14 pruebas de T038/T038a pasan. La dirección se clasifica **primero por el asunto** (la primera línea del correo) y solo si no alcanza por el cuerpo: el asunto dice la operación sin nada que lo contradiga, mientras que el cuerpo está lleno de etiquetas que parecen señales y no lo son (`Operación realizada` encabeza un yapeo recibido y uno enviado por igual; `Enviado por` se parece demasiado a `Enviado a`). El recorte del pie usa una lista de aperturas observadas, **no el `¿`**, que solo existe en los correos del BCP. Enunciado original: Implementar el parser genérico en `lib/dominio/interpretes/interprete.dart` hasta que T038/T038a pasen: **acota primero la zona legible** hasta el primer renglón que empieza con `¿` (punto 3 de D-N12, sin esto el pie del BCP envenena la clasificación), extrae el monto con `Dinero.deTextoDecimal` (T036) sabiendo que va en su propio renglón y no junto a su etiqueta, clasifica la dirección por palabras clave (D-N11 **con la lista ampliada de D-N15**: un envío de dinero es un consumo igual que una compra con tarjeta, FR-008d) antes de intentar extraer nada más, y toma el comercio de la etiqueta `Empresa` con la frase de apertura como respaldo — sin partir el nombre en el asterisco de `ANTHROPIC* CLAUDE SUB` (puntos 4 a 6 de D-N12)
- [ ] T040 [P] [US2] ~~Implementar `normalizarComercio` de forma mínima~~ — nunca se hizo por separado: T046 (US3) creó `lib/dominio/interpretes/normalizador_comercio.dart` directamente con el alcance completo, ver la nota en T046. Sigue sin marcar como `[X]` porque el parser de T039 (todavía bloqueado) es quien la va a consumir de verdad; no hay nada pendiente de esta tarea en sí. **Confirmado al cerrar T039**: el parser devuelve el comercio **crudo** y la normalización ocurre donde corresponde, en `EstadoPendientes` al buscar y aprender la asociación. Separación correcta, la nota de arriba era especulativa.
- [ ] T040a [US2] **Hueco verificado en `normalizarComercio`**: hoy recorta un código numérico solo al **final** (`^(.+?)\s+\d+$`), pero los comercios reales lo traen al principio o en el medio — `231 PVEA VENTANILLA` y `IKF 982 PV VENTANILLA` (G5, G6). Dos sucursales de la misma cadena normalizan distinto y FR-032 aprende una categoría por sucursal. No se arregló junto con T039 porque no es gratis: recortar un número inicial rompería un comercio que legítimamente empiece con dígitos, así que necesita decidirse con más ejemplos reales

### Enganche con el sistema operativo

- [X] T041 [MANUAL] [US2] **Cerrada el 2026-09-13**, y por una vía más simple que la prevista: `adb shell pm list packages` lista los paquetes instalados sin necesidad de provocar una notificación de cada app. Verificados los cuatro que el usuario tiene: `com.bcp.bank.bcp`, `com.bcp.innovacxion.yapeapp`, `pe.solera.tarjetaoh` y `com.falabella.falabellaApp`. Confirmado con el usuario que Sip es la Tarjeta Oh! renombrada —de ahí que el paquete diga `tarjetaoh` y los correos firmen `Sip`— y que la app de Falabella es la del banco, no la de la tienda. Los demás orígenes no están instalados en este teléfono y siguen sin paquete, que es su estado correcto. Enunciado original: Observar en un dispositivo real el `packageName` de cada origen de `origenesReconocidos` (T005) que el usuario tenga instalado, y completarlo en `lib/shared/constantes/origenes_reconocidos.dart` — mismo tipo de insumo manual que T034, pero más liviano (un identificador de paquete, no un formato de texto); los orígenes sin `packageName` verificado quedan filtrados/no escuchados hasta que se completen, sin romper nada. **Reencuadrada por D-N12**: para los orígenes que solo avisan por correo el paquete no existe, y lo que hay que anotar es el **remitente** (el `title` de la notificación de Gmail). Ya observados: `BCP Notificaciones`, `Operaciones Sip`, `YAPE Notificaciones`. Un origen es utilizable si tiene verificado **cualquiera** de los dos
- [X] T041a [US2] **Hecha** — `remitente` junto a `paquete`, `utilizable` cuando cualquiera de los dos esté verificado, y `filtrarNotificacion` como función pura que decide **sin recibir el cuerpo de la notificación**: así FR-008c queda garantizado por la forma del código y no por disciplina de quien lo llame. Sembrados los tres remitentes observados (`BCP Notificaciones`, `Operaciones Sip`, `YAPE Notificaciones`) y el paquete de Yape (`com.bcp.innovacxion.yapeapp`), único origen que publicó push propio. 14 pruebas en `test/dominio/origenes_reconocidos_test.dart`. Alcance original: además de `paquete`, un `remitente`, con `origenUtilizable` cierto cuando cualquiera de los dos esté verificado — hoy la clase solo tiene `paquete` y `paqueteVerificado`, así que tal como está no puede expresar un origen que llega por correo. Incluye la prueba del filtro: un `title` no reconocido no calza, y Gmail sin remitente reconocido tampoco
- [X] T042 [US2] **Hecho el 2026-09-13.** La decisión se extrajo a `lib/dominio/interpretes/decision_captura.dart`, Dart puro y con 11 pruebas, y el callback quedó como pegamento que solo persiste lo que esa función resuelve. Lo que más cuidan las pruebas es lo que **no** se guarda: de un origen ajeno no queda rastro de ningún tipo (FR-008c) y el dinero entrante tampoco genera diagnóstico, porque el diagnóstico es para lo que no se entendió y eso se entendió perfectamente. El callback llama a `DartPluginRegistrant.ensureInitialized()` —sin eso `sqflite` no tiene canal en el isolate headless— y abre y cierra su propia conexión. Enunciado original: Implementar el callback headless en `lib/datos/notificaciones/callback_headless.dart` (`@pragma('vm:entry-point')`): filtra por `origenesReconocidos` (T041/T041a) **por paquete o por remitente**, descarta el resumen de grupo de Gmail por `evento.isGroup`, lee el cuerpo de `evento.raw['bigText']` y no de `text` (que viene truncado), interpreta con el parser de T039, y escribe un `ConsumoPendiente` o una `NotificacionDiagnostico` según el resultado; abre su propia conexión a la base, sin importar nada de `lib/ui/`. **FR-008c es vinculante acá**: lo que no calza con un origen reconocido se descarta **antes** de leer su cuerpo y no deja rastro de ningún tipo — ni pendiente, ni diagnóstico, ni log. La app recibe la notificación de todo correo del teléfono; solo puede mirar la del banco
- [X] T043 [US2] **Ya estaba satisfecho**, verificado el 2026-09-13: `activar()` arranca con `foreground: true` y una notificación discreta, el manifiesto declara `foregroundServiceType="specialUse"` con la `property` que Android 14+ exige, y el `RebootBroadcastReceiver` escucha `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`, `QUICKBOOT_POWERON` y `REBOOT` con `directBootAware`. Quedó implementado de paso al arreglar D-N13. **Falta la tercera pata de D-N4**, que no estaba en ninguna tarea: ver T043a. Enunciado original: Configurar el arranque del servicio en modo *foreground* con una notificación persistente discreta (D-N4), y el receptor de `BOOT_COMPLETED` del manifiesto (T003) para reintentarlo tras un reinicio

- [ ] T043a [US2] **Hueco de D-N4 sin tarea hasta ahora**: la decisión dice que la activación "pide excluir la app de la optimización de batería del fabricante", y **nada en el código lo pide**. No está declarado `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` en el manifiesto ni se solicita desde la app, así que T060 no se puede verificar tal como está escrita. **No se implementó sobre la marcha a propósito**: Google Play restringe ese permiso a un conjunto acotado de casos de uso y exige justificarlo, y la app está a punto de publicarse. Decidir primero si se pide, y con qué justificación, antes de escribirlo

- [X] T064a [US1] **Arreglado y verificado el 2026-09-13**: tras tres ciclos de Desactivar → Activar, cuatro notificaciones de prueba llegaron las cuatro al lado Dart, y el componente del servicio nunca quedó deshabilitado. El arreglo es **por omisión**: `desactivar()` dejó de llamar al `stopService` del plugin —que apaga deshabilitando el componente— y usa `requestUnbind` en su lugar, con `requestRebind` al activar. Los dos van juntos: el rebind solo se probó antes y Android lo rechaza para listeners que no se soltaron con `requestUnbind`. **No hizo falta forkear el plugin**: publica su servicio como estática pública (`NotificationsHandlerService.instance`), así que un `MethodChannel` propio de ~20 líneas en `MainActivity.kt` alcanza. Enunciado original: **D-N13.2 sigue vivo: el ciclo Desactivar → Activar deja la captura muerta y sin síntoma.** Reproducido en dispositivo el 2026-09-13 a las 22:54: antes del ciclo llegaban eventos, después del ciclo ninguno, con el permiso concedido, el componente habilitado y el servicio corriendo en foreground. La causa está en el plugin: al arrancar hace `disableServiceSettings` + `enableServiceSettings` con el comentario *"and try to toggle the service to trigger rebind"*, pero **nunca llama a `NotificationListenerService.requestRebind()`**, que es la única API con la que Android vuelve a vincular un listener cuyo componente se deshabilitó. T064 arregló solo el camino que pasa por la pantalla de ajustes de Android —ahí funciona porque el interruptor lo toca el usuario y eso sí fuerza el rebind—, no el que la app ofrece. ~~**Arreglo propuesto**: un `MethodChannel` propio en `MainActivity.kt` que llame a `requestRebind(ComponentName(...))` después de arrancar el servicio.~~ **Probado el 2026-09-13 y NO funciona.** Se implementó, compiló y corrió: `activar()` se completó entero —el interruptor quedó guardado en la base y no hubo excepción, así que el canal respondió— y Android **ignoró el pedido**; la notificación de prueba posterior no llegó a Dart. La razón está en el contrato de Android: `requestRebind` es *"after a previous call to `requestUnbind()`"* y **falla para listeners que no fueron desvinculados así**. El nuestro no se desvinculó con `requestUnbind`: se cayó porque el componente quedó deshabilitado, que es otro camino. El par correcto sería `requestUnbind` + `requestRebind`, **pero `requestUnbind()` es un método de instancia** del propio servicio, y ese servicio es del plugin: no tenemos la instancia. El código se revirtió para no dejar en `main` un arreglo que no arregla. Verificado a mano, dos veces, que forzar el rebind por `adb shell cmd notification disallow_listener` + `allow_listener` restablece la captura — o sea que **lo único que revincula es volver a conceder el acceso**, y eso desde la app solo puede hacerlo el usuario en los ajustes de Android.

  **Las tres salidas que quedan, sin decidir:**

  1. **Nunca deshabilitar el componente.** `desactivar()` deja de llamar al `stopService` del plugin —que es quien lo deshabilita— y en su lugar apaga solo el interruptor guardado; el callback corta temprano cuando está apagado. Para que la notificación persistente desaparezca hace falta un `stopService`/`stopForeground` propio en Kotlin que **no** toque el componente. Es la más autocontenida y la única que deja "Desactivar" de un solo toque.
  2. **Guiar al usuario a los ajustes al activar**, que es lo que sí revincula. Funciona seguro —es el camino que T064 ya arregló— pero convierte activar en dos pasos y manda al usuario a una pantalla del sistema cada vez.
  3. **Parchear el plugin** (fork) para sacar `disableServiceSettings` del camino de apagado y usar ahí `requestUnbind()`, que desde dentro del servicio sí se puede llamar. Es donde está el problema de verdad, y también donde el costo de mantenimiento es más alto
- [X] T064b [US2] **Resuelta con D-N16**: sin ninguna cifra de dinero en el texto no hubo movimiento, así que se resuelve como `NoEsConsumo` y no deja rastro. Se reusó `NoEsConsumo` en vez de agregar un tipo nuevo —el contrato ya lo cubría con "una promoción, etc." y nadie ramificaría por el caso nuevo— y la contracara quedó probada: con cifra y sin dirección clara, sigue yendo a diagnóstico. El aviso de Yape quedó como G7 en el fixture, el primero que no vino de un instrumento sino de la app trabajando. Enunciado original: **El registro de diagnóstico se va a llenar de correos informativos.** El aviso recurrente de Yape ("Por tu seguridad, te notificaremos por cada yapeo que realices") viene de un remitente reconocido y no tiene palabras de dirección, así que cae en `formatoNoReconocido` y genera una fila cada vez. Es el comportamiento que FR-018 pide y aun así hace al diagnóstico menos útil para lo que existe, que es detectar consumos mal interpretados. Decidir si se reconocen como "avisos que no son movimiento" —una tercera salida junto a `NoEsConsumo`— o se deja como está y se confía en que el usuario lo vacíe

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
- [ ] T060 [MANUAL] **Parcialmente hecha el 2026-09-13** en un Honor CRT-LX3 con Android 14: la captura se verificó de punta a punta —un yapeo enviado de S/ 1.00 produjo exactamente un `ConsumoPendiente` con monto, comercio y fecha correctos, el correo entrante no dejó rastro, y el resumen de grupo de Gmail no duplicó la fila—, lo que prueba además que el isolate headless puede abrir y escribir la base. **Falta** lo que la tarea pide de verdad: sobrevivir un reinicio, y la exención de optimización de batería, que no existe (ver T043a). Enunciado original: Verificar en un dispositivo real, y en lo posible en un fabricante propenso a matar servicios en segundo plano (Samsung o Xiaomi, no el Pixel del emulador de referencia), que el servicio sobrevive un reinicio y que la exención de optimización de batería (D-N4) se puede conceder desde la propia app
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
- [X] T066 [MANUAL] Capturar un **consumo con tarjeta** real con el instrumento de volcado, y anotarlo en `test/dominio/interpretes/fixtures/notificacion-gmail-capturada.md` — capturado el 2026-09-13 10:54 (G4 del fixture): consumo con Tarjeta de Crédito BCP, llegado por correo vía Gmail con el `bigText` completo. Deja **decidible D-N12** y aporta cuatro cosas que ningún texto inventado habría dado: el comercio aparece bajo la etiqueta `Empresa` **y** en la frase de apertura; hay un `Número de operación` que sirve de clave de deduplicación mejor que monto+fecha; el BCP escribe `setiembre` y `septiembre` indistintamente; y el resumen de grupo de Gmail **copia el `bigText` del correo** cuando hay uno solo sin leer, así que la regla de descarte que dejaron G1–G3 contaría el consumo dos veces — la que sirve es `evento.isGroup`. **El consumo vino en dólares** (`$ 23.60`), que es el caso de FR-014 (`NoInterpretable(monedaExtranjera)`): cierra ese camino de T038 y deja abierto el feliz, que necesita un consumo en soles
- [X] T067 **Hecho el 2026-09-13.** Borrados `lib/dominio/interpretes/volcado_notificacion.dart` y su prueba, y el cuerpo del callback pasó a ser el de T042. Con esto la app deja de escribir texto de notificaciones al log y al archivo local, que era lo único que contradecía la política de privacidad. Enunciado original: Borrar el instrumento temporal de volcado (`lib/dominio/interpretes/volcado_notificacion.dart`, su prueba y el cuerpo de `callback_headless.dart`) una vez que T066 esté cerrada — **todavía no**: T066 cerró, pero T034 sigue esperando un consumo en soles (ver su nota), y borrar el instrumento antes de esa captura obliga a reconstruirlo. Es la última tarea antes de poder publicar: mientras exista, el volcado escribe texto de notificaciones al log y a un archivo local, y eso contradice lo que la política de privacidad promete
