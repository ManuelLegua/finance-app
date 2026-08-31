# Phase 1 — Modelo de datos: Cobros parciales de ingreso

**Feature**: 003-cobros-parciales-ingreso | **Fecha**: 2026-08-30

Deriva de las *Key Entities* de [spec.md](./spec.md) y de las decisiones D-C1 a D-C6 de [research.md](./research.md). Reemplaza la entidad `Ingreso` de 001 (un monto único por mes, sin consumidores reales fuera de su propio archivo — D-C5) por `CobroIngreso`, con la misma forma que `AporteAhorro`.

---

## 1. Entidad persistida

### `CobroIngreso`

Un cobro de sueldo, con su propia fecha y monto (FR-001). El mes al que pertenece se deriva de la fecha, igual que `Transaccion` y `AporteAhorro` — nunca del mes que el usuario tenga abierto (FR-002).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `int?` | `null` mientras no esté guardado; autoincremental al guardarlo. |
| `fecha` | `DateTime` | Solo fecha, sin hora — mismo criterio que `AporteAhorro.fecha`. Determina el mes (`Mes.deFecha`, FR-002) y queda sujeta a la regla de cierre de ese mes (FR-006). |
| `monto` | `Dinero` | `> 0`. Entero de centavos, nunca `double` (Principio II). |

**No lleva** nombre, etiqueta ni tipo ("quincena", "fin de mes") — D-C1: ningún acceptance scenario lo pide, y `AporteAhorro` ya resuelve el mismo problema sin ese campo.

**Invariante**: dos `CobroIngreso` con la misma fecha en el mismo mes son válidos y se suman igual que dos gastos del mismo día (edge case de la spec) — `fecha` no es una clave, `id` sí.

---

## 2. Derivado (nunca se guarda)

### `totalIngreso(List<CobroIngreso> cobros) -> Dinero?`

El ingreso total de un mes — lo que hoy consumen sin cambios `ResumenMes.ingreso`, el disponible proyectado, el disponible real, el estado de déficit y la sugerencia de ahorro (FR-003).

| Garantía | Requisito |
|---|---|
| `cobros` vacía → `null`, nunca `Dinero.cero` — un mes sin ningún cobro es "ingreso sin registrar", no un sueldo de cero | FR-005 |
| `cobros` no vacía → suma entera de todos los montos, sin pasar por `double` | FR-003, Principio II |
| Determinística: el mismo conjunto de cobros produce siempre el mismo total, sin depender del orden de la lista | — |
| Con un único cobro, el resultado es idéntico al de un `Ingreso` de 001 con ese mismo monto (SC-003) | FR-007, SC-003 |

Ver contrato completo en [contracts/calculos.md](./contracts/calculos.md).

---

## 3. Esquema SQL — migración incremental

Mismo criterio que 002 (D10 de 001): `onUpgrade` agrega tablas, nunca destruye. Este es el paso que sube `Esquema.version` de 2 a 3.

```sql
CREATE TABLE cobro_ingreso (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha           TEXT    NOT NULL,
  mes_ordinal     INTEGER NOT NULL,
  monto_centavos  INTEGER NOT NULL CHECK (monto_centavos > 0)
);

CREATE INDEX idx_cobro_ingreso_mes ON cobro_ingreso(mes_ordinal);

-- Migra cada ingreso ya guardado a un cobro equivalente, con fecha el primer
-- día de su mes (D-C2, Assumptions de la spec) — es la única fecha razonable
-- cuando el dato original nunca tuvo una.
INSERT INTO cobro_ingreso (fecha, mes_ordinal, monto_centavos)
SELECT
  printf('%04d-%02d-01', mes_ordinal / 12, mes_ordinal % 12 + 1),
  mes_ordinal,
  monto_centavos
FROM ingreso;
```

**La tabla `ingreso` no se toca ni se borra** (D-C2): queda en el esquema, con sus filas intactas, sin que ninguna ruta de la app vuelva a leerla ni escribirla después de esta migración. `mes_ordinal` en `cobro_ingreso` es igual que en `transaccion`/`aporte_ahorro` — columna derivada de `fecha` en toda ruta de escritura, presente para poder indexar por mes.

**`RepositorioMeses` (`lib/datos/repositorios/repositorio_meses_sqlite.dart`)** cambia la fuente `ingreso` de su `UNION` a `cobro_ingreso` (D-C6) — cualquier mes con datos migrados ya tiene su fila ahí, así que la consulta no pierde cobertura.
