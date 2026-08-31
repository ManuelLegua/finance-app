/// Normaliza el nombre de un comercio para que variantes de mayúsculas,
/// espacios y sufijos de sucursal se reconozcan como el mismo comercio
/// (FR-032, D-N7). Es una función pura y determinística: la misma entrada
/// siempre produce la misma salida.
///
/// **Alcance de "sufijo de sucursal" acá**: solo cubre los dos patrones que
/// se pueden reconocer sin arriesgar fusionar comercios que en realidad son
/// distintos — un código de local puramente numérico al final ("TOTTUS
/// 0234") y un segmento introducido por la palabra "SUC"/"SUCURSAL"
/// ("TOTTUS SUC SAN ISIDRO"). **No** cubre un nombre de sucursal pegado sin
/// ningún separador reconocible (p. ej. "PLAZA VEA SURCO" vs "PLAZA VEA SAN
/// ISIDRO" quedan como comercios distintos): separar por guion o asterisco
/// también partiría nombres de comercio legítimos que los usan (p. ej. "UBER
/// *EATS" es un servicio distinto de "UBER" a secas, no una sucursal). D-N7
/// ya anticipa que esto se ajusta con notificaciones reales de varios bancos
/// (D-N9, T034); hasta entonces, ampliar el alcance a ciegas es peor que
/// dejar esos casos sin fusionar.
String normalizarComercio(String comercioCrudo) {
  var normalizado = comercioCrudo.trim().toUpperCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  normalizado = _sinPalabraSucursal(normalizado);
  normalizado = _sinCodigoNumericoFinal(normalizado);
  return normalizado.trim();
}

final RegExp _palabraSucursal = RegExp(r'^(.+?)\s+SUC(?:URSAL)?\.?\s+.+$');

String _sinPalabraSucursal(String comercio) {
  final coincidencia = _palabraSucursal.firstMatch(comercio);
  return coincidencia == null ? comercio : coincidencia.group(1)!;
}

final RegExp _codigoNumericoFinal = RegExp(r'^(.+?)\s+\d+$');

String _sinCodigoNumericoFinal(String comercio) {
  final coincidencia = _codigoNumericoFinal.firstMatch(comercio);
  return coincidencia == null ? comercio : coincidencia.group(1)!;
}
