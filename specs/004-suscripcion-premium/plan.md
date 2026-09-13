# Implementation Plan: Apoyo voluntario (propina)

**Branch**: `004-suscripcion-premium` | **Date**: 2026-08-29 · **Revisado**: 2026-09-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-suscripcion-premium/spec.md`

## Summary

Una suscripción paga dentro de la app, vía Google Play Billing, con un plan mensual y uno anual (ambos con un mes de prueba gratis), que desbloquea Deudas y Ahorro (feature 001) y la captura automática de notificaciones (feature 002). Todo lo demás sigue gratis, sin límite, para siempre. El estado de la suscripción se cachea en el mismo SQLite local para que la app funcione sin conexión salvo en el momento de comprar o restaurar; vencer o cancelar bloquea esas pantallas sin borrar ningún dato ya cargado en ellas.

## Technical Context

**Language/Version**: Dart 3.13.1 / Flutter 3.47.1 (mismo entorno que la feature 001).

**Primary Dependencies**: `in_app_purchase` + `in_app_purchase_android` (paquete oficial de Flutter, ya envuelve Google Play Billing Library 8.0.0 con soporte de planes base y ofertas de prueba — ver [research.md](./research.md) D1). Reutiliza `sqflite` y `provider`, ya presentes desde la feature 001.

**Storage**: SQLite local existente. Una tabla nueva de fila única, `suscripcion_premium` (igual patrón que `configuracion`), agregada en una migración incremental (`Esquema.version` 3 → 4 — la base ya iba por v3: la spec 002 la subió a 2, la 003 a 3) que no toca ninguna tabla existente. Esquema completo en [data-model.md](./data-model.md) §4.

**Testing**: `flutter test` en dominio (vigencia de la suscripción, función pura, escrita antes de implementar) y UI (paywall con un doble en memoria del repositorio); el flujo real de compra/restauración/vencimiento **no se puede automatizar** y se valida a mano contra la pista de pruebas internas de Google Play Console — ver [quickstart.md](./quickstart.md).

**Target Platform**: Android, igual que 001. El paquete elegido es de Flutter/Google, no introduce código nativo propio.

**Project Type**: mismo proyecto Flutter único; no se crea un módulo ni paquete separado.

**Performance Goals**: leer el estado cacheado de la suscripción para decidir si se muestra una pantalla premium o el paywall MUST ser tan rápido como cualquier otra lectura local (< 100 ms); el único punto de la app con latencia de red es la compra/restauración/consulta de ofertas, que ya son acciones explícitas del usuario.

**Constraints**: ninguna pantalla premium MUST exigir conexión para abrirse si ya hay un estado cacheado (edge case "sin conexión" de la spec); ningún dato financiero del usuario MUST viajar en la verificación de la suscripción (FR-016, Principio I enmendado).

**Scale/Scope**: cinco historias de usuario, 17 requisitos funcionales (FR-001 a FR-016 más FR-006a), una pantalla nueva (paywall) y un indicador de estado reusable. Un usuario, una cuenta de Google Play.

## Constitution Check

*GATE: verificado antes de la Fase 0 y revisado tras el diseño de la Fase 1.*

| Principio | Cómo lo cumple este plan | Estado |
|---|---|---|
| **I. Datos locales y privados** *(enmendado v2.0.0)* | El único tráfico de red que esta feature introduce es `in_app_purchase` hablando con los servidores de Google Play para comprar, restaurar o consultar ofertas — exactamente lo que la enmienda autoriza. Ningún `Dinero`, `Deuda`, `Transaccion` ni `AporteAhorro` forma parte de esa comunicación (FR-016, contrato en `contracts/repositorio-suscripcion.md`). | PASS |
| **II. Exactitud monetaria (no negociable)** | Los precios que se muestran en el paywall son strings ya formateados y localizados por Google Play (`OfertaSuscripcion.precioFormateado`); la app no los parsea, no los sobre los que hace aritmética, no los guarda como `Dinero`. No aplica el tipo `Dinero` porque no es dinero que la app calcule o persista, es un precio que Google Play informa. | PASS |
| **III. Lógica financiera pura y probada** | `EstadoSuscripcion.estaVigente` es un getter puro sobre un enum, sin Flutter ni SDK de facturación, probado para las seis situaciones antes de implementarse (D2 en research.md). El plugin de facturación en sí vive enteramente en `lib/datos/`, nunca en `lib/dominio/`; la guarda de pureza (`test/pureza_test.dart`) lo verifica igual que ya verifica `sqflite`. | PASS |
| **IV. Claridad sobre sofisticación** | El paywall explica con texto qué se desbloquea y el precio, no solo un candado (FR-005). El estado de la suscripción ("en prueba", "activa", "vencida") se muestra en texto, nunca solo con un color o un ícono. Vencer la suscripción se comunica explícitamente como el motivo de que Deudas/Ahorro no aparezcan (FR-012), en vez de dejar un hueco sin explicar. | PASS |
| **V. Alcance individual, sin especulación** | Sigue siendo una app de un usuario: la suscripción es un atributo de la cuenta de Google de ese usuario, no introduce multiusuario ni roles. Un solo producto con dos planes (mensual, anual), sin niveles de funcionalidad adicionales que ningún requisito pida. | PASS |

**Restricciones técnicas**: dependencia justificada uno por uno en `research.md` D1 (paquete oficial de Flutter, evita reimplementar la Billing Library a mano). Persistencia versionada con migración incremental que preserva todos los datos existentes (D3 en research.md). Interfaz en español, consistente con el resto del dominio.

**Flujo de desarrollo**: se respeta especificación → plan → tareas → implementación. La prueba de `EstadoSuscripcion.estaVigente` se escribe antes que la implementación del getter, como exige el Principio III para lógica financiera — aunque acotada, decide si el usuario paga o no por una pantalla, así que se trata con el mismo rigor.

**Re-evaluación tras la Fase 1**: el diseño (data-model.md, contracts/) no introdujo ninguna desviación de lo evaluado arriba. La tabla de Complexity Tracking queda vacía.

## Project Structure

### Documentation (this feature)

```text
specs/004-suscripcion-premium/
├── plan.md                              # Este archivo
├── spec.md                              # Especificación
├── research.md                          # Fase 0 — decisiones D1–D5
├── data-model.md                        # Fase 1 — entidades y esquema SQL
├── quickstart.md                        # Fase 1 — validación automática y manual
├── contracts/
│   └── repositorio-suscripcion.md       # Fase 1 — contrato del único repositorio nuevo
├── checklists/
│   └── requirements.md                  # Checklist de calidad de la spec
└── tasks.md                             # Fase 2 — lo genera /speckit-tasks, NO este comando
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── modelos/
│   │   └── estado_suscripcion.dart      # PlanSuscripcion, SituacionSuscripcion,
│   │                                    # EstadoSuscripcion (con .estaVigente),
│   │                                    # OfertaSuscripcion
│   └── repositorios/
│       └── repositorio_suscripcion.dart # interfaz: estadoCacheado, refrescar,
│                                        # ofertasDisponibles, comprar, restaurar
├── datos/
│   ├── esquema.dart                     # + tabla suscripcion_premium (v2)
│   ├── migraciones.dart                 # + paso v3 → v4
│   └── repositorios/
│       └── repositorio_suscripcion_billing.dart  # implementa la interfaz con
│                                                  # in_app_purchase + caché SQLite
└── ui/
    ├── cascaron.dart                    # los destinos Deudas/Ahorro pasan por
    │                                    # EstadoSuscripcion antes de mostrarse
    ├── estado/
    │   └── estado_suscripcion.dart      # ChangeNotifier: premiumActivo, ofertas,
    │                                    # comprar(), restaurar(), cargar()
    └── pantallas/
        └── suscripcion/
            ├── pantalla_paywall.dart    # explica, muestra planes, compra
            └── ficha_estado_suscripcion.dart  # indicador reusable (Ajustes, paywall)

test/
├── dominio/
│   └── suscripcion_test.dart            # estaVigente para las seis situaciones
├── dobles/
│   └── repositorios_en_memoria.dart     # + RepositorioSuscripcionEnMemoria
└── ui/
    └── pantalla_paywall_test.dart       # bloquea/desbloquea según EstadoSuscripcion,
                                          # sin tocar los datos de Deudas/Ahorro
```

**Structure Decision**: misma arquitectura en capas que la feature 001 (`ui → datos → dominio → shared`), sin capas nuevas: un repositorio más y un `ChangeNotifier` más, siguiendo exactamente el patrón ya establecido por `RepositorioAhorro`/`EstadoAhorro`. El SDK de Google Play Billing queda enteramente dentro de `lib/datos/`, igual que `sqflite`; el dominio solo conoce un enum de situación y fechas, nunca el paquete `in_app_purchase`. Se descarta un módulo o paquete separado para esto: es una pantalla y un indicador de estado, separarlo multiplicaría la ceremonia sin ningún beneficio (Principio V).

## Complexity Tracking

Sin violaciones que justificar: el Constitution Check pasa completo antes y después del diseño.

---

# Revisión 2026-09-12 — plan de la propina

Todo lo de arriba describe el plan de la suscripción, que se implementó hasta
T046 y se descarta acá. Se conserva por trazabilidad. **Lo que vale desde esta
línea es lo que sigue.**

## Summary (revisado)

La app se reparte completa y gratis: ningún destino, acción ni dato queda
condicionado a un pago. El único camino de ingreso es una propina por única
vez, repetible, que el usuario deja desde Ajustes a través de Google Play. No
desbloquea nada, no se persiste nada y no aparece en ninguna otra pantalla.
Se conserva la dependencia de facturación y el patrón de repositorio; se borra
todo lo que bloqueaba.

## Technical Context (lo que cambia)

**Primary Dependencies**: las mismas. `in_app_purchase` +
`in_app_purchase_android` siguen siendo la vía, ahora usando
`buyConsumable` en vez de `buyNonConsumable` y sin la extensión de
suscripciones.

**Storage**: **ninguno**. Esta feature deja de persistir. Además le quita una
tabla al esquema: `Esquema.version` pasa de 4 a 5 para borrar
`suscripcion_premium` (research.md D9, data-model.md §3).

**Testing**: se acaba la prueba de dominio, porque se acabó el dominio — no
queda ninguna regla que decidir. Lo que se prueba es la UI con un doble en
memoria (que la pantalla de apoyo muestre los montos, que sin conexión no
invente precios, que cancelar no produzca error) y, sobre todo, **que ningún
destino de la app esté bloqueado**, que es la garantía central de la revisión
(SC-001).

**Performance Goals**: desaparece la exigencia de leer un estado cacheado
antes de abrir una pantalla: ya no hay nada que consultar. La única latencia de
red de la app sigue siendo la de una acción explícita del usuario, ahora solo
en la pantalla de apoyo.

**Constraints**: ninguna pantalla MUST consultar la facturación para
construirse. `EstadoPropinas` solo lo conoce la pantalla de apoyo; el resto de
la app no sabe que existe.

**Scale/Scope**: tres historias, 12 requisitos funcionales (FR-001 a FR-012),
una pantalla nueva y una entrada en Ajustes. Cero entidades persistidas.

## Constitution Check (revisado)

| Principio | Cómo lo cumple el plan revisado | Estado |
|---|---|---|
| **I. Datos locales y privados** *(enmendado v2.0.0)* | El tráfico de red **se reduce**: se consultan los montos y se paga, y desaparecen el refresco periódico de vigencia y la restauración de compras. Ningún tipo del dominio financiero entra en esas llamadas (FR-009). La revisión no necesita enmienda nueva porque no amplía nada. | PASS |
| **II. Exactitud monetaria** | `OfertaPropina.precioFormateado` es un texto que informa Google Play y se muestra tal cual; no se parsea, no se opera y no se guarda. Ningún `Dinero` participa de esta feature. | PASS |
| **III. Lógica financiera pura y probada** | No queda ninguna regla financiera que probar: apoyar no calcula nada. La prueba de entrada que sí exige esta revisión es la inversa y se escribe antes de tocar el cascarón — que **ningún** destino esté condicionado (SC-001). El SDK de facturación sigue confinado a `lib/datos/`, verificado por `test/pureza_test.dart`. | PASS |
| **IV. Claridad sobre sofisticación** | La pantalla de apoyo dice con todas las letras que no desbloquea nada, y muestra el precio antes de tocar nada. Sin conexión lo dice, en vez de mostrar un precio viejo. El resto de la app queda **más** clara: se va un candado de dos pestañas. | PASS |
| **V. Alcance individual, sin especulación** | La revisión borra más de lo que agrega: se van una tabla, cuatro tipos de dominio, tres widgets y una guarda de navegación. No se persiste nada "por si acaso" (D8). | PASS |

**Restricciones técnicas**: la migración v4 → v5 borra una tabla, y es la
primera del proyecto que lo hace. Queda justificado por escrito en research.md
D9: la regla de D10 protege *información del usuario*, y esa tabla solo
guardaba la respuesta de Google Play. Ningún dato cargado por el usuario se
toca.

**Flujo de desarrollo**: el cambio de alcance se refleja primero en la spec
(hecho), después en research/data-model/plan (hecho), después en tasks, y
recién entonces en el código — que es justamente lo que la constitución exige
y lo que esta revisión respeta.

## Project Structure (revisada)

```text
lib/
├── shared/constantes/
│   └── propinas.dart                     # NUEVO · ids de producto, Dart puro
├── dominio/
│   ├── modelos/
│   │   ├── propina.dart                  # NUEVO · OfertaPropina, ResultadoPropina
│   │   └── estado_suscripcion.dart       # BORRADO
│   └── repositorios/
│       ├── repositorio_propinas.dart     # NUEVO · ofertas(), apoyar()
│       └── repositorio_suscripcion.dart  # BORRADO
├── datos/
│   ├── esquema.dart                      # v5; suscripcion_premium sale de creacion
│   ├── migraciones.dart                  # + paso v4 → v5 (DROP TABLE)
│   └── repositorios/
│       ├── repositorio_propinas_billing.dart      # NUEVO
│       ├── repositorio_suscripcion_billing.dart   # BORRADO
│       └── repositorio_respaldo_sqlite.dart       # una tabla menos que vaciar
└── ui/
    ├── cascaron.dart                     # se va AccesoDestino y la guarda
    ├── estado/
    │   ├── estado_propinas.dart          # NUEVO
    │   └── estado_suscripcion.dart       # BORRADO
    └── pantallas/
        ├── propina/
        │   └── pantalla_propina.dart     # NUEVO · única pantalla de la feature
        ├── suscripcion/                  # BORRADA entera (3 archivos)
        ├── ajustes/pantalla_ajustes.dart # entrada "Apoyar esta app"
        └── captura/pantalla_activacion.dart # se va la guarda premium

test/
├── ui/
│   ├── pantalla_propina_test.dart        # NUEVO
│   ├── todo_gratis_test.dart             # RENOMBRADO de gratis_sin_limite_test.dart
│   ├── pantalla_paywall_test.dart        # BORRADO
│   ├── ficha_estado_suscripcion_test.dart# BORRADO
│   ├── restaurar_suscripcion_test.dart   # BORRADO
│   └── vencimiento_suscripcion_test.dart # BORRADO
├── dominio/suscripcion_test.dart         # BORRADO
└── datos/migracion_005_test.dart         # NUEVO · la tabla se va sin tocar el resto
```

**Structure Decision (revisada)**: la feature pasa de atravesar toda la app a
vivir en una sola pantalla. Esa es la señal de que la revisión va en la
dirección correcta: una forma de monetizar que no toca ninguna otra pantalla es
una que no puede degradar el producto.
