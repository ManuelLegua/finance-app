# Implementation Plan: Gestión de sueldo, gasto real, deudas y ahorro

**Branch**: `master` (por decisión del usuario, esta feature se desarrolla sobre `master`; las mejoras posteriores irán en ramas por feature) | **Date**: 2026-08-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-gestion-sueldo-ahorro/spec.md`

## Summary

App Flutter de finanzas personales, individual y sin conexión, que administra un sueldo mensual en soles: registra el ingreso y las obligaciones del mes, las transacciones reales, las deudas de tarjeta en cuotas y los aportes de ahorro, y muestra en paralelo lo presupuestado y lo realmente gastado para decidir cuánto ahorrar.

El enfoque técnico se apoya en tres decisiones que atraviesan todo el diseño:

1. **El dinero es un entero de centavos de punta a punta**, con formateo propio a `S/ 1,234.56` sin pasar nunca por `double` (Principio II, D2).
2. **Las cuotas de deuda no se almacenan: se derivan.** El presupuesto de cualquier mes es *obligaciones guardadas + cuotas vigentes calculadas*, de modo que registrar una deuda una sola vez la hace aparecer correctamente en todos sus meses y corregirla recalcula todos los meses afectados con una sola escritura (D3).
3. **La lógica financiera vive en funciones puras de Dart** sin dependencias de Flutter ni de la base de datos, probadas antes de implementarse y protegidas por una prueba de guarda que falla si alguien importa Flutter dentro del dominio (Principio III, D8).

La persistencia es SQLite local vía `sqflite`, con esquema versionado y migraciones incrementales que preservan los datos.

## Technical Context

**Language/Version**: Dart 3.13.1 / Flutter 3.47.1 (canal `stable`, instalado en `C:\Users\manue\dev\flutter`; no está en el `PATH` de la terminal)

**Primary Dependencies**: `sqflite` (persistencia), `provider` (estado e inyección en la UI), `flutter_localizations` + `intl` (español y formato de fechas; el dinero se formatea a mano), `path`. Dev: `sqflite_common_ffi` (SQLite real en pruebas de escritorio), `flutter_lints`. Justificación paquete por paquete en [research.md](./research.md).

**Storage**: SQLite local en el almacenamiento privado de la app. Ocho tablas (seis de datos, una de metas de ahorro por mes y una de configuración de la app); `PRAGMA user_version` para versionar el esquema y migraciones incrementales no destructivas. Esquema completo en [data-model.md](./data-model.md) §5.

**Testing**: `flutter test` en cuatro frentes — dominio (Dart puro, escrito antes de la implementación), datos (repositorios contra SQLite en memoria con `sqflite_common_ffi`), UI (reglas de presentación verificables) y una prueba de guarda de pureza del dominio.

**Target Platform**: Android como plataforma primaria de desarrollo y prueba. El código Dart se mantiene libre de dependencias específicas de plataforma para que iOS compile sin cambios cuando exista un entorno macOS.

**Project Type**: Aplicación móvil Flutter, proyecto único, sin backend.

**Performance Goals**: 60 fps en navegación y listados; arranque en frío por debajo de 2 s; toda operación de escritura o recálculo del mes percibida como instantánea (< 100 ms) con años de datos acumulados. Las consultas van indexadas por `mes_ordinal`.

**Constraints**: Funcionamiento completo sin conexión (SC-012); ninguna salida de datos del dispositivo (Principio I); exactitud al centavo en el 100% de los casos, incluidos déficit, saldo cero, cuotas parciales y montos de siete cifras (SC-007); accesibilidad del déficit sin depender del color (FR-029).

**Scale/Scope**: Un usuario, un dispositivo. Seis historias de usuario, 61 requisitos funcionales, ~8 pantallas. Volumen esperado del orden de cientos de transacciones por año y decenas de deudas a lo largo de la vida de la app.

## Constitution Check

*GATE: verificado antes de la Fase 0 y revisado tras el diseño de la Fase 1.*

| Principio | Cómo lo cumple este plan | Estado |
|---|---|---|
| **I. Datos locales y privados** | `sqflite` en almacenamiento privado; ninguna dependencia abre red ni recoge telemetría; la app funciona íntegra en modo avión, verificado en el quickstart. | PASS |
| **II. Exactitud monetaria (no negociable)** | Tipo `Dinero` sobre `int` de centavos; no existe constructor desde `double`; el formateo a `S/` se hace desde el entero sin `NumberFormat`; columnas `INTEGER`, nunca `REAL`; los porcentajes se guardan en puntos base. | PASS |
| **III. Lógica financiera pura y probada** | `lib/dominio/` sin imports de Flutter ni de la base de datos; contratos de cálculo definidos en [contracts/calculos-dominio.md](./contracts/calculos-dominio.md); pruebas de caso normal, límite (saldo cero) y adverso (déficit) escritas antes de cada regla; prueba de guarda automatizada que verifica la pureza. | PASS |
| **IV. Claridad sobre sofisticación** | Sin gráficos ni animaciones: ningún requisito los pide. El déficit y el sobregiro se comunican con texto e ícono además de color. Cada pantalla del plan responde a una historia de la spec. Las reglas de presentación están fijadas en D11: Material 3 del SDK sin kit de componentes, cifras tabulares en todo monto, jerarquía por tamaño y contraste AA. | PASS |
| **V. Alcance individual, sin especulación** | Sin multiusuario, autenticación, multimoneda ni sincronización. Sin capa de casos de uso, sin infraestructura de i18n, sin tabla de cuotas materializadas: nada de eso respalda un requisito vigente. | PASS |

**Restricciones técnicas**: stack Flutter + Material (cumple), Android primario con Dart libre de código de plataforma (cumple), persistencia versionada con migraciones que preservan datos (cumple, D10), dependencias justificadas una por una (cumple, tabla en `research.md`), interfaz en español con convención peruana (cumple, D7).

**Flujo de desarrollo**: se respeta el orden especificación → plan → tareas → implementación. Las pruebas de la lógica financiera son requisito de entrada de cada tarea de cálculo, no un paso posterior.

**Re-evaluación tras la Fase 1**: el diseño no introdujo ninguna desviación. La tabla de Complexity Tracking queda vacía.

## Project Structure

### Documentation (this feature)

```text
specs/001-gestion-sueldo-ahorro/
├── plan.md                        # Este archivo
├── spec.md                        # Especificación (revisión 4)
├── research.md                    # Fase 0 — decisiones D1–D14
├── data-model.md                  # Fase 1 — entidades, derivados y esquema SQL
├── quickstart.md                  # Fase 1 — cómo levantar y validar
├── contracts/
│   ├── calculos-dominio.md        # Fase 1 — API de la capa de cálculo puro
│   └── repositorios.md            # Fase 1 — API de persistencia
├── checklists/
│   └── requirements.md            # Checklist de calidad de la spec (16/16)
└── tasks.md                       # Fase 2 — lo genera /speckit-tasks, NO este comando
```

### Source Code (repository root)

```text
lib/
├── main.dart                      # Arranque, tema, locale es_PE, providers raíz
├── core/
│   ├── dinero.dart                # int de centavos + aritmética entera
│   ├── mes.dart                   # Mes(anio, mes) con ordinal
│   ├── formato_soles.dart         # S/ 1,234.56 desde el entero
│   └── formato_fecha.dart         # DateFormat es_PE
├── dominio/                       # PURO: sin flutter, sin sqflite
│   ├── modelos/                   # Ingreso, Obligacion, Transaccion, Tarjeta,
│   │                              # Deuda, MetaAhorro, AporteAhorro,
│   │                              # Configuracion, Categoria, EntidadesPeru,
│   │                              # y los derivados (ResumenMes, LineaCategoria,
│   │                              # EstadoDeuda, PanoramaDeuda, SugerenciaAhorro,
│   │                              # ProgresoAhorro, EstadoCierre)
│   └── calculos/
│       ├── resumen_mes.dart       # totales, disponible, déficit
│       ├── desglose_categorias.dart
│       ├── deudas.dart            # cuotas vigentes, saldo, panorama
│       ├── ahorro.dart            # sugerencia, meta del mes, progreso
│       ├── cierre_mes.dart        # abierto / en gracia / cerrado (D13)
│       └── presupuesto.dart       # precarga de fijas, validación de montos
├── datos/
│   ├── base_datos.dart            # apertura, onCreate, onUpgrade, foreign_keys
│   ├── esquema.dart               # DDL de la versión 1
│   ├── migraciones.dart           # pasos incrementales v(n) → v(n+1)
│   └── repositorios/              # ingreso, obligaciones, transacciones,
│                                  # tarjetas, deudas, ahorro, meses
└── ui/
    ├── tema.dart                  # Material 3 desde semilla, cifras tabulares (D11)
    ├── cascaron.dart              # Scaffold raíz + NavigationBar entre las 6 pantallas
    ├── estado/                    # ChangeNotifiers: mes en curso, deudas, ahorro
    ├── pantallas/
    │   ├── resumen_mes/           # HU2 — pantalla principal
    │   ├── presupuesto/           # HU1 — ingreso y obligaciones
    │   ├── transacciones/         # HU3 — registro y listado de gastos
    │   ├── deudas/                # HU4 — deudas, tarjetas, panorama
    │   ├── ahorro/                # HU5 — regla, meta, aportes, historial
    │   └── categorias/            # HU6 — desglose
    └── widgets/                   # campo de monto, ficha de categoría,
                                   # aviso de déficit, selector de mes

test/
├── dominio/                       # Dart puro; se escribe antes de la implementación
├── datos/                         # repositorios + migraciones (sqflite_common_ffi)
├── ui/                            # widget tests de las reglas de presentación
└── pureza_test.dart               # guarda: lib/dominio no importa flutter ni sqflite
```

**Structure Decision**: proyecto Flutter único con separación en cuatro capas dentro de `lib/`, con la dependencia siempre apuntando hacia adentro (`ui → datos → dominio → core`). Es la estructura mínima que hace cumplible el Principio III —el dominio se prueba sin levantar Flutter— sin introducir capas que ningún requisito respalda. Los identificadores del dominio van en español, igual que la spec, para que no haya salto de vocabulario entre el requisito y el código. El directorio `test/` refleja esa misma división. Se descarta la estructura por feature modules y la separación en paquetes del monorepo: para ~8 pantallas de un solo usuario, multiplicarían la ceremonia sin beneficio (Principio V).

## Complexity Tracking

Sin violaciones que justificar: el Constitution Check pasa completo antes y después del diseño.
