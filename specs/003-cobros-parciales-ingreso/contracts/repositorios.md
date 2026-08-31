# Contrato — Repositorio de cobros de ingreso (`lib/datos/`)

**Feature**: 003-cobros-parciales-ingreso

Misma convención que 001 y 002: interfaz en `lib/dominio/repositorios/`, implementación con sufijo `Sqlite` en `lib/datos/repositorios/`, doble en memoria para pruebas de widget. Ningún repositorio calcula el total del mes — eso lo deriva `totalIngreso` en `lib/dominio/calculos/ingreso.dart` (ver [calculos.md](./calculos.md)); el repositorio solo entrega y guarda filas.

---

## `RepositorioCobrosIngreso`

Reemplaza a `RepositorioIngreso` de 001 (eliminado, D-C5 de research.md).

```dart
abstract interface class RepositorioCobrosIngreso {
  Future<List<CobroIngreso>> porMes(Mes mes);   // orden: fecha ASC (FR-008)
  Future<int> insertar(CobroIngreso cobro);      // devuelve el id asignado
  Future<void> actualizar(CobroIngreso cobro);   // ArgumentError si no tiene id
  Future<void> eliminar(int id);                 // un id inexistente es no-op
}
```

| Garantía | Requisito |
|---|---|
| `porMes` ordena por fecha ascendente — el detalle se lee como llegaron los cobros dentro del mes | FR-008 |
| `insertar`/`actualizar`/`eliminar` no calculan ni verifican el total del mes: eso es responsabilidad de quien llama (`EstadoMes`), leyendo `totalIngreso` después de recargar | — |
| Ningún método aplica la regla de cierre de mes: eso vive en `EstadoMes._escribir`, igual que para `Transaccion` (D-C4) — duplicarla acá crearía dos verdades que se desincronizan (mismo argumento que ya usa `contracts/repositorios.md` de 001 para `RepositorioIngreso` original) | FR-006 |
| Mismo shape que `RepositorioAhorro` para `AporteAhorro` (`aportesPorMes`/`insertarAporte`/`actualizarAporte`/`eliminarAporte`), sin las partes de meta que no aplican acá | — |

## `RepositorioMeses` (sin cambio de interfaz, cambia su fuente SQL)

`mesesRegistrados()`/`tieneDatos(Mes)` siguen con la misma firma; la implementación `Sqlite` cambia la rama `ingreso` de su `UNION` interno a `cobro_ingreso` (D-C6). Ningún consumidor de `RepositorioMeses` necesita saberlo — es un detalle de `RepositorioMesesSqlite`.

## Qué se elimina

`RepositorioIngreso`, `RepositorioIngresoSqlite`, `RepositorioIngresoEnMemoria` y el modelo `Ingreso` (`lib/dominio/modelos/ingreso.dart`) se borran junto con sus pruebas dedicadas (D-C5) — no quedan como código muerto ni como capa de compatibilidad, porque no tienen consumidores reales que proteger.
