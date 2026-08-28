# Contrato — Repositorios y persistencia (`lib/datos/`)

**Feature**: 001-gestion-sueldo-ahorro

Los repositorios son la única puerta entre SQLite y el resto de la app. Devuelven entidades del dominio (§2 de [data-model.md](../data-model.md)), nunca `Map<String, Object?>` ni filas crudas. La UI no conoce SQL; el dominio no conoce repositorios.

**Regla transversal**: ningún repositorio calcula reglas financieras. Suma en SQL solo cuando el resultado es un total plano de filas guardadas; todo lo que dependa de deudas, déficit o ahorro pasa por `lib/dominio/calculos/`.

**Interfaz e implementación separadas**: cada repositorio se declara como
`abstract interface class` en `lib/dominio/repositorios/` y se implementa en
`lib/datos/repositorios/` con el sufijo `Sqlite`. Las capas de arriba dependen
de la interfaz, nunca de la implementación.

Vive en `lib/dominio/` y no en `lib/shared/` por la dirección de las
dependencias: las firmas hablan de `Obligacion`, `Ingreso` y `Configuracion`,
que son modelos del dominio. Ponerlas en `shared/` obligaría a que `shared/`
importe de `dominio/`, invirtiendo la regla `ui → datos → dominio → shared`.
Es la ubicación habitual de un puerto en arquitectura hexagonal: el puerto
pertenece al dominio, el adaptador a la infraestructura.

**Motivo, para que no parezca ceremonia**: las pruebas de widget no pueden
usar SQLite. `sqflite_common_ffi` no completa dentro del reloj falso de
`testWidgets` y la prueba se cuelga en vez de fallar. La interfaz permite
dobles en memoria para probar pantallas y para probar la lógica de
`lib/ui/estado/`, que decide si una escritura está permitida según el cierre
del mes — una decisión que toca dinero y merece pruebas propias.

**Lo que esto NO cambia**: las pruebas de `test/datos/` siguen corriendo
contra SQLite real. El contrato se verifica contra la base de verdad; los
dobles solo se usan donde el comportamiento de la base no es lo que se está
probando. Si un doble se desincroniza del real, es la suite de datos la que
tiene que atraparlo.

**Regla de cierre**: los repositorios **no** validan si un mes está abierto, en gracia o cerrado. Esa decisión es de `cierre_mes.dart` y la aplica la capa de estado antes de llamar a la escritura. Un repositorio que además validara el cierre duplicaría la regla en dos sitios que se desincronizan. La única excepción de negocio la fija FR-057: las deudas se editan siempre, sin consultar el cierre.

---

## `BaseDatos`

```dart
class BaseDatos {
  static const int versionEsquema = 1;
  Future<Database> abrir();                       // crea, migra y activa foreign_keys
  Future<void> cerrar();
}
```

| Garantía | Requisito |
|---|---|
| `onCreate` construye el esquema de la §5 del modelo de datos | — |
| `onUpgrade` aplica pasos incrementales; nunca borra ni recrea tablas con datos | Constitución, restricción de persistencia |
| `PRAGMA foreign_keys = ON` en cada apertura | Integridad de `deuda.tarjeta_id` |
| La base vive en el directorio privado de la app; no se escribe nada fuera del dispositivo | Principio I |

---

## `RepositorioIngreso`

```dart
Future<Dinero?> obtener(Mes mes);                 // null = mes sin ingreso registrado
Future<void>    guardar(Mes mes, Dinero monto);   // inserta o reemplaza
Future<void>    eliminar(Mes mes);
```

`obtener` distingue "no registrado" (`null`) de "cero": la app pide registrar el ingreso en vez de mostrar totales en cero (HU2 esc. 4).

---

## `RepositorioObligaciones`

```dart
Future<List<Obligacion>> porMes(Mes mes);
Future<List<Obligacion>> fijasDeMes(Mes mes);     // insumo de la precarga
Future<int>  insertar(Obligacion obligacion);     // devuelve el id asignado
Future<void> actualizar(Obligacion obligacion);
Future<void> eliminar(int id);
Future<void> insertarLote(List<Obligacion> obligaciones);  // confirmación de la precarga, en una transacción
```

| Garantía | Requisito |
|---|---|
| `porMes` devuelve solo obligaciones guardadas; las cuotas de deuda **no** aparecen aquí | D3 |
| `insertarLote` es atómico: o entran todas las fijas precargadas o ninguna | FR-006 |
| Editar o eliminar deja los totales recalculables de inmediato al releer el mes | FR-002, HU1 esc. 3 |

---

## `RepositorioTransacciones`

```dart
Future<List<Transaccion>> porMes(Mes mes);        // orden: fecha DESC, id DESC
Future<int>  insertar(Transaccion transaccion);
Future<void> actualizar(Transaccion transaccion);
Future<void> eliminar(int id);
```

| Garantía | Requisito |
|---|---|
| `mes_ordinal` se deriva de `fecha` al escribir; una transacción con fecha de otro mes se guarda en el mes de su fecha | FR-008, edge case "gasto con fecha fuera del mes" |
| `porMes` ordena por fecha descendente, desempatando por id descendente para que el orden sea estable | FR-013, HU3 esc. 6 |
| Actualizar la fecha reubica la transacción de mes sin dejar rastro en el anterior | FR-008 |

---

## `RepositorioConfiguracion`

```dart
Future<Configuracion> obtener();                  // crea la fila por defecto si no existe
Future<void>          guardar(Configuracion config);
```

| Garantía | Requisito |
|---|---|
| Por defecto: regla `porcentaje` al 20% y 5 días de gracia, sin obligar a configurar antes de usar la app | FR-031, FR-032, FR-055 |

## `RepositorioTarjetas`

```dart
Future<List<Tarjeta>> todas();
Future<List<Tarjeta>> deCredito();                // las únicas que admiten deudas en cuotas
Future<int>  insertar(Tarjeta tarjeta);
Future<void> actualizar(Tarjeta tarjeta);
Future<void> eliminar(int id);                    // falla si tiene deudas asociadas
```

| Garantía | Requisito |
|---|---|
| Cada tarjeta lleva nombre, entidad emisora y tipo | FR-059 |
| `eliminar` rechaza la operación cuando la tarjeta tiene deudas: la integridad referencial no se resuelve borrando en cascada datos financieros del usuario | FR-059 |
| `deCredito` es lo que alimenta el selector del formulario de deuda | FR-061 |
| La lista de entidades emisoras **no** se consulta aquí: es una constante del dominio, sin acceso a red | FR-060, Principio I |

---

## `RepositorioDeudas`

```dart
Future<List<Deuda>> todas();
Future<List<Deuda>> activas();                    // sin mes_saldada_ordinal
Future<List<Deuda>> porTarjeta(int tarjetaId);
Future<int>  insertar(Deuda deuda);
Future<void> actualizar(Deuda deuda);             // recálculo implícito de todos los meses
Future<void> marcarSaldada(int id, Mes mes);
Future<void> eliminar(int id);
```

| Garantía | Requisito |
|---|---|
| No existe tabla de cuotas: actualizar una deuda es **una** escritura y todos los meses quedan correctos al recalcularse | FR-023, D3 |
| `marcarSaldada` solo fija `mes_saldada_ordinal`; no toca transacciones reales ya registradas | FR-021, edge case "edición retroactiva" |
| `todas` incluye las de inicio futuro, para el total adeudado | FR-020, FR-022 |

---

## `RepositorioAhorro`

```dart
Future<Dinero?>            metaDeMes(Mes mes);    // null = mes sin meta fijada
Future<void>               guardarMeta(Mes mes, Dinero monto);
Future<void>               eliminarMeta(Mes mes);
Future<List<(Mes, Dinero)>> metasHasta(Mes mes);  // insumo de la propuesta, orden cronológico

Future<List<AporteAhorro>> aportesPorMes(Mes mes);
Future<Dinero>             acumuladoHistorico();
Future<List<(Mes, Dinero)>> historialPorMes(Mes desde, Mes hasta);
Future<int>  insertarAporte(AporteAhorro aporte);
Future<void> actualizarAporte(AporteAhorro aporte);
Future<void> eliminarAporte(int id);
```

| Garantía | Requisito |
|---|---|
| `metaDeMes` distingue "sin meta" (`null`) de "meta en cero"; cada mes conserva la suya | FR-035, FR-054 |
| `acumuladoHistorico` suma con `SUM()` sobre enteros; nunca sobre `REAL` | FR-041, Principio II |
| `historialPorMes` incluye los meses del rango con aportes; los meses sin aportes los completa la capa de dominio con `S/ 0.00`, no se inventan filas | FR-043 |
| Editar o eliminar un aporte recalcula mes y acumulado en la siguiente lectura | FR-052, HU5 esc. 10 |

---

## `RepositorioMeses`

```dart
Future<List<Mes>> mesesRegistrados();             // todo mes con ingreso, obligación, transacción o aporte
Future<bool>      tieneDatos(Mes mes);
```

Sostiene FR-051 (conservar y poder consultar los meses registrados) y la detección de "mes nuevo" que dispara la propuesta de precarga (FR-006).

---

## Errores

| Situación | Comportamiento |
|---|---|
| Violación de `CHECK` o de FK | Excepción de `sqflite` envuelta en `ErrorPersistencia` con contexto legible; nunca se muestra el SQL crudo al usuario |
| Id inexistente en `actualizar`/`eliminar` | No-op silencioso: el usuario ya no ve ese registro |
| Base corrupta o ilegible al abrir | Se propaga; la app muestra un estado de error explícito en vez de arrancar con datos vacíos que el usuario confundiría con pérdida silenciosa |
