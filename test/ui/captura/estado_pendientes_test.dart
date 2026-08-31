import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dobles/repositorios_en_memoria.dart';

/// FR-020 a FR-028, FR-033: confirmar, corregir y descartar un pendiente.
void main() {
  late RepositorioPendientesEnMemoria repoPendientes;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late RepositorioAsociacionesEnMemoria repoAsociaciones;
  late RepositorioDeudasEnMemoria repoDeudas;
  late EstadoMes estadoMes;
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

  setUp(() async {
    repoPendientes = RepositorioPendientesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    repoAsociaciones = RepositorioAsociacionesEnMemoria();
    repoDeudas = RepositorioDeudasEnMemoria();
    // Día 1 de agosto, dentro de la gracia por defecto (5 días): julio, usado
    // en la prueba de "fecha del consumo, no la de hoy", todavía admite
    // registrar (FR-055). Agosto es siempre el mes abierto.
    estadoMes = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: repoTransacciones,
      repoDeudas: repoDeudas,
      ahora: () => DateTime(2026, 8, 1),
      mesInicial: const Mes(2026, 8),
    );
    await estadoMes.cargar();
    estado = EstadoPendientes(
      repoPendientes: repoPendientes,
      repoAsociaciones: repoAsociaciones,
      estadoMes: estadoMes,
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

  group('respeta el cierre de mes (FR-055)', () {
    test('confirmar con fecha de un mes cerrado no crea la transacción ni '
        'borra el pendiente', () async {
      await repoPendientes.insertar(
        pendiente(
          // Dos meses antes de "ahora" (agosto): cerrado sin gracia, a
          // diferencia del mes inmediatamente anterior.
          fecha: DateTime(2026, 6, 15),
          categoriaPropuesta: Categoria.comida,
        ),
      );
      await estado.cargar();

      final confirmado = await estado.confirmar(estado.pendientes.single);

      expect(confirmado, isFalse);
      expect(estado.error, isNotNull);
      expect(await repoTransacciones.porMes(const Mes(2026, 6)), isEmpty);
      expect(await repoPendientes.todos(), hasLength(1));
    });

    test('confirmar como deuda no se ve afectado por el cierre: FR-057 las '
        'excluye de la regla', () async {
      await repoPendientes.insertar(pendiente(fecha: DateTime(2026, 6, 15)));
      await estado.cargar();

      final confirmado = await estado.confirmar(
        estado.pendientes.single,
        comoDeuda: const Deuda(
          id: null,
          descripcion: 'Tienda X',
          tarjetaId: 1,
          cuotaMensual: Dinero.deCentavos(15000),
          numCuotas: 12,
          mesInicio: Mes(2026, 6),
        ),
      );

      expect(confirmado, isTrue);
      expect(await repoDeudas.todas(), hasLength(1));
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

  group('categorización aprendida (FR-029, FR-030, FR-031)', () {
    test('confirmar un comercio nunca antes visto con una categoría guarda la '
        'asociación', () async {
      await repoPendientes.insertar(
        pendiente(comercio: 'Tottus San Isidro', categoriaPropuesta: null),
      );
      await estado.cargar();

      await estado.confirmar(
        estado.pendientes.single,
        categoria: Categoria.comida,
      );

      expect(
        await repoAsociaciones.categoriaDe('TOTTUS SAN ISIDRO'),
        Categoria.comida,
      );
    });

    test('un consumo posterior del mismo comercio llega con categoriaPropuesta '
        'ya llena', () async {
      await repoAsociaciones.asociar('TOTTUS', Categoria.comida);
      await repoPendientes.insertar(
        pendiente(comercio: 'Tottus', notificacionId: 'nueva'),
      );

      await estado.cargar();

      expect(estado.pendientes.single.categoriaPropuesta, Categoria.comida);
    });

    test('confirmarlo con una categoría distinta actualiza la asociación, no '
        'la duplica', () async {
      await repoAsociaciones.asociar('TOTTUS', Categoria.comida);
      await repoPendientes.insertar(pendiente(comercio: 'Tottus'));
      await estado.cargar();

      await estado.confirmar(
        estado.pendientes.single,
        categoria: Categoria.otros,
      );

      expect(await repoAsociaciones.categoriaDe('TOTTUS'), Categoria.otros);
      expect(await repoAsociaciones.todas(), hasLength(1));
    });

    test('una categoría propuesta por el parser no se pisa con una asociación '
        'distinta al cargar', () async {
      await repoAsociaciones.asociar('TOTTUS', Categoria.comida);
      await repoPendientes.insertar(
        pendiente(comercio: 'Tottus', categoriaPropuesta: Categoria.otros),
      );

      await estado.cargar();

      expect(estado.pendientes.single.categoriaPropuesta, Categoria.otros);
    });
  });

  group('confirmar como deuda en cuotas (FR-035, FR-036, FR-037)', () {
    test('con la marca "en cuotas" crea una Deuda con los datos del formulario '
        'y no crea una Transaccion', () async {
      await repoPendientes.insertar(
        pendiente(comercio: 'Tienda X', centavos: 15000),
      );
      await estado.cargar();

      final confirmado = await estado.confirmar(
        estado.pendientes.single,
        comoDeuda: const Deuda(
          id: null,
          descripcion: 'Tienda X',
          tarjetaId: 1,
          cuotaMensual: Dinero.deCentavos(15000),
          numCuotas: 12,
          mesInicio: Mes(2026, 8),
        ),
      );

      expect(confirmado, isTrue);
      final deuda = (await repoDeudas.todas()).single;
      expect(deuda.descripcion, 'Tienda X');
      expect(deuda.tarjetaId, 1);
      expect(deuda.cuotaMensual, const Dinero.deCentavos(15000));
      expect(deuda.numCuotas, 12);
      expect(deuda.mesInicio, const Mes(2026, 8));
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), isEmpty);
    });

    test('borra el pendiente al confirmarlo como deuda', () async {
      await repoPendientes.insertar(pendiente());
      await estado.cargar();

      await estado.confirmar(
        estado.pendientes.single,
        comoDeuda: const Deuda(
          id: null,
          descripcion: 'Tienda X',
          tarjetaId: 1,
          cuotaMensual: Dinero.deCentavos(15000),
          numCuotas: 12,
          mesInicio: Mes(2026, 8),
        ),
      );

      expect(estado.pendientes, isEmpty);
      expect(await repoPendientes.todos(), isEmpty);
    });

    test('no guarda ninguna asociación comercio-categoría: una deuda no lleva '
        'categoría propia', () async {
      await repoPendientes.insertar(pendiente(comercio: 'Tienda X'));
      await estado.cargar();

      await estado.confirmar(
        estado.pendientes.single,
        comoDeuda: const Deuda(
          id: null,
          descripcion: 'Tienda X',
          tarjetaId: 1,
          cuotaMensual: Dinero.deCentavos(15000),
          numCuotas: 12,
          mesInicio: Mes(2026, 8),
        ),
      );

      expect(await repoAsociaciones.todas(), isEmpty);
    });

    test('sin la marca de cuotas, el comportamiento es el de una transacción '
        'normal, sin tocar RepositorioDeudas', () async {
      await repoPendientes.insertar(
        pendiente(categoriaPropuesta: Categoria.comida),
      );
      await estado.cargar();

      await estado.confirmar(estado.pendientes.single);

      expect(await repoDeudas.todas(), isEmpty);
      expect(await repoTransacciones.porMes(const Mes(2026, 8)), hasLength(1));
    });
  });
}
