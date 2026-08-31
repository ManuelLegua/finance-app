# Quickstart — Validar la feature 003

**Feature**: 003-cobros-parciales-ingreso | **Fecha**: 2026-08-30

Guía para comprobar que registrar el sueldo en varios cobros hace lo que dice la spec. A diferencia de 002, no es exclusiva de Android — corre en cualquier plataforma de la app. No contiene código de implementación: eso pertenece a `tasks.md`.

---

## Requisitos previos

Los mismos que 001 (`CLAUDE.md` § Entorno). No hace falta ningún dispositivo Android real ni `adb` — a diferencia de 002, esta feature no toca nada específico de plataforma.

---

## Puesta en marcha

```powershell
flutter pub get
flutter analyze
flutter test              # dominio, datos y UI de esta feature corren junto con las de 001/002
flutter run
```

---

## Migración desde una base existente (SC-004)

Antes de tocar la UI, verificar que una base con el esquema anterior (`Esquema.version == 2`, con filas en `ingreso`) sube a la versión 3 sin perder ningún mes:

1. Correr `flutter test test/datos/base_datos_test.dart` — ahí vive la prueba de la migración v2→v3 (mismo patrón que la v1→v2 de 002 en `test/datos/migracion_002_test.dart`): crear una base en v2 con dos o tres meses de `ingreso`, migrar a v3, y verificar que `cobro_ingreso` tiene un cobro por cada mes migrado, con el mismo monto y con fecha el primer día de ese mes.
2. Confirmar en la misma prueba que la tabla `ingreso` sigue existiendo con sus filas intactas (D-C2) — no es una prueba de que se borró, es una prueba de que **no** se borró.

---

## Recorrido manual

1. **US1 — Dos cobros en el mismo mes** → Presupuesto → registrar un cobro de S/ 960.00 con fecha 15, y otro de S/ 1,040.00 con fecha 30, del mismo mes. El total que muestra la tarjeta de ingreso debe ser S/ 2,000.00.
2. **Sin dividir el sueldo** → en un mes distinto, registrar un único cobro de S/ 2,000.00 → el comportamiento (tarjeta, resumen, sugerencia de ahorro) debe ser indistinguible del de un `Ingreso` único de 001 (SC-003) — comparar contra un mes de antes de esta feature si hay datos de referencia.
3. **US2 — Detalle de los cobros** → abrir la sección de ingreso del presupuesto del mes con dos cobros → deben listarse ambos por separado, con su fecha y monto, además del total arriba (FR-008).
4. **US3 — Corregir un cobro puntual** → con los dos cobros de S/ 960.00 y S/ 1,040.00, corregir el segundo a S/ 1,000.00 → el total pasa a S/ 1,960.00 y el primer cobro (S/ 960.00) queda sin cambios.
5. **US3 — Eliminar uno de varios** → eliminar uno de los dos cobros → el ingreso del mes queda como el monto del cobro restante, no en cero ni "sin registrar".
6. **US3 — Eliminar el único cobro del mes** → con un solo cobro, eliminarlo → el mes vuelve a "ingreso sin registrar" (mismo texto y comportamiento que HU2 escenario 4 de 001, no un total de S/ 0.00).
7. **Cierre de mes (FR-006)** → con los días de gracia en 0 (Ajustes, igual que el recorrido de 001), navegar al mes anterior e intentar registrar un cobro ahí → debe rechazarse con el mismo mensaje que un gasto rezagado fuera de la ventana de gracia.
8. **Ventana de gracia** → con los días de gracia configurados (por defecto 5) y dentro de esa ventana, registrar un cobro con fecha del mes anterior → debe aceptarse, y una vez guardado no debe poder editarse ni eliminarse (FR-056 de 001, heredado por FR-006 de esta spec).
