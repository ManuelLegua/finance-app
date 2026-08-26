# Contrato — Capa de cálculo financiero (`lib/dominio/calculos/`)

**Feature**: 001-gestion-sueldo-ahorro

Esta es la interfaz que la app expone hacia adentro: funciones **puras** de Dart, sin `flutter`, sin `sqflite`, sin `DateTime.now()` dentro. Reciben datos ya cargados y devuelven derivados. Es el contrato que las pruebas del Principio III verifican, y la prueba de guarda (D8) impide que se contamine.

**Regla transversal**: ninguna función lanza excepción por datos financieramente adversos (déficit, sobregiro, saldo negativo). Esos son estados legítimos que se **reportan** en el resultado. Solo se lanza `ArgumentError` ante datos estructuralmente imposibles (mes fuera de rango, número de cuotas < 1).

---

## `resumen_mes.dart`

```dart
ResumenMes calcularResumenMes({
  required Mes mes,
  required Dinero? ingreso,            // null = mes sin ingreso registrado
  required List<Obligacion> obligaciones,
  required List<Deuda> deudas,         // todas; la función filtra las vigentes
  required List<Transaccion> transacciones,
});
```

| Garantía | Requisito |
|---|---|
| `totalComprometido` = Σ obligaciones + Σ cuotas vigentes en `mes` | FR-016, FR-025 |
| `disponibleProyectado` = `ingreso - totalComprometido` | FR-026 |
| `disponibleReal` = `ingreso - gastoRealTotal` | FR-027 |
| `enDeficit` solo si `totalComprometido > ingreso`; con igualdad exacta es `false` y `faltante` es cero | FR-028, FR-030 |
| Con `ingreso == null`, `ingresoRegistrado` es `false` y no se emiten totales como si fueran válidos | HU2 esc. 4 |
| Toda suma es entera; ningún resultado pasa por `double` | FR-049 |

---

## `desglose_categorias.dart`

```dart
List<LineaCategoria> calcularDesglose({
  required Mes mes,
  required Dinero? ingreso,
  required List<Obligacion> obligaciones,
  required List<Deuda> deudas,
  required List<Transaccion> transacciones,
});
```

| Garantía | Requisito |
|---|---|
| Devuelve las líneas ordenadas por `gastado` descendente | FR-044 |
| Omite categorías sin presupuesto **ni** gasto en el mes | FR-047 |
| `Σ linea.gastado == calcularResumenMes(...).gastoRealTotal`, exacto | FR-046 |
| Marca `sobregirada` y `noPresupuestada` como campos, no como color | FR-011, FR-012, FR-029 |
| Las cuotas vigentes entran en la línea `tarjetaCredito` como presupuestado | FR-016 |
| `pesoIngresoBp == 0` cuando no hay ingreso, sin dividir entre cero | Edge case "ingreso cero o ausente" |

---

## `deudas.dart`

```dart
EstadoDeuda calcularEstadoDeuda(Deuda deuda, {required Mes mesRef});
Dinero      cuotaVigenteEnMes(Deuda deuda, Mes mes);   // Dinero.cero si no aporta
Dinero      compromisoDeudasEnMes(List<Deuda> deudas, Mes mes);
PanoramaDeuda calcularPanorama(List<Deuda> deudas, {required Mes mesRef});
```

| Garantía | Requisito |
|---|---|
| `cuotasPagadas = (mesRef - mesInicio)` acotado a `0..numCuotas` | D4, HU4 esc. 1 y 2 |
| `saldoPendiente = cuotaMensual * cuotasRestantes` | FR-018 |
| `mesUltimaCuota = mesInicio.mas(numCuotas - 1)` | FR-018 |
| Una deuda con `mesInicio > mesRef` aporta `Dinero.cero` al mes pero suma al `totalAdeudado` | FR-020, HU4 esc. 5 |
| Tras `mesUltimaCuota` no aporta y queda `saldada` | FR-019, HU4 esc. 4 |
| Con `mesSaldadaAnticipada` fijado: no aporta desde ese mes inclusive y `saldoPendiente == Dinero.cero` | FR-021, HU4 esc. 8 |
| `compromisoDeudasEnMes` es desglosable: la UI puede pedir la cuota deuda por deuda con `cuotaVigenteEnMes` | FR-017, HU4 esc. 3 |
| `numCuotas == 1` es válido | Edge case "deuda de una sola cuota" |
| `mesLibreDeDeudas` es `null` cuando no hay deudas activas | Edge case "sin deudas activas" |

---

## `ahorro.dart`

```dart
SugerenciaAhorro calcularSugerencia({
  required Configuracion config,
  required Dinero? ingreso,
  required Dinero disponibleProyectado,
  required bool enDeficit,
});

ProgresoAhorro calcularProgreso({
  required Dinero? metaDelMes,           // null = ese mes no tiene meta fijada
  required Dinero disponibleProyectado,
  required List<AporteAhorro> aportesDelMes,
  required Dinero acumuladoHistorico,
});

Dinero? proponerMetaDelMes({
  required Mes mesDestino,
  required List<(Mes, Dinero)> metasAnteriores,  // ordenadas por mes
});
```

| Garantía | Requisito |
|---|---|
| Regla `porcentaje`: `montoSugerido = ingreso.porPuntosBase(config.porcentajeBp)`, aritmética entera half-up | FR-033, HU5 esc. 1 |
| Si el sugerido excede el disponible: `excedeDisponible == true` y `montoAlcanzable == disponibleProyectado` | FR-034, HU5 esc. 2 |
| Regla `remanente`: `montoSugerido == disponibleProyectado` | FR-033, HU5 esc. 3 |
| En déficit: `noCorresponde == true` y no se emite monto sugerido | FR-037, HU5 esc. 6 |
| Sin ingreso registrado: `noCorresponde == true`; no se calculan porcentajes | Edge case "ingreso cero o ausente" |
| `metaAlcanzable` y `recorteNecesario` según meta vs. disponible | FR-035, FR-036 |
| Varios aportes del mes se suman; el excedente sobre la meta se reporta | FR-039, FR-040, HU5 esc. 8 |
| `meta == null` ⇒ sin veredicto de progreso, pero sí acumulado | Edge case "meta no fijada" |
| Un aporte mayor que el disponible se acepta y se informa, no se bloquea | FR-042 |
| La meta es **la del mes evaluado**: un mes pasado se juzga contra la suya, no contra la vigente hoy | FR-054, HU5 esc. 12 |
| `proponerMetaDelMes` devuelve la meta del último mes anterior que tuvo una, o `null` si ninguno; **nunca guarda** | FR-053, HU5 esc. 13 |

---

## `cierre_mes.dart`

```dart
EstadoCierre estadoDe(Mes mes, {required DateTime hoy, required int diasGraciaCierre});
bool puedeRegistrarEn(Mes mes, {required DateTime hoy, required int diasGraciaCierre});
bool puedeEditarEn(Mes mes, {required DateTime hoy});
```

`hoy` se recibe como parámetro, nunca se lee con `DateTime.now()` dentro: es lo que hace la regla testeable sin manipular el reloj del sistema.

| Garantía | Requisito |
|---|---|
| El mes en curso admite registrar, editar y eliminar | FR-052 |
| El mes anterior admite **registrar** mientras `hoy.day <= diasGraciaCierre` | FR-055 |
| El mes anterior **nunca** admite editar ni eliminar, ni siquiera en gracia | FR-056 |
| Cualquier mes anterior al anterior es solo lectura absoluta | FR-052 |
| `diasGraciaCierre == 0` cierra el mes anterior de inmediato | FR-055 |
| `estadoDe` devuelve un `motivo` legible para mostrar sin depender del color | FR-058 |
| Las deudas quedan fuera de esta regla: `deudas.dart` no la consulta | FR-057 |

## `presupuesto.dart`

```dart
List<Obligacion> proponerFijasDelMesAnterior({
  required Mes mesDestino,
  required List<Obligacion> obligacionesMesAnterior,
});

ResultadoValidacion validarMonto(String entrada);
```

| Garantía | Requisito |
|---|---|
| Propone copias de las obligaciones `fija` del mes anterior, con el mismo monto, para que el usuario confirme o ajuste; nunca las guarda por su cuenta | FR-006, HU1 esc. 4 |
| Las `variable` no se proponen | FR-004 |
| Las cuotas de deuda **no** se proponen: se derivan solas | D3, edge case "mes sin datos" |
| `validarMonto` rechaza vacío, no numérico, negativo y más de dos decimales, devolviendo el motivo en español | FR-005, HU1 esc. 5 |
| `validarMonto` acepta hasta siete cifras enteras | Edge case "montos grandes" |

---

## Tipos de resultado

Todos inmutables, con `==`/`hashCode` por valor para que las pruebas comparen resultados completos en vez de campo por campo. Definidos en `lib/dominio/modelos/` y descritos en [data-model.md](../data-model.md) §3.
