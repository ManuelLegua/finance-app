# Quickstart — Validar la feature 002

**Feature**: 002-captura-notificaciones-bancarias | **Fecha**: 2026-08-30

Guía para comprobar que la captura hace lo que dice la spec. Requiere un **dispositivo Android real** (o emulador) — es exclusiva de Android (FR-007) y `flutter test` no puede levantar `NotificationListenerService`. No contiene código de implementación: eso pertenece a `tasks.md`.

---

## Requisitos previos

Los mismos que 001 (`CLAUDE.md` § Entorno), más:

- Un dispositivo o emulador Android con `adb` disponible en el `PATH` (`$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`).
- Para validar con notificaciones reales: al menos 2-3 apps bancarias o de billetera distintas instaladas y con sesión iniciada (mientras más variadas — un banco tradicional, una billetera, un emisor de tarjeta — mejor valida el parser genérico). No es indispensable para la primera validación (ver "Notificación simulada" abajo), pero **sí** es indispensable antes de dar por bueno el reconocimiento (D-N9 de research.md) — un parser que solo pasó contra una notificación simulada no está validado.

---

## Puesta en marcha

```powershell
flutter pub get
flutter analyze
flutter test              # dominio, datos y UI de esta feature corren igual que 001, sin Android
flutter run
```

---

## Notificación simulada (sin depender de un consumo real)

Para probar el camino completo (servicio de escucha → intérprete → pendiente → confirmación) sin esperar un consumo real, `adb` puede publicar una notificación que la app reconozca.

**El `packageName` no se puede falsificar**: todo lo que publica `adb` sale como `com.android.shell`, y ese paquete no está en `origenesReconocidos`. Lo que sí calza es el **remitente**, el segundo modo de identificación que decidió D-N12: basta con que el `title` sea uno de los remitentes conocidos.

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb shell "cmd notification post -S bigtext -t 'BCP Notificaciones' prueba1 `$'Realizaste un consumo con tu Tarjeta de Credito BCP\nMonto\nS/ 45.00\nEmpresa\nSUPERMERCADO EJEMPLO\nFecha y hora\n14 de setiembre de 2026 - 00:30 AM'"
```

**Dos detalles que hacen fallar el comando si se omiten**, los dos verificados el 2026-09-14:

- **El `-t` tiene que ser un remitente reconocido** (`BCP Notificaciones`, `Operaciones Sip`, `Sip`, `YAPE Notificaciones`). Sin eso la notificación se descarta por origen no reconocido, en silencio y sin dejar rastro, que es exactamente lo que FR-008c manda hacer.
- **El cuerpo necesita saltos de línea de verdad.** El monto y el comercio van en el renglón siguiente a su etiqueta en todos los bancos reales, y el parser cuenta con eso. Un cuerpo de una sola línea no produce comercio. Por eso va envuelto en `$'...'`, que el shell del teléfono interpreta: pasar el texto con saltos literales rompe el comando y el *tag* termina ocupando el lugar del texto.

Esto simula una notificación del sistema, no de una app bancaria real — sirve para probar que la escucha, el filtro, el parser y la bandeja funcionan de punta a punta, pero **no** valida el parser contra el formato real de ningún banco. Para eso hace falta un consumo real o los fixtures de `test/dominio/interpretes/fixtures/` (ver `contracts/interpretes.md`).

> **Una consecuencia que conviene tener presente**: como el filtro por remitente no exige que la notificación venga del cliente de correo, **cualquier app del teléfono podría inyectar un pendiente titulando su notificación como un banco**. Nada se registra por eso —todo pendiente exige confirmación explícita (FR-020)— pero el `origen` que se guarda sería el de esa app. Es lo que hace posible esta simulación, y está sin decidir si conviene acotarlo.

---

## Recorrido manual

1. **Activación (HU1)** → Ajustes → Captura de notificaciones. Leer la explicación, activar, conceder el permiso en la pantalla de Android, volver a la app: debe verse "Captura activa" con la lista de orígenes reconocidos (15, de los cuales cuatro tienen paquete o remitente verificado tras T041: BCP, Yape, Oh! / Sip y Banco Falabella; los otros once no se escuchan hasta que alguien los observe en un dispositivo, y eso no rompe nada).
2. **Denegar el permiso** → repetir sin conceder: la app debe mostrar "inactiva" sin mensajes de error alarmantes, y el registro manual de gastos (US3 de 001) debe seguir funcionando igual.
3. **Consumo simulado** → publicar la notificación de prueba de arriba con la captura activa → abrir la bandeja de pendientes → debe aparecer con monto, comercio y fecha.
4. **Confirmar** → el pendiente debe pedir categoría (comercio nunca antes visto, FR-033), confirmarlo, y verificar en Gastos (pantalla de 001) que apareció como transacción con la fecha del consumo, no la de hoy.
5. **Comercio aprendido** → simular un segundo consumo del mismo comercio (mismo texto) → el pendiente ya debe traer la categoría propuesta.
6. **Revocar el permiso desde Ajustes de Android** (no desde la app) → volver a la app: debe avisar que la captura dejó de funcionar.
7. **Modo avión** → con la captura activa, activar modo avión y repetir el paso 3: debe seguir funcionando igual (Principio I — nada de esto depende de red).
8. **Reiniciar el dispositivo** → con la captura activa, reiniciar → repetir el paso 3 sin volver a abrir la app manualmente antes: si el servicio no se reactivó solo, es la limitación documentada en D-N4 (modo foreground), no un bug silencioso — confirmar que al menos abrir la app una vez lo reactiva.
9. **Diagnóstico** → publicar una notificación de un remitente reconocido **con monto pero sin dirección clara** → debe aparecer en el registro de diagnóstico, nunca como pendiente con datos inventados:

   ```powershell
   & $adb shell "cmd notification post -S bigtext -t 'BCP Notificaciones' prueba9 `$'Se ha procesado una operacion\nMonto\nS/ 80.00'"
   ```

   **Tiene que llevar monto.** Un texto sin ninguna cifra **no** va a diagnóstico: desde D-N16 se resuelve como "no es un movimiento" y no deja rastro, porque el formato se entendió perfectamente y no había nada que reconocer. El diagnóstico es para lo que falló, no para lo que no era.

---

## Validación con bancos reales (antes de dar por bueno el parser genérico)

Por cada origen de la muestra elegida (al menos 3, de tipos distintos — ver Requisitos previos): provocar o esperar un consumo real pequeño, confirmar que el pendiente generado tiene el monto, comercio y fecha correctos, y guardar el texto de esa notificación (sin datos personales sensibles más allá del comercio y el monto) como fixture en `test/dominio/interpretes/fixtures/`. Sin este paso, el parser genérico no se considera validado — ver D-N9. Una vez validado contra la muestra, **no hace falta repetir este paso por cada banco de `origenesReconocidos`**: es la ventaja de un parser compartido sobre un intérprete por banco (D-N2). Si en el uso real aparece un banco que el parser no reconoce bien, el registro de diagnóstico (paso 9) es la señal para ajustarlo — el ajuste beneficia a todos los orígenes a la vez.
