# Implementation Plan: Captura automática de consumos desde notificaciones bancarias

**Branch**: `main` (una sola rama hasta que la app se valide, igual que 001) | **Date**: 2026-08-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-captura-notificaciones-bancarias/spec.md`

## Summary

Exclusiva de Android: la app escucha las notificaciones de **cualquier banco o billetera peruana reconocida** con `NotificationListenerService`, las interpreta con **un único parser genérico** (texto → monto/comercio/fecha/dirección), y deja cada consumo como **pendiente** en una bandeja. Nada se registra sin que el usuario confirme de un toque; al confirmar se crea una `Transaccion` de la especificación 001 (o una `Deuda` en cuotas, HU4). La app aprende la categoría de cada comercio con el uso.

**Revisión 2026-08-30**: la versión original de este plan asumía un intérprete de texto por banco, para un conjunto cerrado de cuatro (BCP, Yape, Plin, SIP). El usuario pidió cubrir cualquier banco, presentes o futuros, sin que sumar uno exija código nuevo — ver research.md D-N2 y D-N10 para el porqué del cambio.

El enfoque técnico se apoya en cuatro decisiones:

1. **La escucha corre en un isolate en segundo plano** (`flutter_notification_listener`), no en el hilo de la UI: FR-011 exige capturar con la app cerrada, y eso es un servicio Android nativo con un callback Dart headless, no algo que un `StreamBuilder` en pantalla pueda ofrecer.
2. **Un único parser genérico, no un intérprete por banco**, en `lib/dominio/interpretes/`, con la misma disciplina de pureza y de "nunca pasar por `double`" que ya rige `lib/dominio/calculos/` (Principio II y III). Reconoce patrones comunes a cualquier notificación de consumo — no un formato fijo por banco — y es la parte más valiosa de probar, porque es la única que puede tener un error silencioso con datos reales.
3. **Qué apps escuchar es una lista de datos (`origenesReconocidos`), no código**: agregar un banco nuevo es agregar un elemento a esa lista, no escribir ni desplegar un intérprete (FR-008a, D-N10). La lista acota la escucha a apps financieras conocidas — no es "cualquier notificación del teléfono".
4. **Nunca se guarda nada sin pasar por una fila de "pendiente"**: la tabla intermedia es la que hace que FR-020 (nunca en silencio) sea estructuralmente imposible de saltarse, no solo una convención de la UI.

## Technical Context

**Language/Version**: Dart 3.13.1 / Flutter 3.47.1, igual que 001.

**Primary Dependencies**: `flutter_notification_listener` (^1.4.0) para `NotificationListenerService` con callback headless — ver [research.md](./research.md) D-N1 por qué se prefirió sobre las alternativas, incluida la duda pendiente de verificar su licencia antes de fijarla. El resto reutiliza lo ya presente en 001: `sqflite` (nuevas tablas en la misma base), `provider`. **Ninguna dependencia nueva de red** — nada de esto cambia el Principio I.

**Storage**: mismas SQLite local. Tres tablas nuevas (`consumo_pendiente`, `comercio_categoria`, `notificacion_diagnostico`) y una columna nueva en `configuracion` (`captura_notificaciones_activa`), agregadas por un paso de migración incremental (D10 de 001). Esquema completo en [data-model.md](./data-model.md).

**Testing**: `flutter test`, mismos cuatro frentes que 001. El frente nuevo con más valor es `test/dominio/interpretes/`: el parser genérico se prueba con notificaciones reales de una muestra representativa de bancos/billeteras, no con texto inventado — ver la nota de riesgo en research.md D-N9 (más liviana que la versión original: una muestra, no una captura exhaustiva por banco).

**Target Platform**: **Solo Android** (FR-007). El dominio (`interpretes/`) es Dart puro y compila igual en iOS, pero la capa `datos/notificaciones/` y las pantallas de esta feature se ocultan por completo fuera de Android — no hay una versión "vacía" visible, según exige el edge case "Dispositivo iOS" de la spec.

**Project Type**: Extensión del mismo proyecto Flutter único de 001. No se crea un módulo ni paquete separado.

**Performance Goals**: procesar una notificación entrante y dejarla como pendiente en menos de 1 s desde que el sistema la entrega (SC no numerado explícitamente, pero SC-004/SC-010 lo implican). La bandeja de pendientes debe abrir tan rápido como cualquier otra pantalla de la app (sin dependencia de red que la retrase, por diseño).

**Constraints**: funcionamiento 100% sin conexión (Principio I, SC-007); el contenido de notificaciones nunca sale del dispositivo; ninguna transacción se crea sin confirmación explícita (FR-020, no negociable); el servicio debe sobrevivir el cierre de la app y, en la medida de lo posible, el reinicio del dispositivo (FR-011), con la limitación documentada de Android de requerir modo foreground para reiniciar tras un reboot.

**Scale/Scope**: 15 orígenes sembrados al lanzar (los 15 emisores de `EntidadesPeru` de 001 (ya incluye Yape y Plin)), ampliable sin código nuevo (FR-008a); cuatro historias de usuario, ~40 requisitos funcionales, ~6 pantallas nuevas (activación, bandeja de pendientes, confirmar/editar pendiente, asociaciones aprendidas, registro de diagnóstico, y el punto de entrada de "marcar como cuotas" que reutiliza el formulario de deuda de 001).

## Constitution Check

*GATE: verificado antes de la Fase 0 y revisado tras el diseño de la Fase 1.*

| Principio | Cómo lo cumple este plan | Estado |
|---|---|---|
| **I. Datos locales y privados** | El texto de la notificación y los datos extraídos nunca salen del dispositivo (FR-019); ninguna dependencia nueva abre red; la excepción ya enmendada (v2.0.0) es exclusiva de Google Play Billing y no aplica acá. | PASS |
| **II. Exactitud monetaria (no negociable)** | El intérprete extrae el monto como texto y lo compone a `Dinero` con la misma aritmética entera de `validarMonto` (D2) — nunca pasa por `double`. Ver D-N3. | PASS |
| **III. Lógica financiera pura y probada** | `lib/dominio/interpretes/` queda sin imports de Flutter ni del plugin de notificaciones, cubierto por la misma guarda de pureza de `test/pureza_test.dart` (se amplía su alcance). El parser genérico se prueba con notificaciones reales de una muestra representativa antes de implementarse. | PASS, con la salvedad D-N9 |
| **IV. Claridad sobre sofisticación** | La confirmación es una pantalla simple con los datos ya llenos; el estado de la captura (activa/inactiva/permiso revocado) se explica con texto, no un ícono ambiguo. Sin gráficos ni animaciones nuevas. | PASS |
| **V. Alcance individual, sin especulación** | El parser genérico y la lista de orígenes reconocidos responden a un requisito explícito del usuario (cubrir cualquier tarjeta, no solo cuatro bancos), no a especulación propia. Sin configuración de reglas por parte del usuario, sin edición de la lista de orígenes desde la UI (D-N10 la deja como posible mejora futura, no un requisito de esta spec). La categorización aprendida sigue siendo una tabla de asociación simple, no un modelo de aprendizaje automático. | PASS |

**Restricciones técnicas**: Android como plataforma primaria se cumple por diseño (es exclusiva de Android); el dominio sigue libre de código de plataforma; la migración de esquema es incremental y no destructiva (mismo mecanismo de 001); la dependencia nueva se justifica en research.md D-N1 frente al costo de reimplementarla a mano.

**Flujo de desarrollo**: se respeta especificación → plan → tareas → implementación. Las pruebas de los intérpretes (la lógica financiera de esta feature) son requisito de entrada de sus tareas, no un paso posterior.

**Re-evaluación tras la Fase 1**: el diseño no introdujo desviaciones nuevas. La tabla de Complexity Tracking queda vacía.

## Project Structure

### Documentation (this feature)

```text
specs/002-captura-notificaciones-bancarias/
├── plan.md                        # Este archivo
├── spec.md                        # Especificación
├── research.md                    # Fase 0 — decisiones D-N1 a D-N9
├── data-model.md                  # Fase 1 — entidades y esquema SQL incremental
├── quickstart.md                  # Fase 1 — cómo validar, incluida notificación simulada por adb
├── contracts/
│   ├── interpretes.md             # Fase 1 — contrato de los intérpretes puros
│   └── repositorios.md            # Fase 1 — contrato de los tres repositorios nuevos
├── checklists/
│   └── requirements.md            # Checklist de calidad de la spec (ya existente)
└── tasks.md                       # Fase 2 — lo genera /speckit-tasks, NO este comando
```

### Source Code (repository root)

```text
lib/
├── shared/constantes/
│   ├── enums.dart                       # + MotivoDiagnostico
│   └── origenes_reconocidos.dart        # OrigenReconocido: datos, no código (D-N10)
├── dominio/
│   ├── modelos/
│   │   ├── consumo_pendiente.dart
│   │   ├── asociacion_comercio.dart
│   │   └── notificacion_diagnostico.dart
│   └── interpretes/                     # PURO, igual guarda que dominio/calculos/
│       ├── interprete.dart              # contrato + parser genérico único (D-N2)
│       └── normalizador_comercio.dart
├── datos/
│   ├── notificaciones/
│   │   ├── servicio_escucha.dart        # arranque/parada del plugin, permiso
│   │   └── callback_headless.dart       # @pragma('vm:entry-point'), corre sin UI
│   └── repositorios/
│       ├── repositorio_pendientes.dart
│       ├── repositorio_asociaciones.dart
│       └── repositorio_diagnostico.dart
└── ui/
    └── pantallas/
        └── captura/
            ├── pantalla_activacion.dart
            ├── pantalla_pendientes.dart
            ├── formulario_confirmar_pendiente.dart
            ├── pantalla_asociaciones.dart
            └── pantalla_diagnostico.dart

test/
├── dominio/interpretes/                 # Notificaciones reales de una muestra de orígenes
├── datos/                               # repositorios nuevos + migración v(n+1)
└── ui/captura/
```

**Structure Decision**: se extiende la misma estructura en cuatro capas de 001 (`ui → datos → dominio → shared`), sin introducir un módulo nuevo. `dominio/interpretes/` es un par de `dominio/calculos/`, no un reemplazo: los cálculos financieros no cambian, solo ganan una fuente más de transacciones. `datos/notificaciones/` es la única capa con código específico de Android (el plugin, el callback headless); el resto del dominio y la UI no lo saben. Esto mantiene el Principio III intacto y deja clarísimo qué archivo tocar si Android cambia cómo entrega notificaciones.

## Complexity Tracking

Sin violaciones que justificar: el Constitution Check pasa completo antes y después del diseño.
