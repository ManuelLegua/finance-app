# finance-app

App Flutter de finanzas personales, individual y sin conexión, para administrar un sueldo mensual en soles peruanos: presupuesto, gastos reales, deudas de tarjeta en cuotas y ahorro.

## Entorno

- Flutter 3.47.1 stable / Dart 3.13.1. En la máquina principal el SDK está en `C:\Users\manue\dev\flutter` y **no está en el `PATH`**; agregarlo a la sesión antes de trabajar:
  ```powershell
  $env:PATH = "C:\Users\manue\dev\flutter\bin;$env:PATH"
  ```
- `flutter pub get` · `flutter analyze` · `flutter test` · `flutter run`
- Las pruebas corren en Windows sin emulador (`sqflite_common_ffi`). Solo la validación manual necesita un Android real.

## Correr la app en un emulador

En la máquina principal ya está todo instalado. **En una máquina nueva hay que montarlo**, y son unos 2 GB de descarga.

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$android = "$sdk\cmdline-tools\latest\bin\android.exe"

# El SDK manager nuevo se llama `android`, no `sdkmanager`
& $android sdk install "emulator" "system-images/android-35-ext15/google_apis/x86_64"

& "$sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd `
  --name finanzas_pixel `
  --package "system-images;android-35-ext15;google_apis;x86_64" `
  --device pixel_7
```

**Aceleración por hardware.** Sin ella el emulador es inusable. Verificá con `& "$sdk\emulator\emulator.exe" -accel-check`: tiene que devolver `0`.

En **CPU AMD** (como el Ryzen 7 5800H de la máquina principal) hace falta el driver AEHD de Google, y su instalador pide **administrador**:

```powershell
& $android sdk install "extras/google/Android_Emulator_Hypervisor_Driver"
# Después, en una terminal como administrador:
cd "$env:LOCALAPPDATA\Android\Sdk\extras\google\Android_Emulator_Hypervisor_Driver"
.\silent_install.bat
```

En Intel se usa HAXM, o `Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All` (requiere reiniciar).

**Correr la app:**

```powershell
$env:PATH = "C:\Users\manue\dev\flutter\bin;$env:PATH"
flutter emulators --launch finanzas_pixel
flutter run    # r = hot reload · R = hot restart · q = salir
```

### Tropiezos conocidos del emulador

| Síntoma | Solución |
|---|---|
| `adb: device offline` intermitente | `adb reconnect`, o esperar unos segundos y reintentar |
| El teclado sale como una barrita flotante | `adb shell pm clear com.google.android.inputmethod.latin` |
| No aparece el teclado en pantalla | Android detecta el teclado físico de la laptop. Tipeá con él, o tocá el ícono de teclado en la franja negra inferior |
| Empezar con datos limpios | `adb shell pm clear io.github.manuellegua.finanzas` |

`adb` vive en `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`.

## Recorrido de prueba manual

Lo que la suite no puede verificar: si la pantalla se entiende de un vistazo (Principio IV). Los tres defectos de layout que aparecieron hasta ahora — etiquetas más largas que su contenedor, la última vez "Presupuesto" partido en dos líneas en un teléfono real — salieron de acá, no de las pruebas: `flutter test` no carga tipografía real ni mide en anchos de pantalla reales, así que este tipo de desborde no es reproducible en la suite (ver `lib/shared/estilos/tema.dart`).

1. **Presupuesto** → registrar el sueldo y dos o tres obligaciones.
2. **Resumen** → el disponible tiene que leerse sin hacer cuentas. Subí las obligaciones por encima del ingreso: el déficit se comunica con ícono y texto, no solo con color.
3. **Gastos** → anotar uno debe llevar menos de quince segundos (SC-002). Gastá de más en una categoría y mirá la marca de sobregiro.
4. **Tarjetas** (menú lateral) → una de crédito y una de débito. La de débito **no** debe ofrecerse al crear una deuda (FR-061).
5. **Deudas** → 12 cuotas de S/ 150 desde este mes. Tiene que decir "0 de 12 pagadas": la cuota del mes en curso todavía no se pagó (D4).
6. **Resumen** → la categoría tarjeta de crédito se despliega y muestra de qué deuda sale el monto (FR-017).
7. **Editar la deuda** y cambiarle la cuota: el comprometido se recalcula solo, sin reescribir nada. Es D3 funcionando.
8. **Ajustes** → poner los días de gracia en 0 y navegar al mes anterior: queda cerrado de inmediato.
9. **Ajustes → Respaldo** → exportar: tiene que abrirse la hoja de compartir de Android. Después `adb shell pm clear io.github.manuellegua.finanzas`, restaurar ese archivo y comprobar que el disponible del mes vuelve idéntico. El recorrido completo está en [quickstart.md](specs/005-respaldo-exportacion-datos/quickstart.md).

## Cómo se trabaja acá

Desarrollo dirigido por especificación con Spec Kit. **Ninguna funcionalidad se implementa antes de estar descrita en `specs/` y aprobada.** El orden es spec → plan → tasks → implementación; un cambio de alcance se refleja primero en la spec, nunca directo en el código.

| Dónde | Qué |
|---|---|
| `.specify/memory/constitution.md` | Los cinco principios. Prevalece sobre cualquier otra práctica |
| `specs/001-gestion-sueldo-ahorro/spec.md` | 61 requisitos funcionales y 12 criterios de éxito |
| `specs/001-gestion-sueldo-ahorro/plan.md` | Contexto técnico, Constitution Check, estructura |
| `specs/001-gestion-sueldo-ahorro/research.md` | 14 decisiones técnicas (D1–D14) con las alternativas rechazadas |
| `specs/001-gestion-sueldo-ahorro/data-model.md` | Entidades, derivados y el esquema SQLite completo |
| `specs/001-gestion-sueldo-ahorro/contracts/` | API de la capa de cálculo puro y de los repositorios |
| `specs/001-gestion-sueldo-ahorro/tasks.md` | **La cola de trabajo**: 105 tareas numeradas por historia |
| `specs/002-captura-notificaciones-bancarias/` | **En curso: 52 de 62 tareas.** Alcance revisado 2026-08-30: reconocimiento genérico de cualquier banco/billetera (lista ampliable), no un intérprete por banco — ver research.md D-N2/D-N10/D-N11 |
| `specs/003-cobros-parciales-ingreso/` | **Implementada (33 de 34 tareas; falta T033, recorrido manual en dispositivo).** Ingreso en varios cobros por mes (quincena + fin de mes, etc.); `CobroIngreso` reemplazó a `Ingreso` (un monto único), mismo patrón que `AporteAhorro`. La tabla `ingreso` de la v1 ya no se crea en instalaciones nuevas — solo sigue existiendo, intacta, en las que vienen de una versión anterior (D-C2/D-C5 de research.md) |
| `specs/004-suscripcion-premium/` | **Revisada el 2026-09-12 y reimplementada: de suscripción paga a propina voluntaria** (68 de 70 tareas). La app se reparte completa y gratis; apoyar no desbloquea nada. La carpeta conserva su nombre viejo para no romper los enlaces del historial (Principio I enmendado a v2.0.0, sin enmienda nueva) |
| `specs/005-respaldo-exportacion-datos/` | **Implementada (43 de 43).** Exportar todo a un archivo y volver a cargarlo. El respaldo **es** el propio archivo SQLite (D1), así que restaurar uno viejo reutiliza las migraciones que ya existen (Principio I enmendado a v3.0.0) |

Antes de proponer un cambio de diseño, leer `research.md`: es probable que la alternativa ya se haya evaluado y rechazado por escrito.

## Reglas que no se negocian

1. **El dinero es un `int` de centavos, de punta a punta.** Nunca `double`, nunca `float`. El tipo `Dinero` no tiene constructor desde `double`. El formato `S/ 1,234.56` se produce a mano desde el entero — **no** con `intl.NumberFormat`, que recibe `num` y reintroduciría el punto flotante justo antes de mostrar la cifra. Columnas `INTEGER`, jamás `REAL`. Porcentajes en puntos base (20% = 2000).

2. **`lib/dominio/` y las carpetas puras de `lib/shared/` son Dart puro.** Sin `package:flutter/`, sin `package:sqflite/`, sin `DateTime.now()` adentro (la fecha entra como parámetro). `test/pureza_test.dart` falla si alguien lo viola.

3. **Las pruebas de reglas financieras se escriben ANTES que la implementación**, cubriendo caso normal, límite (saldo exactamente cero) y adverso (déficit). Es requisito de entrada por constitución, no un paso opcional.

4. **Nada sale del dispositivo por su cuenta.** Sin red, sin telemetría, sin cuentas, sin sincronización. Ninguna dependencia puede abrir conexiones. Hay exactamente dos excepciones, las dos enmiendas a la constitución y las dos acotadas por escrito: Google Play Billing (v2.0.0) y el **respaldo a pedido del usuario** (v3.0.0) — que genera un archivo y se lo entrega a la hoja de compartir del sistema, nunca a un servidor propio, y nunca sin que el usuario lo pida en ese momento. No hay respaldo automático ni programado. Cualquier otra salida de datos exige enmendar la constitución primero.

5. **YAGNI.** El código que no respalda un requisito vigente no se escribe. Sin multiusuario, multimoneda, capas de casos de uso ni infraestructura de i18n.

## Decisiones fáciles de romper sin querer

- **Las cuotas de deuda se derivan, no se almacenan** (D3). El presupuesto de un mes es *obligaciones guardadas + cuotas vigentes calculadas*. No existe tabla de cuotas: crear una rompería el recálculo retroactivo.
- **La cuota del mes en curso cuenta como pendiente** (D4). Una deuda de 12 cuotas que arranca este mes tiene 12 por pagar, no 11.
- **La categoría `tarjetaCredito` no admite obligaciones manuales**: ese compromiso lo derivan las deudas. Registrarlo a mano duplica el monto.
- **El cierre de meses se calcula desde la fecha, no se persiste** (D13). Meses pasados son de solo lectura, con ventana de gracia configurable para registrar pagos rezagados; lo registrado en gracia queda inmutable. Única excepción: corregir una deuda (FR-057).
- **La meta de ahorro es por mes**, no global (D12). Un mes pasado se evalúa contra la meta que regía entonces.
- **Sin API de bancos ni tasas de interés** (D14). La lista de entidades peruanas es una constante local. La cuota la informa el banco; replicar la amortización daría discrepancias de centavos.

## Estructura de carpetas

```
lib/
├── shared/          # TODO lo reutilizable vive acá. Nada se duplica fuera.
│   ├── tipos/       # Dinero, Mes — Dart puro
│   ├── constantes/  # enums y constantes de dominio — Dart puro
│   ├── formato/     # FormatoSoles, FormatoFecha — Dart puro
│   ├── estilos/     # Tema, Espaciado — Flutter
│   └── componentes/ # widgets reutilizables — Flutter
├── dominio/         # PURO: modelos y cálculos financieros
├── datos/           # esquema, migraciones, repositorios
└── ui/              # estado y pantallas
```

**Antes de crear un enum, una constante, un estilo o un widget, buscar en `shared/`.** Si algo se usa en dos lugares, va a `shared/`; si se duplica, es un error a corregir, no una variante.

Las cuatro primeras subcarpetas de `shared/` son **Dart puro** y `test/pureza_test.dart` las verifica junto con `lib/dominio/`: sin Flutter, sin sqflite, sin `DateTime.now()`. `estilos/` y `componentes/` sí usan Flutter y quedan fuera de esa guarda.

Los imports internos son **absolutos** (`package:finanzas/shared/tipos/dinero.dart`), nunca relativos: mover un archivo no obliga a reescribir rutas y se ve de dónde viene cada cosa.

## Código legible por encima de código breve

El objetivo es que alguien que llega al proyecto entienda una función sin reconstruir contexto. En concreto:

- **Enums en vez de `bool` o cadenas sueltas** para cualquier cosa que represente una decisión o un estado. `tipo: TipoEscritura.modificar` se lee solo; `requiereEdicion: true` obliga a ir a la firma. Además el `switch` exhaustivo hace que agregar un caso sin manejarlo no compile.
- **Constantes con nombre en vez de números mágicos**: `Espaciado.entreCampos`, no `16`. `_maxCifrasEnteras`, no `7`.
- **Nombres que digan la intención**: `obligacionesMesAnterior`, no `lista`.
- **Prohibidas las variables de una letra y las abreviaturas**, incluso en lambdas cortas y en `catch`. Va `(categoria) => categoria.slug`, no `(c) => c.slug`; `catch (error)`, no `catch (e)`; `Database conexion`, no `db`. Quien supervisa sabe que `c` es categoría, pero el que llega después no, y el costo de escribirlo entero es cero.
- **Una responsabilidad por archivo**, y el nombre del archivo la anuncia. Si `formulario_obligacion.dart` termina conteniendo también un diálogo de ingreso, se separa.
- **Comentar el porqué, no el qué.** El código dice qué hace; el comentario explica la decisión que no es obvia (por qué el parseo no pasa por `double`, por qué el cierre se deriva de la fecha).
- Funciones cortas, anidamiento bajo, salidas tempranas antes que `else` encadenados.

## Convenciones de código

- Arquitectura en capas, dependencia siempre hacia adentro: `ui → datos → dominio → shared`. `shared/` no importa de ninguna capa; la guarda de pureza lo verifica.
- **Identificadores del dominio en español** (`Mes`, `Obligacion`, `Transaccion`, `Deuda`, `AporteAhorro`, `CobroIngreso`), igual que la spec, para que no haya salto de vocabulario entre el requisito y el código. Las palabras del framework quedan en inglés.
- UI en español, formato peruano. Material 3 del SDK, sin kit de componentes. Cifras tabulares en todo monto. **Ningún estado se comunica solo por color** (déficit, sobregiro, mes cerrado).
- La regla de cierre se aplica en `lib/ui/estado/`, nunca en los repositorios: duplicarla crearía dos verdades que se desincronizan.

## Git

- Rama única `main` hasta que la app se valide; después, una rama por feature.
- **`user.email` se fija a nivel local en este repo** (`manuel.mendoza161296@gmail.com`), porque la config global de las máquinas de trabajo usa otro correo. `.git/config` no se clona: al clonar en otra máquina hay que volver a fijarlo.
  ```bash
  git config --local user.email manuel.mendoza161296@gmail.com
  ```
- Mensajes de commit en español, prefijo `docs:` / `feat:` / `fix:` / `chore:`, referenciando la tarea que atienden.

## Estado actual

**Spec 001 completa (108/108)**, validada en emulador y en un Android real (T107).
**Spec 002 en curso (52/62)** — el tramo que falta dejó de ser solo insumo manual: ver el hallazgo del 2026-09-12 más abajo.
**Spec 003 implementada (33/34)** — falta T033, recorrido manual en dispositivo.
**Spec 004 revisada a propina (68/70)** — ya no hay nada bloqueado detrás de un pago; lo que falta son las dos tareas manuales de Play Console y dispositivo (T068, T069).
**Spec 005 implementada (43/43)** — validada en emulador el 2026-09-08: exportar abre la hoja de compartir, `pm clear` + restaurar devuelve los datos idénticos, y un archivo que no es respaldo se rechaza con su motivo. El paso 8 de T042, que esperaba una suscripción real, quedó sin objeto al desaparecer el acceso pagado.
**525 pruebas, todas en verde.** Bajaron de 552 porque la revisión de la spec 004 borró las cinco suites de la suscripción (paywall, ficha, restaurar, vencimiento, migración v4) y sumó las de la propina. La que dependía del reloj real (`pantalla_ahorro_test.dart`, FR-042) se arregló en `3b31be7`.
**`flutter analyze` sin issues.**

| Spec 001 · Historia | Estado |
|---|---|
| US1 · ingreso y presupuesto | ✅ |
| US2 · resumen y déficit | ✅ |
| US3 · gastos reales | ✅ |
| US4 · deudas en cuotas | ✅ |
| US5 · ahorro (T083–T094) | ✅ |
| US6 · desglose por categoría (T095–T099) | ✅ |
| Polish (T100–T108) | ✅ |

### Dónde retomar la spec 002

| Spec 002 · Fase | Estado |
|---|---|
| Setup + Foundational (T001–T010) | ✅ esquema v2, migración probada, `OrigenReconocido` |
| US1 · activar la captura (T011–T019) | ✅ permiso, 4 estados, servicio en foreground |
| US2 · bandeja de pendientes (T020–T033) | ✅ confirmar/corregir/descartar, deduplicación, diagnóstico |
| US2 · parser genérico (T034–T043) | ⛔ **bloqueado por insumo manual** |
| US3 · categorización aprendida (T044–T051) | ✅ normalizador de comercio, `RepositorioAsociaciones`, propuesta y aprendizaje en `EstadoPendientes`, pantalla "Comercios" |
| US4 · consumos en cuotas (T052–T055) | ✅ `EstadoPendientes.confirmar(comoDeuda:)`, interruptor "fue una compra en cuotas" en el formulario (oculto sin tarjetas de crédito) |
| Polish (T056–T058 hechas; T060–T061 [MANUAL] esperan al parser + dispositivo; T062 al cierre) | en curso |

**El bloqueo (D-N9 de research.md):** no existe documentación pública del formato
de las notificaciones de ningún banco peruano, así que el parser genérico no se
puede escribir ni probar contra texto inventado. Faltan dos insumos que solo se
consiguen con el teléfono en la mano:

- **T034** — el texto de notificaciones reales (título y cuerpo tal como aparecen
  en la barra de notificaciones, **no** el correo del banco, que usa otra
  plantilla), de al menos 3 orígenes variados. Documentar en
  `test/dominio/interpretes/fixtures/`.
- **T041** — el `packageName` Android de cada app bancaria instalada, para
  completar `lib/shared/constantes/origenes_reconocidos.dart`, que hoy tiene los
  15 nombres pero todos con `paquete: ''` (un origen sin paquete no se escucha,
  y eso no rompe nada).

**Hallazgo del 2026-09-12 que agrava el bloqueo, y que hay que leer antes de
retomar esto.** El usuario intentó capturar el insumo de T034 y lo que salió es
otra cosa: en su teléfono las apps de BCP, Yape y Sip **solo mandan push del
dinero entrante** (transferencias y yapeos recibidos). Los consumos —lo único
que esta spec captura, FR-012 y FR-013 mandan ignorar todo lo entrante— llegan
**únicamente por correo**, y lo que aparece en la barra es una notificación de
Gmail, no del banco.

La consecuencia es de diseño, no de implementación: **con el diseño actual
—filtrar por el `packageName` de cada app bancaria (D-N10)— la captura no
registraría ni un consumo en este dispositivo.** Todo push que reciba sería
correctamente clasificado como entrante y descartado. El insumo que T034 pide no
existe acá, así que T034 no está "pendiente de capturar": está pendiente de una
decisión de alcance.

Los textos que sí se consiguieron quedaron transcritos en
`test/dominio/interpretes/fixtures/correo-gmail.md`, marcados como anexo y **no**
como cumplimiento de T034. No son inservibles: confirman palabras clave de
D-N11 (`realizaste un consumo`, `acabas de yapear`, `recibiste`), aportan tres
frases salientes que D-N11 no contempla (`transacción`, `pago de servicios`,
`enviar a celular`), y dejan ver tres cosas que ningún texto inventado habría
anticipado — que Yape parte el `S/` y la cifra en líneas distintas, que el mismo
comercio se escribe `ESVISALUD SAC` o `ESVISALUD S.A.C.` según la tarjeta, y que
un traspaso entre cuentas propias genera dos notificaciones opuestas por el
mismo monto que la deduplicación de D-N7 no relaciona.

Antes de escribir una línea de parser hay que resolver, **en la spec**, por
dónde entran los consumos. Las tres salidas evaluadas, sin decidir todavía:
activar alertas push de consumo en los ajustes de la app del banco, si es que se
puede; reconocer Gmail como origen y filtrar por remitente en vez de por paquete
(que implica que la app reciba el preview de todo el correo, no solo el
bancario); o aceptar que la feature no se sostiene en este teléfono. La primera
pregunta a responder, y la más barata, es si el `NotificationEvent` de Gmail
trae el correo completo o solo el preview truncado: en las capturas el corte cae
justo sobre el comercio, y sin comercio no hay categorización aprendida (US3).

Hasta entonces la captura está construida de punta a punta salvo el tramo
notificación → pendiente: el callback headless
(`lib/datos/notificaciones/callback_headless.dart`) existe y está registrado,
pero **no interpreta ni guarda nada** — mientras siga así, FR-020 ("nunca en
silencio") se cumple solo, porque no hay ninguna ruta desde ahí hasta una
`Transaccion`.

**Instrumento temporal para desbloquear T034/T041 (2026-09-12).** El cuerpo del
callback, que estaba vacío, ahora **solo escribe al log del dispositivo**, para
responder la pregunta más barata que dejó abierta el hallazgo: si la
notificación de Gmail trae el correo del banco completo o el mismo preview
truncado. `NotificationEvent.text` expone solo `EXTRA_TEXT`, pero el lado
Android del plugin reenvía además `EXTRA_BIG_TEXT` y `EXTRA_TEXT_LINES`, que
llegan a Dart en `evento.raw['bigText']` y `raw['textLines']` y que nadie miró
nunca. La lógica es pura y está probada en
`lib/dominio/interpretes/volcado_notificacion.dart`, que además calcula el
veredicto en una línea en vez de dejar la comparación al ojo.

La raya de privacidad está puesta a propósito: de **toda** notificación se
registra solo el nombre del paquete (que es lo que T041 necesita y no revela
contenido), y el texto completo **solo** de los paquetes de
`paquetesBajoObservacion`, que hoy es únicamente Gmail. Volcar el cuerpo de
cada notificación del teléfono a un log sería una fuga hacia adentro, y el
Principio I no deja de aplicar porque el destino sea local.

Cómo leerlo, con el teléfono conectado:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb logcat -c                                   # limpiar el buffer
# provocar el correo del banco, esperar la notificación
& $adb logcat -d | Select-String "FINANZAS-VOLCADO"
```

**Este volcado se borra en cuanto termine de dar el insumo.** No es el
principio de T042: es lo que tiene que pasar antes, porque T042 no se puede
escribir sin saber qué texto llega realmente.

### Resultado del 2026-09-13: `bigText` trae el correo completo

**La vía de Gmail es viable.** El evento sí trae el cuerpo entero del correo —
301 y 1024 caracteres contra 24 y 79 del preview— en `raw['bigText']`. El
truncamiento que parecía matar la spec 002 era un artefacto de leer solo
`NotificationEvent.text`. Los volcados, capturados por la propia app y no
transcritos, están en
[notificacion-gmail-capturada.md](test/dominio/interpretes/fixtures/notificacion-gmail-capturada.md).

Cuatro cosas que quedan decididas sobre cómo tendría que ser el parser, y que
ningún texto inventado habría anticipado:

1. **El remitente viene en `title`**, no en el paquete: para Gmail el
   `packageName` siempre es `com.google.android.gm`, así que el filtro por
   paquete de D-N10 no alcanza. Hay que filtrar por `title` (`BCP
   Notificaciones`, `Operaciones Sip`, `YAPE Notificaciones`).
2. **Gmail publica dos notificaciones por correo**: una agrupada ("3 mensajes
   nuevos", con `textLines` y sin `bigText`) y una individual por correo (con
   `bigText`). Tomar las dos contaría cada consumo dos veces. La regla para
   descartar la agrupada es `bigText == null && textLines != null`.
3. **El monto está en su propia línea**, separado de la etiqueta que lo nombra.
   Un parser que busque `S/` en la misma línea que "Monto" falla en los dos
   correos capturados.
4. **`bigText` se corta a los 1024 caracteres exactos**, a mitad de palabra. En
   lo capturado el dato útil entra en los primeros 200, pero un consumo que
   ponga el comercio más abajo lo perdería. Sin verificar.

**Lo que falta**: los tres capturados son movimientos entre cuentas, no
consumos con tarjeta — lo único que la spec registra. Falta un consumo real
para cerrar T034.

### Tres bugs de la spec 002 que salieron de este mismo recorrido

Son independientes del parser y hoy hacen que **la captura no funcione en
ningún teléfono con Android 13 o superior**. Hay que arreglarlos aunque la
decisión de alcance cambie:

1. **La app nunca pide `POST_NOTIFICATIONS`.** Desde Android 13 un servicio en
   primer plano está obligado a publicar una notificación; sin ese permiso
   Android lo mata con ANR (`Context.startForegroundService() did not then call
   Service.startForeground()`). Conceder el permiso **no alcanzó** por sí solo:
   hizo falta además que `activar()` corriera con el servicio ya vinculado, que
   es lo único que termina de inicializar el motor de Flutter del plugin. Dos
   defectos que se manifestaban igual. **Arreglado (T063)** con
   `permission_handler` (D-N14).
2. **"Desactivar" puede dejar la feature inutilizable.** El plugin deshabilita
   el componente del servicio a nivel de sistema; Android entonces revoca el
   acceso a notificaciones y saca la app de la lista de ajustes — justo la
   lista adonde la propia app te manda a arreglarlo. Sin salida por interfaz:
   hay que desinstalar. Solo la app puede reactivar ese componente, `adb` no
   (da `SecurityException`).
3. **`EstadoCaptura` miente.** **Arreglado (T065)**. "Captura activa" se deriva del permiso más el
   interruptor guardado, sin comprobar que el servicio exista. Se vio la
   pantalla diciendo "activa" con el servicio muerto. Es el más grave de los
   tres: un usuario creería que sus consumos se están capturando mientras no se
   captura nada.

**Y una cuarta cosa, que es de operación y no de código**: tras una
reinstalación hay que volver a conceder el permiso de notificaciones **y**
hacer el ciclo Desactivar → Activar, porque el identificador del callback que
Android guarda apunta al build anterior. Sin eso el callback no corre y no hay
ninguna señal de que algo ande mal.

**Nota para cuando se retome T042**: la propuesta de categoría de US3 (FR-030)
ya no necesita resolverse ahí. `EstadoPendientes.cargar()` le busca la
asociación aprendida a cualquier pendiente que llegue sin `categoriaPropuesta`
(`lib/ui/estado/estado_pendientes.dart`), sea que lo haya escrito el callback
headless real o un doble de prueba — así que T042 solo necesita escribir el
`ConsumoPendiente` crudo que sale del parser, sin consultar
`RepositorioAsociaciones` por su cuenta.

### Dónde retomar la spec 003

| Spec 003 · Fase | Estado |
|---|---|
| Foundational (T001–T016) | ✅ `CobroIngreso`, `RepositorioCobrosIngreso`, migración v2→v3, `EstadoMes` recableado |
| US1 · registrar el sueldo en cobros (T017–T023) | ✅ `agregarCobro`, `FormularioCobro`, total correcto en toda la app |
| US2 · ver el detalle (T024–T025) | ✅ lista de cobros en la tarjeta de ingreso |
| US3 · corregir/eliminar un cobro (T026–T030) | ✅ `actualizarCobro`/`eliminarCobro`, respeta cierre de mes |
| Polish (T031–T032, T034) | ✅ pureza, analyze/format, este párrafo |
| T033 [MANUAL] | pendiente — recorrido de [quickstart.md](specs/003-cobros-parciales-ingreso/quickstart.md) en la app corriendo, con especial atención a la migración desde una base con datos reales de 001/002 |

Solo falta la validación manual (T033) para dar la spec 003 por cerrada del todo.

### Dónde retomar la spec 004

| Spec 004 · Fase (tras la revisión del 2026-09-12) | Estado |
|---|---|
| T001–T046 · la suscripción | ⚰️ implementada y **descartada**. Se conservan en `tasks.md` porque explican por qué existió ese código |
| Documentación de la revisión (T047–T052) | ✅ spec, research (D7/D8/D9), data-model, plan, contrato y quickstart reescritos |
| Pruebas primero (T053–T055) | ✅ `todo_gratis_test.dart`, `pantalla_propina_test.dart`, `migracion_005_test.dart` |
| Dominio y datos (T056–T062) | ✅ `OfertaPropina`, `RepositorioPropinas(Billing)`, esquema v5 y respaldo con una tabla menos |
| Interfaz (T063–T067) | ✅ pantalla de apoyo, entrada en Ajustes, y borrado del paywall y de la guarda del cascarón |
| T068, T069 [MANUAL] | pendientes — crear los tres consumibles en Play Console y recorrer `quickstart.md` en un dispositivo |

**Qué cambió y por qué**: cobrar por Deudas, Ahorro y la captura ponía una
barrera a funcionalidad que no tiene costo marginal —corre entera en el
teléfono— a cambio de dos de cinco pestañas cerradas en la primera pantalla.
Ahora la app se reparte completa y el ingreso es una propina que **no
desbloquea nada** (research.md D7).

**Tres cosas fáciles de romper sin querer:**

- **`test/ui/todo_gratis_test.dart` está escrito en negativo**: verifica que
  ninguna condición de acceso exista. Si alguien vuelve a condicionar un
  destino, falla ahí, y esa es su única razón de ser.
- **`EstadoPropinas` no vive en el árbol de providers de `main.dart`**: lo crea
  la ruta que abre la pantalla de apoyo (`seccion_apoyo.dart`) y muere con
  ella. Subirlo al árbol volvería posible que otra pantalla consulte si el
  usuario pagó, que es justo lo que FR-002 prohíbe.
- **Los productos de Play Console tienen que ser consumibles**, no compras
  únicas: de eso depende poder apoyar más de una vez (FR-007).

**Dos bloqueos que se disolvieron con la revisión**: T035 de esta spec (la
guarda de suscripción en el callback headless de la spec 002) ya no existe
porque no hay nada que guardar, y el paso 8 de T042 de la spec 005 (que el
premium no se herede del archivo restaurado) quedó sin objeto.

### Dónde retomar la spec 005

| Spec 005 · Fase | Estado |
|---|---|
| Setup + Foundational (T001–T009) | ✅ `share_plus` y `file_picker` auditados contra el Principio I, `validarRespaldo` puro, `RepositorioRespaldo`, `BaseDatos` sabe reabrirse |
| US1 · exportar un respaldo (T010–T018) | ✅ copia con el WAL consolidado, sin las dos tablas que no viajan, entregada a la hoja de compartir |
| US2 · restaurar (T020–T029) | ✅ inspección sin migrar el candidato, intercambio todo-o-nada, migración de un respaldo v3 probada |
| US3 · no perder datos por error (T031–T037) | ✅ aviso de reemplazo con confirmación aparte, motivo concreto de rechazo, vuelta atrás |
| Polish (T038–T041, T043) | ✅ |
| T019, T030 [MANUAL] | ✅ verificadas en emulador: la hoja de compartir entrega `finanzas-respaldo-AAAA-MM-DD.db`, y tras `adb shell pm clear` el respaldo devuelve los datos idénticos |
| T042 [MANUAL] | ✅ pasos 6 y 7 verificados (confirmación aparte al reemplazar, rechazo de un archivo cualquiera con su motivo). El paso 8 —que el premium no se herede del archivo— quedó **sin objeto** el 2026-09-12: la spec 004 se revisó a propina y ya no existe acceso pagado que heredar |

**Esta feature no toca el esquema**: `Esquema.version` sigue en 4. Es la primera del proyecto que no agrega ni altera tablas — opera sobre el archivo entero, no sobre sus filas.

Dos cosas fáciles de romper sin querer, las dos con prueba propia en `test/datos/respaldo_test.dart`:

- **Lo que no viaja se vacía en la copia, nunca en el original** (D4). Hoy es solo `notificacion_diagnostico`: se borra del archivo exportado, y si alguien invirtiera el orden, exportar le borraría al usuario su diagnóstico. `suscripcion_premium` estaba en esa lista hasta la revisión de la spec 004, que borró la tabla entera en la migración v4 → v5.
- **Los `-wal`/`-shm` viejos se borran al reemplazar** (D3). Un sidecar huérfano junto a un archivo principal distinto es corrupción silenciosa, no un error visible.

Y una consecuencia en `main.dart`: restaurar cierra y reabre la base, así que la conexión anterior queda muerta. El árbol de providers cuelga de una `key` con la conexión viva y se reconstruye entero al restaurar.
