---

description: "Task list para 001-gestion-sueldo-ahorro"
---

# Tasks: Gestión de sueldo, gasto real, deudas y ahorro

**Input**: Documentos de diseño en `specs/001-gestion-sueldo-ahorro/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: **SÍ se incluyen y no son opcionales.** El Principio III de la constitución exige que las pruebas de cada regla financiera se escriban *antes* que su implementación, y el Flujo de Desarrollo las declara "requisito de entrada, no un paso posterior opcional". Dentro de cada fase, las tareas de prueba van primero y deben fallar antes de implementar.

**Organización**: agrupadas por historia de usuario para poder implementar y validar cada una por separado.

**Revisión 3** (spec revisión 4): se añaden el cierre de meses pasados con ventana de gracia (FR-052, FR-055 – FR-058), la gestión de tarjetas con entidad emisora y tipo (FR-059 – FR-061) y el manejo de errores de persistencia. La meta de ahorro es por mes; `config_ahorro` pasa a ser `configuracion` y aloja también los días de gracia.

## Format: `[ID] [P?] [Story] Descripción`

- **[P]**: puede hacerse en paralelo (archivos distintos, sin dependencias pendientes). Con un solo desarrollador, léase como "el orden entre estas tareas da igual".
- **[Story]**: a qué historia pertenece (US1…US6).
- Cada tarea indica la ruta exacta del archivo.

## Path Conventions

Proyecto Flutter único (ver *Structure Decision* en plan.md): código en `lib/`, pruebas en `test/`, ambos en la raíz del repositorio.

---

## Phase 1: Setup (infraestructura compartida)

**Propósito**: dejar el proyecto listo para trabajar, sin lógica de negocio todavía.

- [X] T001 Añadir dependencias con `flutter pub add sqflite path provider intl`, `flutter pub add --dev sqflite_common_ffi` y la entrada `flutter_localizations` del SDK, verificando el resultado en `pubspec.yaml`
- [X] T002 [P] Crear la estructura de directorios `lib/core/`, `lib/dominio/modelos/`, `lib/dominio/calculos/`, `lib/datos/repositorios/`, `lib/ui/estado/`, `lib/ui/pantallas/`, `lib/ui/widgets/`, `test/dominio/`, `test/datos/`, `test/ui/` según plan.md
- [X] T003 [P] Endurecer el análisis estático en `analysis_options.yaml`: `strict-casts`, `strict-raw-types`, y reglas de estilo del proyecto sobre `flutter_lints`
- [X] T004 [P] Definir el tema en `lib/ui/tema.dart` según D11: `ColorScheme.fromSeed()` de Material 3 en claro y oscuro, un `TextStyle` de montos con `fontFeatures: [FontFeature.tabularFigures()]`, y contraste AA. Sin librerías de componentes
- [X] T005 [P] Escribir la guarda de pureza en `test/pureza_test.dart`: recorre `lib/dominio/` y falla si algún archivo importa `package:flutter/` o `package:sqflite/` (Principio III, D8)
- [X] T006 Reemplazar el contador de demo en `lib/main.dart` por la raíz real: `MaterialApp` con `flutter_localizations`, `locale` fijo `es_PE`, el tema de T004 y los `Provider` raíz vacíos

**Checkpoint**: `flutter analyze` y `flutter test` corren limpios sobre un esqueleto vacío.

---

## Phase 2: Foundational (prerrequisitos bloqueantes)

**Propósito**: los tipos monetarios, la base de datos, la regla de cierre de meses y el cascarón de navegación, de los que dependen **todas** las historias.

**⚠️ CRÍTICO**: ninguna historia puede empezar hasta terminar esta fase.

- [X] T007 [P] Escribir `test/dominio/dinero_test.dart` **antes de implementar**: aritmética entera, `porPuntosBase` con redondeo half-up, comparaciones, negativos, y ausencia de constructor desde `double`
- [X] T008 [P] Escribir `test/dominio/mes_test.dart` **antes de implementar**: `ordinal`, `siguiente`/`anterior`/`mas`, `diferencia`, cruce de año, rechazo de mes fuera de 1–12
- [X] T009 [P] Escribir `test/dominio/formato_soles_test.dart` **antes de implementar**: `S/ 1,234.56`, cero, negativos, siete cifras `S/ 9,999,999.99`, siempre dos decimales
- [X] T010 Implementar `lib/core/dinero.dart` hasta que T007 pase (int de centavos, D2)
- [X] T011 Implementar `lib/core/mes.dart` hasta que T008 pase (ordinal `anio * 12 + mes - 1`, D5)
- [X] T012 Implementar `lib/core/formato_soles.dart` hasta que T009 pase, formateando desde el entero sin `double` ni `NumberFormat`
- [X] T013 [P] Implementar `lib/core/formato_fecha.dart` con `DateFormat` de `intl` en `es_PE`
- [X] T014 [P] Definir `Categoria`, `TipoObligacion`, `ReglaAhorro` y `TipoTarjeta` con sus slugs de persistencia y etiquetas en español en `lib/dominio/modelos/enums.dart`
- [X] T015 [P] Escribir `test/dominio/cierre_mes_test.dart` **antes de implementar**: el mes en curso admite todo; el mes anterior admite registrar mientras `hoy.day <= diasGraciaCierre` pero **nunca** editar ni eliminar; con `diasGraciaCierre == 0` el mes anterior queda cerrado de inmediato; cualquier mes previo al anterior es solo lectura; `hoy` siempre entra como parámetro, sin tocar el reloj del sistema
- [X] T016 Implementar `estadoDe`, `puedeRegistrarEn` y `puedeEditarEn` en `lib/dominio/calculos/cierre_mes.dart` hasta que T015 pase, más el derivado `EstadoCierre` con su `motivo` legible en `lib/dominio/modelos/estado_cierre.dart` (D13, FR-058)
- [X] T017 [P] Crear el modelo `Configuracion` (regla de ahorro, porcentaje en puntos base, días de gracia) en `lib/dominio/modelos/configuracion.dart`
- [X] T018 Escribir el DDL de la versión 1 en `lib/datos/esquema.dart` copiando el esquema de data-model.md §5 (ocho tablas: `ingreso`, `obligacion`, `transaccion`, `tarjeta`, `deuda`, `aporte_ahorro`, `meta_ahorro`, `configuracion`), con sus `CHECK` e índices
- [X] T019 Implementar el andamiaje de migraciones incrementales en `lib/datos/migraciones.dart` (pasos v(n) → v(n+1), nunca destructivos, D10)
- [X] T020 Implementar `lib/datos/base_datos.dart`: apertura por `getDatabasesPath()`, `onCreate`, `onUpgrade`, `PRAGMA foreign_keys = ON` en cada conexión
- [X] T021 Implementar el manejo de errores de persistencia en `lib/datos/error_persistencia.dart` según [contracts/repositorios.md](./contracts/repositorios.md) §Errores: envolver las excepciones de `sqflite` con contexto legible sin exponer el SQL, no-op silencioso ante id inexistente, y propagación explícita si la base no abre — la app debe decir "no pude abrir tus datos" en vez de arrancar vacía y hacer creer que se perdió todo
- [X] T022 [P] Implementar `lib/datos/repositorios/repositorio_configuracion.dart` con los valores por defecto (regla `porcentaje` al 20%, 5 días de gracia)
- [X] T023 [P] Crear el helper de pruebas `test/datos/helper_bd.dart` que inicializa `sqflite_common_ffi` y abre una base en memoria
- [X] T024 Escribir `test/datos/base_datos_test.dart`: se crea el esquema completo, `user_version` queda en 1, las FK están activas, un paso de migración simulado preserva los datos existentes, y una base ilegible produce un `ErrorPersistencia` en vez de una base vacía
- [X] T025 Construir el cascarón de navegación en `lib/ui/cascaron.dart`: `Scaffold` raíz con `NavigationBar` y los cinco destinos (resumen, presupuesto, gastos, deudas, ahorro), con espacios reservados para las pantallas que aún no existen, y engancharlo desde `lib/main.dart`
- [X] T026 [P] Crear `lib/ui/widgets/aviso_mes_cerrado.dart`: banner con ícono y texto que explica que el mes está cerrado o en ventana de gracia y qué se puede hacer, legible sin distinguir colores (FR-058)

**Checkpoint**: el dinero es exacto, la base abre y migra, la regla de cierre está probada y se puede navegar entre secciones vacías.

---

## Phase 3: User Story 1 — Registrar ingreso y presupuesto del mes (P1) 🎯 MVP

**Goal**: el usuario registra su sueldo del mes y arma su presupuesto de obligaciones, y todo persiste.

**Independent Test**: registrar un ingreso y varias obligaciones, cerrar la app y reabrirla para confirmar que persisten; editar y eliminar recalcula; los montos inválidos se rechazan con motivo; un mes cerrado no admite cambios.

### Tests para US1 ⚠️ (escribir primero, deben fallar)

- [X] T027 [P] [US1] Escribir `test/dominio/presupuesto_test.dart`: `validarMonto` rechaza vacío, no numérico, negativo y más de dos decimales; acepta siete cifras; `proponerFijasDelMesAnterior` propone solo las fijas y nunca las guarda
- [X] T028 [P] [US1] Escribir `test/datos/repositorio_ingreso_test.dart`: `obtener` devuelve `null` para mes sin registrar (distinto de cero), `guardar` inserta y reemplaza
- [X] T029 [P] [US1] Escribir `test/datos/repositorio_obligaciones_test.dart`: `porMes`, `fijasDeMes`, atomicidad de `insertarLote`, actualizar y eliminar

### Implementación para US1

- [X] T030 [P] [US1] Crear el modelo `Ingreso` en `lib/dominio/modelos/ingreso.dart`
- [X] T031 [P] [US1] Crear el modelo `Obligacion` en `lib/dominio/modelos/obligacion.dart`
- [X] T032 [US1] Implementar `validarMonto` y `proponerFijasDelMesAnterior` en `lib/dominio/calculos/presupuesto.dart` según [contracts/calculos-dominio.md](./contracts/calculos-dominio.md)
- [X] T033 [P] [US1] Implementar `lib/datos/repositorios/repositorio_ingreso.dart`
- [X] T034 [P] [US1] Implementar `lib/datos/repositorios/repositorio_obligaciones.dart`, con `insertarLote` dentro de una transacción
- [X] T035 [US1] Crear el `ChangeNotifier` del mes en curso en `lib/ui/estado/estado_mes.dart`: carga ingreso y obligaciones, expone alta, edición y baja, y **consulta `cierre_mes.dart` antes de toda escritura** — la regla de cierre se aplica acá, no en los repositorios
- [X] T036 [P] [US1] Crear el campo de monto reutilizable en `lib/ui/widgets/campo_monto.dart`: teclado numérico, `validarMonto`, mensaje de error en español, y el estilo de cifras tabulares de T004
- [X] T037 [US1] Construir `lib/ui/pantallas/presupuesto/pantalla_presupuesto.dart`: ingreso del mes y lista de obligaciones con su tipo fija/variable visible (FR-004). En un mes cerrado muestra `aviso_mes_cerrado` y deshabilita las acciones de escritura (FR-052)
- [X] T038 [US1] Construir el alta y edición de obligaciones en `lib/ui/pantallas/presupuesto/formulario_obligacion.dart` (nombre, categoría, monto, tipo). **El selector de categorías excluye `tarjetaCredito`**: ese compromiso lo derivan las deudas y registrarlo a mano duplicaría el monto en el presupuesto (data-model.md §2)
- [X] T039 [US1] Añadir el diálogo de precarga de fijas del mes anterior en `lib/ui/pantallas/presupuesto/pantalla_presupuesto.dart`, que solo confirma o ajusta, nunca guarda solo (FR-006)
- [X] T040 [US1] Escribir `test/ui/pantalla_presupuesto_test.dart` y `test/ui/estado_mes_test.dart`: monto vacío y en cero se rechazan sin guardar nada; `tarjetaCredito` no aparece entre las categorías elegibles; en un mes cerrado no hay acciones de edición y se explica el motivo; un fallo de persistencia se muestra en vez de tragarse. Desbloqueada al dar a los repositorios una interfaz en `lib/dominio/repositorios/` con dobles en memoria (D15)

**Checkpoint**: US1 funciona sola. El usuario ya tiene su presupuesto mensual en un solo lugar.

---

## Phase 4: User Story 2 — Ver el resumen del mes y saber si estoy en déficit (P1) 🎯 MVP

**Goal**: el usuario ve cuánto entró, cuánto está comprometido y cuánto le queda, y el déficit se comunica sin ambigüedad.

**Independent Test**: cargar ingreso y obligaciones conocidas y verificar que los totales coinciden al centavo con la cuenta a mano, incluidos déficit, saldo exactamente cero y mes sin ingreso.

### Tests para US2 ⚠️ (escribir primero, deben fallar)

- [X] T041 [P] [US2] Escribir `test/dominio/resumen_mes_test.dart`: caso normal (S/ 3,000 − S/ 1,800 = S/ 1,200), déficit con faltante exacto de S/ 350.00, saldo exactamente cero **sin** déficit, y mes sin ingreso registrado

### Implementación para US2

- [X] T042 [P] [US2] Crear el derivado `ResumenMes` en `lib/dominio/modelos/resumen_mes.dart` con `ingresoRegistrado`, `enDeficit` y `faltante`
- [X] T043 [US2] Implementar `calcularResumenMes` en `lib/dominio/calculos/resumen_mes.dart`. Los parámetros `deudas` y `transacciones` aceptan lista vacía: las deudas llegan en US4 y las transacciones en US3, así que hasta entonces `disponibleReal` será igual al ingreso
- [X] T044 [P] [US2] Implementar `lib/datos/repositorios/repositorio_meses_sqlite.dart` y su puerto en `lib/dominio/repositorios/`: meses con datos y detección de mes nuevo (FR-051)
- [X] T045 [US2] Extender `lib/ui/estado/estado_mes.dart` para exponer el `ResumenMes` recalculado tras cada cambio
- [X] T046 [P] [US2] Crear `lib/shared/componentes/aviso_deficit.dart`: ícono más texto explícito con el faltante, legible sin distinguir colores (FR-029)
- [X] T047 [P] [US2] Crear `lib/shared/componentes/selector_mes.dart` para navegar entre meses registrados, señalando cuáles están cerrados
- [X] T048 [US2] Construir `lib/ui/pantallas/resumen_mes/pantalla_resumen.dart` como destino principal del cascarón: ingreso, comprometido, disponible proyectado y estado de déficit, con el disponible en la jerarquía tipográfica mayor (D11)
- [X] T049 [US2] Escribir `test/ui/pantalla_resumen_test.dart`: el déficit se lee sin color, y el mes sin ingreso pide registrarlo en vez de mostrar ceros

**Checkpoint**: **MVP completo.** US1 + US2 responden la pregunta central de la app.

---

## Phase 4b: Navegación completa (D16)

**Propósito**: cerrar la navegación antes de que lleguen más pantallas, para
enchufar cada historia una sola vez y en su lugar definitivo.

Sale de validar el MVP en el emulador: con seis destinos la etiqueta
"Presupuesto" se partía en dos líneas, y al repartir las nueve pantallas que
comprometen las specs apareció que los ajustes transversales (días de gracia
del cierre) no pertenecen a ninguna pantalla temática.

- [X] T050 Añadir el `NavigationDrawer` en `lib/ui/cascaron.dart` con hamburguesa en el `AppBar`: los cinco destinos frecuentes quedan en la `NavigationBar` y el drawer lista los ocasionales (desglose por categoría, tarjetas, ajustes), con espacio para lo que agreguen las features siguientes. El encabezado del drawer muestra el mes en curso
- [X] T051 Construir `lib/ui/pantallas/ajustes/pantalla_ajustes.dart` con los **días de gracia del cierre** (FR-055), leídos y guardados por `RepositorioConfiguracion`. Es un ajuste transversal: no va dentro de la configuración de ahorro
- [X] T052 Escribir `test/ui/cascaron_test.dart`: la barra inferior muestra cinco destinos con sus etiquetas en una línea, el drawer abre y lista los destinos secundarios, y navegar por el drawer lleva a la pantalla correcta

**Checkpoint**: la navegación no vuelve a tocarse. Cada historia siguiente
enchufa su pantalla donde corresponde.

---

## Phase 5: User Story 3 — Registrar gastos reales y contrastarlos (P1)

**Goal**: el usuario anota lo que gasta día a día y ve, por categoría, lo presupuestado contra lo gastado.

**Independent Test**: registrar gastos en categorías con presupuesto conocido y verificar acumulados por categoría, total real y avisos de sobregiro; comprobar la ventana de gracia para pagos rezagados.

### Tests para US3 ⚠️ (escribir primero, deben fallar)

- [X] T053 [P] [US3] Escribir `test/dominio/desglose_test.dart`: comida S/ 45 de S/ 600 deja S/ 555; pasajes sobregirados en S/ 15; categoría sin presupuesto marcada como no presupuestada; Σ gastado por categoría == gasto real total
- [X] T054 [P] [US3] Escribir `test/datos/repositorio_transacciones_test.dart`: orden por fecha descendente estable, `mes_ordinal` derivado de la fecha, y que cambiar la fecha reubica la transacción de mes

### Implementación para US3

- [X] T055 [P] [US3] Crear el modelo `Transaccion` en `lib/dominio/modelos/transaccion.dart`
- [X] T056 [P] [US3] Crear el derivado `LineaCategoria` en `lib/dominio/modelos/linea_categoria.dart` con `sobregirada` y `noPresupuestada` como campos, no como color
- [X] T057 [US3] Implementar `calcularDesglose` en `lib/dominio/calculos/desglose_categorias.dart` (peso porcentual y orden llegan en US6)
- [X] T058 [US3] Implementar `lib/datos/repositorios/repositorio_transacciones.dart`, derivando `mes_ordinal` de la fecha en toda ruta de escritura
- [X] T059 [US3] Extender `lib/ui/estado/estado_mes.dart` con las transacciones del mes, el gasto real acumulado y la verificación de cierre antes de cada escritura
- [X] T060 [P] [US3] Construir el alta y edición de gastos en `lib/ui/pantallas/transacciones/formulario_transaccion.dart` (monto, fecha, categoría, descripción), optimizado para menos de 15 segundos (SC-002)
- [X] T061 [US3] Implementar el flujo de **pago rezagado** en `lib/ui/pantallas/transacciones/pantalla_transacciones.dart`: dentro de la ventana de gracia se admite registrar un gasto con fecha del mes anterior, avisando de forma explícita que quedará inmutable al guardarse (FR-055, FR-056); pasada la ventana, la fecha del mes anterior se rechaza con el motivo
- [X] T062 [US3] Construir `lib/ui/pantallas/transacciones/pantalla_transacciones.dart`: listado del mes por fecha descendente, con editar y eliminar solo cuando el mes lo permite
- [X] T063 [P] [US3] Crear `lib/shared/componentes/ficha_categoria.dart` (presupuestado, gastado, restante, marca de sobregiro) y mostrarlo en la pantalla de resumen junto al disponible real
- [X] T064 [US3] Escribir `test/ui/pantalla_transacciones_test.dart`: orden del listado, marca visible de gasto no presupuestado, un gasto que excede el presupuesto **se guarda igual** (FR-014), y un gasto registrado en gracia no ofrece editar ni eliminar

**Checkpoint**: núcleo funcional completo. La app sirve para el uso diario.

---

## Phase 6: User Story 4 — Administrar deudas de tarjeta en cuotas (P2)

**Goal**: registrar una deuda una sola vez y que sus cuotas aparezcan solas en cada mes que corresponde, con visibilidad del total adeudado.

**Independent Test**: registrar deudas con distintos meses de inicio y plazos, y verificar que la cuota correcta aparece en cada mes, que el saldo decrece cuota a cuota y que la deuda desaparece del presupuesto al vencer la última.

### Tests para US4 ⚠️ (escribir primero, deben fallar)

- [X] T065 [P] [US4] Escribir `test/dominio/deudas_test.dart` cubriendo los ocho escenarios de la HU4: saldo S/ 1,800 al registrar 12×S/ 150 en el mes de inicio (la cuota del mes en curso cuenta como pendiente, D4), 3 pagadas → 9 restantes y S/ 1,350, dos deudas de la misma tarjeta sumando S/ 230, deuda vencida que deja de aportar, deuda de inicio futuro fuera del presupuesto pero dentro del total adeudado, edición retroactiva **que sí afecta meses cerrados** (FR-057), saldado anticipado y deuda de una sola cuota
- [X] T066 [P] [US4] Escribir `test/datos/repositorio_tarjetas_test.dart`: alta con entidad y tipo, `deCredito` filtra correctamente, y borrar una tarjeta con deudas se rechaza
- [X] T067 [P] [US4] Escribir `test/datos/repositorio_deudas_test.dart`: alta, `activas`, `porTarjeta`, `marcarSaldada` y edición

### Implementación para US4

- [X] T068 [P] [US4] Crear el modelo `Tarjeta` (nombre, entidad, tipo) en `lib/dominio/modelos/tarjeta.dart`
- [X] T069 [P] [US4] Crear la constante `EntidadesPeru` en `lib/dominio/modelos/entidades.dart` con los emisores peruanos habituales (BCP, Interbank, BBVA, Scotiabank, Falabella, Ripley, Pichincha, BanBif, Mibanco, Banco de la Nación, Caja Arequipa, Caja Huancayo, Oh!, Yape, Plin). **Lista local, sin API ni acceso a red** (D14, FR-060)
- [X] T070 [P] [US4] Crear el modelo `Deuda` en `lib/dominio/modelos/deuda.dart` con `mesSaldadaAnticipada` opcional
- [X] T071 [P] [US4] Crear los derivados `EstadoDeuda` y `PanoramaDeuda` en `lib/dominio/modelos/estado_deuda.dart`
- [X] T072 [US4] Implementar `calcularEstadoDeuda`, `cuotaVigenteEnMes`, `compromisoDeudasEnMes` y `calcularPanorama` en `lib/dominio/calculos/deudas.dart`, sin materializar cuotas (D3) y **sin consultar la regla de cierre** (FR-057)
- [X] T073 [US4] Integrar las cuotas vigentes en `lib/dominio/calculos/resumen_mes.dart` y `lib/dominio/calculos/desglose_categorias.dart`, y ampliar `test/dominio/resumen_mes_test.dart` y `test/dominio/desglose_test.dart` con casos que incluyan deudas
- [X] T074 [P] [US4] Implementar `lib/datos/repositorios/repositorio_tarjetas.dart` con `deCredito`, rechazando borrar tarjetas con deudas asociadas
- [X] T075 [US4] Implementar `lib/datos/repositorios/repositorio_deudas.dart`
- [X] T076 [US4] Crear `lib/ui/estado/estado_deudas.dart` y conectarlo al recálculo del mes en curso
- [X] T077 [P] [US4] Construir la gestión de tarjetas en `lib/ui/pantallas/deudas/pantalla_tarjetas.dart`: alta, edición y baja con nombre, entidad elegida de `EntidadesPeru` o escrita a mano, y tipo débito/crédito (FR-059, FR-060)
- [X] T078 [P] [US4] Construir el alta y edición en `lib/ui/pantallas/deudas/formulario_deuda.dart` (descripción, tarjeta, cuota, número de cuotas, mes de inicio), con el selector de tarjeta limitado a las **de crédito** (FR-061) y registrando la cuota tal como la informa el banco, sin calcular intereses (FR-024)
- [X] T079 [US4] Construir `lib/ui/pantallas/deudas/pantalla_deudas.dart`: total adeudado, compromiso mensual agregado, mes libre de deudas y estado explícito cuando no hay deudas
- [X] T080 [US4] Hacer desplegable el compromiso de tarjeta de crédito en `lib/ui/pantallas/resumen_mes/pantalla_resumen.dart`, mostrando las deudas que lo componen (FR-017)
- [X] T081 [US4] Añadir la acción de saldar anticipadamente en `lib/ui/pantallas/deudas/pantalla_deudas.dart`, con confirmación
- [X] T082 [US4] Escribir `test/ui/pantalla_deudas_test.dart`: sin deudas activas comunica el estado libre de deuda; una tarjeta de débito no aparece al crear una deuda

**Checkpoint**: el usuario ve el año, no solo el mes.

---

## Phase 7: User Story 5 — Decidir cuánto ahorrar y registrar lo que ahorro (P2)

**Goal**: la app sugiere cuánto apartar según la regla elegida, evalúa la meta **del mes** y lleva la cuenta de lo efectivamente ahorrado.

**Independent Test**: configurar cada regla y comparar el monto sugerido con el cálculo esperado; fijar metas por encima y por debajo del disponible; registrar aportes y verificar acumulado y progreso; comprobar que un mes pasado se evalúa contra su propia meta.

### Tests para US5 ⚠️ (escribir primero, deben fallar)

- [X] T083 [P] [US5] Escribir `test/dominio/ahorro_test.dart` cubriendo los trece escenarios de la HU5: 20% de S/ 3,000 = S/ 600; el 20% que excede el disponible de S/ 300 y ofrece lo alcanzable; regla remanente; meta alcanzable con margen S/ 700; meta no alcanzable con recorte S/ 300; supresión en déficit; aportes que suman S/ 550 con excedente S/ 50; acumulado histórico; meses sin aportes en S/ 0.00; **un mes pasado con meta S/ 400 evaluado contra S/ 400 y no contra la meta actual de S/ 700 (FR-054)**; y **`proponerMetaDelMes` que devuelve la meta del último mes que la tuvo sin guardarla (FR-053)**
- [X] T084 [P] [US5] Escribir `test/datos/repositorio_ahorro_test.dart`: `metaDeMes` distingue `null` de cero, `metasHasta` en orden cronológico, `SUM()` entero del acumulado, aportes por mes, edición y borrado

### Implementación para US5

- [X] T085 [P] [US5] Crear el modelo `MetaAhorro` (mes + monto) en `lib/dominio/modelos/meta_ahorro.dart`
- [X] T086 [P] [US5] Crear el modelo `AporteAhorro` en `lib/dominio/modelos/aporte_ahorro.dart`
- [X] T087 [P] [US5] Crear los derivados `SugerenciaAhorro` y `ProgresoAhorro` en `lib/dominio/modelos/progreso_ahorro.dart`, con la meta del mes evaluado y el historial que lleva la meta de cada mes
- [X] T088 [US5] Implementar `calcularSugerencia`, `calcularProgreso` y `proponerMetaDelMes` en `lib/dominio/calculos/ahorro.dart`, con aritmética entera half-up
- [X] T089 [US5] Implementar `lib/datos/repositorios/repositorio_ahorro.dart`: metas por mes (`metaDeMes`, `guardarMeta`, `eliminarMeta`, `metasHasta`), aportes, acumulado e historial
- [X] T090 [US5] Crear `lib/ui/estado/estado_ahorro.dart`, aplicando la regla de cierre a los aportes igual que a las transacciones
- [X] T091 [P] [US5] Construir `lib/ui/pantallas/ahorro/configuracion_ahorro.dart`: regla y porcentaje (globales) y meta **del mes en curso** precargada con `proponerMetaDelMes` y sin fijarse hasta que el usuario confirme (FR-053)
- [X] T092 [US5] Construir `lib/ui/pantallas/ahorro/pantalla_ahorro.dart`: sugerencia, progreso contra la meta del mes, alta de aportes, historial mes a mes con la meta de cada uno, y acumulado histórico en una sola pantalla (SC-010)
- [X] T093 [US5] Añadir la tarjeta de ahorro sugerido a `lib/ui/pantallas/resumen_mes/pantalla_resumen.dart`, suprimida en déficit con el motivo explícito (FR-037)
- [X] T094 [US5] Escribir `test/ui/pantalla_ahorro_test.dart`: aporte mayor que el disponible se acepta e informa; un mes sin meta figura sin veredicto; la meta propuesta no queda guardada hasta confirmarla; un mes cerrado no admite nuevos aportes

**Checkpoint**: el objetivo declarado de la app queda cubierto.

---

## Phase 8: User Story 6 — Ver en qué se va el dinero por categoría (P3)

**Goal**: el usuario identifica su categoría de mayor gasto y dónde se pasó del presupuesto, en una sola pantalla.

**Independent Test**: con gastos repartidos en varias categorías, verificar que los subtotales suman el total, que los porcentajes son correctos y que el orden es de mayor a menor gasto.

### Tests para US6 ⚠️ (escribir primero, deben fallar)

- [ ] T095 [P] [US6] Ampliar `test/dominio/desglose_test.dart` con el orden descendente por gasto, la omisión de categorías sin presupuesto ni gasto, `pesoIngresoBp` sin dividir entre cero cuando no hay ingreso, y la suma exacta de subtotales

### Implementación para US6

- [ ] T096 [US6] Completar `pesoIngresoBp` y el orden descendente en `lib/dominio/calculos/desglose_categorias.dart`
- [ ] T097 [US6] Construir `lib/ui/pantallas/categorias/pantalla_desglose.dart`: una fila por categoría con presupuestado, gastado, diferencia y peso sobre el ingreso
- [ ] T098 [US6] Señalar las categorías sobregiradas con ícono y texto además del color en `lib/ui/pantallas/categorias/pantalla_desglose.dart` (FR-029)
- [ ] T099 [US6] Escribir `test/ui/pantalla_desglose_test.dart`: orden de las filas y ausencia de categorías vacías

**Checkpoint**: las seis historias funcionan de forma independiente.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [ ] T100 [P] Verificar que `test/pureza_test.dart` sigue pasando con `lib/dominio/` ya completo (Principio III)
- [ ] T101 [P] Añadir a `test/dominio/formato_soles_test.dart` y `test/ui/` los casos de siete cifras `S/ 9,999,999.99`, comprobando que no desbordan la interfaz
- [ ] T102 [P] Medir el resumen del mes con un dataset sintético de tres años en `test/datos/rendimiento_test.dart` y confirmar que los índices por `mes_ordinal` se usan
- [ ] T103 [P] Dejar `flutter analyze` sin issues y `dart format` aplicado a todo el proyecto
- [ ] T104 [P] Revisar en todas las pantallas de `lib/ui/pantallas/` que ningún estado (déficit, sobregiro, no presupuestado, meta incumplida, mes cerrado) se comunique solo por color, y que todo monto use las cifras tabulares de `lib/ui/tema.dart`
- [ ] T105 Ejecutar `flutter pub deps` y confirmar que ninguna dependencia transitiva abre red ni recoge telemetría (Principio I)
- [ ] T106 [P] Con las pantallas ya construidas, evaluar si `flex_color_scheme` mejora el tema de `lib/ui/tema.dart` lo suficiente para justificar la dependencia (D11); si no, dejarlo fuera y anotar la decisión
- [ ] T107 Recorrer entero [quickstart.md](./quickstart.md) en un dispositivo Android real, incluidas las comprobaciones de modo avión y reinicio del dispositivo
- [ ] T108 [P] Actualizar `README.md` con la puesta en marcha, el `PATH` del SDK y cómo correr la suite

---

## Dependencies & Execution Order

### Dependencias de fase

- **Setup (F1)**: sin dependencias.
- **Foundational (F2)**: depende de F1. **Bloquea todas las historias** — sin `Dinero`, `Mes`, la base de datos, la regla de cierre y el cascarón no hay dónde montar nada.
- **US1 (F3)** y **US2 (F4)**: dependen solo de F2.
- **US3 (F5)**: depende de F2. Reutiliza la pantalla de resumen de US2 para las fichas de categoría (T063); sin US2, US3 sigue siendo testeable por su propia pantalla.
- **US4 (F6)**: depende de F2. T073 modifica cálculos de US2 y US3; conviene hacerla después de ambas. Las tarjetas (T068, T069, T074, T077) son autónomas y pueden adelantarse.
- **US5 (F7)**: depende de F2 y del `disponibleProyectado` que produce US2.
- **US6 (F8)**: depende de `calcularDesglose`, creado en US3 (T057).
- **Polish (F9)**: al final de las historias que se decidan entregar. T106 exige tener pantallas reales que juzgar.

### Dentro de cada historia

Pruebas → modelos → cálculos puros → repositorios → estado → pantallas → prueba de widget. Las pruebas de reglas financieras **deben fallar antes** de escribir su implementación.

### La regla de cierre se aplica en un solo sitio

`cierre_mes.dart` decide; `lib/ui/estado/` consulta antes de escribir; los repositorios **no** validan cierre (contracts/repositorios.md). Duplicar la comprobación en la capa de datos crearía dos verdades que se desincronizan. Las deudas quedan fuera por FR-057.

### Oportunidades de paralelismo

- T002–T005 en Setup.
- T007–T009 (las tres suites de tipos base), luego T013–T014 y T017 en Foundational.
- Dentro de cada historia, los modelos marcados [P] y las suites de prueba iniciales. En US4, los cuatro modelos T068–T071 van juntos.
- Con un solo desarrollador, [P] significa que el orden entre esas tareas es indiferente y pueden agruparse en un mismo commit.

---

## Parallel Example: User Story 1

```text
# Primero, las tres suites de prueba juntas (deben fallar):
T027  test/dominio/presupuesto_test.dart
T028  test/datos/repositorio_ingreso_test.dart
T029  test/datos/repositorio_obligaciones_test.dart

# Después, los dos modelos juntos:
T030  lib/dominio/modelos/ingreso.dart
T031  lib/dominio/modelos/obligacion.dart

# Y los dos repositorios juntos:
T033  lib/datos/repositorios/repositorio_ingreso.dart
T034  lib/datos/repositorios/repositorio_obligaciones.dart
```

---

## Implementation Strategy

### MVP primero (US1 + US2)

La spec lo dice explícitamente: la HU2 "junto con la historia 1 constituye el MVP".

1. Fase 1 — Setup (T001–T006)
2. Fase 2 — Foundational (T007–T026, crítica, bloquea todo)
3. Fase 3 — US1 (T027–T040)
4. Fase 4 — US2 (T041–T049)
5. **PARAR Y VALIDAR**: el usuario registra su sueldo, arma su presupuesto y sabe si está en déficit.

### Entrega incremental

1. Setup + Foundational → base lista
2. + US1 + US2 → **MVP**, validar
3. + US3 → núcleo funcional: la app sirve para el uso diario, validar
4. + US4 → visibilidad de la deuda a un año, validar
5. + US5 → el objetivo declarado de la app, validar
6. + US6 → desglose para decidir recortes, validar
7. Fase 9 — Polish

Cada incremento deja la app usable y no rompe lo anterior.

---

## Notes

- Total: **108 tareas**. Setup: 6 · Foundational: 20 · US1: 14 · US2: 9 · Navegación: 3 · US3: 12 · US4: 18 · US5: 12 · US6: 5 · Polish: 9.
- Las pruebas de reglas financieras no son opcionales aquí: son requisito de entrada por constitución.
- Commitear por tarea o por grupo coherente, referenciando el id de la tarea.
- Cualquier desviación de un principio se justifica por escrito en plan.md, no en silencio durante la implementación.
