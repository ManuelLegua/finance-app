# Implementation Plan: Respaldo y exportación de datos

**Branch**: `005-respaldo-exportacion-datos` | **Date**: 2026-09-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-respaldo-exportacion-datos/spec.md`

## Summary

Poder sacar una copia de los datos a un archivo que el usuario guarda o
comparte donde quiera, y poder volver a cargarla al reinstalar la app o cambiar
de teléfono. El archivo de respaldo **es el propio archivo SQLite** de la app,
no un volcado a otro formato: eso hace que restaurar un respaldo viejo en una
versión nueva funcione reutilizando las migraciones que ya existen y ya están
probadas, sin una segunda escalera de versiones que mantener. El reemplazo es
todo o nada, con el archivo anterior a un rename de distancia hasta que la base
nueva abre bien.

## Technical Context

**Language/Version**: Dart 3.13.1 / Flutter 3.47.1 (mismo entorno que la feature 001).

**Primary Dependencies**: dos paquetes nuevos, justificados uno por uno en [research.md](./research.md) D5 — `share_plus` para entregar el archivo a la hoja de compartir de Android y `file_picker` para que el usuario elija el archivo a restaurar (Storage Access Framework, sin permisos de almacenamiento). Reutiliza `sqflite` y `path`, presentes desde la feature 001, y `dart:io` para las operaciones de archivo, que quedan confinadas a `lib/datos/`.

**Storage**: SQLite local existente, **sin cambios de esquema**. `Esquema.version` sigue en 4. Es la primera feature del proyecto que no agrega ni altera tablas: opera sobre el archivo completo, no sobre sus filas (D1). Detalle en [data-model.md](./data-model.md).

**Testing**: `flutter test`, con una cobertura mucho mayor que la de la spec 004 — `sqflite_common_ffi` corre SQLite real en Windows, así que el ida y vuelta completo, la migración de un respaldo v3 en una app v4, el rechazo de archivos inválidos y el todo-o-nada se prueban **sin emulador**, con archivos de verdad en un directorio temporal. Solo la hoja de compartir y el selector de archivos exigen dispositivo — ver [quickstart.md](./quickstart.md).

**Target Platform**: Android, igual que 001. Los dos paquetes nuevos son multiplataforma; no se agrega código nativo propio.

**Project Type**: mismo proyecto Flutter único; no se crea módulo ni paquete separado.

**Performance Goals**: exportar MUST completarse en menos de 15 segundos (SC-002). Con la base de un solo usuario es una copia de archivo de milisegundos; el tiempo real que percibe el usuario lo domina la hoja de compartir del sistema, no la app.

**Constraints**: ninguna operación MUST transmitir datos por su cuenta (Principio I, enmienda v3.0.0); un intento fallido de restaurar MUST dejar los datos exactamente como estaban (FR-008, FR-009, SC-003); el acceso premium MUST no poder heredarse de un archivo (FR-003, SC-004).

**Scale/Scope**: tres historias de usuario, 12 requisitos funcionales, un repositorio nuevo, una regla pura, un `ChangeNotifier` y una sección nueva en Ajustes. Sin pantallas nuevas.

## Constitution Check

*GATE: verificado antes de la Fase 0 y revisado tras el diseño de la Fase 1.*

| Principio | Cómo lo cumple este plan | Estado |
|---|---|---|
| **I. Datos locales y privados** *(enmendado v3.0.0)* | Esta feature es exactamente lo que la enmienda del 2026-09-07 autoriza, y se mantiene dentro de sus cuatro condiciones: la app no transmite nada (genera un archivo y lo entrega a la hoja de compartir del sistema, D5), no hay servidor propio ni cuenta, no existe respaldo automático ni programado —el contrato del repositorio **excluye explícitamente** una API que lo permita— y el destino lo elige el usuario fuera de la app. Además el archivo sale sin la tabla de suscripción ni el diagnóstico de notificaciones (D4), que es contenido sensible que no necesita viajar. | PASS |
| **II. Exactitud monetaria (no negociable)** | El respaldo mueve el archivo entero: en ningún punto del camino se deserializa, convierte ni reformatea un monto. No hay ninguna oportunidad de que un centavo pase por un `double`, porque no hay ninguna conversión de por medio. | PASS |
| **III. Lógica financiera pura y probada** | La única regla con criterio propio de esta feature —si un archivo candidato es aceptable y por qué motivo no— se modela como función pura del dominio (`validarRespaldo`, D6), sin `dart:io` ni `sqflite`, y se prueba antes de implementarse con caso normal, límite y adverso. El manejo de archivos queda en `lib/datos/`, donde la guarda de pureza ya lo exige. | PASS |
| **IV. Claridad sobre sofisticación** | El rechazo de un archivo se explica con el motivo concreto (corrupto / no es de esta app / es de una versión más nueva), nunca con un "error" genérico: por eso el veredicto es un enum de cuatro valores y no un `bool`. El aviso previo a reemplazar dice con todas las letras qué se va a perder, en texto (FR-007). No se agrega ninguna pantalla nueva: es una sección más en Ajustes, donde el usuario ya va a buscar este tipo de cosas. | PASS |
| **V. Alcance individual, sin especulación** | Restaurar reemplaza todo, no combina copias ni resuelve conflictos entre dos versiones de un mismo mes — eso sería sincronización, que es justo lo que el principio descarta. Sin respaldos automáticos, sin recordatorios, sin export analítico: cada uno de ellos está descartado por escrito en las Assumptions de la spec. | PASS |

**Restricciones técnicas**: dos dependencias nuevas, justificadas en research.md D5 frente a la alternativa de escribir el canal nativo a mano, y con la comprobación concreta de que no abren red como tarea de implementación. La persistencia sigue versionada y ninguna migración cambia; al contrario, esta feature **reutiliza** las migraciones existentes en lugar de duplicarlas (D1). Interfaz en español.

**Flujo de desarrollo**: se respeta especificación → plan → tareas → implementación. `validarRespaldo` se escribe con su prueba antes que la implementación, como exige el Principio III.

**Nota de gobernanza**: esta feature quedó habilitada por la enmienda al Principio I aprobada el 2026-09-07 (constitución v3.0.0). Sin esa enmienda, el Constitution Check no pasaba: exportar es salida de datos del dispositivo y el principio original la prohibía sin enmienda explícita.

**Re-evaluación tras la Fase 1**: el diseño (data-model.md, contracts/) no introdujo ninguna desviación de lo evaluado arriba. La tabla de Complexity Tracking queda vacía.

## Project Structure

### Documentation (this feature)

```text
specs/005-respaldo-exportacion-datos/
├── plan.md                            # Este archivo
├── spec.md                            # Especificación
├── research.md                        # Fase 0 — decisiones D1–D6
├── data-model.md                      # Fase 1 — entidades, regla pura, archivo de respaldo
├── quickstart.md                      # Fase 1 — validación automática y manual
├── contracts/
│   └── repositorio-respaldo.md        # Fase 1 — contrato del único repositorio nuevo
├── checklists/
│   └── requirements.md                # Checklist de calidad de la spec
└── tasks.md                           # Fase 2 — lo genera /speckit-tasks, NO este comando
```

### Source Code (repository root)

```text
lib/
├── dominio/
│   ├── modelos/
│   │   └── respaldo.dart               # ResultadoValidacionRespaldo (enum),
│   │                                   # InformeRespaldo, ArchivoRespaldo
│   ├── calculos/
│   │   └── validacion_respaldo.dart    # validarRespaldo(...) — Dart puro
│   └── repositorios/
│       └── repositorio_respaldo.dart   # interfaz: exportar, inspeccionar, restaurar
├── datos/
│   ├── base_datos.dart                 # + reemplazarArchivo/reabrir para el swap de D3
│   ├── migraciones.dart                # solo se corrige el comentario desactualizado
│   │                                   # que dice que no existe respaldo
│   └── repositorios/
│       └── repositorio_respaldo_sqlite.dart  # copia, checkpoint, vaciado de las
│                                             # tablas que no viajan, swap todo-o-nada
└── ui/
    ├── estado/
    │   └── estado_respaldo.dart        # ChangeNotifier: exportar(), inspeccionar(),
    │                                   # restaurar(), y las fases de data-model.md §4
    └── pantallas/
        └── ajustes/
            └── seccion_respaldo.dart   # sección nueva en Ajustes: exportar,
                                        # restaurar y el aviso de reemplazo

test/
├── dominio/
│   └── validacion_respaldo_test.dart   # los cuatro veredictos, con límite y adverso
├── datos/
│   └── respaldo_test.dart              # ida y vuelta, migración de un respaldo v3,
│                                       # rechazos sin tocar datos, todo-o-nada, sidecars
├── dobles/
│   └── repositorios_en_memoria.dart    # + RepositorioRespaldoEnMemoria
└── ui/
    └── respaldo_test.dart              # confirmación previa al reemplazo, cancelar
                                        # no cambia nada, mensajes por motivo de rechazo
```

**Structure Decision**: misma arquitectura en capas que el resto del proyecto (`ui → datos → dominio → shared`), sin capas nuevas. La particularidad es que este repositorio opera sobre el **archivo** de la base y no sobre sus filas, así que es el único que necesita tocar el ciclo de vida de `BaseDatos` (cerrar, reemplazar, reabrir): esa capacidad se agrega ahí, en `lib/datos/base_datos.dart`, y no se replica en el repositorio, para que siga habiendo un solo lugar que sepa abrir la base. La sección de respaldo va dentro de la pantalla de Ajustes existente en vez de ser una pantalla propia, siguiendo el Principio IV: es una sección más, no un destino de navegación.

## Complexity Tracking

Sin violaciones que justificar: el Constitution Check pasa completo antes y después del diseño.
