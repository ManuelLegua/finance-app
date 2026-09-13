/// Los montos de propina que se ofrecen, por su identificador en Google Play
/// Console (spec 004 revisada, data-model.md §4).
///
/// Es una **lista de datos y no un enum**, por el mismo criterio que
/// `origenesReconocidos` en la spec 002: agregar o quitar un monto es editar
/// esta lista y dar de alta el producto en Play Console, sin migración de
/// esquema ni tipo nuevo. El orden de la lista es el orden en que se muestran.
///
/// La app **no conoce ni el precio ni el nombre** de cada uno: los pide a
/// Google Play y muestra lo que responda (FR-004). Un identificador que la
/// tienda no reconozca simplemente no aparece, sin romper nada.
///
/// Los productos MUST estar dados de alta como **consumibles**, no como
/// compras únicas: de eso depende poder apoyar más de una vez (FR-007).
const List<String> idsDePropina = <String>[
  'propina_cafe',
  'propina_menu',
  'propina_generosa',
];
