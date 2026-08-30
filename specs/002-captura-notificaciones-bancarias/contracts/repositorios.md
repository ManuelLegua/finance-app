# Contrato — Repositorios y servicio de escucha (`lib/datos/`)

**Feature**: 002-captura-notificaciones-bancarias

Misma convención que 001: interfaz en `lib/dominio/repositorios/`, implementación con sufijo `Sqlite` en `lib/datos/repositorios/`, dobles en memoria para pruebas de widget. Ningún repositorio interpreta notificaciones ni decide categorías — eso vive en `lib/dominio/interpretes/` y en el propio flujo de confirmación.

---

## `RepositorioPendientes`

```dart
abstract interface class RepositorioPendientes {
  Future<List<ConsumoPendiente>> todos();            // orden: fecha DESC (FR-021)
  Future<ResumenPendientes> resumen();                // FR-022
  Future<int?> insertar(ConsumoPendiente pendiente);  // null si ya existía (ver abajo)
  Future<void> eliminar(int id);                      // confirmar o descartar (FR-020, FR-025)
}
```

| Garantía | Requisito |
|---|---|
| `todos()` ordena del más reciente al más antiguo | FR-021 |
| `insertar` es un upsert silencioso sobre `(origenPaquete, notificacionId)`: una notificación reeditada no produce una segunda fila ni un error | FR-015, D-N5 |
| `insertar` de dos pendientes con distinto `notificacionId` los conserva a ambos aunque monto y comercio coincidan | FR-016 |
| Ningún método construye una `Transaccion` ni una `Deuda`: eso lo hace el flujo de confirmación en `lib/ui/estado/`, reutilizando los repositorios de 001, igual que la regla de cierre nunca vive en un repositorio | Simetría con 001 |

## `RepositorioAsociaciones`

```dart
abstract interface class RepositorioAsociaciones {
  Future<Categoria?> categoriaDe(String comercioNormalizado);  // FR-030
  Future<void> asociar(String comercioNormalizado, Categoria categoria); // FR-029, FR-031 (upsert)
  Future<List<AsociacionComercio>> todas();           // FR-034
  Future<void> eliminar(String comercioNormalizado);   // FR-034
}
```

| Garantía | Requisito |
|---|---|
| `asociar` sobre un comercio ya asociado reemplaza la categoría, no la duplica | FR-031 |
| `categoriaDe` de un comercio nunca visto es `null`, no una categoría por defecto inventada | FR-033 |

## `RepositorioDiagnostico`

```dart
abstract interface class RepositorioDiagnostico {
  Future<List<NotificacionDiagnostico>> todos();  // orden: fecha DESC
  Future<void> insertar(NotificacionDiagnostico entrada);
  Future<void> eliminar(int id);
  Future<void> vaciar();                          // FR-018 "borrable"
}
```

## `ServicioEscuchaNotificaciones` (`lib/datos/notificaciones/`)

No es un repositorio — envuelve el plugin de la plataforma (D-N1). Es la única pieza de esta feature con código específico de Android.

```dart
abstract interface class ServicioEscuchaNotificaciones {
  Future<bool> permisoConcedido();
  Future<void> abrirAjustesDePermiso();      // FR-002
  Future<void> activar();                    // arranca el servicio + guarda captura_notificaciones_activa=1
  Future<void> desactivar();                 // detiene el servicio + guarda captura_notificaciones_activa=0 (FR-005)
  EstadoCaptura estadoActual();              // combina permiso real + interruptor (FR-003)
}
```

| Garantía | Requisito |
|---|---|
| `estadoActual()` refleja el permiso real del sistema en cada llamada, nunca un valor cacheado de una sesión anterior | FR-003 |
| `desactivar()` detiene el procesamiento de notificaciones nuevas sin borrar `ConsumoPendiente`, `Transaccion` ni `AsociacionComercio` existentes | FR-005, edge case "desactivar la captura" |
| En una plataforma que no sea Android, esta implementación no se instancia — el cascarón de navegación ni ofrece la pantalla (D-N8) | FR-007 |

**Callback headless** (`lib/datos/notificaciones/callback_headless.dart`): la función marcada `@pragma('vm:entry-point')` que el plugin invoca sin UI corre el intérprete correspondiente y escribe directo con `RepositorioPendientes`/`RepositorioDiagnostico` — abre su propia conexión a la base (D1 de 001 ya soporta múltiples aperturas). No importa nada de `lib/ui/`.
