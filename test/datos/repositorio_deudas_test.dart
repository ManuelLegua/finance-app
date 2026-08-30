import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/error_persistencia.dart';
import 'package:finanzas/datos/repositorios/repositorio_deudas_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_tarjetas_sqlite.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../builders/deuda_builder.dart';
import '../builders/tarjeta_builder.dart';
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
    tarjetaCredito = await repoTarjetas.insertar(TarjetaBuilder().build());
  });

  tearDown(() async => baseDatos.cerrar());

  group('tarjetas', () {
    test('guarda nombre, entidad y tipo', () async {
      final guardada = (await repoTarjetas.todas()).single;

      expect(guardada.nombre, 'BCP Visa');
      expect(guardada.entidad, 'BCP');
      expect(guardada.tipo, TipoTarjeta.credito);
    });

    test('deCredito filtra las de débito (FR-061)', () async {
      await repoTarjetas.insertar(
        TarjetaBuilder(nombre: 'BCP Débito', tipo: TipoTarjeta.debito).build(),
      );

      expect(await repoTarjetas.todas(), hasLength(2));
      final credito = await repoTarjetas.deCredito();
      expect(credito, hasLength(1));
      expect(credito.single.nombre, 'BCP Visa');
    });

    test('el nombre es único', () async {
      await expectLater(
        repoTarjetas.insertar(TarjetaBuilder(entidad: 'Interbank').build()),
        throwsA(isA<ErrorPersistencia>()),
      );
    });

    test('borrar una tarjeta con deudas se rechaza con motivo', () async {
      await repoDeudas.insertar(
        DeudaBuilder(tarjetaId: tarjetaCredito).build(),
      );

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
      await repoDeudas.insertar(
        DeudaBuilder(tarjetaId: tarjetaCredito).build(),
      );
      final guardada = (await repoDeudas.todas()).single;

      expect(guardada.descripcion, 'Celular');
      expect(guardada.cuotaMensual, const Dinero.deCentavos(15000));
      expect(guardada.numCuotas, 12);
      expect(guardada.mesInicio, agosto);
      expect(guardada.mesSaldadaAnticipada, isNull);
      expect(guardada.id, isNotNull);
    });

    test('activas excluye las saldadas anticipadamente', () async {
      await repoDeudas.insertar(
        DeudaBuilder(descripcion: 'Vigente', tarjetaId: tarjetaCredito).build(),
      );
      await repoDeudas.insertar(
        DeudaBuilder(
          descripcion: 'Saldada',
          tarjetaId: tarjetaCredito,
          mesSaldadaAnticipada: const Mes(2026, 9),
        ).build(),
      );

      expect(await repoDeudas.todas(), hasLength(2));
      final activas = await repoDeudas.activas();
      expect(activas, hasLength(1));
      expect(activas.single.descripcion, 'Vigente');
    });

    test('porTarjeta filtra por su tarjeta', () async {
      final otra = await repoTarjetas.insertar(
        TarjetaBuilder(nombre: 'Oh! Mastercard', entidad: 'Oh!').build(),
      );
      await repoDeudas.insertar(
        DeudaBuilder(descripcion: 'De BCP', tarjetaId: tarjetaCredito).build(),
      );
      await repoDeudas.insertar(
        DeudaBuilder(descripcion: 'De Oh!', tarjetaId: otra).build(),
      );

      final deBcp = await repoDeudas.porTarjeta(tarjetaCredito);
      expect(deBcp, hasLength(1));
      expect(deBcp.single.descripcion, 'De BCP');
    });

    test('actualizar recalcula sin tocar filas de cuotas', () async {
      // No hay filas de cuotas que reescribir: es una sola escritura (D3).
      final id = await repoDeudas.insertar(
        DeudaBuilder(numCuotas: 12, tarjetaId: tarjetaCredito).build(),
      );
      await repoDeudas.actualizar(
        DeudaBuilder(
          id: id,
          numCuotas: 10,
          cuotaCentavos: 20000,
          tarjetaId: tarjetaCredito,
        ).build(),
      );

      final corregida = (await repoDeudas.todas()).single;
      expect(corregida.numCuotas, 10);
      expect(corregida.cuotaMensual, const Dinero.deCentavos(20000));
    });

    test('marcarSaldada fija el mes y la saca de activas', () async {
      final id = await repoDeudas.insertar(
        DeudaBuilder(tarjetaId: tarjetaCredito).build(),
      );
      await repoDeudas.marcarSaldada(id, const Mes(2026, 11));

      final saldada = (await repoDeudas.todas()).single;
      expect(saldada.mesSaldadaAnticipada, const Mes(2026, 11));
      expect(await repoDeudas.activas(), isEmpty);
    });

    test('no puede apuntar a una tarjeta inexistente', () async {
      await expectLater(
        repoDeudas.insertar(DeudaBuilder(tarjetaId: 999).build()),
        throwsA(isA<ErrorPersistencia>()),
      );
    });

    test('rechaza cuotas menores a una', () async {
      // La invariante vive en el modelo, antes de llegar a la base.
      expect(() => DeudaBuilder(numCuotas: 0).build(), throwsAssertionError);
    });

    test('eliminar la quita', () async {
      final id = await repoDeudas.insertar(
        DeudaBuilder(tarjetaId: tarjetaCredito).build(),
      );
      await repoDeudas.eliminar(id);
      expect(await repoDeudas.todas(), isEmpty);
    });
  });
}
