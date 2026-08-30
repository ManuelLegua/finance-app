import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';

/// Construye `Obligacion` de prueba con valores por defecto razonables.
///
/// Reemplaza los helpers ad-hoc (`obligacionDe`, `crear`, `presupuesto`) que
/// había repetidos, con defaults distintos entre sí, en
/// `test/dominio/desglose_test.dart`, `test/dominio/presupuesto_test.dart`,
/// `test/dominio/resumen_mes_test.dart`, `test/datos/repositorio_obligaciones_test.dart`,
/// `test/ui/pantalla_resumen_test.dart` y `test/ui/estado_mes_test.dart`.
class ObligacionBuilder {
  ObligacionBuilder({
    this.id,
    this.mes = const Mes(2026, 8),
    this.nombre = 'Alquiler',
    this.categoria = Categoria.departamento,
    this.centavos = 90000,
    this.tipo = TipoObligacion.fija,
  });

  int? id;
  Mes mes;
  String nombre;
  Categoria categoria;
  int centavos;
  TipoObligacion tipo;

  Obligacion build() => Obligacion(
    id: id,
    mes: mes,
    nombre: nombre,
    categoria: categoria,
    monto: Dinero.deCentavos(centavos),
    tipo: tipo,
  );
}
