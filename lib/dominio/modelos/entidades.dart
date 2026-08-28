/// Entidades emisoras de tarjetas del Perú (FR-060).
///
/// **Lista local, sin API** (D14). No existe un servicio público confiable con
/// el padrón peruano: la SBS y el BCRP publican portales web de consulta, no
/// endpoints documentados, y habría que scrapear HTML sujeto a cambios sin
/// aviso. El conjunto son unas quince entidades que cambian rarísimo, así que
/// vivir en el código funciona sin conexión y no obliga a enmendar el
/// Principio I.
///
/// El usuario puede escribir una que no esté: la lista sugiere, no restringe.
abstract final class EntidadesPeru {
  static const List<String> sugeridas = <String>[
    'BCP',
    'Interbank',
    'BBVA',
    'Scotiabank',
    'Banco Falabella',
    'Banco Ripley',
    'Banco Pichincha',
    'BanBif',
    'Mibanco',
    'Banco de la Nación',
    'Caja Arequipa',
    'Caja Huancayo',
    'Oh!',
    'Yape',
    'Plin',
  ];
}
