# Contrato: `RepositorioPropinas`

**Feature**: 004-suscripcion-premium · **Revisión 2026-09-12**

Reemplaza a `repositorio-suscripcion.md`, que describía la interfaz de la
suscripción descartada.

Sigue las mismas reglas transversales que
`001-gestion-sueldo-ahorro/contracts/repositorios.md`: interfaz en
`lib/dominio/repositorios/`, implementación con sufijo `Billing` en
`lib/datos/repositorios/`, y ningún repositorio calcula reglas de negocio.

**Particularidad frente a los demás**: es el único que habla con un servicio
externo (Google Play Billing), amparado por la enmienda al Principio I
(v2.0.0). Y es el único que **no persiste nada**: no hay tabla detrás (D8).

```dart
Future<List<OfertaPropina>> ofertasDisponibles();
Future<ResultadoPropina>    apoyar(OfertaPropina oferta);
```

| Método | Garantía |
|---|---|
| `ofertasDisponibles()` | Consulta en vivo los montos y precios vigentes en Google Play, en el orden de `idsDePropina` (FR-004). Si la tienda no está disponible, **lanza** `ErrorPersistencia.alLeer` con un mensaje que la pantalla pueda mostrar junto a un reintento: no hay nada útil que cachear, y mostrar un precio viejo sería engañoso (FR-011). Un identificador que Play Console no reconozca se omite de la lista, sin fallar. **Antes de consultar, acusa recibo de cualquier compra pendiente de una sesión anterior** (FR-010). |
| `apoyar(oferta)` | Lanza el flujo de compra de Google Play para ese monto y devuelve cómo terminó. Acusa recibo de la compra completada antes de devolver `completada` (FR-010). Que el usuario cancele **no es un error**: devuelve `cancelada` sin lanzar (FR-008). |

**Lo que esta interfaz deliberadamente no tiene**, y por qué:

- **No hay `estadoCacheado()` ni `refrescar()`**: no existe un estado de apoyo.
  Apoyar no concede nada, así que no hay vigencia que consultar (D8).
- **No hay `restaurar()`**: restaurar compras es una exigencia de la política
  de Google Play para lo que concede algo. Una propina no concede nada, así que
  no hay nada que recuperar en un dispositivo nuevo (D8).
- **Ningún método devuelve "si el usuario apoyó"**: nada en la app puede
  depender de eso, y no exponerlo es la forma estructural de garantizar FR-002.

**Idempotencia**: acusar recibo de una compra ya acusada no MUST tener efecto
ni fallar. Como no hay estado local, no hay duplicado posible del lado de la
app: lo único repetible es la propia compra, que es precisamente lo que FR-007
permite.

**Privacidad (FR-009)**: ningún método recibe ni devuelve `Dinero`, `Deuda`,
`Transaccion`, `AporteAhorro` ni ningún otro tipo del dominio financiero. Lo
único que cruza la red es el identificador del producto y el token de compra
que gestiona la propia Billing Library.
