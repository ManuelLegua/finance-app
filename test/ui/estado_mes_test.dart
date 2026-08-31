import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/dominio/modelos/configuracion.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../builders/obligacion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// `EstadoMes` es donde se aplica la regla de cierre antes de cada escritura
/// (FR-052, FR-055, FR-056). Es una decisión que toca dinero: si dejara pasar
/// una edición sobre un mes cerrado, el histórico dejaría de ser confiable.
///
/// Estas pruebas existen gracias a los dobles: con SQLite real se colgarían
/// igual que las de widget.
void main() {
  late RepositorioCobrosIngresoEnMemoria repoCobrosIngreso;
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late RepositorioTransaccionesEnMemoria repoTransacciones;

  const agosto = Mes(2026, 8);
  const julio = Mes(2026, 7);
  const mayo = Mes(2026, 5);

  EstadoMes crearEstado({
    required Mes mes,
    required DateTime hoy,
    int diasGraciaCierre = 5,
  }) => EstadoMes(
    repoCobrosIngreso: repoCobrosIngreso,
    repoObligaciones: repoObligaciones,
    repoConfiguracion: RepositorioConfiguracionEnMemoria(
      Configuracion.porDefecto.copiarCon(diasGraciaCierre: diasGraciaCierre),
    ),
    repoTransacciones: repoTransacciones,
    repoDeudas: RepositorioDeudasEnMemoria(),
    ahora: () => hoy,
    mesInicial: mes,
  );

  Obligacion obligacionDe(Mes mes, {int? id}) =>
      ObligacionBuilder(id: id, mes: mes).build();

  CobroIngreso cobroDe(DateTime fecha, {int centavos = 300000}) =>
      CobroIngreso(id: null, fecha: fecha, monto: Dinero.deCentavos(centavos));

  setUp(() {
    repoCobrosIngreso = RepositorioCobrosIngresoEnMemoria();
    repoObligaciones = RepositorioObligacionesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
  });

  group('mes en curso', () {
    test('admite registrar y editar', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      expect(await estado.agregarCobro(cobroDe(DateTime(2026, 8, 10))), isTrue);
      expect(await estado.agregarObligacion(obligacionDe(agosto)), isTrue);

      final guardada = estado.obligaciones.single;
      expect(
        await estado.actualizarObligacion(
          guardada.copiarCon(monto: const Dinero.deCentavos(95000)),
        ),
        isTrue,
      );
      expect(estado.obligaciones.single.monto, const Dinero.deCentavos(95000));
      expect(estado.error, isNull);
    });
  });

  group('mes cerrado', () {
    test('rechaza registrar y no llega al repositorio', () async {
      final estado = crearEstado(mes: mayo, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      expect(
        await estado.agregarCobro(cobroDe(DateTime(2026, 5, 10))),
        isFalse,
      );
      // La escritura se detiene antes de la capa de datos, no después.
      expect(await repoCobrosIngreso.porMes(mayo), isEmpty);
    });

    test('explica el motivo en vez de fallar en silencio', () async {
      final estado = crearEstado(mes: mayo, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      await estado.agregarObligacion(obligacionDe(mayo));

      expect(estado.error, isNotNull);
      expect(estado.error, contains('cerrado'));
    });

    test('rechaza eliminar', () async {
      final estado = crearEstado(mes: mayo, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      expect(await estado.eliminarObligacion(1), isFalse);
    });

    test('no propone precarga: el mes no admite escritura', () async {
      await repoObligaciones.insertar(obligacionDe(const Mes(2026, 4)));
      final estado = crearEstado(mes: mayo, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      expect(await estado.propuestaDePrecarga(), isEmpty);
    });
  });

  group('ventana de gracia', () {
    test('el mes anterior admite crear un pago rezagado (FR-055)', () async {
      final estado = crearEstado(mes: julio, hoy: DateTime(2026, 8, 3));
      await estado.cargar();

      expect(await estado.agregarObligacion(obligacionDe(julio)), isTrue);
      expect(estado.obligaciones, hasLength(1));
    });

    test('pero NO admite editar lo ya registrado (FR-056)', () async {
      // La distinción entre crear y modificar es toda la razón por la que
      // existe TipoEscritura.
      await repoObligaciones.insertar(obligacionDe(julio));
      final estado = crearEstado(mes: julio, hoy: DateTime(2026, 8, 3));
      await estado.cargar();

      final guardada = estado.obligaciones.single;
      expect(
        await estado.actualizarObligacion(
          guardada.copiarCon(monto: const Dinero.deCentavos(95000)),
        ),
        isFalse,
      );
      expect(estado.obligaciones.single.monto, const Dinero.deCentavos(90000));
    });

    test('tampoco admite eliminar', () async {
      await repoObligaciones.insertar(obligacionDe(julio));
      final estado = crearEstado(mes: julio, hoy: DateTime(2026, 8, 3));
      await estado.cargar();

      expect(await estado.eliminarObligacion(1), isFalse);
      expect(estado.obligaciones, hasLength(1));
    });

    test('con 0 días de gracia el mes anterior ya está cerrado', () async {
      final estado = crearEstado(
        mes: julio,
        hoy: DateTime(2026, 8, 1),
        diasGraciaCierre: 0,
      );
      await estado.cargar();

      expect(await estado.agregarObligacion(obligacionDe(julio)), isFalse);
    });

    test('pasada la ventana ya no admite registrar', () async {
      final estado = crearEstado(mes: julio, hoy: DateTime(2026, 8, 6));
      await estado.cargar();

      expect(await estado.agregarObligacion(obligacionDe(julio)), isFalse);
    });
  });

  group('errores de la capa de datos', () {
    test('se reportan como mensaje, sin romper el estado', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();
      repoObligaciones.errorEnLaProximaEscritura = Exception('disco lleno');

      expect(await estado.agregarObligacion(obligacionDe(agosto)), isFalse);
      expect(estado.error, isNotNull);
      expect(estado.obligaciones, isEmpty);
    });

    test('limpiarError deja el estado utilizable otra vez', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();
      repoObligaciones.errorEnLaProximaEscritura = Exception('disco lleno');
      await estado.agregarObligacion(obligacionDe(agosto));

      estado.limpiarError();
      expect(estado.error, isNull);

      expect(await estado.agregarObligacion(obligacionDe(agosto)), isTrue);
    });
  });

  group('precarga de fijas', () {
    test('propone las del mes anterior sin guardarlas (FR-006)', () async {
      await repoObligaciones.insertar(obligacionDe(julio));
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      final propuestas = await estado.propuestaDePrecarga();

      expect(propuestas, hasLength(1));
      expect(propuestas.single.id, isNull);
      expect(propuestas.single.mes, agosto);
      // Nada se escribió todavía.
      expect(estado.obligaciones, isEmpty);
    });

    test('no propone nada si el mes ya tiene obligaciones', () async {
      await repoObligaciones.insertar(obligacionDe(julio));
      await repoObligaciones.insertar(obligacionDe(agosto));
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      expect(await estado.propuestaDePrecarga(), isEmpty);
    });

    test('confirmarla las guarda todas', () async {
      await repoObligaciones.insertar(obligacionDe(julio));
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      final propuestas = await estado.propuestaDePrecarga();
      expect(await estado.confirmarPrecarga(propuestas), isTrue);
      expect(estado.obligaciones, hasLength(1));
      expect(estado.obligaciones.single.mes, agosto);
    });
  });

  group('navegación entre meses', () {
    test('cambiar de mes recarga sus datos', () async {
      await repoCobrosIngreso.insertar(
        cobroDe(DateTime(2026, 7, 10), centavos: 280000),
      );
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      expect(estado.ingreso, isNull);

      await estado.irAlMesAnterior();
      expect(estado.mes, julio);
      expect(estado.ingreso, const Dinero.deCentavos(280000));
    });
  });

  group('total comprometido', () {
    test('suma las obligaciones del mes', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      await estado.agregarObligacion(obligacionDe(agosto));
      await estado.agregarObligacion(
        obligacionDe(agosto).copiarCon(monto: const Dinero.deCentavos(12000)),
      );

      expect(estado.totalComprometido, const Dinero.deCentavos(102000));
    });

    test('sin obligaciones es cero, no null', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      expect(estado.totalComprometido, Dinero.cero);
    });
  });

  group('cobros de ingreso (spec 003, FR-001 a FR-006)', () {
    test(
      'agregarCobro en el mes en curso lo agrega y el total refleja la suma',
      () async {
        final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
        await estado.cargar();

        await estado.agregarCobro(
          cobroDe(DateTime(2026, 8, 15), centavos: 96000),
        );
        await estado.agregarCobro(
          cobroDe(DateTime(2026, 8, 30), centavos: 104000),
        );

        expect(estado.ingreso, const Dinero.deCentavos(200000));
        expect(estado.cobros, hasLength(2));
      },
    );

    test('agregarCobro con fecha de un mes cerrado se rechaza antes de llegar '
        'al repositorio', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();

      final confirmado = await estado.agregarCobro(
        cobroDe(DateTime(2026, 5, 10)),
      );

      expect(confirmado, isFalse);
      expect(await repoCobrosIngreso.porMes(mayo), isEmpty);
    });

    test(
      'actualizarCobro corrige un cobro sin tocar los demás del mes',
      () async {
        final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
        await estado.cargar();
        await estado.agregarCobro(
          cobroDe(DateTime(2026, 8, 15), centavos: 96000),
        );
        await estado.agregarCobro(
          cobroDe(DateTime(2026, 8, 30), centavos: 104000),
        );

        final segundo = estado.cobros.last;
        await estado.actualizarCobro(
          segundo.copiarCon(monto: const Dinero.deCentavos(100000)),
        );

        expect(estado.cobros.first.monto, const Dinero.deCentavos(96000));
        expect(estado.cobros.last.monto, const Dinero.deCentavos(100000));
        expect(estado.ingreso, const Dinero.deCentavos(196000));
      },
    );

    test('eliminarCobro borra uno y deja el otro intacto', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();
      await estado.agregarCobro(
        cobroDe(DateTime(2026, 8, 15), centavos: 96000),
      );
      await estado.agregarCobro(
        cobroDe(DateTime(2026, 8, 30), centavos: 104000),
      );

      await estado.eliminarCobro(estado.cobros.first.id!);

      expect(estado.cobros, hasLength(1));
      expect(estado.ingreso, const Dinero.deCentavos(104000));
    });

    test('eliminar el único cobro del mes vuelve a "sin registrar"', () async {
      final estado = crearEstado(mes: agosto, hoy: DateTime(2026, 8, 15));
      await estado.cargar();
      await estado.agregarCobro(cobroDe(DateTime(2026, 8, 15)));

      await estado.eliminarCobro(estado.cobros.single.id!);

      expect(estado.ingreso, isNull);
      expect(estado.ingresoRegistrado, isFalse);
    });

    test('actualizarCobro y eliminarCobro se rechazan en un mes cerrado '
        '(FR-006, sin ventana de gracia para editar)', () async {
      await repoCobrosIngreso.insertar(cobroDe(DateTime(2026, 7, 3)));
      final estado = crearEstado(mes: julio, hoy: DateTime(2026, 8, 3));
      await estado.cargar();

      final guardado = estado.cobros.single;
      expect(
        await estado.actualizarCobro(
          guardado.copiarCon(monto: const Dinero.deCentavos(1)),
        ),
        isFalse,
      );
      expect(await estado.eliminarCobro(guardado.id!), isFalse);
      expect(estado.cobros.single.monto, guardado.monto);
    });
  });
}
