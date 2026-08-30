import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dobles/repositorios_en_memoria.dart';

/// FR-020 a FR-028, FR-033: confirmar, corregir y descartar un pendiente.
void main() {
  late RepositorioPendientesEnMemoria repoPendientes;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late EstadoPendientes estado;

  ConsumoPendiente pendiente({
    int centavos = 4500,
    String comercio = 'Comercio de prueba',
    DateTime? fecha,
    Categoria? categoriaPropuesta,
    String notificacionId = 'notif-1',
  }) => ConsumoPendiente(
    id: null,
    origenPaquete: 'com.ejemplo.banco',
    notificacionId: notificacionId,
    monto: Dinero.deCentavos(centavos),
    comercio: comercio,
    fecha: fecha ?? DateTime(2026, 8, 10),
    categoriaPropuesta: categoriaPropuesta,
    capturadoEn: DateTime(2026, 8, 10, 12),
  );

  setUp(() {
    repoPendientes = RepositorioPendientesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    estado = EstadoPendientes(
      repoPendientes: repoPendientes,
      repoTransacciones: repoTransacciones,
    );
  });

  group('confirmar (FR-020, FR-026)', () {
    test(
      'crea la transacción con la fecha del consumo, no la de hoy',
      () async {
        await repoPendientes.insertar(
          pendiente(
            fecha: DateTime(2026, 7, 28),
            categoriaPropuesta: Categoria.comida,
          ),
        );
        await estado.cargar();
        final guardado = estado.pendientes.single;

        final confirmado = await estado.confirmar(guardado);

        expect(confirmado, isTrue);
        final transacciones = await repoTransacciones.porMes(
          const Mes(2026, 7),
        );
        expect(transacciones, hasLength(1));
        expect(transacciones.first.fecha, DateTime(2026, 7, 28));
        expect(transacciones.first.categoria, Categoria.comida);
        expect(transacciones.first.monto, const Dinero.deCentavos(4500));
      },
    );

    test('borra el pendiente al confirmarlo', () async {
      await repoPendientes.insertar(
        pendiente(categoriaPropuesta: Categoria.comida),
      );
      await estado.cargar();

      await estado.confirmar(estado.pendientes.single);

      expect(estado.pendientes, isEmpty);
      expect(await repoPendientes.todos(), isEmpty);
    });

    test('permite corregir monto, comercio, fecha y categoría', () async {
      await repoPendientes.insertar(
        pendiente(categoriaPropuesta: Categoria.otros),
      );
      await estado.cargar();

      await estado.confirmar(
        estado.pendientes.single,
        monto: const Dinero.deCentavos(9900),
        comercio: 'Corregido',
        fecha: DateTime(2026, 8, 5),
        categoria: Categoria.comida,
      );

      final transaccion = (await repoTransacciones.porMes(const Mes(2026, 8)))
          .single;
      expect(transaccion.monto, const Dinero.deCentavos(9900));
      expect(transaccion.descripcion, 'Corregido');
      expect(transaccion.fecha, DateTime(2026, 8, 5));
      expect(transaccion.categoria, Categoria.comida);
    });
  });

  group('categoría obligatoria (FR-033)', () {
    test(
      'un pendiente de comercio desconocido exige elegir categoría',
      () async {
        await repoPendientes.insertar(pendiente()); // sin categoriaPropuesta
        await estado.cargar();

        final confirmado = await estado.confirmar(estado.pendientes.single);

        expect(confirmado, isFalse);
        expect(estado.error, isNotNull);
        // No se creó nada: ni transacción ni se perdió el pendiente.
        expect(await repoTransacciones.porMes(const Mes(2026, 8)), isEmpty);
        expect(await repoPendientes.todos(), hasLength(1));
      },
    );

    test('un comercio ya conocido no exige elegirla de nuevo', () async {
      await repoPendientes.insertar(
        pendiente(categoriaPropuesta: Categoria.pasajes),
      );
      await estado.cargar();

      final confirmado = await estado.confirmar(estado.pendientes.single);

      expect(confirmado, isTrue);
    });
  });

  group('descartar (FR-025)', () {
    test('borra el pendiente sin crear ninguna transacción', () async {
      await repoPendientes.insertar(pendiente());
      await estado.cargar();

      await estado.descartar(estado.pendientes.single);

      expect(estado.pendientes, isEmpty);
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), isEmpty);
    });
  });

  group('resumen (FR-022, FR-028)', () {
    test('suma cantidad y monto de los pendientes', () async {
      await repoPendientes.insertar(
        pendiente(centavos: 4500, notificacionId: 'a'),
      );
      await repoPendientes.insertar(
        pendiente(centavos: 3200, notificacionId: 'b'),
      );
      await estado.cargar();

      expect(estado.resumen.cantidad, 2);
      expect(estado.resumen.montoTotal, const Dinero.deCentavos(7700));
      expect(estado.resumen.esCantidadInusual, isFalse);
    });
  });
}
