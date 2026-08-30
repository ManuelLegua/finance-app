# Implementation Plan: Suscripción premium

**Branch**: `004-suscripcion-premium` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-suscripcion-premium/spec.md`

## Summary

Una suscripción paga dentro de la app, vía Google Play Billing, con un plan mensual y uno anual (ambos con un mes de prueba gratis), que desbloquea Deudas y Ahorro (feature 001) y la captura automática de notificaciones (feature 002). Todo lo demás sigue gratis, sin límite, para siempre. El estado de la suscripción se cachea en el mismo SQLite local para que la app funcione sin conexión salvo en el momento de comprar o restaurar; vencer o cancelar bloquea esas pantallas sin borrar ningún dato ya cargado en ellas.

## Technical Context

**Language/Version**: Dart 3.13.1 / Flutter 3.47.1 (mismo entorno que la feature 001).

**Primary Dependencies**: `in_app_purchase` + `in_app_purchase_android` (paquete oficial de Flutter, ya envuelve Google Play Billing Library 8.0.0 con soporte de planes base y ofertas de prueba — ver [research.md](./research.md) D1). Reutiliza `sqflite` y `provider`, ya presentes desde la feature 001.

**Storage**: SQLite local existente. Una tabla nueva de fila única, `suscripcion_premium` (igual patrón que `configuracion`), agregada en una migración incremental (`Esquema.version` 1 → 2) que no toca ninguna tabla existente. Esquema completo en [data-model.md](./data-model.md) §4.

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
│   ├── migraciones.dart                 # + paso v1 → v2
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
