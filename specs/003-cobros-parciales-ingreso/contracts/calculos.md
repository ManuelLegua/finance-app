# Contrato — Capa de cálculo financiero (`lib/dominio/calculos/`)

**Feature**: 003-cobros-parciales-ingreso

Extiende el contrato de 001 ([calculos-dominio.md](../../001-gestion-sueldo-ahorro/contracts/calculos-dominio.md)) con una función nueva. Misma regla transversal: función **pura**, sin `flutter`, sin `sqflite`, sin `DateTime.now()` dentro; ninguna excepción por datos financieramente adversos, solo `ArgumentError` ante datos estructuralmente imposibles.

---

## `ingreso.dart`

```dart
Dinero? totalIngreso(List<CobroIngreso> cobros);
```

| Garantía | Requisito |
|---|---|
| `cobros.isEmpty` → `null`, nunca `Dinero.cero` | FR-005 |
| `cobros` no vacía → suma entera de `cobro.monto` para cada `cobro`, sin `double` | FR-003, Principio II |
| No depende del orden de `cobros`: sumar es conmutativo | — |
| No filtra ni agrupa por fecha — asume que **quien la llama** (`EstadoMes`) ya le pasó solo los cobros del mes que corresponde | — |

**Quién la llama**: `EstadoMes.ingreso` (getter), sobre `_cobros` — la lista que `EstadoMes.cargar()` obtiene de `RepositorioCobrosIngreso.porMes(_mes)`. Mismo patrón que `EstadoMes.cuotasVigentes` sobre `compromisoDeudasEnMes(_deudas, _mes)`: el estado guarda la lista cruda, el dominio puro deriva el total en cada lectura.

**Consumido sin cambios por**: `calcularResumenMes({required Dinero? ingreso, ...})` (001) — el parámetro `ingreso` sigue siendo `Dinero?`, ahora producido por `totalIngreso` en vez de leído directo de un repositorio. Ningún otro cálculo de 001 (déficit, disponible, sugerencia de ahorro) cambia de firma.
