# finanzas

App Flutter de finanzas personales, individual y sin conexión, para administrar un
sueldo mensual en soles peruanos: presupuesto, gastos reales, deudas de tarjeta en
cuotas y ahorro.

## Puesta en marcha

Requiere el SDK de Flutter 3.47.1 (Dart 3.13.1). Si no está en el `PATH` de la sesión:

```powershell
$env:PATH = "C:\Users\manue\dev\flutter\bin;$env:PATH"
```

```bash
flutter pub get      # instala las dependencias
flutter analyze      # análisis estático — debe quedar sin issues
flutter test         # 335 pruebas, corren en Windows sin emulador
flutter run          # levanta la app en un dispositivo o emulador conectado
```

Las pruebas usan `sqflite_common_ffi` para correr contra SQLite real sin necesitar un
emulador Android. Solo la validación manual del recorrido completo (ver más abajo)
necesita un dispositivo o emulador de verdad.

## Montar el emulador desde cero

En una máquina nueva hay que instalar el SDK de Android y el emulador (~2 GB). Los
pasos completos — incluida la aceleración por hardware en CPU AMD e Intel y los
tropiezos conocidos del emulador — están documentados en
[`CLAUDE.md`](./CLAUDE.md#correr-la-app-en-un-emulador).

## Recorrido de prueba manual

Lo que la suite automática no puede verificar es si la pantalla se entiende de un
vistazo. El recorrido paso a paso — presupuesto, resumen, gastos, tarjetas, deudas,
ahorro y ajustes — está en [`CLAUDE.md`](./CLAUDE.md#recorrido-de-prueba-manual).

## Cómo se trabaja acá

Desarrollo dirigido por especificación con Spec Kit: ninguna funcionalidad se
implementa antes de estar descrita en `specs/` y aprobada. El estado del proyecto, los
principios de la constitución y las convenciones de código están documentados en
[`CLAUDE.md`](./CLAUDE.md).
