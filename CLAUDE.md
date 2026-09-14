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

## Firmar la app para publicar

El `release` se firma con la clave de depuración **mientras no exista
`android/key.properties`**. Eso sirve para instalar y probar, y Play Store lo
rechaza — que es el comportamiento buscado: el build no se rompe en una máquina
recién clonada, pero tampoco deja publicar por accidente algo mal firmado.

**La keystore se genera una sola vez.** No está en el repo ni puede estarlo
(`android/.gitignore` excluye `key.properties`, `*.jks` y `*.keystore`):

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
& "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v `
  -keystore C:\Users\manue\llaves\finanzas-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias finanzas
```

Después se copia `android/key.properties.ejemplo` a `android/key.properties` y
se completan las cuatro líneas. Con eso, `flutter build apk --release` y
`flutter build appbundle` firman solos.

**Perder la keystore es perder la app.** Google no deja cambiar la clave de
firma de una app ya publicada salvo por un trámite de recuperación que no
siempre prospera: sin ese archivo no se puede volver a publicar una
actualización, nunca. Hay que guardarla fuera del repo **y** tener una copia en
otro lado. Lo mismo vale para las contraseñas.

Para Play Store el formato es `appbundle` (`.aab`), no `apk`. El APK sigue
sirviendo para instalar a mano y para los probadores que no pasan por la
tienda.

## Política de privacidad

Vive en [docs/politica-de-privacidad.md](docs/politica-de-privacidad.md).
Google Play exige una URL pública para publicar cualquier app, y con más razón
para una que pide acceso a notificaciones.

**La política describe el comportamiento previsto, y hay una condición que hay
que cumplir antes de publicar**: el instrumento temporal de volcado
(`lib/dominio/interpretes/volcado_notificacion.dart` y el cuerpo de
`callback_headless.dart`) escribe el texto de las notificaciones de Gmail al
log del dispositivo y a un archivo local. Eso **contradice** lo que la política
promete sobre no guardar el contenido de las notificaciones. **T067 de la spec
002 tiene que estar cerrada antes de subir nada a Play.**

Dos cosas más antes de publicarla:

- Completar el correo de contacto, que está como marcador de posición.
- Cualquier salida de datos nueva se documenta acá **antes** de publicar la
  versión que la introduce, no después. Es la misma regla que el Principio I
  aplica a la constitución.

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
| `specs/006-moneda-extranjera/` | **Draft, bloqueada.** Aceptar montos en dólares sin abandonar el sol como moneda de cuenta: la conversión ocurre una vez, con un tipo de cambio que informa el usuario, y el importe original viaja como dato adjunto. Ninguno de los 8 archivos de `lib/dominio/calculos/` cambia. Necesita una **enmienda v4.0.0** al Principio II —que hoy dice "la moneda es siempre el sol peruano"— y quedan dos `[NEEDS CLARIFICATION]` de alcance (FR-029, FR-030) |
| `specs/007-ciclo-facturacion-tarjeta/` | **Draft, con 2 `[NEEDS CLARIFICATION]`.** Cada tarjeta de crédito guarda día de cierre, día de vencimiento y pago mínimo; un consumo pesa en el mes del estado de cuenta donde cae, no en el de la compra. **Hallazgo que agranda la feature**: hoy `Transaccion` no guarda con qué tarjeta se pagó —solo `Deuda` apunta a una— así que hay migración de esquema, no tres campos sueltos. El mes se deriva, nunca se persiste (misma regla que D3 y D13) |

Antes de proponer un cambio de diseño, leer `research.md`: es probable que la alternativa ya se haya evaluado y rechazado por escrito.

## Reglas que no se negocian

1. **El dinero es un `int` de centavos, de punta a punta.** Nunca `double`, nunca `float`. El tipo `Dinero` no tiene constructor desde `double`. El formato `S/ 1,234.56` se produce a mano desde el entero — **no** con `intl.NumberFormat`, que recibe `num` y reintroduciría el punto flotante justo antes de mostrar la cifra. Columnas `INTEGER`, jamás `REAL`. Porcentajes en puntos base (20% = 2000).

2. **`lib/dominio/` y las carpetas puras de `lib/shared/` son Dart puro.** Sin `package:flutter/`, sin `package:sqflite/`, sin `DateTime.now()` adentro (la fecha entra como parámetro). `test/pureza_test.dart` falla si alguien lo viola.

3. **Las pruebas de reglas financieras se escriben ANTES que la implementación**, cubriendo caso normal, límite (saldo exactamente cero) y adverso (déficit). Es requisito de entrada por constitución, no un paso opcional.

4. **Nada sale del dispositivo por su cuenta.** Incluida la copia automática
   de Android: `android:allowBackup="false"` más
   `reglas_extraccion_datos.xml` apagan la subida a Google Drive y la
   transferencia entre dispositivos. Sin eso —y así estuvo hasta el
   2026-09-13— Android sube el almacenamiento privado de la app, **con la base
   SQLite entera**, y la promesa de esta regla sería falsa sin que nadie la
   hubiera roto en el código. Sin red, sin telemetría, sin cuentas, sin sincronización. Ninguna dependencia puede abrir conexiones. Hay exactamente dos excepciones, las dos enmiendas a la constitución y las dos acotadas por escrito: Google Play Billing (v2.0.0) y el **respaldo a pedido del usuario** (v3.0.0) — que genera un archivo y se lo entrega a la hoja de compartir del sistema, nunca a un servidor propio, y nunca sin que el usuario lo pida en ese momento. No hay respaldo automático ni programado. Cualquier otra salida de datos exige enmendar la constitución primero.

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
**Spec 006 escrita y bloqueada** — aceptar montos en dólares sin abandonar el sol como moneda de cuenta. No hay código ni lo va a haber hasta que se apruebe la enmienda v4.0.0 al Principio II y se cierren los dos `[NEEDS CLARIFICATION]` de alcance (FR-029, FR-030).
**565 pruebas, todas en verde (2026-09-14).** Subieron de 525 con el tramo del parser de la spec 002 (T038/T038a, T039, T041a, T042, T064b) y los dos bugs que encontró el recorrido manual (T055a, T061a). Habían bajado de 552 porque la revisión de la spec 004 borró las cinco suites de la suscripción y sumó las de la propina; la que dependía del reloj real (`pantalla_ahorro_test.dart`, FR-042) se arregló en `3b31be7`.
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
| US2 · parser genérico (T034–T043) | ✅ **completo**. La captura anda de punta a punta: filtro, parser, callback y arranque del servicio |
| US3 · categorización aprendida (T044–T051) | ✅ normalizador de comercio, `RepositorioAsociaciones`, propuesta y aprendizaje en `EstadoPendientes`, pantalla "Comercios" |
| US4 · consumos en cuotas (T052–T055) | ✅ `EstadoPendientes.confirmar(comoDeuda:)`, interruptor "fue una compra en cuotas" en el formulario (oculto sin tarjetas de crédito) |
| Polish (T056–T058, T043a, T064a, T064b hechas; T062 al cierre) | ⚠️ **T060/T061 recorridos en parte el 2026-09-14** — ver "Dónde retomar el recorrido manual" más abajo |

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
mismo monto que la deduplicación de D-N5 no relaciona.

Esa decisión de alcance **ya se tomó** — ver "D-N12, cerrada" más abajo. De las
tres salidas evaluadas (activar alertas push en la app del banco; reconocer
Gmail como origen y filtrar por remitente; o aceptar que la feature no se
sostiene) quedó la segunda: la primera no existe como ajuste en este teléfono y
la tercera dejó de estar justificada al verificarse que la vía de Gmail entrega
el consumo entero.

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

### Resultado del 2026-09-13, más tarde: el consumo con tarjeta, capturado

**T066 cerrada.** A las 10:54 llegó un consumo real con Tarjeta de Crédito
BCP, por correo y vía Gmail como los anteriores, y está transcrito como G4 en
[notificacion-gmail-capturada.md](test/dominio/interpretes/fixtures/notificacion-gmail-capturada.md).
Con esto **D-N12 ya se puede decidir**: la vía de Gmail entrega el consumo
entero, con comercio, monto, fecha, últimos cuatro dígitos de la tarjeta y
número de operación, todo dentro de los primeros 511 caracteres de los 1024
que Android deja pasar.

Cinco cosas que cambian lo que hay que escribir en el parser:

1. **La regla de descarte del punto 2 de arriba es falsa.** Gmail publicó dos
   notificaciones para este correo, y la del resumen de grupo (`id: 0`) traía
   **el mismo `bigText` completo y sin `textLines`** — porque resumía un solo
   correo sin leer. `bigText == null && textLines != null` no las distingue y
   el consumo se contaría dos veces. Lo que sí las distingue es
   `evento.isGroup`, campo tipado del plugin.
2. **El comercio viene dos veces**: bajo la etiqueta `Empresa` y dentro de la
   frase de apertura. `ANTHROPIC* CLAUDE SUB` — el asterisco es parte del
   nombre que manda el adquirente, y el normalizador de comercio (T040) no
   debe partirlo ahí.
3. **Hay un `Número de operación`**, mejor clave de deduplicación (D-N5) que
   monto+fecha.
4. **El BCP escribe `setiembre` y `septiembre`** indistintamente, el mismo día
   y desde el mismo remitente.
5. **El pie del correo envenena las palabras clave de D-N11.** El boilerplate
   fijo del BCP dice "¿Problemas con tus **compras**? Si tu compra fue
   **rechazada**…" y "…tu **tarjeta de débito o crédito**…". Un clasificador
   que lea el `bigText` entero encuentra señales contradictorias y, por la
   propia regla de D-N11, mandaría a diagnóstico un consumo que es inequívoco
   en sus primeros 200 caracteres. El parser tiene que acotar lo que lee:
   hasta el primer renglón que empiece con `¿`, que en los dos correos del BCP
   separa la operación del pie.

**Lo que falta**: el consumo capturado vino **en dólares** (`$ 23.60`), que es
justo el caso que FR-014 manda rechazar como `NoInterpretable(monedaExtranjera)`
—la regla 5 del proyecto no admite multimoneda y D14 rechazó traer tipos de
cambio—. Así que cierra ese camino de T038 y deja abierto el feliz: **falta un
consumo con tarjeta en soles** para terminar de cerrar T034. Hasta entonces el
instrumento de volcado sigue en pie y **T067 no se puede cerrar**, que es el
requisito que falta para publicar en Play.

### D-N12 cerrada (2026-09-13): el consumo entra por correo

Con G4 en la mano, la decisión de alcance que el hallazgo del 2026-09-12 dejó
planteada **ya está tomada y escrita** en `research.md`, `spec.md` y
`tasks.md`. Lo esencial:

- **Un origen reconocido deja de ser necesariamente una app.** El filtro pasa a
  tener dos modos —paquete de Android **o** remitente (el `title` del aviso de
  Gmail)—, porque para todo correo el paquete es `com.google.android.gm` y no
  distingue el banco de nada. Enmienda el mecanismo de D-N10, no su fundamento.
- **La raya de privacidad quedó escrita como requisito, FR-008c.** Reconocer
  Gmail implica que la app recibe la notificación de *todo* correo del teléfono.
  Lo que no calce con un remitente reconocido se descarta **antes de leer el
  cuerpo** y no deja rastro: ni pendiente, ni diagnóstico, ni log. No hace falta
  enmendar la constitución —nada sale del dispositivo— pero sí dejarlo atado.
- **`OrigenReconocido` no puede expresar esto todavía**: hoy solo tiene
  `paquete`. Es T041a, tarea nueva.
- **T038a es nueva y ya está escrita**: todo lo que los fixtures existentes
  cubren (entrante, moneda extranjera, el recorte del pie) sin esperar el
  consumo en soles.

**Lo que sigue bloqueado es solo el camino feliz de T038**, que necesita ese
fixture. La decisión ya no bloquea nada.

**Estado tras T038a/T041a (2026-09-13).** T041a está hecha y en verde. T038a
está escrita y **en rojo a propósito**: `interpretar()` es un stub que lanza
`UnimplementedError` y T039 la implementa hasta que esas 8 pruebas pasen. Es el
rojo que pide la regla 3, no un descuido — `flutter test` va a quedar rojo hasta
que se escriba T039, que ya no está bloqueada por nada.

Tres cosas de ese tramo fáciles de romper sin querer:

- **`filtrarNotificacion` no recibe el cuerpo de la notificación, y es a
  propósito.** Es lo que hace que FR-008c sea una propiedad de la forma del
  código y no una disciplina: quien decide si una notificación se procesa no
  puede leer un correo personal ni queriendo. Agregarle el texto como parámetro
  anularía la garantía sin romper ninguna prueba.
- **El título se compara exacto, nunca con `contains`.** Un `contains` haría que
  un correo de alguien llamado "BCP" calce como banco. Fallar por defecto
  —capturar de menos— es la forma segura de fallar acá.
- **`fixtures/textos_capturados.dart` se genera desde el `.md`, no se edita.**
  D-N9 prohíbe construir el parser contra texto inventado, y esa prohibición no
  vale nada si el texto se re-teclea al pasarlo a Dart.

**Aclaración del 2026-09-13 (D-N15, FR-008d): un envío de dinero es un consumo.**
Un yapeo enviado, una transferencia o un pago de servicios bajan el saldo igual
que una compra con tarjeta, así que se capturan igual. Las palabras clave de
D-N11 se habían escrito pensando solo en tarjetas y mandaban a diagnóstico un
gasto perfectamente legible. Dos consecuencias:

- **El campo `comercio` se llena con el destinatario** cuando no hay comercio.
  No se renombró: tocaría esquema, repositorios y UI para ganar vocabulario, y
  la categorización aprendida funciona igual con una persona que con una tienda.
- **Un traspaso entre cuentas propias se va a proponer como gasto.** G2 y G3 del
  fixture son exactamente eso. No se puede distinguir del texto —la app no
  conoce el nombre ni las cuentas del usuario— y lo atrapa la confirmación de
  FR-020. Hay una prueba que lo fija: si algún día devuelve `NoEsConsumo`,
  alguien intentó adivinar lo que no se puede saber.

### T034 cerrada la noche del 2026-09-13: dos consumos en soles

Llegaron por correo vía Gmail, de **Sip**, con tarjeta de crédito: `S/. 37.70`
en `IKF 982 PV VENTANILLA` y `S/. 15.90` en `231 PVEA VENTANILLA`. Están como
G5 y G6 en el fixture, leídos con `adb logcat` y **no transcritos**: los dos
cuerpos miden exactamente lo que el volcado declaró (667 y 665), así que no les
falta nada.

**Cuatro cosas que desmienten lo que se había decidido con los correos del BCP**,
y que ningún texto inventado —ni un segundo correo del mismo banco— habría
mostrado:

1. **Un emisor usa más de un nombre de remitente.** Sip firma `Operaciones Sip`
   un envío de dinero y **`Sip`, tres caracteres**, un consumo con tarjeta. La
   lista que había sembrado T041a tenía solo el primero, así que **estos dos
   consumos se descartaban por origen no reconocido**. `OrigenReconocido` pasó
   de `remitente` a `remitentes`, un conjunto.
2. **El sol se escribe `S/.` con punto.** El BCP escribe `S/ 23.60`; Sip,
   `S/. 37.70`. La expresión regular de ejemplo de D-N3 —`S/\s*(...)`— no
   reconoce la segunda.
3. **La regla de acotar el pie en el primer `¿` no generaliza.** Era una
   particularidad del BCP: el `bigText` de Sip **no contiene un solo `¿`**, su
   pie arranca con "Si no reconoces la operación". Está corregido en D-N12, con
   la salida que asoma anotada pero sin fijar: clasificar la dirección por el
   **asunto** del correo, que es corto y no tiene pie, y usar el cuerpo solo
   para extraer los datos.
4. **Las etiquetas difieren**: `Monto:` y `Establecimiento:` con dos puntos en
   Sip, `Monto` y `Empresa` sin ellos en el BCP. Lo único constante es que el
   valor va en el renglón siguiente.

El punto 3 es la moraleja de D-N9 en acción: una regla deducida de un solo banco
se lee como general y no lo es.

**Nota de operación**: el build instalado en el teléfono es de **release**, así
que `run-as` no puede leer el archivo del volcado (`package not debuggable`) y
`adb logcat` fue la única vía. Sigue siendo el build anterior a `5fa0148`, por
lo que cada línea aparece dos veces en el log.


### T039: el parser genérico, escrito y en verde (2026-09-13)

`lib/dominio/interpretes/interprete.dart`. Tres decisiones que no son obvias
leyendo el código y que conviene no deshacer sin entender:

- **La dirección se clasifica primero por el asunto**, la primera línea del
  correo, y solo si eso no alcanza se mira el cuerpo. El asunto dice la
  operación en pocas palabras y sin nada alrededor que la contradiga; el cuerpo
  está lleno de etiquetas que **parecen** señales y no lo son. `Operación
  realizada` encabeza tanto un yapeo recibido como uno enviado, y `Enviado por`
  —me lo mandaron— se parece muchísimo a `Enviado a`, que es lo contrario.
  Preguntarle al asunto primero esquiva todas esas trampas de una vez.
- **El pie se recorta con una lista de aperturas observadas, no con el `¿`.**
  Ver el punto 3 de D-N12 y por qué esa regla, escrita a la tarde, era falsa
  para la noche.
- **El monto acepta `S/` y `S/.`**, porque el BCP escribe uno y Sip el otro.
  Hay una prueba dedicada a que no se vuelva a escribir la expresión sin el
  punto opcional.

**El comercio sale crudo del parser**; normalizarlo es tarea de
`EstadoPendientes` al buscar y aprender la asociación, que es donde ya estaba.

**Un hueco verificado y anotado como T040a**: `normalizarComercio` recorta el
código numérico solo al **final**, y los comercios reales lo traen al principio
o en el medio (`231 PVEA VENTANILLA`, `IKF 982 PV VENTANILLA`). Dos sucursales
de la misma cadena normalizan distinto y FR-032 termina aprendiendo una
categoría por sucursal. No se arregló acá porque no es gratis: recortar un
número inicial rompería un comercio que legítimamente empiece con dígitos.


### La captura, cerrada de punta a punta (2026-09-13, noche)

**T067, T042, T041 y T043.** El tramo notificación → pendiente, que estuvo
abierto desde que se registró el callback, ya existe.

- **T067**: borrado el instrumento de volcado. La app dejó de escribir texto de
  notificaciones al log y al archivo local, que era lo único que contradecía la
  política de privacidad — y el último requisito que faltaba para publicar.
- **T042**: la decisión vive en `lib/dominio/interpretes/decision_captura.dart`,
  Dart puro y con 11 pruebas; el callback quedó como pegamento que solo
  persiste lo que esa función resuelve. **Si aparece un `if` con una regla de
  negocio en el callback, está en el lugar equivocado.** Dos cosas que no son
  obvias: llama a `DartPluginRegistrant.ensureInitialized()` —sin eso `sqflite`
  no tiene canal en el isolate headless y abrir la base falla— y abre y cierra
  su propia conexión, porque el isolate puede quedar vivo entre notificaciones
  y sostener una conexión contra la misma base que usa la app es pedir un
  bloqueo.
- **T041**: los paquetes salieron de `adb shell pm list packages`, mucho más
  simple que provocar una notificación por app. Verificados los cuatro que hay
  instalados. **Sip es la Tarjeta Oh! renombrada** —por eso el paquete dice
  `tarjetaoh` y los correos firman `Sip`— y la app de Falabella es la del
  banco, no la de la tienda; las dos cosas confirmadas con el usuario, no
  deducidas.
- **T043**: ya estaba satisfecho. `activar()` arranca en foreground con
  notificación discreta, el manifiesto declara `foregroundServiceType`
  `specialUse` con la `property` que Android 14+ exige, y el receptor de
  arranque cubre `BOOT_COMPLETED`, `LOCKED_BOOT_COMPLETED`,
  `QUICKBOOT_POWERON` y `REBOOT`.

**Lo que faltaba de D-N4 y no tenía tarea era T043a**, la exención de
optimización de batería — **hecha el 2026-09-14**, ver su sección más abajo.

**Lo que la captura hace hoy, y lo que no.** Un consumo con tarjeta que llegue
por correo de un origen reconocido se interpreta y aparece en la bandeja. No
hay ninguna ruta que registre un gasto sin que el usuario lo confirme (FR-020),
y de un correo ajeno no queda rastro de ningún tipo (FR-008c). Falta el
recorrido en dispositivo real: T060 y T061.


### La captura verificada en dispositivo (2026-09-13, 23:01)

**Funciona de punta a punta.** Un yapeo enviado de S/ 1.00 en un Honor CRT-LX3
con Android 14 produjo exactamente esto en la base:

```
consumo_pendiente      S/ 1.00 · "Manuel Alexander Legua Mendoza" · 2026-09-13
                       origen com.google.android.gm · categoria_propuesta NULL
notificacion_diagnostico  formato_no_reconocido · aviso informativo de Yape
```

Lo que eso prueba, y que hasta acá era todo suposición:

- **El isolate headless abre y escribe la base.** Era el único tramo escrito
  sin poder ejecutarlo, y el que fallaba en silencio si `sqflite` no quedaba
  registrado.
- **Una sola fila, no dos**: el descarte por `isGroup` funciona con un correo
  real, no solo con el fixture.
- **El correo entrante del BCP no dejó rastro** — ni pendiente ni diagnóstico.
- `categoria_propuesta` llega en `NULL`, que es lo correcto: la resuelve
  `EstadoPendientes` al cargar.

### El bug que esa prueba destapó, y cómo se arregló (T064a)

**El ciclo Desactivar → Activar deja la captura muerta, sin ningún síntoma.**
Reproducido con hora exacta: a las 22:52 llegaban eventos, a las 22:54 se hizo
el ciclo, y a las 22:56 el yapeo no generó ni uno — con el permiso concedido,
el componente habilitado y el servicio corriendo en foreground.

La causa está en el plugin: al arrancar hace `disable` + `enable` del
componente con el comentario *"and try to toggle the service to trigger
rebind"*, pero **nunca llama a `NotificationListenerService.requestRebind()`**,
que es la única API con la que Android vuelve a vincular un listener cuyo
componente se deshabilitó.

**T064 había arreglado solo la mitad**: el camino que pasa por la pantalla de
ajustes de Android funciona porque el interruptor lo toca el usuario, y eso sí
fuerza el rebind. El camino que la app ofrece —su propio interruptor— estaba
roto.

**Arreglado en T064a, y el arreglo es por omisión**: `desactivar()` dejó de
llamar al `stopService` del plugin y usa `requestUnbind` en su lugar, con
`requestRebind` al activar. Verificado en dispositivo: tras tres ciclos de
Desactivar → Activar, cuatro notificaciones de prueba llegaron las cuatro, y el
componente nunca quedó deshabilitado.

**Dos cosas que costaron y conviene no volver a descubrir:**

- **`requestRebind` por sí solo no sirve, y se probó.** Android lo rechaza para
  listeners que no se soltaron con `requestUnbind` — su documentación dice
  *"after a previous call to requestUnbind()"*. Los dos van juntos o no van.
- **No hizo falta forkear el plugin.** Publica su servicio como estática
  pública (`NotificationsHandlerService.instance`), así que se puede llamar
  `requestUnbind()` sobre él desde un `MethodChannel` propio. `MainActivity.kt`
  es el único código nativo del proyecto y existe solo para esto.

**Si alguna vez hay que forzar el rebind a mano** (por ejemplo con un build
viejo instalado):

```powershell
$comp = "io.github.manuellegua.finanzas/im.zoe.labs.flutter_notification_listener.NotificationsHandlerService"
& $adb shell cmd notification disallow_listener $comp
& $adb shell cmd notification allow_listener $comp
```

### D-N16, que salió de la misma prueba (T064b, resuelta)

El aviso recurrente de Yape ("Por tu seguridad, te notificaremos por cada yapeo
que realices") venía de un remitente reconocido, **no trae monto** y por eso
caía en `formatoNoReconocido`, generando una fila de diagnóstico cada vez que
el usuario yapea.

**La regla ahora: sin ninguna cifra de dinero en el texto, no hubo movimiento**
— se resuelve como `NoEsConsumo` y no deja rastro. Es la primera pregunta del
parser, antes de clasificar la dirección.

Estaba mal por partida doble: afirmaba algo falso —el formato se entendió
perfectamente, no había nada que reconocer— y rompía el registro que existe
para encontrar consumos mal interpretados. Un diagnóstico lleno de filas
rutinarias se deja de mirar, y entonces los fallos de verdad no los ve nadie.

**Por qué el monto y no otra señal**: es la única condición *necesaria* de un
consumo. Un movimiento puede no decir el comercio ni la fecha, y puede redactar
la dirección de mil formas, pero si baja el saldo dice cuánto.

**Tres cosas fáciles de romper sin querer:**

- **La contracara también está probada**: con una cifra y sin dirección clara,
  **sí** va a diagnóstico. Si hay dinero en el texto hubo un movimiento, y no
  haber podido clasificarlo es justo lo que hay que registrar.
- **No se agregó un tipo nuevo de resultado.** El contrato ya cubría el caso
  ("una promoción, etc." en `NoEsConsumo`) y nadie ramificaría por uno nuevo:
  ni el callback ni la interfaz tratan distinto un entrante de una promoción.
- **El riesgo asumido está escrito**: un consumo cuyo monto quede más allá del
  corte de 1024 caracteres se silenciaría en vez de ir a diagnóstico. Se acepta
  porque ese diagnóstico tampoco permitiría entender nada, y porque el ruido
  degrada el registro todos los días mientras ese caso es hipotético.


### La exención de batería, sin permiso restringido (T043a)

D-N4 pedía que la activación ofreciera excluir la app de la optimización de
batería, y nada lo hacía. Lo que frenaba era la sospecha de que hiciera falta
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, un permiso que Google Play limita a
casos de uso acotados — mal momento para sumarlo, en una app que además lee
notificaciones y está por publicarse.

**La tensión se disolvió: Android ofrece dos caminos y solo uno exige el
permiso.**

| | Diálogo directo | Lista del sistema *(elegido)* |
|---|---|---|
| Intent | `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` |
| Permiso | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | **ninguno** |
| Para el usuario | un toque | busca la app en una lista |

**El manifiesto no cambió.** Consultar si la app ya está exenta
(`isIgnoringBatteryOptimizations`) tampoco exige permiso, así que el aviso sabe
cuándo no molestar.

**Dos cosas de diseño fáciles de deshacer sin querer:**

- **El aviso no es un `SituacionCaptura`.** La captura funciona sin la
  exención; lo que cambia es cuánto aguanta con el teléfono quieto. Meterlo en
  el enum haría que la pantalla dijera "no funciona" cuando sí funciona.
- **Aparece solo con la captura ya funcionando.** Antes de eso no hay servicio
  al que matar, y sumar un permiso a la pantalla donde el usuario todavía está
  decidiendo si quiere la feature solo la vuelve más difícil de aceptar.


### El primer bug que encontró el recorrido manual (T055a)

Preparando T061 apareció algo que ninguna prueba veía: **el interruptor "fue
una compra en cuotas" no aparecía en un arranque limpio de la app**, y con él
US4 entera quedaba inalcanzable sin ninguna señal de que faltara algo — el
usuario concluiría que la app no sabe registrar compras en cuotas.

`PantallaPendientes` leía `EstadoTarjetas` con `context.read` al abrir el
diálogo, pero **ese provider es lazy y su `cargar()` es asíncrono**: si esa
pantalla era la primera en pedir las tarjetas —abrir la app y tocar Pendientes,
sin pasar por Tarjetas ni Deudas— la lista todavía estaba vacía, y el formulario
oculta el interruptor cuando no hay tarjetas de crédito. Visitar Tarjetas antes
lo hacía aparecer, que es lo que lo volvía tan fácil de no ver.

**Por qué la suite no lo atrapaba**: `pantalla_pendientes_test.dart` cargaba las
tarjetas en su `setUp`. La prueba estaba escrita sobre la condición que el bug
rompe, así que no podía fallar. La prueba nueva monta el estado **sin** cargar.

Es exactamente el tipo de defecto que el recorrido manual existe para
encontrar, y el primero que sale de mirar la pantalla y no la base. El
segundo fue T061a — ver "Dónde retomar el recorrido manual".

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
reinstalación hay que volver a conceder el permiso de notificaciones.
~~**y** hacer el ciclo Desactivar → Activar~~ — eso último llegó a ser
**dañino** hasta el 2026-09-13, porque el ciclo dejaba la captura muerta; con
T064a arreglado ya no rompe nada, pero sigue sin hacer falta.

**Nota para cuando se retome T042**: la propuesta de categoría de US3 (FR-030)
ya no necesita resolverse ahí. `EstadoPendientes.cargar()` le busca la
asociación aprendida a cualquier pendiente que llegue sin `categoriaPropuesta`
(`lib/ui/estado/estado_pendientes.dart`), sea que lo haya escrito el callback
headless real o un doble de prueba — así que T042 solo necesita escribir el
`ConsumoPendiente` crudo que sale del parser, sin consultar
`RepositorioAsociaciones` por su cuenta.

### Dónde retomar el recorrido manual (2026-09-14)

Seis de los nueve pasos del [quickstart](specs/002-captura-notificaciones-bancarias/quickstart.md)
quedaron recorridos en un Honor CRT-LX3 con Android 14, conduciendo el teléfono
por `adb` (capturas de pantalla con `exec-out screencap`, toques con `input
tap`, y la base leída con `exec-out run-as ... cat`). **Encontró dos bugs que
ninguna prueba veía**, los dos ya arreglados: T055a y T061a.

| Paso | | Qué quedó probado |
|---|---|---|
| 3 | ✅ | El pendiente aparece con monto, comercio y fecha; el total suma bien |
| 4 | ✅ | Confirmar pide categoría por comercio nuevo (FR-033), crea la transacción con la **fecha del consumo** y aprende la asociación |
| 5 | ✅ | El segundo consumo del mismo comercio llega con la categoría ya propuesta |
| 6 | ⚠️ | **La mitad**: al revocar, la app avisa bien. Que se reanude al reconceder no se pudo verificar — ver T061b |
| 7 | ⛔ | Modo avión, sin recorrer — ver T061c |
| 8 | ✅ | **Tras reiniciar el teléfono y sin abrir la app, el consumo se capturó igual**: el servicio vuelve solo por `BOOT_COMPLETED` (D-N4, FR-011) |
| 9 | ✅ | Un texto con monto y sin dirección clara va a diagnóstico, nunca a pendiente con datos inventados |

**Y FR-008c verificado en un teléfono real**, que era la promesa más fuerte de la
feature: un mensaje personal con `S/ 300.00` adentro **no dejó rastro de ningún
tipo** — ni pendiente, ni diagnóstico.

#### El bug grave que salió de acá: T061a

**Capturar un consumo con la app abierta dejaba la base inutilizable para la
interfaz.** La bandeja mostraba "Nada esperando confirmación" con las filas
presentes en el archivo, y no se recuperaba hasta reiniciar la app.

La causa era el `cerrar()` del callback headless, introducido en T042:
**`sqflite` comparte el handle nativo por ruta entre isolates del mismo
proceso**, así que cerrar desde el isolate de fondo le cierra la conexión a la
interfaz. El comentario que justificaba ese cierre —"sostener una conexión
abierta en segundo plano es pedir un bloqueo"— estaba exactamente al revés, y
el comentario nuevo lo dice para que nadie lo reintroduzca.

**Lo que costó fue atribuirlo, no arreglarlo.** El Resumen seguía mostrando
cifras correctas y eso parecía descartar la hipótesis — pero venían de memoria:
la transacción la había escrito la propia interfaz al confirmar. Lo que lo
destrabó fue comprobar que **reiniciar la app devolvía los pendientes
intactos**, o sea que el dato nunca estuvo en riesgo, solo la conexión.

#### Cómo conducir el teléfono desde acá, que cuesta acertar

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb connect <IP>:<puerto>          # la depuración inalámbrica se apaga al reiniciar
& $adb -s <serie> exec-out screencap -p > captura.png
& $adb -s <serie> shell input tap <x> <y>
& $adb -s <serie> exec-out run-as io.github.manuellegua.finanzas cat databases/finanzas.db > db.db
```

Cuatro cosas que hicieron perder tiempo y no son obvias:

- **`exec-out`, nunca `shell ... cat`**, para sacar binarios: `shell` traduce
  saltos de línea y corrompe el archivo (la base salía con 84 bytes de más).
- **Una captura de pantalla justo después de un toque sale a destiempo**: se ve
  el cuadro de la animación, no el resultado. Hay que pedirla en una llamada
  aparte, y aun así el primer intento puede mostrar la pantalla anterior.
- **`screencap` devolviendo 0 bytes no es el teléfono**: es la conexión
  inalámbrica degradándose. Se arregla reconectando, no reiniciando.
- **Git Bash convierte `/sdcard/...` en una ruta de Windows.** Anteponer
  `MSYS_NO_PATHCONV=1` cuando haga falta una ruta del dispositivo.

#### En qué estado quedó el teléfono

- **La captura quedó sin vincular**, por haber revocado y reconcedido el permiso
  por `adb`. Se repara con **Captura → Desactivar → Activar** en la app, que es
  lo que arregló T064a.
- Quedaron **5 pendientes de prueba** en la bandeja (`PRUEBA CON APP ABIERTA`,
  `PRUEBA TRAS REINICIO`, `SUPERMERCADO EJEMPLO`, el yapeo real de S/ 1.00 y
  uno más) y **dos filas en el diagnóstico**. Se descartan desde la app.
- Hay varias notificaciones de prueba en la barra, publicadas con
  `cmd notification post`.

#### Lo que queda abierto de la spec 002

Todo el código está escrito. Lo que falta es verificación y una decisión:

- **T061b** — que la captura **se reanude** tras reconceder el permiso. La
  primera mitad del paso 6 quedó probada; esta no. Reconcedido por `adb`, con
  el servicio corriendo, el proceso vivo, el permiso concedido y ningún
  componente deshabilitado, no volvió a llegar nada. **Puede ser un artefacto
  de conceder por `adb`**, que no es el camino del usuario: hay que repetirlo
  tocando el interruptor en la pantalla de Android. Si tampoco revincula, la
  app le está prometiendo algo que no ocurre ("la captura dejó de funcionar
  hasta que lo concedas de nuevo"), y es la misma familia que D-N13.2.
- **T061c** — el paso 7, modo avión. **No lo puede hacer un agente conectado
  por depuración inalámbrica**: activarlo corta el Wi-Fi y con él la propia
  conexión de `adb`. Queda para el usuario, o para una sesión por cable.
- **T040a** — el hueco del normalizador con códigos de tienda. No urge: mejora
  sola a medida que aparezcan más ejemplos reales.
- **T062** — actualizar este archivo al cerrar la spec.

Con T067 hecha, **no queda nada que impida publicar** salvo la decisión sobre
T061b.

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
