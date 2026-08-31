# Implementation Plan: Cobros parciales de ingreso

**Branch**: `main` (rama única hasta que la app se valide, igual que 001 y 002) | **Date**: 2026-08-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-cobros-parciales-ingreso/spec.md`

## Summary

Reemplaza el ingreso mensual de la spec 001 —hoy un único monto por mes— por una lista de **cobros** (`CobroIngreso`: fecha + monto), igual que ya existen `Transaccion` para gastos y `AporteAhorro` para ahorro. El ingreso total de un mes deja de ser un dato guardado y pasa a ser un **derivado**: la suma de sus cobros. Todo lo que hoy consume ese total (disponible proyectado, disponible real, déficit, sugerencia de ahorro) sigue recibiendo exactamente el mismo `Dinero?` que antes, así que no cambia una sola línea fuera de la ruta de escritura y lectura del ingreso.

El enfoque técnico se apoya en tres decisiones:

1. **`CobroIngreso` es un par (fecha, monto), sin nombre ni etiqueta** — mismo patrón que `AporteAhorro` (D-C1 en research.md), no uno nuevo. El mes se deriva de la fecha, igual que en `Transaccion` y `AporteAhorro` (FR-002).
2. **El total sigue siendo un valor derivado, calculado por una función pura** (`totalIngreso`, en `lib/dominio/calculos/ingreso.dart`), no un dato que la UI o el repositorio recalculen por su cuenta. Es el mismo patrón que ya usan `compromisoDeudasEnMes` (D3, spec 001) y `totalGastado`: la entidad se guarda desglosada, el total se deriva en el dominio puro.
3. **La migración de esquema es aditiva, nunca destructiva** (D10 de 001): se crea la tabla `cobro_ingreso`, se copian ahí los `ingreso` existentes como un cobro equivalente por mes, y la tabla `ingreso` **se deja de usar pero no se borra** — la regla ya escrita en `migraciones.dart` ("nunca borra ni recrea tablas con datos") no distingue entre una tabla vigente y una que la app dejó de leer.

## Technical Context

**Language/Version**: Dart 3.13.1 / Flutter 3.47.1, igual que 001 y 002.

**Primary Dependencies**: Ninguna nueva. Reutiliza `sqflite` (una tabla más en la misma base) y `provider`. Ningún cambio de superficie sobre el Principio I.

**Storage**: misma SQLite local. Una tabla nueva (`cobro_ingreso`, mismo shape que `aporte_ahorro`) agregada por un paso de migración incremental v2→v3; la tabla `ingreso` queda en el esquema sin usarse, sin dato migrado sin copiar. Esquema completo en [data-model.md](./data-model.md).

**Testing**: `flutter test`, los mismos cuatro frentes que 001/002. El frente con más peso es dominio: `totalIngreso` se prueba antes de implementarse (caso normal — dos cobros que suman el total esperado —, límite — un mes sin cobros da `null`, no cero — y adverso — un cobro corregido a un monto menor no arrastra el valor viejo). La migración v2→v3 se prueba igual que la v1→v2 de 002: contra una base con datos del esquema anterior, verificando que no se pierde ningún ingreso ya registrado (SC-004).

**Target Platform**: Todas las plataformas de la app (a diferencia de 002, esto no es exclusivo de Android — es una extensión directa de 001).

**Project Type**: Extensión del mismo proyecto Flutter único de 001. No se crea módulo ni paquete separado.

**Performance Goals**: sin cambios sobre 001 — un mes tiene, en el caso real que motiva la spec, dos o tres cobros; sumar eso es trivial frente al resto de `EstadoMes.cargar()`.

**Constraints**: SC-003 exige cero diferencia de comportamiento para quien no divide su sueldo — el `Dinero?` que llega a `ResumenMes`, `EstadoAhorro` y `PantallaResumen` tiene que ser bit a bit el mismo que producía un `Ingreso` único de igual monto. Migrar una base existente no puede perder ni un mes ya registrado (SC-004, FR-009).

**Scale/Scope**: una entidad nueva (`CobroIngreso`), un repositorio que reemplaza a `RepositorioIngreso`, una función de dominio nueva, tres historias de usuario, 9 requisitos funcionales. Sin pantallas nuevas: se amplía la tarjeta de ingreso que ya existe en `PantallaPresupuesto`.

## Constitution Check

*GATE: verificado antes de la Fase 0 y revisado tras el diseño de la Fase 1.*

| Principio | Cómo lo cumple este plan | Estado |
|---|---|---|
| **I. Datos locales y privados** | Ningún dato ni dependencia nueva sale del dispositivo; es una extensión de la misma SQLite local. | PASS |
| **II. Exactitud monetaria (no negociable)** | `CobroIngreso.monto` es `Dinero` (entero de centavos), igual que `AporteAhorro`; `totalIngreso` suma con aritmética entera, sin pasar por `double`; columna `monto_centavos INTEGER`. | PASS |
| **III. Lógica financiera pura y probada** | `totalIngreso` vive en `lib/dominio/calculos/ingreso.dart`, sin Flutter ni sqflite, cubierto por la guarda de pureza existente (el directorio ya está vigilado, no hace falta ampliarla). Pruebas de caso normal, límite (mes sin cobros → `null`) y adverso (corregir un cobro no arrastra el monto viejo) antes de implementar. | PASS |
| **IV. Claridad sobre sofisticación** | La tarjeta de ingreso pasa de un monto a una lista breve (2-3 filas en el caso real) más el total remarcado; sin gráficos ni animaciones nuevas. Ningún requisito pide más que texto. | PASS |
| **V. Alcance individual, sin especulación** | Sin nombre/etiqueta por cobro (Assumptions de la spec ya lo descarta explícitamente), sin límite de cantidad configurable, sin seguimiento de flujo de caja diario dentro del mes (Assumptions lo descarta por nombre). | PASS |

**Restricciones técnicas**: migración incremental que preserva datos (D10, verificado en Storage arriba); sin dependencias nuevas que justificar; interfaz en español con convención peruana sin cambios.

**Flujo de desarrollo**: especificación → plan → tareas → implementación, sin saltos. La prueba de `totalIngreso` y de la migración v2→v3 son requisito de entrada de sus tareas, no un paso posterior.

**Re-evaluación tras la Fase 1**: el diseño no introdujo desviaciones. La tabla de Complexity Tracking queda vacía.

## Project Structure

### Documentation (this feature)

```text
specs/003-cobros-parciales-ingreso/
├── plan.md                        # Este archivo
├── spec.md                        # Especificación
├── research.md                    # Fase 0 — decisiones D-C1 a D-C6
├── data-model.md                  # Fase 1 — entidad, derivado y esquema SQL incremental
├── quickstart.md                  # Fase 1 — cómo validar, incluida la migración
├── contracts/
│   ├── calculos.md                # Fase 1 — contrato de `totalIngreso`
│   └── repositorios.md            # Fase 1 — contrato de `RepositorioCobrosIngreso`
├── checklists/
│   └── requirements.md            # Checklist de calidad de la spec (ya existente)
└── tasks.md                       # Fase 2 — lo genera /speckit-tasks, NO este comando
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── modelos/
│   │   └── cobro_ingreso.dart           # nuevo — reemplaza a modelos/ingreso.dart (sin uso real hoy)
│   ├── repositorios/
│   │   └── repositorio_cobros_ingreso.dart  # nuevo — reemplaza a repositorio_ingreso.dart
│   └── calculos/
│       └── ingreso.dart                 # nuevo — totalIngreso(List<CobroIngreso>)
├── datos/
│   ├── esquema.dart                     # + tabla cobro_ingreso, version 2 → 3
│   ├── migraciones.dart                 # + paso v3: crear tabla, copiar ingreso existente
│   └── repositorios/
│       └── repositorio_cobros_ingreso_sqlite.dart  # nuevo — reemplaza a repositorio_ingreso_sqlite.dart
└── ui/
    ├── estado/
    │   └── estado_mes.dart              # _ingreso pasa a derivarse de _cobros; agregarCobro/actualizarCobro/eliminarCobro
    └── pantallas/presupuesto/
        ├── dialogo_ingreso.dart         # se amplía a formulario de un cobro (monto + fecha), o se reemplaza
        └── pantalla_presupuesto.dart    # _TarjetaIngreso pasa a listar cobros + total (US2)

test/
├── dominio/
│   └── ingreso_test.dart                # nuevo — totalIngreso: normal, límite, adverso
├── datos/
│   ├── repositorio_cobros_ingreso_test.dart  # nuevo
│   └── base_datos_test.dart             # + migración v2 → v3
├── builders/
│   └── cobro_ingreso_builder.dart       # nuevo, mismo patrón que deuda_builder.dart
└── ui/
    ├── estado_mes_test.dart             # agregarCobro/actualizarCobro/eliminarCobro, cierre de mes
    └── pantalla_presupuesto_test.dart   # lista de cobros + total (US2), corrección puntual (US3)
```

**Structure Decision**: mismas cuatro capas de 001/002, sin módulo nuevo. `RepositorioIngreso`/`RepositorioIngresoSqlite`/`modelos/ingreso.dart` se **eliminan** en vez de dejarse deprecados: nada fuera de esta feature los usa hoy (`Ingreso` como clase ya está sin consumidores reales, ver research.md D-C5), y mantener dos formas de leer "el ingreso del mes" sería la clase de duplicación que el Principio V descarta. La tabla SQL `ingreso` es la única pieza que sí se conserva sin usarse, porque ahí sí hay datos del usuario en juego (D10).

## Complexity Tracking

Sin violaciones que justificar: el Constitution Check pasa completo antes y después del diseño.
