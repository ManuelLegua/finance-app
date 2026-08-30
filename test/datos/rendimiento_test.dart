import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_ahorro_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_obligaciones_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_transacciones_sqlite.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../builders/aporte_ahorro_builder.dart';
import '../builders/obligacion_builder.dart';
import '../builders/transaccion_builder.dart';
import 'helper_bd.dart';

/// Que el resumen del mes siga siendo barato con años de historial (T102).
///
/// Tres años de uso diario acumulan miles de filas. Sin un índice por
/// `mes_ordinal`, cada consulta de "este mes" recorrería toda la tabla y el
/// costo crecería con el historial completo, no con lo que realmente importa:
/// un mes. `EXPLAIN QUERY PLAN` confirma que SQLite usa el índice — un
/// tiempo de ejecución bajo por sí solo no lo demuestra, porque con un
/// dataset de prueba chico hasta un recorrido completo sería rápido.
void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late Database conexion;

  const mesesDeHistorial = 36; // tres años
  const primerMes = Mes(2023, 9);
  const mesConsultado = Mes(2026, 8); // el último de los tres años

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    conexion = await baseDatos.abrir();

    final repoObligaciones = RepositorioObligacionesSqlite(conexion);
    final repoTransacciones = RepositorioTransaccionesSqlite(conexion);
    final repoAhorro = RepositorioAhorroSqlite(conexion);

    for (var i = 0; i < mesesDeHistorial; i++) {
      final mes = primerMes.mas(i);
      for (var j = 0; j < 5; j++) {
        await repoObligaciones.insertar(
          ObligacionBuilder(mes: mes, nombre: 'Obligación $j').build(),
        );
      }
      for (var dia = 1; dia <= 28; dia++) {
        await repoTransacciones.insertar(
          TransaccionBuilder(fecha: DateTime(mes.anio, mes.mes, dia)).build(),
        );
      }
      await repoAhorro.guardarMeta(mes, const Dinero.deCentavos(50000));
      await repoAhorro.insertarAporte(
        AporteAhorroBuilder(fecha: DateTime(mes.anio, mes.mes, 20)).build(),
      );
    }
  });

  tearDown(() async => baseDatos.cerrar());

  /// `EXPLAIN QUERY PLAN` debe decir "USING INDEX <nombre>", nunca
  /// "SCAN <tabla>" a secas: eso último es la firma de un recorrido completo.
  Future<void> esperarUsoDeIndice(
    String sql,
    List<Object?> argumentos,
    String indice,
  ) async {
    final plan = await conexion.rawQuery('EXPLAIN QUERY PLAN $sql', argumentos);
    final detalle = plan.map((fila) => fila['detail']).join(' | ');
    expect(
      detalle,
      contains('USING INDEX $indice'),
      reason: 'Plan real: $detalle',
    );
  }

  group('los tres repositorios por mes usan su índice', () {
    test('obligacion → idx_obligacion_mes', () async {
      await esperarUsoDeIndice(
        'SELECT * FROM obligacion WHERE mes_ordinal = ?',
        [mesConsultado.ordinal],
        'idx_obligacion_mes',
      );
    });

    test('transaccion → idx_transaccion_mes', () async {
      await esperarUsoDeIndice(
        'SELECT * FROM transaccion WHERE mes_ordinal = ? '
            'ORDER BY fecha DESC, id DESC',
        [mesConsultado.ordinal],
        'idx_transaccion_mes',
      );
    });

    test('aporte_ahorro → idx_aporte_mes', () async {
      await esperarUsoDeIndice(
        'SELECT * FROM aporte_ahorro WHERE mes_ordinal = ?',
        [mesConsultado.ordinal],
        'idx_aporte_mes',
      );
    });
  });

  group(
    'el volumen de tres años no cambia lo que trae una consulta por mes',
    () {
      // Cuánto tarda no es una señal confiable acá: con un dataset de este
      // tamaño hasta un recorrido completo es rápido, y un tiempo de reloj
      // real es exactamente el tipo de aserción frágil que este proyecto evita
      // (rules/testing.md). La prueba de arriba, con `EXPLAIN QUERY PLAN`, es
      // la que de verdad demuestra que el costo no crece con el historial.
      test('un mes trae solo sus filas, no las de los tres años', () async {
        final repoTransacciones = RepositorioTransaccionesSqlite(conexion);

        final delMes = await repoTransacciones.porMes(mesConsultado);
        final historialCompleto = await conexion.query('transaccion');

        expect(delMes, hasLength(28));
        expect(historialCompleto, hasLength(28 * mesesDeHistorial));
      });
    },
  );
}
