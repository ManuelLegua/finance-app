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
| Empezar con datos limpios | `adb shell pm clear com.example.finanzas` |

`adb` vive en `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`.

## Recorrido de prueba manual

Lo que la suite no puede verificar: si la pantalla se entiende de un vistazo (Principio IV). Los dos defectos de layout que aparecieron hasta ahora — etiquetas más largas que su contenedor — salieron de acá, no de las pruebas.

1. **Presupuesto** → registrar el sueldo y dos o tres obligaciones.
2. **Resumen** → el disponible tiene que leerse sin hacer cuentas. Subí las obligaciones por encima del ingreso: el déficit se comunica con ícono y texto, no solo con color.
3. **Gastos** → anotar uno debe llevar menos de quince segundos (SC-002). Gastá de más en una categoría y mirá la marca de sobregiro.
4. **Tarjetas** (menú lateral) → una de crédito y una de débito. La de débito **no** debe ofrecerse al crear una deuda (FR-061).
5. **Deudas** → 12 cuotas de S/ 150 desde este mes. Tiene que decir "0 de 12 pagadas": la cuota del mes en curso todavía no se pagó (D4).
6. **Resumen** → la categoría tarjeta de crédito se despliega y muestra de qué deuda sale el monto (FR-017).
7. **Editar la deuda** y cambiarle la cuota: el comprometido se recalcula solo, sin reescribir nada. Es D3 funcionando.
8. **Ajustes** → poner los días de gracia en 0 y navegar al mes anterior: queda cerrado de inmediato.

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
| `specs/002-captura-notificaciones-bancarias/` | Spec completa, aún sin plan |
| `specs/003-cobros-parciales-ingreso/` | Ingreso en varios cobros por mes (quincena + fin de mes, etc.); spec completa, aún sin plan |
| `specs/004-suscripcion-premium/` | Suscripción paga (Deudas + Ahorro + captura de notificaciones); spec completa, aún sin plan |

Antes de proponer un cambio de diseño, leer `research.md`: es probable que la alternativa ya se haya evaluado y rechazado por escrito.

## Reglas que no se negocian

1. **El dinero es un `int` de centavos, de punta a punta.** Nunca `double`, nunca `float`. El tipo `Dinero` no tiene constructor desde `double`. El formato `S/ 1,234.56` se produce a mano desde el entero — **no** con `intl.NumberFormat`, que recibe `num` y reintroduciría el punto flotante justo antes de mostrar la cifra. Columnas `INTEGER`, jamás `REAL`. Porcentajes en puntos base (20% = 2000).

2. **`lib/dominio/` y las carpetas puras de `lib/shared/` son Dart puro.** Sin `package:flutter/`, sin `package:sqflite/`, sin `DateTime.now()` adentro (la fecha entra como parámetro). `test/pureza_test.dart` falla si alguien lo viola.

3. **Las pruebas de reglas financieras se escriben ANTES que la implementación**, cubriendo caso normal, límite (saldo exactamente cero) y adverso (déficit). Es requisito de entrada por constitución, no un paso opcional.

4. **Nada sale del dispositivo.** Sin red, sin telemetría, sin cuentas, sin sincronización. Ninguna dependencia puede abrir conexiones. Cualquier funcionalidad que implique salida de datos exige enmendar la constitución primero.

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
- **Identificadores del dominio en español** (`Mes`, `Obligacion`, `Transaccion`, `Deuda`, `AporteAhorro`), igual que la spec, para que no haya salto de vocabulario entre el requisito y el código. Las palabras del framework quedan en inglés.
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

**94 de 108 tareas.** US1 a US5 completas y validadas en emulador; 316 pruebas en verde y `flutter analyze` sin issues.

| Historia | Estado |
|---|---|
| US1 · ingreso y presupuesto | ✅ |
| US2 · resumen y déficit | ✅ |
| US3 · gastos reales | ✅ |
| US4 · deudas en cuotas | ✅ |
| US5 · ahorro (T083–T094) | ✅ |
| US6 · desglose por categoría (T095–T099) | pendiente |
| Polish (T100–T108) | pendiente |

Sigue pendiente, fuera de la spec: **no hay respaldo ni exportación**. Con un solo usuario es asumible; antes de repartir la app a probadores conviene que sea una feature propia.
