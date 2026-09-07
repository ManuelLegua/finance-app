---

description: "Task list para 004-suscripcion-premium"
---

# Tasks: Suscripción premium

**Input**: Documentos de diseño en `specs/004-suscripcion-premium/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/repositorio-suscripcion.md](./contracts/repositorio-suscripcion.md), [quickstart.md](./quickstart.md)

**Tests**: **SÍ se incluyen y no son opcionales.** El Principio III exige prueba antes de implementación para la lógica que decide acceso o dinero, y acá `EstadoSuscripcion.estaVigente` decide si el usuario ve o no una pantalla por la que paga. Con la salvedad de D5 de research.md: el flujo real de compra/restauración/vencimiento **no se puede automatizar** — se valida a mano contra la pista de pruebas internas de Google Play (tareas `[MANUAL]`).

**Corrección respecto al plan**: plan.md y data-model.md dicen que `Esquema.version` pasa de **1 a 2**. Eso quedó desactualizado: la base ya va por **v3** (spec 002 la subió a 2, spec 003 a 3). Esta feature agrega la migración **v3 → v4**. El resto del diseño no cambia.

**Organización**: agrupadas por historia de usuario, en el orden de prioridad de la spec (US1, US2 y US3 son P1; US4 y US5 son P2).

## Format: `[ID] [P?] [Story] Descripción`

- **[P]**: puede hacerse en paralelo (archivos distintos, sin dependencias pendientes).
- **[Story]**: a qué historia pertenece (US1…US5).
- **[MANUAL]**: no se puede completar sin la app publicada en la pista de pruebas internas de Google Play Console y una cuenta de prueba de licencias — no es una tarea de código.
- Cada tarea indica la ruta exacta del archivo.

## Path Conventions

Mismo proyecto Flutter único de 001: código en `lib/`, pruebas en `test/`, ambos en la raíz del repositorio. Esta feature no crea estructura nueva, extiende la existente (ver *Structure Decision* en plan.md).

---

## Phase 1: Setup

**Propósito**: la dependencia de facturación y el andamiaje de directorios, sin lógica todavía.

- [X] T001 Agregar la dependencia con `flutter pub add in_app_purchase in_app_purchase_android`, verificando en `pubspec.yaml` que quedaron fijadas y anotando en `research.md` D1 la versión exacta instalada y la versión de Billing Library que envuelve — quedaron `in_app_purchase ^3.3.0` e `in_app_purchase_android ^0.5.3`, que declara `com.android.billingclient:billing:8.0.0`, la misma versión que asumía D1
- [X] T002 [P] Crear los directorios `lib/ui/pantallas/suscripcion/` y confirmar que `lib/dominio/modelos/`, `lib/dominio/repositorios/` y `lib/datos/repositorios/` ya existen (existen desde 001), según plan.md — quedó hecho al crear `pantalla_paywall.dart` en T016 (git no versiona directorios vacíos, así que no tenía sentido antes). Los otros tres ya existían
- [X] T003 Verificar la licencia real del paquete instalado leyendo el `LICENSE` en `.pub-cache`, igual que se hizo con `flutter_notification_listener` en la spec 002 (T059), y dejarlo anotado en `research.md` D1 — BSD de tres cláusulas de The Flutter Authors en ambos paquetes, sin ambigüedad

**Checkpoint**: `flutter analyze` y `flutter test` corren limpios con la dependencia nueva incorporada.

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Propósito**: los enums, el modelo de dominio con su regla de vigencia, el esquema y el puerto de datos de los que dependen las cinco historias.

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta terminar esta fase.

- [X] T004 [P] Definir `PlanSuscripcion` (`mensual`, `anual`) y `SituacionSuscripcion` (`nunca`, `enPrueba`, `activa`, `enGracia`, `vencida`, `cancelada`) en `lib/shared/constantes/enums.dart`, con el mismo patrón slug/etiqueta/`desdeSlug` que `Categoria` y `MotivoDiagnostico` — slugs exactamente como los fija data-model.md §1, porque son los que valida el `CHECK` de la tabla
- [X] T005 [US1] Escribir `test/dominio/suscripcion_test.dart` **antes de implementar** (Principio III): `estaVigente` es `true` para `enPrueba`, `activa` y `enGracia`, y `false` para `nunca`, `vencida` y `cancelada` — las seis situaciones, ninguna por omisión; además, que el getter no mira `vigenteHasta` ni la fecha del dispositivo (D2 de research.md: dos relojes desincronizados no deciden un acceso pago) — se verificó que fallaba antes de existir el modelo, y se sumó una prueba que se rompe si mañana se agrega una situación al enum sin decidir si concede acceso
- [X] T006 Implementar `EstadoSuscripcion` (con `situacion`, `plan`, `vigenteHasta`, `ultimaVerificacion` y el getter puro `estaVigente`) y `OfertaSuscripcion` (`plan`, `precioFormateado`, `duracionPruebaDias`) en `lib/dominio/modelos/estado_suscripcion.dart` hasta que T005 pase — `precioFormateado` es un `String` que llega ya formateado por Google Play y **no** se convierte a `Dinero` ni se opera aritméticamente (Principio II, Constitution Check de plan.md)
- [X] T007 [P] Definir la interfaz `RepositorioSuscripcion` en `lib/dominio/repositorios/repositorio_suscripcion.dart` con los cinco métodos del contrato (`estadoCacheado`, `refrescar`, `ofertasDisponibles`, `comprar`, `restaurar`), documentando en cada uno la garantía que fija contracts/repositorio-suscripcion.md
- [X] T008 Escribir el DDL de `suscripcion_premium` en `lib/datos/esquema.dart` (subir `Esquema.version` de 3 a **4**) y el paso `4:` en el mapa `Migraciones.pasos` de `lib/datos/migraciones.dart` — DDL exacto en data-model.md §4, fila única `id = 1` igual que `configuracion`, sin tocar ninguna tabla existente
- [X] T009 Ampliar `test/datos/base_datos_test.dart`: la migración v3 → v4 crea `suscripcion_premium`, preserva las filas de 001/002/003 ya existentes, y `user_version` sube en uno — se hizo en un archivo propio, `test/datos/migracion_004_test.dart`, siguiendo el precedente de `migracion_002_test.dart` (probar el camino real de `onUpgrade`, no solo que el DDL sea válido); `base_datos_test.dart` solo suma la tabla nueva a la lista de tablas esperadas. A diferencia de la 002, el esquema v3 no se congela a mano: el paso v4 es puramente aditivo, así que "v3" es el esquema actual menos esa tabla
- [X] T010 Implementar `RepositorioSuscripcionBilling` en `lib/datos/repositorios/repositorio_suscripcion_billing.dart`: `estadoCacheado()` lee la fila local sin tocar la red y devuelve `situacion = nunca` si no hay fila; `refrescar()` consulta Google Play y **no lanza si no hay conexión** (devuelve el cacheado); `ofertasDisponibles()` sí lanza `ErrorPersistencia.alLeer` sin conexión (mostrar un precio viejo sería engañoso); `comprar`/`restaurar` según el contrato. Todo el SDK `in_app_purchase` queda contenido acá, nunca en `lib/dominio/` ni en `lib/ui/`

  **Dos límites del cliente que aparecieron al implementarlo** (documentados en el propio código, sobre `_situacionSegunCompra`): sin un servidor que consulte la Play Developer API —que el Principio I no permite montar— (1) un refresco **no puede distinguir "en prueba" de "activa"**, así que `enPrueba` solo se fija al comprar, donde sí se conoce la oferta elegida; y (2) una suscripción **cancelada pero con período aún vigente se ve igual que una activa**, porque Google la sigue devolviendo — se refleja como `activa` a propósito (el usuario conserva el acceso que pagó) y recién pasa a `vencida` cuando Google deja de reportarla. Consecuencia: `SituacionSuscripcion.cancelada` existe en el modelo (data-model.md la define) pero **este adaptador nunca la produce**. Confirmar en T044 si conviene quitarla del enum o si el flujo real la hace alcanzable
- [X] T011 [P] Crear el doble `RepositorioSuscripcionEnMemoria` en `test/dobles/repositorios_en_memoria.dart`, con el mismo `errorEnLaProximaEscritura` que ya tienen los demás dobles, más una forma de simular "sin conexión" para `ofertasDisponibles()` — además `vecesQueSeCompro`, para que T023 pueda verificar que un doble toque no dispara dos compras
- [X] T012 [P] Verificar que `test/pureza_test.dart` falla si `lib/dominio/` importa `package:in_app_purchase`: agregar ese paquete al mapa `prohibidos` junto a `package:flutter/` y `package:sqflite` (`test/pureza_test.dart:35`)

**Checkpoint**: el esquema guarda el estado, el dominio sabe decidir la vigencia sin conocer el SDK, y hay con qué probar la UI sin tocar Google Play.

---

## Phase 3: User Story 1 — Descubrir qué se desbloquea (P1) 🎯 MVP (junto con US2 y US3)

**Goal**: un usuario sin suscripción que toca Deudas o Ahorro entiende qué se desbloquea y a qué precio, en vez de encontrarse una pantalla vacía o un candado sin explicación.

**Independent Test**: entrar a Deudas y a Ahorro sin suscripción activa y verificar que aparece el aviso con el precio mensual, el anual y la prueba gratis (quickstart.md, paso 1).

### Tests para US1 ⚠️

- [X] T013 [P] [US1] Escribir `test/ui/pantalla_paywall_test.dart` **antes de implementar**: sin suscripción vigente, Deudas y Ahorro muestran el paywall y **no** la pantalla real (FR-001, FR-002); el paywall nombra las tres funcionalidades que desbloquea, el precio de ambos planes y la prueba gratis, todo como texto (FR-005, Principio IV: no alcanza con un ícono de candado); cerrarlo devuelve a la pantalla anterior sin haber iniciado ninguna compra (Acceptance Scenario 4)
- [X] T014 [P] [US1] Ampliar `test/ui/pantalla_paywall_test.dart`: si `ofertasDisponibles()` falla por falta de conexión, el paywall lo explica y ofrece reintentar, **sin inventar precios** (data-model.md §2)

### Implementación para US1

- [X] T015 [US1] Crear el `ChangeNotifier` `EstadoSuscripcion` en `lib/ui/estado/estado_suscripcion.dart` (nombrado `EstadoSuscripcionPremium` si choca con el modelo de dominio homónimo que exporta, mismo criterio que `EstadoCapturaNotificaciones` en la spec 002): expone `premiumActivo`, `situacion`, `ofertas`, y los métodos `cargar()`, `refrescar()`, `comprar(plan)` y `restaurar()`, delegando en `RepositorioSuscripcion`
- [X] T016 [US1] Construir `lib/ui/pantallas/suscripcion/pantalla_paywall.dart` hasta que T013/T014 pasen: explica en texto qué desbloquea (Deudas, Ahorro y captura de notificaciones), muestra ambos planes con su `precioFormateado` y la prueba gratis, y ofrece cerrar sin comprar
- [X] T017 [US1] Enganchar la guarda en `lib/ui/cascaron.dart`: los destinos `Deudas` y `Ahorro` de `_frecuentes` consultan `EstadoSuscripcion.premiumActivo` y muestran el paywall en su lugar cuando no está vigente (FR-001, FR-002), sin desmontar ni tocar los repositorios de esas pantallas
- [X] T018 [US1] Bloquear el flujo de activación de la captura de notificaciones en `lib/ui/pantallas/captura/pantalla_activacion.dart`: sin suscripción vigente, muestra el paywall y **no inicia** la solicitud del permiso de Android (FR-003) — el permiso ya concedido antes de vencer no se revoca desde acá, eso es US4
- [X] T019 [US1] Escribir `test/ui/captura/pantalla_activacion_test.dart` (ampliar el existente de la spec 002): sin suscripción, el interruptor de activación no dispara el flujo de permiso y se ve el aviso de suscripción

**Checkpoint**: US1 funciona sola. Sin suscripción, las tres zonas premium se comunican como premium y explican por qué — todavía sin poder comprar nada.

---

## Phase 4: User Story 2 — Elegir plan, probar gratis y desbloquear al instante (P1) 🎯 MVP

**Goal**: el usuario elige mensual o anual, arranca el mes de prueba sin cobro, y al volver a la app ve Deudas y Ahorro disponibles sin reiniciarla.

**Independent Test**: completar una suscripción de prueba en cada plan contra la pista interna de Google Play y verificar el desbloqueo inmediato, que no hay cobro durante la prueba, y que una compra cancelada no desbloquea nada (quickstart.md, pasos 2 y 3).

### Tests para US2 ⚠️

- [X] T020 [P] [US2] Ampliar `test/ui/pantalla_paywall_test.dart` **antes de implementar**: `comprar(plan)` que devuelve un estado vigente desbloquea Deudas y Ahorro **sin reconstruir la app desde cero** (FR-007, SC-002); `comprar` que devuelve el estado sin cambios (usuario canceló o Google rechazó) deja todo bloqueado y no muestra ningún error de fallo, porque cancelar es un flujo esperado, no un error (FR-008, Acceptance Scenarios 3 y 4) — las pruebas tocan el botón del plan dentro del cascarón ya montado, así que "sin reconstruir" se verifica de verdad: el mismo árbol que mostraba el aviso pasa a mostrar la pantalla. Se sumó al doble un `confirmacionPendiente` (un `Completer`) porque sin dejar una compra a medias no había forma de probar ni el doble toque (T023) ni lo que se ve mientras Google responde
- [X] T021 [P] [US2] Escribir `test/ui/ficha_estado_suscripcion_test.dart`: la ficha dice en texto si está en prueba gratis, activa o no activa, con qué plan y hasta cuándo (FR-009, Acceptance Scenario 5), sin comunicar el estado solo por color (Principio IV) — la prueba de Principio IV recorre las **seis** situaciones del enum, no una muestra: agregar una nueva sin darle texto propio rompe la suite. Las expectativas se escriben contra `situacion.etiqueta` y no contra literales, para que el nombre de cada estado tenga un solo dueño

### Implementación para US2

- [X] T022 [US2] Implementar `comprar(plan)` en `EstadoSuscripcion` (`lib/ui/estado/estado_suscripcion.dart`) hasta que T020 pase: notifica a los oyentes con el estado nuevo, de forma que la guarda de `cascaron.dart` deje pasar sin reinicio; una cancelación del usuario no produce banner de error — cancelar no toca `_error` en ningún momento: el repositorio devuelve el estado sin cambios y acá simplemente se guarda. El getter `comprando` es el que expone la compra en curso a la pantalla
- [X] T023 [US2] Conectar los botones de plan del paywall (`lib/ui/pantallas/suscripcion/pantalla_paywall.dart`) a `comprar(PlanSuscripcion.mensual)` y `comprar(PlanSuscripcion.anual)`, con estado de "compra en curso" que evita disparar dos compras con un doble toque (edge case "la confirmación de Google tarda") — la guarda está en `EstadoSuscripcionPremium.comprar`, no solo en el botón deshabilitado: si mañana se dispara una compra desde otro lado, la protección sigue puesta. Mientras Google confirma se muestra **texto** ("Confirmando la compra con Google Play…"), porque dos botones grisados sin explicación se leen como que la app se colgó
- [X] T024 [P] [US2] Construir `lib/ui/pantallas/suscripcion/ficha_estado_suscripcion.dart` hasta que T021 pase: indicador reusable con la situación vigente en texto, el plan y la fecha hasta la que cubre — el título sale de `situacion.etiqueta` y el detalle de un `switch` exhaustivo, así que sumar una situación al enum no compila hasta decidir qué se le explica al usuario. `vencida` y `cancelada` aclaran que los datos siguen guardados: es exactamente lo que se teme al ver una pantalla bloqueada (FR-011)
- [X] T025 [US2] Mostrar la ficha en `lib/ui/pantallas/ajustes/pantalla_ajustes.dart` y en el paywall (FR-009), de forma que el estado de la suscripción sea consultable desde un lugar fijo de la app — en Ajustes siempre, bajo su propia sección; en el paywall **solo si hubo suscripción antes**: a quien nunca se suscribió, un "Nunca suscripto" arriba del aviso no le agrega nada, y a quien se le venció le explica por qué volvió a ver esta pantalla
- [X] T026 [US2] Implementar el refresco de D4 en `EstadoSuscripcion.cargar()`/`refrescar()`: al abrir la app y al entrar a una pantalla premium o a la ficha de estado, con política de mejor esfuerzo — sin conexión usa el cacheado, sin bloquear ni mostrar error. Al abrir la app ya lo hacía `main.dart`; se sumó el disparo en la navegación (`_refrescarSiEsPremium` en `lib/ui/cascaron.dart`, para los destinos con `AccesoDestino.premium`) y al entrar a Ajustes, que es donde vive la ficha. **`PantallaActivacion` queda fuera**: no es un destino premium del cascarón sino una pantalla gratis con un flujo bloqueado adentro (T018), y lee el mismo estado que estos dos caminos ya mantienen fresco
- [ ] T027 [MANUAL] [US2] Crear el producto de suscripción en Google Play Console (ID `premium`, planes base `mensual` y `anual`, oferta de prueba de un mes en cada uno) y subir la app a la pista de **pruebas internas** con el mismo `applicationId` y firma — **sin esto ninguna compra funciona ni siquiera en depuración** (quickstart.md, Requisitos previos). Ojo: el `applicationId` actual es `com.example.finanzas` (`android/app/build.gradle.kts:19`), que Play Console **rechaza**: hay que cambiarlo a un dominio propio antes de subir nada
- [ ] T028 [MANUAL] [US2] Configurar una cuenta de prueba de licencias en Play Console y recorrer la compra de ambos planes según quickstart.md pasos 2 y 3, incluida la simulación del fin del período de prueba (el estado debe pasar de "en prueba" a "activa" al refrescar)

**Checkpoint**: US1 + US2 + US3 son el MVP. Se puede comprar, la prueba gratis arranca sin cobro y el acceso se desbloquea sin reiniciar.

---

## Phase 5: User Story 3 — Lo básico sigue gratis sin límite (P1) 🎯 MVP

**Goal**: quien nunca se suscribe sigue usando Presupuesto, Resumen, Gastos y Categorías sin límite ni avisos de pago.

**Independent Test**: usar la app intensivamente sin suscripción y verificar que ninguna de esas pantallas se bloquea ni muestra avisos (quickstart.md, paso 4).

### Tests para US3 ⚠️

- [X] T029 [P] [US3] Escribir `test/ui/gratis_sin_limite_test.dart`: con `situacion = nunca`, las pantallas de Presupuesto, Resumen, Transacciones y Categorías se muestran completas, sin paywall ni aviso de pago (FR-004, SC-005), y siguen funcionando con muchos meses y muchas obligaciones/gastos cargados (Acceptance Scenario 2) — se cubren los **seis** destinos gratis (los cuatro más Tarjetas y Ajustes), no solo los cuatro del enunciado, porque la guarda vive en el cascarón y alcanza a todos por igual. Las seis pruebas pasaron en la primera corrida: es lo que se esperaba de una verificación (ver T030), no una prueba que se escribió después del código. Que no pasen en vano lo asegura el contraste: la misma prueba exige que Deudas y Ahorro **sí** muestren el paywall con el mismo `find.byType`, y cada destino gratis tiene que mostrar además su pantalla real, así que una navegación que fallara en silencio rompería la prueba en vez de darla por buena

  El volumen se verifica por el total, no por la lista: 40 obligaciones de S/ 100.00 tienen que dar `S/ 4,000.00` de comprometido y 60 gastos de S/ 10.00, `S/ 600.00` de gasto real. Una cifra exacta prueba que no se recortó nada; contar filas visibles solo probaría cuántas entran en pantalla

### Implementación para US3

- [X] T030 [US3] Revisar que la guarda de T017 se aplique **solo** a los destinos premium: recorrer `_frecuentes` y `_ocasionales` en `lib/ui/cascaron.dart` y confirmar que Presupuesto, Resumen, Gastos, Categorías, Tarjetas y Ajustes no la consultan — es una tarea de verificación con prueba, no de código nuevo si T017 quedó bien acotada. **Quedó bien acotada: cero código nuevo.** En todo `cascaron.dart` hay exactamente dos `acceso: AccesoDestino.premium` (Deudas y Ahorro); el resto toma el `gratis` por omisión de `_Destino`. Y `_cuerpoDe` sale temprano con `if (destino.acceso == AccesoDestino.gratis) return destino.pantalla;` **antes** de leer el provider, así que una pantalla gratis ni siquiera consulta el estado de la suscripción para dibujarse

  Único matiz que vale anotar: Ajustes **sí** lee `EstadoSuscripcionPremium`, pero para mostrar la ficha de FR-009 y refrescarla (T025/T026), no para decidir si se dibuja. La prueba de T029 lo deja explícito en un caso propio: la ficha informa, no bloquea

**Checkpoint**: la monetización no degrada nada de lo que la app ya prometía gratis.

---

## Phase 6: User Story 4 — La suscripción vence o se cancela (P2)

**Goal**: al vencer, las pantallas premium vuelven a bloquearse sin que se pierda ni un dato, y el resumen del mes explica que el motivo es la suscripción, no un error.

**Independent Test**: cargar datos en Deudas y Ahorro, simular el vencimiento y verificar que reactivando la suscripción reaparecen idénticos (quickstart.md, paso 5).

### Tests para US4 ⚠️

- [X] T031 [P] [US4] Ampliar `test/ui/pantalla_paywall_test.dart` **antes de implementar**: pasar de un estado vigente a `vencida`/`cancelada` vuelve a mostrar el paywall en Deudas y Ahorro (FR-010), y **ninguna fila** de deudas, aportes de ahorro, asociaciones comercio-categoría ni consumos pendientes se borra o modifica en el proceso (FR-011, SC-003) — verificarlo leyendo los repositorios después del cambio de estado, no solo mirando la pantalla. Se hizo en archivo propio, `test/ui/vencimiento_suscripcion_test.dart`, siguiendo el precedente de T009: acá se siembran las cuatro zonas que nombra FR-011 y el escenario es el vencimiento, no el paywall. El cambio de estado se simula como pasa de verdad —se mueve lo que informa Google Play y la app se entera al refrescar, nadie toca la app— y hay una prueba de ida y vuelta (vigente → vencida → reactivada) que comprueba que vuelve la misma deuda, que es lo que pide el Acceptance Scenario 2. Las 8 pruebas pasaron de una: la guarda no desmonta ni consulta los repositorios premium, así que no había por dónde perder un dato; valen como red de regresión
- [X] T032 [P] [US4] Escribir la prueba de `enGracia` en `test/dominio/suscripcion_test.dart` y en el paywall: un cobro fallido con período de gracia de Google **mantiene** el acceso, no lo corta al primer fallo (FR-013) — el dominio ya lo cubría desde T005 y el paywall desde T013. Lo que faltaba y se sumó es la **transición**, que es donde estaba el riesgo real: `activa → enGracia` no bloquea nada, y recién `enGracia → vencida` muestra el aviso
- [X] T033 [P] [US4] **Revisado 2026-08-31 (D6 de research.md)**: ~~el resumen explica en texto que las cuotas no aparecen por la suscripción~~ → ampliar `test/ui/pantalla_resumen_test.dart` para fijar que con la suscripción no vigente el resumen muestra el **mismo** presupuesto que con suscripción: las cuotas de deuda siguen contadas en el comprometido y el desglose de tarjeta de crédito se sigue pudiendo desplegar (FR-012 reescrito, Acceptance Scenario 3). Es una prueba de regresión: nada en el resumen consulta hoy la suscripción, y esta prueba existe para que nadie meta esa dependencia más adelante creyendo que arregla algo — la red está tendida en el propio montaje, porque el árbol de `pantalla_resumen_test.dart` **no tiene** `EstadoSuscripcionPremium`: si el resumen empezara a consultarla, la prueba no fallaría por una cifra distinta sino por un provider inexistente

### Implementación para US4

- [X] T034 [US4] **Revisado 2026-08-31 (D6 de research.md)**: ~~mostrar un aviso en el desglose~~ → verificar que `lib/ui/pantallas/resumen_mes/` y `lib/ui/estado/estado_mes.dart` **no consultan** la suscripción por ningún camino, igual que T030 hizo con los destinos gratis del cascarón. Sin código nuevo si la verificación sale limpia: una cifra financiera que cambia según el estado de pago de la app deja de ser confiable, y omitir las cuotas dejaría el disponible del mes inflado. **Salió limpia: cero coincidencias de `Suscripcion` o `premium` en los dos archivos, cero código nuevo**
- [ ] T035 [US4] Detener el procesamiento de notificaciones nuevas cuando la suscripción no está vigente, en `lib/datos/notificaciones/callback_headless.dart`: el callback consulta el estado cacheado (`estadoCacheado()`, sin red, porque corre en un isolate headless) y descarta la notificación sin escribir nada; **los pendientes ya existentes no se tocan** (FR-011, Acceptance Scenario 4). Depende de que T042 de la spec 002 exista — si sigue bloqueada, dejar la comprobación escrita en el cuerpo vacío del callback con su prueba pendiente. **Sigue bloqueada** (T034/T041 de la spec 002 esperan insumo manual del teléfono), así que quedó escrito el requisito en la documentación de `alRecibirNotificacion` y un comentario en el cuerpo vacío marcando dónde va: `estadoCacheado()` y no `refrescar()`, porque el isolate headless corre sin UI y sin garantía de red. La prueba automatizada no se puede escribir todavía: el callback no recibe dependencias inyectables y hoy no escribe nada, así que cualquier aserción pasaría en vano. La mitad verificable de FR-011 —que los pendientes viejos sobrevivan— está en T036
- [X] T036 [P] [US4] Escribir `test/ui/captura/estado_pendientes_test.dart` (ampliar): con la suscripción vencida, la bandeja sigue mostrando los pendientes que ya existían y permite descartarlos, pero no llegan nuevos (FR-011) — se amplió `pantalla_pendientes_test.dart` y no `estado_pendientes_test.dart`: `EstadoPendientes` no recibe la suscripción por ningún lado, así que el escenario solo se puede montar donde hay árbol de widgets. La mitad de "no llegan nuevos" es del callback headless (T035) y queda con él

**Checkpoint**: cancelar se siente como perder acceso, nunca como perder datos.

---

## Phase 7: User Story 5 — Restaurar la suscripción (P2)

**Goal**: reinstalar la app o instalarla en otro dispositivo con la misma cuenta de Google recupera el acceso sin volver a pagar.

**Independent Test**: instalar la app con una cuenta de prueba ya suscripta y verificar que restaurar no pide pago (quickstart.md, paso 6).

### Tests para US5 ⚠️

- [ ] T037 [P] [US5] Escribir `test/ui/restaurar_suscripcion_test.dart` **antes de implementar**: `restaurar()` que encuentra una suscripción activa desbloquea el acceso sin pasar por el flujo de compra (FR-014); `restaurar()` que no encuentra ninguna informa con texto claro que esa cuenta no tiene suscripción, y **no** deja al usuario creyendo que falló la app (FR-015, Acceptance Scenario 2)

### Implementación para US5

- [ ] T038 [US5] Implementar `restaurar()` en `EstadoSuscripcion` (`lib/ui/estado/estado_suscripcion.dart`) hasta que T037 pase, delegando en `RepositorioSuscripcion.restaurar()`
- [ ] T039 [US5] Agregar la acción explícita "Restaurar suscripción" en el paywall y en la ficha de estado de Ajustes (FR-014), con el mensaje de "no encontramos ninguna suscripción para esta cuenta" cuando corresponda (FR-015)
- [ ] T040 [MANUAL] [US5] Recorrer quickstart.md paso 6: desinstalar y reinstalar (o instalar en otro dispositivo) con la cuenta de prueba ya suscripta y verificar que restaurar devuelve el acceso sin pedir pago

**Checkpoint**: las cinco historias funcionan de forma independiente. La spec 004 queda completa a falta de la validación manual.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T041 [P] Verificar que `test/pureza_test.dart` pasa con todo lo nuevo: `lib/dominio/modelos/estado_suscripcion.dart` y `lib/dominio/repositorios/repositorio_suscripcion.dart` no importan `in_app_purchase`, Flutter ni sqflite (T012 dejó la guarda lista)
- [ ] T042 [P] Revisar que ningún estado de esta feature (en prueba, activa, en gracia, vencida, bloqueo por suscripción en el resumen) se comunique solo por color, siguiendo el patrón de `MarcaEstado`/`AvisoMesCerrado` de 001
- [ ] T043 [P] Dejar `flutter analyze` sin issues y `dart format` aplicado a todo lo nuevo
- [ ] T044 [MANUAL] Recorrer entero [quickstart.md](./quickstart.md) contra la pista de pruebas internas, incluido el paso 7 (modo avión con suscripción activa ya verificada: Deudas debe seguir accesible con el estado cacheado)
- [ ] T045 Corregir plan.md y data-model.md §4, que dicen `Esquema.version` 1 → 2: la migración real de esta feature es **v3 → v4** (ver la nota al inicio de este documento)
- [ ] T046 [P] Actualizar `CLAUDE.md` con el estado de esta feature una vez completa

---

## Dependencies & Execution Order

### Dependencias de fase

- **Setup (F1)**: sin dependencias.
- **Foundational (F2)**: depende de F1. **Bloquea las cinco historias** — sin el modelo, el esquema y el puerto no hay estado que consultar.
- **US1 (F3)**: depende solo de F2. Es la primera entrega útil: comunica el premium aunque todavía no se pueda comprar.
- **US2 (F4)**: depende de F2 y del paywall de US1 (T016), que es donde viven los botones de plan.
- **US3 (F5)**: depende de F2 y de la guarda de US1 (T017) — es, en esencia, verificar que esa guarda no se pasó de alcance.
- **US4 (F6)**: depende de F2; sus pruebas usan el paywall de US1. La parte del callback headless (T035) depende además de T042 de la spec 002, hoy bloqueada.
- **US5 (F7)**: depende de F2 y de la ficha de estado de US2 (T024), donde va la acción de restaurar.
- **Polish (F8)**: al final de las historias que se decidan entregar.

### El bloqueo de Google Play Console

T027, T028, T040 y T044 están marcadas `[MANUAL]` porque exigen la app publicada en la pista de pruebas internas con un `applicationId` propio (hoy es `com.example.finanzas`, que Play Console rechaza) y una cuenta de prueba de licencias. **Todo lo demás se puede construir y probar sin tocar Google Play**, gracias al doble en memoria de T011: el paywall, la guarda de acceso, el bloqueo por vencimiento y la restauración se prueban contra la interfaz, no contra la Billing Library.

### Dentro de cada historia

Pruebas → modelos → repositorios → estado → pantallas → prueba de widget, igual que 001, 002 y 003.

### Oportunidades de paralelismo

- T002 en Setup.
- T004, T007, T011, T012 en Foundational.
- T013–T014 (pruebas de US1) pueden avanzar en paralelo con T027 (alta en Play Console) — no dependen entre sí.
- T031, T032, T033 (pruebas de US4) son archivos distintos.
- Con un solo desarrollador, [P] significa que el orden entre esas tareas es indiferente.

---

## Implementation Strategy

### MVP primero (US1 + US2 + US3)

1. Fase 1 — Setup (T001–T003)
2. Fase 2 — Foundational (T004–T012, crítica, bloquea todo)
3. Fase 3 — US1 (T013–T019): el premium ya se comunica, aunque no se pueda comprar
4. Fase 4 — US2 (T020–T028): **empezar por T020–T026, que no dependen de Play Console**; en paralelo, dar de alta el producto y la pista interna (T027)
5. Fase 5 — US3 (T029–T030): confirmar que lo gratis siguió gratis
6. **PARAR Y VALIDAR**: comprar en la pista interna, verificar desbloqueo sin reinicio.

### Entrega incremental

1. Setup + Foundational → base lista
2. + US1 → el paywall explica qué se vende
3. + US2 + US3 → **MVP**: se puede cobrar sin degradar lo gratuito
4. + US4 → vencer deja de parecerse a perder datos
5. + US5 → restaurar, exigencia de la política de Google Play
6. Fase 8 — Polish

Cada incremento deja la app usable y no rompe 001, 002 ni 003.

---

## Notes

- Total: **46 tareas** (4 de ellas `[MANUAL]`: T027, T028, T040 y T044). Setup: 3 · Foundational: 9 · US1: 7 · US2: 9 · US3: 2 · US4: 6 · US5: 4 · Polish: 6.
- La prueba de `estaVigente` (T005) se escribe antes que su implementación: decide si el usuario accede a algo por lo que paga, y eso entra en el Principio III aunque el getter sea corto.
- `precioFormateado` nunca se convierte a `Dinero` ni se opera: es un texto que informa Google Play, no un monto que la app calcule (Constitution Check de plan.md).
- Commitear por tarea o por grupo coherente, referenciando el id de la tarea.
- Cualquier desviación de un principio se justifica por escrito en plan.md, no en silencio durante la implementación.
