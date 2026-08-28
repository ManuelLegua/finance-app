import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/repositorios/repositorio_deudas_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_tarjetas_sqlite.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/dominio/modelos/tarjeta.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos baseDatos;
  late RepositorioTarjetasSqlite repoTarjetas;
  late RepositorioDeudasSqlite repoDeudas;
  late int tarjetaCredito;

  const agosto = Mes(2026, 8);

  setUp(() async {
    baseDatos = await abrirBaseEnMemoria();
    final conexion = await baseDatos.abrir();
    repoTarjetas = RepositorioTarjetasSqlite(conexion);
    repoDeudas = RepositorioDeudasSqlite(conexion);
    tarjetaCredito = await repoTarjetas.insertar(
      const Tarjeta(
        id: null,
        nombre: 'BCP Visa',
        entidad: 'BCP',
        tipo: TipoTarjeta.credito,
      ),
    );
  });

  tearDown(() async => baseDatos.cerrar());

  Deuda deuda({
    int? id,
    String descripcion = 'Celular',
    int cuotaCentavos = 15000,
    int numCuotas = 12,
    Mes mesInicio = agosto,
    Mes? mesSaldadaAnticipada,
    int? tarjetaId,
  }) => Deuda(
    id: id,
    descripcion: descripcion,
    tarjetaId: tarjetaId ?? tarjetaCredito,
    cuotaMensual: Dinero.deCentavos(cuotaCentavos),
    numCuotas: numCuotas,
    mesInicio: mesInicio,
    mesSaldadaAnticipada: mesSaldadaAnticipada,
  );

  group('tarjetas', () {
    test('guarda nombre, entidad y tipo', () async {
      final guardada = (await repoTarjetas.todas()).single;

      expect(guardada.nombre, 'BCP Visa');
      expect(guardada.entidad, 'BCP');
      expect(guardada.tipo, TipoTarjeta.credito);
    });

    test('deCredito filtra las de débito (FR-061)', () async {
      await repoTarjetas.insertar(
        const Tarjeta(
          id: null,
          nombre: 'BCP Débito',
          entidad: 'BCP',
          tipo: TipoTarjeta.debito,
        ),
      );

      expect(await repoTarjetas.todas(), hasLength(2));
      final credito = await repoTarjetas.deCredito();
      expect(credito, hasLength(1));
      expect(credito.single.nombre, 'BCP Visa');
    });

    test('el nombre es único', () async {
      await expectLater(
        repoTarjetas.insertar(
          const Tarjeta(
            id: null,
            nombre: 'BCP Visa',
            entidad: 'Interbank',
            tipo: TipoTarjeta.credito,
          ),
        ),
        throwsA(isA<ErrorPersistencia>()),
      );
    });

    test('borrar una tarjeta con deudas se rechaza con motivo', () async {
      await repoDeudas.insertar(deuda());

      await expectLater(
        repoTarjetas.eliminar(tarjetaCredito),
        throwsA(
          isA<ErrorPersistencia>().having(
            (error) => error.mensaje,
            'mensaje',
            contains('deudas registradas'),
          ),
        ),
      );
      // Y no borró nada.
      expect(await repoTarjetas.todas(), hasLength(1));
    });

    test('una tarjeta sin deudas sí se puede borrar', () async {
      await repoTarjetas.eliminar(tarjetaCredito);
      expect(await repoTarjetas.todas(), isEmpty);
    });
  });

  group('deudas', () {
    test('guarda todos sus campos', () async {
      await repoDeudas.insertar(deuda());
      final guardada = (await repoDeudas.todas()).single;

      expect(guardada.descripcion, 'Celular');
      expect(guardada.cuotaMensual, const Dinero.deCentavos(15000));
      expect(guardada.numCuotas, 12);
      expect(guardada.mesInicio, agosto);
      expect(guardada.mesSaldadaAnticipada, isNull);
      expect(guardada.id, isNotNull);
    });

    test('activas excluye las saldadas anticipadamente', () async {
      await repoDeudas.insertar(deuda(descripcion: 'Vigente'));
      await repoDeudas.insertar(
        deuda(descripcion: 'Saldada', mesSaldadaAnticipada: const Mes(2026, 9)),
      );

      expect(await repoDeudas.todas(), hasLength(2));
      final activas = await repoDeudas.activas();
      expect(activas, hasLength(1));
      expect(activas.single.descripcion, 'Vigente');
    });

    test('porTarjeta filtra por su tarjeta', () async {
      final otra = await repoTarjetas.insertar(
        const Tarjeta(
          id: null,
          nombre: 'Oh! Mastercard',
          entidad: 'Oh!',
          tipo: TipoTarjeta.credito,
        ),
      );
      await repoDeudas.insertar(deuda(descripcion: 'De BCP'));
      await repoDeudas.insertar(deuda(descripcion: 'De Oh!', tarjetaId: otra));

      final deBcp = await repoDeudas.porTarjeta(tarjetaCredito);
      expect(deBcp, hasLength(1));
      expect(deBcp.single.descripcion, 'De BCP');
    });

    test('actualizar recalcula sin tocar filas de cuotas', () async {
      // No hay filas de cuotas que reescribir: es una sola escritura (D3).
      final id = await repoDeudas.insertar(deuda(numCuotas: 12));
      await repoDeudas.actualizar(
        deuda(id: id, numCuotas: 10, cuotaCentavos: 20000),
      );

      final corregida = (await repoDeudas.todas()).single;
      expect(corregida.numCuotas, 10);
      expect(corregida.cuotaMensual, const Dinero.deCentavos(20000));
    });

    test('marcarSaldada fija el mes y la saca de activas', () async {
      final id = await repoDeudas.insertar(deuda());
      await repoDeudas.marcarSaldada(id, const Mes(2026, 11));

      final saldada = (await repoDeudas.todas()).single;
      expect(saldada.mesSaldadaAnticipada, const Mes(2026, 11));
      expect(await repoDeudas.activas(), isEmpty);
    });

    test('no puede apuntar a una tarjeta inexistente', () async {
      await expectLater(
        repoDeudas.insertar(deuda(tarjetaId: 999)),
        throwsA(isA<ErrorPersistencia>()),
      );
    });

    test('rechaza cuotas menores a una', () async {
      // La invariante vive en el modelo, antes de llegar a la base.
      expect(() => deuda(numCuotas: 0), throwsAssertionError);
    });

    test('eliminar la quita', () async {
      final id = await repoDeudas.insertar(deuda());
      await repoDeudas.eliminar(id);
      expect(await repoDeudas.todas(), isEmpty);
    });
  });
}
