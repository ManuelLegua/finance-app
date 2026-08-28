# Phase 0 — Research: Gestión de sueldo, gasto real, deudas y ahorro

**Feature**: 001-gestion-sueldo-ahorro | **Fecha**: 2026-08-26

**Entorno verificado**: Flutter 3.47.1 (canal `stable`, en `C:\Users\manue\dev\flutter`), Dart 3.13.1. El SDK no está en el `PATH` de la terminal; los comandos se invocan por ruta completa o se agrega `C:\Users\manue\dev\flutter\bin` al `PATH` (ver `quickstart.md`).

Cada decisión responde a un desconocido del Technical Context o a una restricción de la constitución.

---

## D1 — Persistencia local: `sqflite`

**Decisión**: `sqflite` (SQLite embebido) con la ruta de base de datos resuelta por `path` + `getDatabasesPath()`. Versionado del esquema con `PRAGMA user_version` y migraciones incrementales en `onUpgrade`.

**Rationale**: la constitución exige base de datos local versionada con migraciones que preserven datos. El modelo es relacional de verdad (mes → obligaciones/transacciones/aportes; tarjeta → deudas) y las consultas son agregaciones por mes y categoría, que SQL resuelve sin cargar todo en memoria. `sqflite` no abre red, no tiene telemetría y funciona igual en Android e iOS sin código específico de plataforma.

**Alternativas consideradas**:
- **drift**: da SQL tipado y migraciones asistidas, pero introduce generación de código (`build_runner`) y una capa de abstracción grande para seis tablas. Rechazada por coste/beneficio (Principio V).
- **Hive / Isar**: rápidas, pero orientadas a documentos; las agregaciones por categoría y las migraciones de esquema quedan a cargo del código de la app. Rechazadas: el modelo es relacional.
- **JSON en disco**: obliga a cargar y reescribir todo el histórico en cada operación y no ofrece migraciones. Rechazada.

---

## D2 — Dinero: entero de centavos con formateador propio

**Decisión**: tipo de valor `Dinero` que envuelve un `int` de centavos. Toda la aritmética es entera. El formato `S/ 1,234.56` lo produce un formateador escrito a mano a partir del entero (división entera y agrupación de miles por texto), **sin** pasar por `double` ni por `NumberFormat`.

**Rationale**: Principio II (no negociable). `intl.NumberFormat` recibe `num`; usarlo obligaría a convertir centavos a `double` justo antes de imprimir, reintroduciendo el punto flotante en el único lugar donde el usuario mira la cifra. Formatear desde el entero es ~20 líneas y garantiza exactitud al centavo (SC-007) y ausencia de descuadres en subtotales (FR-046, FR-049).

**Reglas de redondeo fijadas**:
- Porcentaje del ingreso: se calcula sobre enteros como `(centavos * puntosBase)` dividido entre `10000` con redondeo al centavo más cercano (half-up). El porcentaje se guarda en **puntos base** (20% = 2000) para no almacenar decimales.
- Pesos porcentuales del desglose (FR-045): se calculan sobre enteros y se redondean solo al presentarlos; nunca se usan para derivar montos.

**Alternativas consideradas**: el paquete `decimal` (decimales de precisión arbitraria) — más potente de lo necesario y añade una dependencia para algo que el entero resuelve. Rechazada.

---

## D3 — Cuotas de deuda: derivadas, nunca materializadas

**Decisión**: no se almacena una fila por cuota. El presupuesto de un mes se calcula como *obligaciones guardadas de ese mes* + *cuotas vigentes derivadas de las deudas activas*. Una deuda aporta cuota al mes `m` si `mesInicio <= m <= mesInicio + numCuotas - 1` y la deuda no fue saldada anticipadamente en un mes anterior o igual a `m`.

**Rationale**: FR-016 y FR-023 piden que las cuotas aparezcan solas en cada mes y que editar una deuda recalcule los meses afectados. Con cuotas materializadas, cada edición obligaría a reescribir filas de meses pasados y futuros, con riesgo de dejar estados inconsistentes. Derivándolas, la edición de la deuda es la única escritura y todos los meses quedan correctos por construcción. También hace trivial FR-019 (dejar de aportar tras la última cuota) y FR-020 (deuda futura fuera del presupuesto actual pero dentro del total adeudado).

**Consecuencia asumida**: el presupuesto de un mes pasado cambia si se corrige la deuda. Es exactamente lo que pide FR-023, y no toca las transacciones reales ya registradas (edge case "edición retroactiva").

**Alternativas consideradas**: materializar cuotas como obligaciones al abrir cada mes. Rechazada por el coste de recálculo retroactivo y por duplicar la fuente de verdad.

---

## D4 — Semántica de "cuota pagada"

**Decisión**: `cuotasPagadas(mesRef)` = `mesRef - mesInicio`, acotado al rango `0..numCuotas`. La cuota del mes en curso cuenta como **pendiente** hasta que el mes termina.

**Rationale**: lo fija la propia spec. El escenario 1 de la HU4 dice que una deuda de 12 cuotas de S/ 150.00 que arranca en el mes en curso tiene saldo pendiente S/ 1,800.00 — es decir, 0 cuotas pagadas en su mes de inicio. El escenario 2 (3 pagadas → 9 restantes, S/ 1,350.00) es coherente con la misma fórmula. Sin esta regla escrita, el saldo pendiente admite dos lecturas que difieren en una cuota.

**Alternativas consideradas**: contar la cuota del mes en curso como pagada. Rechazada: contradice el escenario 1.

---

## D5 — Identidad del mes: ordinal entero

**Decisión**: valor `Mes(anio, mes)` con `ordinal = anio * 12 + (mes - 1)`. Se persiste el ordinal como `INTEGER`.

**Rationale**: el dominio hace aritmética de meses constantemente (mes de la última cuota, vigencia de cuotas, precarga del mes anterior, historial). Con un ordinal, todo eso es suma y resta de enteros y el orden cronológico es el orden numérico, sin lógica de acarreo de año ni comparaciones de texto. La conversión a y desde `(anio, mes)` vive en el propio tipo.

**Alternativas consideradas**: texto `YYYY-MM` (ordena bien pero no suma) y `DateTime` (arrastra día, hora y zona horaria, irrelevantes y fuente de errores de borde). Ambas rechazadas.

---

## D6 — Estado de UI: `provider` sobre `ChangeNotifier`

**Decisión**: `provider` con notificadores por área (mes en curso, deudas, ahorro). La UI no calcula: pide al dominio y muestra.

**Rationale**: se necesita inyectar repositorios y reconstruir solo las porciones afectadas de la pantalla. `provider` es pequeño, estable y de mantenimiento activo; lo que aporta —`ChangeNotifierProvider`, `Consumer`, `context.watch`— habría que escribirlo a mano con `InheritedNotifier` repitiéndolo por cada store.

**Alternativas consideradas**:
- **`setState` puro**: insuficiente para compartir el estado del mes entre pantallas.
- **`InheritedNotifier` a mano**: viable, pero multiplica el boilerplate por cada notificador sin ganar nada.
- **Riverpod / BLoC**: más aparato conceptual del que justifica una app de un usuario y ~8 pantallas (Principio V).

---

## D7 — Localización: `flutter_localizations` + `intl` solo para fechas

**Decisión**: `flutter_localizations` (viene del SDK) con `locale` fijo `es_PE` para los textos de Material. `intl` (`DateFormat`) únicamente para formatear fechas. Los textos de la app son literales en español en el código; **no** se monta ARB ni generación de traducciones.

**Rationale**: la constitución pide interfaz en español y convención peruana; la app es monolingüe y de un solo usuario, así que una infraestructura de i18n sería trabajo sin requisito que lo respalde (Principio V). `intl` llega igualmente como dependencia transitiva de `flutter_localizations`; se declara explícita en `pubspec.yaml` para fijar su versión en lugar de depender de la que arrastre el SDK. El dinero **no** pasa por `intl` (ver D2).

---

## D8 — Pruebas: `flutter_test` + `sqflite_common_ffi` + guarda de pureza

**Decisión**: tres niveles.

1. **Dominio** (`test/dominio/`): Dart puro, escrito **antes** de cada regla financiera (Principio III). Cubre caso normal, límite (saldo exactamente cero) y adverso (déficit).
2. **Datos** (`test/datos/`): repositorios contra SQLite real en memoria vía `sqflite_common_ffi`, que permite correr las pruebas en Windows sin emulador. Incluye una prueba de migración.
3. **Widget** (`test/ui/`): las pantallas con reglas de presentación verificables (déficit no dependiente del color, orden del listado, formato de montos).

Además, una **prueba de guarda** que recorre `lib/dominio/` y falla si algún archivo importa `package:flutter/` o `package:sqflite/`. Convierte el Principio III en algo que la suite verifica, en vez de una convención que se erosiona.

**Alternativas consideradas**: probar el dominio solo a través de widgets. Rechazada: esconde los errores de cálculo detrás de la UI y contradice el Principio III.

---

## D9 — Estructura por capas dentro de `lib/`

**Decisión**: `lib/dominio/` (puro), `lib/datos/` (sqflite y repositorios), `lib/ui/` (pantallas y widgets), `lib/core/` (tipos transversales: `Dinero`, `Mes`, formateadores). La dependencia siempre apunta hacia adentro: `ui → datos → dominio → core`.

**Rationale**: es la separación mínima que hace cumplible el Principio III y que permite que las pruebas del dominio corran sin levantar Flutter. No se introducen capas adicionales (casos de uso, DTOs, mappers genéricos) porque ningún requisito las pide.

**Nomenclatura**: los identificadores del dominio van en español (`Mes`, `Obligacion`, `Transaccion`, `Deuda`, `AporteAhorro`), igual que la spec, para que no haya un salto de vocabulario entre el requisito y el código. Las palabras del framework y de la plataforma quedan en inglés.

---

## D10 — Migraciones del esquema

**Decisión**: `onCreate` construye la versión actual; `onUpgrade` aplica pasos incrementales de una versión a la siguiente, cada uno idempotente y cubierto por una prueba. Nunca se borra ni se recrea la base para migrar.

**Rationale**: la constitución exige que toda migración preserve los datos del usuario, y estos datos no tienen respaldo (la spec descarta backup y exportación en esta versión): una migración destructiva sería una pérdida irreversible.

---

## D11 — Diseño visual: Material 3 del SDK, sin kit de componentes

**Decisión**: el tema sale de `ColorScheme.fromSeed()` de Material 3, que ya viene en Flutter. **No** se añade ninguna librería de componentes de UI. Tres reglas de presentación fijadas para toda la app:

1. **Cifras tabulares en todo monto**: `fontFeatures: [FontFeature.tabularFigures()]`. Sin esto los dígitos tienen anchos distintos y las columnas de montos bailan al cambiar de mes.
2. **Jerarquía por tamaño, no por color**: el dato que responde la pregunta de la pantalla va en el tamaño mayor; el resto queda subordinado.
3. **Contraste AA** en todo texto, y ningún estado comunicado solo por color (FR-029).

**Rationale**: el Principio IV pide que el usuario entienda su situación de un vistazo y prohíbe añadir elementos que no respondan a un requisito. Un kit de componentes traería decenas de widgets que nadie va a usar y una estética que habría que domar. Material 3 ya resuelve contraste, tamaño táctil y jerarquía tipográfica, y no cuesta una dependencia.

**Navegación**: `NavigationBar` con **cinco destinos** (resumen, presupuesto, gastos, deudas, ahorro). Material 3 admite de tres a cinco; con seis, la etiqueta "Presupuesto" no entraba y se partía en dos líneas en una pantalla de 1080 px — se detectó corriendo la app en el emulador, no en las pruebas. El desglose por categoría (US6) se alcanza desde el resumen: es una vista de detalle del mes, no una sección propia.

**Alternativas consideradas**:
- **`flex_color_scheme`** (v8.4.0, publisher verificado, 90.8k descargas semanales, sin dependencias de red): produce temas claro y oscuro más pulidos que `fromSeed` a mano. Es solo `ThemeData`, así que entra y sale sin tocar las pantallas. **Aplazada a la fase de Polish**: se evalúa cuando haya pantallas reales que juzgar, no antes.
- **`google_fonts`**: **rechazada**. Descarga las tipografías desde servidores de Google en tiempo de ejecución, lo que rompe SC-012 (uso sin conexión) y contradice el Principio I. Si en algún momento se quiere una tipografía propia, se empaqueta el archivo como asset.

---

## D12 — Meta de ahorro por mes, no global

**Decisión**: la meta de ahorro se guarda **por mes** en su propia tabla (`meta_ahorro`). La regla de cálculo (porcentaje o remanente) sigue siendo global, en la tabla `configuracion`. Al abrir un mes sin meta, la app propone la del último mes que tuvo una, sin guardarla hasta que el usuario confirme.

**Rationale**: con una meta global única, el historial evaluaría los meses pasados contra la meta de hoy — si el usuario sube su meta de S/ 400 a S/ 700, meses que había cumplido pasarían a figurar como incumplidos. Eso destruye el valor del historial, que es justamente ver cómo le fue mes a mes. La propuesta automática evita el coste de reescribir la meta cada mes y usa el mismo criterio que la precarga de obligaciones fijas: proponer, nunca escribir en silencio.

**Alternativas consideradas**: meta global única (más simple, una columna menos) — rechazada por el problema del historial retroactivo. Meta calculada automáticamente desde la regla de ahorro — rechazada: la sugerencia y la meta son cosas distintas, la meta es un compromiso que el usuario fija.

---

## D13 — Cierre de meses: derivado de la fecha, no persistido

**Decisión**: un mes está `abierto` (el actual), `enGracia` (el anterior, mientras el día de hoy no supere `diasGraciaCierre`) o `cerrado`. El estado **se calcula** a partir de la fecha de hoy y de la configuración; no hay columna de cierre ni proceso que "cierre" el mes. La regla vive en `lib/dominio/calculos/cierre_mes.dart` y recibe `hoy` como parámetro, nunca llama a `DateTime.now()`.

**Rationale**: un cierre persistido exigiría un proceso que corra al cambiar de mes — y si el usuario no abre la app durante seis semanas, ese proceso no corrió y el estado queda mentiroso. Derivarlo de la fecha es correcto siempre, sin importar cuándo se abra la app. Recibir `hoy` como parámetro hace que la ventana de gracia se pruebe con fechas fijas en vez de manipulando el reloj del sistema, que es la única forma de que estas pruebas sean estables.

**Consecuencia asumida**: un mes cerrado no tiene vía de corrección para ingresos, obligaciones, transacciones ni aportes. La spec lo acepta explícitamente: la validación al ingresar y la confirmación del usuario son la defensa, y un error que las atraviese se trata como defecto del software, no como flujo de usuario. La única excepción es la deuda (FR-057), porque su cuota nunca fue un dato del mes sino un derivado (D3).

**Alternativas consideradas**: marca `cerrado` en una tabla de meses, con proceso de cierre — rechazada por lo anterior. Bloqueo por antigüedad en días en vez de por mes calendario — rechazada: la unidad de gestión de toda la app es el mes.

---

## D14 — Entidades bancarias: lista local, sin API, sin tasas

**Decisión**: la lista de entidades emisoras es una constante en `lib/dominio/modelos/entidades.dart`, editable en el código y ampliable por el usuario con texto libre. **No se consulta ninguna API** y **no se almacenan tasas de interés**.

**Rationale**: no existe API pública para desarrolladores con el padrón de entidades peruanas ni con las tasas por tarjeta. La [SBS](https://www.sbs.gob.pe/app/pp/EstadisticasSAEEPortal/Paginas/TIActivaTipoCreditoEmpresa.aspx?tip=B) y el [BCRP](https://estadisticas.bcrp.gob.pe/estadisticas/series/mensuales/tasas-de-interes) publican portales web de consulta, no servicios documentados: habría que scrapear HTML sujeto a cambios sin aviso. Y el conjunto de emisores del Perú son unas quince entidades que cambian rarísimo. Una lista en el código funciona sin conexión, no se rompe nunca y no obliga a enmendar el Principio I.

Sobre las tasas, la decisión ya estaba tomada en la spec y se ratifica: la app registra la cuota que informa el banco (FR-024) porque replicar la amortización produce discrepancias de centavos contra el estado de cuenta. Además, la tasa publicada por la SBS es un promedio del mercado, no la del contrato del usuario ni la de su promoción vigente: guardarla daría un número que aparenta precisión y está mal.

**Alternativas consideradas**: scraping del tarifario de la SBS — rechazada por fragilidad y por exigir conexión. API de terceros agregadores — rechazada: introduce un servicio externo y una dependencia de red que el Principio I prohíbe sin enmienda.

---

## D15 — Repositorios con interfaz, para poder probar sin base de datos

**Decisión**: cada repositorio se declara como `abstract interface class` en `lib/dominio/repositorios/` y se implementa en `lib/datos/repositorios/` con el sufijo `Sqlite`. Las capas de arriba dependen de la interfaz. Las pruebas de widget y las de `lib/ui/estado/` usan dobles en memoria en `test/dobles/`.

**Rationale**: no es una abstracción preventiva, resuelve un problema demostrado. `sqflite_common_ffi` no completa dentro del reloj falso de `testWidgets`: la prueba de la pantalla de presupuesto se colgaba indefinidamente en vez de fallar, y `runAsync` no alcanzó. Sin la interfaz, cada historia sumaría una prueba de widget saltada.

El beneficio secundario resultó mayor que el motivo original: habilitó probar `EstadoMes`, que decide si una escritura está permitida según el cierre del mes. Esa decisión toca dinero — si dejara pasar una edición sobre un mes cerrado, el histórico dejaría de ser confiable — y antes no tenía cobertura propia.

**Ubicación**: en `lib/dominio/` y no en `lib/shared/`, aunque `shared/` sea donde vive lo reutilizable. Las firmas hablan de `Obligacion`, `Ingreso` y `Configuracion`, que son modelos del dominio; ponerlas en `shared/` obligaría a que `shared/` importe de `dominio/`, invirtiendo la regla `ui → datos → dominio → shared`. Es la ubicación habitual de un puerto en arquitectura hexagonal: el puerto pertenece al dominio, el adaptador a la infraestructura.

**Riesgo asumido**: un doble puede desincronizarse del adaptador real y hacer pasar una prueba que en la app falla. Se acota manteniendo `test/datos/` contra SQLite real: el contrato se verifica contra la base de verdad, y los dobles solo se usan donde el comportamiento de la base no es lo que se está probando. También se pierde la cobertura de integración pantalla-más-base, que queda a cargo de la validación manual del quickstart en un dispositivo.

**Frente al Principio V**: hay exactamente una implementación real y un doble por interfaz. No se declara ninguna interfaz cuyo repositorio no exista.

**Alternativas consideradas**: una costura única en `EstadoMes`, con un doble del propio notificador — menos código, pero deja sin cubrir la lógica de `EstadoMes`, que es justamente la que decide sobre escrituras de dinero. Rechazada.

---

## Dependencias resultantes

| Paquete | Uso | Justificación frente a hacerlo a mano |
|---|---|---|
| `sqflite` | Persistencia local | Ver D1. Implementar almacenamiento relacional con migraciones a mano no es razonable. |
| `path` | Componer la ruta de la BD | Trivial, pero ya es dependencia transitiva de `sqflite`; evita concatenar rutas con separadores de plataforma. |
| `provider` | Estado e inyección en la UI | Ver D6. |
| `intl` | Formato de fechas | Ver D7. Entra igualmente como dependencia transitiva de `flutter_localizations`, pero se declara explícita en `pubspec.yaml` para fijar su versión en vez de heredarla. |
| `flutter_localizations` | Textos de Material en español | Viene del SDK, no es un tercero. |
| `sqflite_common_ffi` *(dev)* | SQLite real en las pruebas de escritorio | Ver D8. |

Ninguna abre conexiones de red ni recoge telemetría (Principio I). Las versiones se resuelven con `flutter pub add` en la primera tarea de implementación; no se fijan aquí para no anclar versiones sin verificar.

---

## Desconocidos resueltos

Todos los `NEEDS CLARIFICATION` del Technical Context quedan resueltos por D1–D10. No queda ninguno abierto para la Fase 1.
