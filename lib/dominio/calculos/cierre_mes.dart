import 'package:finanzas/dominio/modelos/estado_cierre.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Regla de cierre de meses (FR-052, FR-055 – FR-058).
///
/// D13: el estado se **calcula** desde la fecha, no se guarda. Un cierre
/// persistido exigiría un proceso que corra al cambiar de mes; si el usuario
/// no abre la app durante seis semanas ese proceso nunca corrió y el estado
/// queda mintiendo. Derivarlo es correcto siempre.
///
/// `hoy` entra como parámetro y nunca se lee con `DateTime.now()`: es lo que
/// permite probar la ventana de gracia con fechas fijas en vez de manipular
/// el reloj del sistema. `test/pureza_test.dart` lo verifica.
///
/// **Las deudas quedan fuera de esta regla.** Corregir una deuda recalcula
/// las cuotas derivadas de todos los meses, cerrados incluidos, porque la
/// cuota nunca fue un dato del mes sino un derivado de la deuda (FR-057, D3).

const int _diasGraciaMinimo = 0;
const int _diasGraciaMaximo = 28;

/// En qué situación está [mes] respecto de la edición.
EstadoCierre estadoDe(
  Mes mes, {
  required DateTime hoy,
  required int diasGraciaCierre,
}) {
  _validarDiasGracia(diasGraciaCierre);

  final mesActual = Mes.deFecha(hoy);

  // Los meses futuros se tratan como abiertos: el usuario planifica en ellos.
  if (mes >= mesActual) {
    return const EstadoCierre(situacion: SituacionMes.abierto);
  }

  final esElAnterior = mes == mesActual.anterior;
  if (esElAnterior && hoy.day <= diasGraciaCierre) {
    return EstadoCierre(
      situacion: SituacionMes.enGracia,
      motivo:
          'El mes $mes ya cerró. Hasta el día $diasGraciaCierre podés '
          'registrar pagos con fecha de ese mes, pero una vez guardados no '
          'se pueden editar ni eliminar.',
    );
  }

  return EstadoCierre(
    situacion: SituacionMes.cerrado,
    motivo:
        'El mes $mes está cerrado y no admite cambios. Lo único que puede '
        'modificarlo es corregir una deuda, porque sus cuotas se calculan a '
        'partir de la deuda y no se guardan mes a mes.',
  );
}

/// Si se puede **crear** un registro con fecha de [mes].
bool puedeRegistrarEn(
  Mes mes, {
  required DateTime hoy,
  required int diasGraciaCierre,
}) =>
    estadoDe(mes, hoy: hoy, diasGraciaCierre: diasGraciaCierre).admiteRegistrar;

/// Si se puede **editar o eliminar** un registro de [mes].
///
/// No depende de los días de gracia: la gracia habilita registrar, nunca
/// editar (FR-056).
bool puedeEditarEn(Mes mes, {required DateTime hoy}) => mes >= Mes.deFecha(hoy);

void _validarDiasGracia(int dias) {
  if (dias < _diasGraciaMinimo || dias > _diasGraciaMaximo) {
    throw ArgumentError.value(
      dias,
      'diasGraciaCierre',
      'Debe estar entre $_diasGraciaMinimo y $_diasGraciaMaximo',
    );
  }
}
