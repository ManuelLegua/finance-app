# Contrato: `RepositorioSuscripcion`

**Feature**: 004-suscripcion-premium

Sigue las mismas reglas transversales que `001-gestion-sueldo-ahorro/contracts/repositorios.md`: interfaz en `lib/dominio/repositorios/`, implementación con sufijo `Sqlite`/`Billing` en `lib/datos/repositorios/`, y **ningún repositorio calcula reglas de negocio** — decidir si el acceso premium está vigente es del dominio (`EstadoSuscripcion.estaVigente`), no de este repositorio.

**Particularidad de este repositorio frente a los demás**: es el único que habla con un servicio externo (Google Play Billing), amparado por la enmienda al Principio I (v2.0.0). El resto de sus garantías son idénticas a cualquier otro repositorio del proyecto: la UI no conoce el SDK de facturación, solo esta interfaz.

```dart
Future<EstadoSuscripcion>        estadoCacheado();
Future<EstadoSuscripcion>        refrescar();
Future<List<OfertaSuscripcion>>  ofertasDisponibles();
Future<EstadoSuscripcion>        comprar(PlanSuscripcion plan);
Future<EstadoSuscripcion>        restaurar();
```

| Método | Garantía |
|---|---|
| `estadoCacheado()` | Lee la fila local (`suscripcion_premium`), sin tocar la red. Nunca falla por falta de conexión: si nunca hubo una fila, devuelve `EstadoSuscripcion` con `situacion = nunca`. |
| `refrescar()` | Consulta Google Play y actualiza la fila local con lo que responda. Si no hay conexión, **no lanza error**: devuelve el `estadoCacheado()` sin cambios (FR y edge case "sin conexión" de la spec). |
| `ofertasDisponibles()` | Consulta en vivo los planes y precios vigentes en Google Play (FR-005). Si no hay conexión, lanza `ErrorPersistencia.alLeer` con un mensaje que el paywall pueda mostrar con una opción de reintentar — a diferencia de `estadoCacheado()`, acá no hay nada útil que cachear (mostrar un precio viejo sería engañoso). |
| `comprar(plan)` | Lanza el flujo de compra de Google Play para el plan elegido. Al completarse, actualiza y devuelve el nuevo `EstadoSuscripcion`. Si el usuario cancela o Google rechaza la compra, devuelve el estado sin cambios (nunca lanza una excepción por una cancelación del usuario: es un flujo esperado, FR-008). |
| `restaurar()` | Le pide a Google Play las compras ya asociadas a la cuenta activa del dispositivo y actualiza el estado local. Si no encuentra ninguna, devuelve `EstadoSuscripcion` con `situacion = nunca` (FR-015): la UI decide cómo comunicar "no encontramos ninguna suscripción". |

**Idempotencia**: `comprar` y `restaurar` MUST poder llamarse más de una vez sin duplicar ningún efecto — una segunda confirmación de Google para la misma compra (edge case "la confirmación tarda") actualiza el mismo estado, no crea una segunda fila ni cobra dos veces. Como la tabla es de fila única (`id = 1`), esto lo garantiza la propia forma de la tabla: no hay dónde insertar un duplicado.

**Privacidad (FR-016)**: ningún método de esta interfaz recibe ni devuelve `Dinero`, `Deuda`, `Transaccion`, `AporteAhorro` ni ningún otro tipo del dominio financiero. Los únicos datos que cruzan la red son el identificador del producto/plan y el token de compra que la propia Billing Library gestiona.
