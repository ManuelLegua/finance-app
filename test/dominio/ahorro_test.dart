import 'package:finanzas/dominio/calculos/ahorro.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-031 a FR-043, FR-053, FR-054, con los trece escenarios de la HU5.
void main() {
  const agosto = Mes(2026, 8);

  group('escenario 1: porcentaje del ingreso', () {
    test('20% de S/ 3,000 sugiere S/ 600', () {
      final sugerencia = calcularSugerencia(
        regla: ReglaAhorro.porcentajeIngreso,
        porcentajeBp: 2000,
        ingreso: Dinero.deSoles(3000),
        disponibleProyectado: Dinero.deSoles(2000),
        enDeficit: false,
      );

      expect(sugerencia.montoSugerido, Dinero.deSoles(600));
      expect(sugerencia.montoAlcanzable, Dinero.deSoles(600));
      expect(sugerencia.excedeDisponible, isFalse);
      expect(sugerencia.noCorresponde, isFalse);
    });
  });

  group('escenario 2: el porcentaje excede el disponible', () {
    test('ingreso S/ 3,000 con compromisos de S/ 2,700 ofrece S/ 300', () {
      final sugerencia = calcularSugerencia(
        regla: ReglaAhorro.porcentajeIngreso,
        porcentajeBp: 2000,
        ingreso: Dinero.deSoles(3000),
        disponibleProyectado: Dinero.deSoles(300),
        enDeficit: false,
      );

      expect(sugerencia.montoSugerido, Dinero.deSoles(600));
      expect(sugerencia.montoAlcanzable, Dinero.deSoles(300));
      expect(sugerencia.excedeDisponible, isTrue);
      expect(sugerencia.noCorresponde, isFalse);
    });
  });

  group('escenario 3: regla remanente', () {
    test('con S/ 1,200 disponibles sugiere ahorrar S/ 1,200', () {
      final sugerencia = calcularSugerencia(
        regla: ReglaAhorro.remanente,
        porcentajeBp: 2000,
        ingreso: Dinero.deSoles(2000),
        disponibleProyectado: Dinero.deSoles(1200),
        enDeficit: false,
      );

      expect(sugerencia.montoSugerido, Dinero.deSoles(1200));
      expect(sugerencia.montoAlcanzable, Dinero.deSoles(1200));
      expect(sugerencia.excedeDisponible, isFalse);
    });
  });

  group('escenario 4: meta alcanzable', () {
    test('meta de S/ 500 con S/ 1,200 disponibles deja margen de S/ 700', () {
      final progreso = calcularProgreso(
        mes: agosto,
        disponibleProyectado: Dinero.deSoles(1200),
        ahorradoMes: Dinero.cero,
        metaDelMes: Dinero.deSoles(500),
        acumuladoHistorico: Dinero.cero,
        aportesPorMes: const [],
        metas: [(agosto, Dinero.deSoles(500))],
      );

      expect(progreso.metaAlcanzable, isTrue);
      expect(progreso.margenDisponible, Dinero.deSoles(700));
      expect(progreso.recorteNecesario, isNull);
    });
  });

  group('escenario 5: meta no alcanzable', () {
    test('meta de S/ 1,500 con S/ 1,200 disponibles exige recortar S/ 300', () {
      final progreso = calcularProgreso(
        mes: agosto,
        disponibleProyectado: Dinero.deSoles(1200),
        ahorradoMes: Dinero.cero,
        metaDelMes: Dinero.deSoles(1500),
        acumuladoHistorico: Dinero.cero,
        aportesPorMes: const [],
        metas: [(agosto, Dinero.deSoles(1500))],
      );

      expect(progreso.metaAlcanzable, isFalse);
      expect(progreso.recorteNecesario, Dinero.deSoles(300));
      expect(progreso.margenDisponible, isNull);
    });
  });

  group('escenario 6: déficit', () {
    test('en déficit no corresponde ahorrar', () {
      final sugerencia = calcularSugerencia(
        regla: ReglaAhorro.porcentajeIngreso,
        porcentajeBp: 2000,
        ingreso: Dinero.deSoles(2000),
        disponibleProyectado: Dinero.deSoles(-300),
        enDeficit: true,
      );

      expect(sugerencia.noCorresponde, isTrue);
      expect(sugerencia.montoSugerido, Dinero.cero);
      expect(sugerencia.montoAlcanzable, Dinero.cero);
    });

    test('sin ingreso registrado tampoco corresponde', () {
      final sugerencia = calcularSugerencia(
        regla: ReglaAhorro.remanente,
        porcentajeBp: 2000,
        ingreso: null,
        disponibleProyectado: Dinero.cero,
        enDeficit: false,
      );

      expect(sugerencia.noCorresponde, isTrue);
    });
  });

  group('escenario 7: progreso contra la meta', () {
    test('meta S/ 500 con un aporte de S/ 300 deja S/ 200 pendientes', () {
      final progreso = calcularProgreso(
        mes: agosto,
        disponibleProyectado: Dinero.deSoles(1200),
        ahorradoMes: Dinero.deSoles(300),
        metaDelMes: Dinero.deSoles(500),
        acumuladoHistorico: Dinero.deSoles(300),
        aportesPorMes: [(agosto, Dinero.deSoles(300))],
        metas: [(agosto, Dinero.deSoles(500))],
      );

      expect(progreso.ahorradoMes, Dinero.deSoles(300));
      expect(progreso.pendiente, Dinero.deSoles(200));
      expect(progreso.excedente, Dinero.cero);
    });
  });

  group('escenario 8: se supera la meta', () {
    test('S/ 300 más S/ 250 superan la meta de S/ 500 en S/ 50', () {
      final progreso = calcularProgreso(
        mes: agosto,
        disponibleProyectado: Dinero.deSoles(1200),
        ahorradoMes: Dinero.deSoles(550),
        metaDelMes: Dinero.deSoles(500),
        acumuladoHistorico: Dinero.deSoles(550),
        aportesPorMes: [(agosto, Dinero.deSoles(550))],
        metas: [(agosto, Dinero.deSoles(500))],
      );

      expect(progreso.ahorradoMes, Dinero.deSoles(550));
      expect(progreso.pendiente, Dinero.cero);
      expect(progreso.excedente, Dinero.deSoles(50));
    });
  });

  group('escenario 9: acumulado histórico', () {
    test('suma el aporte de cada mes registrado', () {
      final progreso = calcularProgreso(
        mes: agosto,
        disponibleProyectado: Dinero.cero,
        ahorradoMes: Dinero.cero,
        metaDelMes: null,
        acumuladoHistorico: Dinero.deSoles(850),
        aportesPorMes: [
          (const Mes(2026, 6), Dinero.deSoles(300)),
          (const Mes(2026, 7), Dinero.deSoles(550)),
        ],
        metas: const [],
      );

      expect(progreso.acumuladoHistorico, Dinero.deSoles(850));
      expect(progreso.historialPorMes, hasLength(2));
      expect(progreso.historialPorMes[0].mes, const Mes(2026, 6));
      expect(progreso.historialPorMes[0].ahorrado, Dinero.deSoles(300));
      expect(progreso.historialPorMes[1].mes, const Mes(2026, 7));
      expect(progreso.historialPorMes[1].ahorrado, Dinero.deSoles(550));
    });
  });

  group('escenario 11: mes sin aportes', () {
    test('un mes con meta pero sin aportes figura en S/ 0.00, no cumplida', () {
      final progreso = calcularProgreso(
        mes: agosto,
        disponibleProyectado: Dinero.cero,
        ahorradoMes: Dinero.cero,
        metaDelMes: null,
        acumuladoHistorico: Dinero.cero,
        aportesPorMes: const [],
        metas: [(const Mes(2026, 7), Dinero.deSoles(400))],
      );

      final renglon = progreso.historialPorMes.single;
      expect(renglon.mes, const Mes(2026, 7));
      expect(renglon.ahorrado, Dinero.cero);
      expect(renglon.meta, Dinero.deSoles(400));
      expect(renglon.metaCumplida, isFalse);
    });
  });

  group('escenario 12: cada mes contra su propia meta (FR-054)', () {
    test(
      'julio con meta S/ 400 no se evalúa contra la meta vigente S/ 700',
      () {
        final progreso = calcularProgreso(
          mes: agosto,
          disponibleProyectado: Dinero.deSoles(1200),
          ahorradoMes: Dinero.cero,
          metaDelMes: Dinero.deSoles(700),
          acumuladoHistorico: Dinero.deSoles(400),
          aportesPorMes: [(const Mes(2026, 7), Dinero.deSoles(400))],
          metas: [
            (const Mes(2026, 7), Dinero.deSoles(400)),
            (agosto, Dinero.deSoles(700)),
          ],
        );

        final julio = progreso.historialPorMes.firstWhere(
          (renglon) => renglon.mes == const Mes(2026, 7),
        );
        expect(julio.meta, Dinero.deSoles(400));
        expect(julio.ahorrado, Dinero.deSoles(400));
        expect(julio.metaCumplida, isTrue);

        // Y el mes evaluado sigue viendo su propia meta vigente.
        expect(progreso.metaDelMes, Dinero.deSoles(700));
      },
    );

    test('un mes sin meta figura sin veredicto', () {
      final progreso = calcularProgreso(
        mes: agosto,
        disponibleProyectado: Dinero.cero,
        ahorradoMes: Dinero.cero,
        metaDelMes: null,
        acumuladoHistorico: Dinero.cero,
        aportesPorMes: const [],
        metas: const [],
      );

      expect(progreso.metaDelMes, isNull);
      expect(progreso.pendiente, isNull);
      expect(progreso.excedente, isNull);
      expect(progreso.metaAlcanzable, isNull);
      expect(progreso.recorteNecesario, isNull);
      expect(progreso.margenDisponible, isNull);
    });
  });

  group('escenario 13: propuesta de meta (FR-053)', () {
    test('propone la meta del último mes anterior que tuvo una', () {
      final propuesta = proponerMetaDelMes(agosto, [
        (const Mes(2026, 5), Dinero.deSoles(300)),
        (const Mes(2026, 7), Dinero.deSoles(500)),
      ]);

      expect(propuesta.montoPropuesto, Dinero.deSoles(500));
      expect(propuesta.hayPropuesta, isTrue);
    });

    test('ignora la meta del propio mes evaluado o de meses futuros', () {
      final propuesta = proponerMetaDelMes(agosto, [
        (agosto, Dinero.deSoles(999)),
        (const Mes(2026, 9), Dinero.deSoles(999)),
      ]);

      expect(propuesta.hayPropuesta, isFalse);
      expect(propuesta.montoPropuesto, isNull);
    });

    test('sin ningún mes anterior con meta, no hay propuesta', () {
      final propuesta = proponerMetaDelMes(agosto, const []);
      expect(propuesta.hayPropuesta, isFalse);
    });
  });

  group('exactitud', () {
    test('el 20% de un ingreso impar redondea al centavo más cercano', () {
      // Reusa Dinero.porPuntosBase, que ya prueba su propio redondeo: acá
      // solo se verifica que calcularSugerencia lo use sin punto flotante.
      final sugerencia = calcularSugerencia(
        regla: ReglaAhorro.porcentajeIngreso,
        porcentajeBp: 2000,
        ingreso: const Dinero.deCentavos(333333),
        disponibleProyectado: const Dinero.deCentavos(333333),
        enDeficit: false,
      );

      expect(sugerencia.montoSugerido, const Dinero.deCentavos(66667));
    });
  });
}
