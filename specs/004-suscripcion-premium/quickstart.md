# Quickstart — Validar la feature 004

**Feature**: 004-suscripcion-premium | **Fecha**: 2026-08-29

Guía para levantar el proyecto y comprobar que la suscripción premium hace lo
que dice la spec. A diferencia de 001, buena parte de esta feature **no se
puede probar solo con `flutter test`**: comprar, restaurar y vencer una
suscripción real solo se verifican contra Google Play. Esta guía cubre ambos
frentes.

---

## Requisitos previos

- Lo mismo que la feature 001 (Flutter 3.47.1 en el `PATH` de la sesión,
  emulador o dispositivo Android).
- **Una app subida a Google Play Console**, al menos a la pista de **pruebas
  internas** (no hace falta publicarla en producción). Google Play Billing no
  funciona contra un `flutter run` de depuración sin que la app exista en la
  Play Console con el mismo `applicationId` y la misma firma de subida.
- **El producto de suscripción creado en Play Console**: un ID de producto
  (ej. `premium`) con dos planes base (`mensual`, `anual`) y una oferta de
  prueba de un mes en cada uno (FR-006, FR-006a). Se crea en Play Console →
  Monetizar → Productos → Suscripciones.
- **Una cuenta de prueba de licencias** (Play Console → Configuración → Prueba
  de licencias): sin esto, cualquier intento de compra sale con el propio
  usuario real, con dinero real.

---

## Puesta en marcha

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## Validación automática

Cubre todo lo que no depende de hablar con Google Play de verdad.

```powershell
flutter test test/dominio/suscripcion_test.dart   # vigencia por cada situación
flutter test test/ui/pantalla_paywall_test.dart   # el paywall bloquea/desbloquea según EstadoSuscripcion
flutter test test/pureza_test.dart                # el dominio sigue sin importar el plugin de facturación
```

| Qué se comprueba | Dónde | Requisito |
|---|---|---|
| `enPrueba`, `activa`, `enGracia` conceden acceso; `vencida`, `cancelada`, `nunca` no | `test/dominio/suscripcion_test.dart` | FR-001 – FR-003, FR-010 |
| Deudas/Ahorro muestran el paywall sin suscripción, y la pantalla real con ella | `test/ui/pantalla_paywall_test.dart` | FR-001, FR-002 |
| Los datos de Deudas/Ahorro no se tocan al cambiar el estado de suscripción | `test/ui/pantalla_paywall_test.dart` | FR-011 |
| El dominio no importa el paquete `in_app_purchase` | `test/pureza_test.dart` | Principio III |

---

## Validación manual por historia de usuario

Con una cuenta de prueba de licencias configurada, y usando las **tarjetas de
prueba de Google Play** (Play Console permite pagos de prueba instantáneos y
también "renovar/cancelar/expirar ahora" sobre una suscripción de prueba, sin
esperar un mes real):

1. **US1 — Descubrir el paywall**. Sin haberte suscrito, entrá a Deudas.
   Tenés que ver la explicación de qué se desbloquea, el precio mensual, el
   anual, y que el primer mes es gratis en cualquiera de los dos. Repetí en
   Ahorro.
2. **US2 — Suscribirse**. Elegí el plan mensual, completá la compra de
   prueba. Sin salir de la app, Deudas y Ahorro tienen que quedar accesibles.
   Consultá el estado: tiene que decir "en prueba gratis" y la fecha del
   primer cobro.
3. **US2 (cobro)** — Desde Play Console, sobre esa suscripción de prueba,
   usá la opción de simular el fin del período de prueba. El estado en la
   app (al refrescar) tiene que pasar a "activa".
4. **US3 — Lo gratis sigue gratis**. Sin ninguna suscripción (otra cuenta de
   prueba, o cancelá y esperá a que venza), recorré Presupuesto, Resumen y
   Gastos: ninguna debe mostrar avisos de pago.
5. **US4 — Vencimiento sin pérdida de datos**. Con una deuda y un aporte de
   ahorro ya cargados, cancelá la suscripción de prueba desde Play Console
   (o simulá el vencimiento). Deudas y Ahorro vuelven a mostrar el paywall.
   Volvé a suscribirte (o restaurá): la deuda y el aporte tienen que
   reaparecer exactamente iguales.
6. **US5 — Restaurar**. Desinstalá y reinstalá la app (o instalala en otro
   dispositivo/emulador) con la misma cuenta de prueba ya suscripta. Usá la
   opción de restaurar: el acceso premium tiene que volver sin pedir pago.
7. **Sin conexión**. Con una suscripción activa ya verificada al menos una
   vez, poné el dispositivo en modo avión y entrá a Deudas: tiene que seguir
   accesible, usando el último estado conocido.

---

## Qué queda fuera de esta guía

- El monto exacto de cada plan y si el precio final es mensual/anual se
  configuran en Play Console, no en el código (ver `research.md` y
  `Assumptions` de la spec).
- Publicar la app en producción, más allá de la pista de pruebas internas,
  es una decisión aparte del usuario del proyecto, no parte de esta
  validación.
