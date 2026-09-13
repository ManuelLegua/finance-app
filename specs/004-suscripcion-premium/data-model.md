# Data Model: Apoyo voluntario (propina)

**Revisado 2026-09-12** junto con la spec. El modelo anterior —`EstadoSuscripcion`,
`PlanSuscripcion`, `SituacionSuscripcion`, `OfertaSuscripcion` y la tabla
`suscripcion_premium`— **desaparece por completo**. Ver research.md D7, D8 y D9.

---

## 1. Lo que esta feature persiste

**Nada.**

No es una omisión: es la decisión D8. Una propina no concede ningún acceso, así
que no hay estado que consultar, cachear, vencer ni restaurar. El historial de
compras vive en Google Play, que es de quien es. La app no guarda si el usuario
apoyó, cuántas veces ni cuándo.

Esta es la primera feature del proyecto que no agrega ni una fila al SQLite. La
segunda cosa rara que hace con la base es la contraria: **quitarle una tabla**
(§3).

## 2. Valores en memoria

### `OfertaPropina` (`lib/dominio/modelos/propina.dart`)

Un monto que se puede dejar, tal como lo informa Google Play. No se persiste:
se consulta en vivo cada vez que se abre la pantalla de apoyo (FR-004).

| Campo | Tipo | Reglas |
|---|---|---|
| `id` | `String` | Identificador del producto en Google Play Console. Es lo único que la app conoce de antemano (§4). |
| `titulo` | `String` | Nombre que la tienda le da al producto, ya localizado. |
| `precioFormateado` | `String` | Precio ya formateado y localizado por Google Play (p. ej. `S/ 5.00`). |

**Por qué `precioFormateado` es `String` y no `Dinero`**: no es dinero que la
app calcule, sume ni guarde — es un precio que la tienda informa para mostrar
tal cual. Sobre este valor no se hace aritmética ni se parsea nada, así que el
Principio II no le aplica. Es el mismo criterio que tenía
`OfertaSuscripcion.precioFormateado` y es la única razón por la que un monto
puede vivir en un `String` en este proyecto.

### `ResultadoPropina` (enum)

Cómo terminó un intento de apoyar. Es un enum y no un `bool` porque son cuatro
desenlaces con tratamientos distintos, y el `switch` exhaustivo obliga a
manejarlos todos.

| Valor | Cuándo | Qué hace la UI |
|---|---|---|
| `completada` | Google confirmó el pago. | Agradece (FR-012). |
| `cancelada` | El usuario cerró el diálogo de Google. | **Nada**: no es un error (FR-008). |
| `pendiente` | Google aceptó pero todavía no confirma. | Lo dice; se acusará recibo al volver (FR-010). |
| `fallida` | La tienda rechazó la compra o no está disponible. | Muestra el motivo y deja reintentar (FR-011). |

## 3. Cambio de esquema: `suscripcion_premium` se elimina

`Esquema.version` pasa de **4 a 5**. El paso v4 → v5 es una sola sentencia:

```sql
DROP TABLE IF EXISTS suscripcion_premium;
```

**Es la primera migración destructiva del proyecto, y no viola D10.** La regla
es que ninguna migración destruya *información del usuario*; esta tabla nunca
tuvo ninguna: era la caché de lo que respondía Google Play sobre la vigencia de
la suscripción. Nada de lo que el usuario cargó a mano vive ahí.

`IF EXISTS` no es defensivo por costumbre: un respaldo restaurado puede venir
de una v1, v2 o v3, donde la tabla nunca existió, y esa migración también pasa
por acá.

La tabla sale además de `Esquema.creacion`, así que **una instalación nueva ya
no la crea**. Su DDL se conserva como constante porque el paso v3 → v4 lo sigue
necesitando: una base que venga de la v3 la crea y la migración siguiente la
borra. Es el mismo patrón que la tabla `ingreso` de la spec 001, que tampoco
está en `creacion` y solo existe en instalaciones que vienen de antes (D-C2 de
la spec 003).

### Consecuencia sobre el respaldo (spec 005)

| Antes | Después |
|---|---|
| `_tablasQueNoViajan = ['suscripcion_premium', 'notificacion_diagnostico']` | `_tablasQueNoViajan = ['notificacion_diagnostico']` |
| Al restaurar, `_descartarSuscripcionHeredada()` borraba la fila para que nadie se fabricara acceso pagado editando el archivo | Se elimina: la migración v4 → v5 borra la tabla entera, y de todos modos ya no hay acceso que fabricarse |

## 4. Los identificadores de producto

`lib/shared/constantes/propinas.dart` — Dart puro, verificado por
`test/pureza_test.dart`.

```dart
const List<String> idsDePropina = <String>[
  'propina_cafe',
  'propina_menu',
  'propina_generosa',
];
```

Es una **lista de datos, no un enum**, por el mismo criterio que
`origenesReconocidos` en la spec 002: agregar o quitar un monto es editar esta
lista y crear el producto en Play Console, sin migración de esquema ni tipo
nuevo. El orden de la lista es el orden en que se muestran.

La app no conoce ni el precio ni el nombre de cada uno: los pide a Google Play
y muestra lo que responda (FR-004). Un identificador que no exista en Play
Console simplemente no aparece, sin romper nada.
