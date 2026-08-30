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

Para probar el camino completo (servicio de escucha → intérprete → pendiente → confirmación) sin esperar un consumo real, `adb` puede publicar una notificación con el `packageName` de un origen soportado:

```powershell
adb shell cmd notification post -S bigtext -t "Consumo aprobado" tag_prueba "Consumo aprobado por S/ 45.00 en SUPERMERCADO EJEMPLO"
```

Esto simula una notificación del sistema, no de una app bancaria real — sirve para probar que el servicio de escucha, el filtro por `packageName` reconocido y la UI de pendientes funcionan de punta a punta, pero **no** valida el parser genérico real (el texto exacto de `adb shell cmd notification post` no reproduce el formato real de ningún banco). Para eso hace falta un consumo real u observar notificaciones reales guardadas como fixture (ver `contracts/interpretes.md`).

---

## Recorrido manual

1. **Activación (HU1)** → Ajustes → Captura de notificaciones. Leer la explicación, activar, conceder el permiso en la pantalla de Android, volver a la app: debe verse "Captura activa" con la lista de orígenes reconocidos (15 al lanzar — los emisores de `EntidadesPeru`, que ya incluye Yape y Plin).
2. **Denegar el permiso** → repetir sin conceder: la app debe mostrar "inactiva" sin mensajes de error alarmantes, y el registro manual de gastos (US3 de 001) debe seguir funcionando igual.
3. **Consumo simulado** → publicar la notificación de prueba de arriba con la captura activa → abrir la bandeja de pendientes → debe aparecer con monto, comercio y fecha.
4. **Confirmar** → el pendiente debe pedir categoría (comercio nunca antes visto, FR-033), confirmarlo, y verificar en Gastos (pantalla de 001) que apareció como transacción con la fecha del consumo, no la de hoy.
5. **Comercio aprendido** → simular un segundo consumo del mismo comercio (mismo texto) → el pendiente ya debe traer la categoría propuesta.
6. **Revocar el permiso desde Ajustes de Android** (no desde la app) → volver a la app: debe avisar que la captura dejó de funcionar.
7. **Modo avión** → con la captura activa, activar modo avión y repetir el paso 3: debe seguir funcionando igual (Principio I — nada de esto depende de red).
8. **Reiniciar el dispositivo** → con la captura activa, reiniciar → repetir el paso 3 sin volver a abrir la app manualmente antes: si el servicio no se reactivó solo, es la limitación documentada en D-N4 (modo foreground), no un bug silencioso — confirmar que al menos abrir la app una vez lo reactiva.
9. **Diagnóstico** → publicar una notificación de un origen soportado con texto ilegible (sin monto) → debe aparecer en el registro de diagnóstico, no como pendiente con datos inventados.

---

## Validación con bancos reales (antes de dar por bueno el parser genérico)

Por cada origen de la muestra elegida (al menos 3, de tipos distintos — ver Requisitos previos): provocar o esperar un consumo real pequeño, confirmar que el pendiente generado tiene el monto, comercio y fecha correctos, y guardar el texto de esa notificación (sin datos personales sensibles más allá del comercio y el monto) como fixture en `test/dominio/interpretes/fixtures/`. Sin este paso, el parser genérico no se considera validado — ver D-N9. Una vez validado contra la muestra, **no hace falta repetir este paso por cada banco de `origenesReconocidos`**: es la ventaja de un parser compartido sobre un intérprete por banco (D-N2). Si en el uso real aparece un banco que el parser no reconoce bien, el registro de diagnóstico (paso 9) es la señal para ajustarlo — el ajuste beneficia a todos los orígenes a la vez.
