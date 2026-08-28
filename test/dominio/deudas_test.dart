import 'package:finanzas/dominio/calculos/deudas.dart';
import 'package:finanzas/dominio/modelos/deuda.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-015 a FR-024, con los ocho escenarios de la HU4.
///
/// D3: **las cuotas no se almacenan, se derivan**. No hay tabla de cuotas: el
/// aporte de una deuda a cada mes se calcula desde su mes de inicio y su
/// número de cuotas.
///
/// D4: **la cuota del mes en curso cuenta como pendiente**. Una deuda de 12
/// cuotas que arranca este mes tiene doce por pagar, no once.
void main() {
  const agosto = Mes(2026, 8);

  Deuda deuda({
    int id = 1,
    int cuotaCentavos = 15000,
    int numCuotas = 12,
    Mes mesInicio = agosto,
    Mes? mesSaldadaAnticipada,
    int tarjetaId = 1,
    String descripcion = 'Celular',
  }) => Deuda(
    id: id,
    descripcion: descripcion,
    tarjetaId: tarjetaId,
    cuotaMensual: Dinero.deCentavos(cuotaCentavos),
    numCuotas: numCuotas,
    mesInicio: mesInicio,
    mesSaldadaAnticipada: mesSaldadaAnticipada,
  );

  group('escenario 1: recién registrada', () {
    test('12 cuotas de S/ 150 desde este mes dejan S/ 1,800 pendientes', () {
      final estado = calcularEstadoDeuda(deuda(), mesRef: agosto);

      // La cuota del mes en curso todavía no se pagó (D4).
      expect(estado.cuotasPagadas, 0);
      expect(estado.cuotasRestantes, 12);
      expect(estado.saldoPendiente, const Dinero.deCentavos(180000));
    });

    test('aporta su cuota al presupuesto del mes de inicio', () {
      expect(
        cuotaVigenteEnMes(deuda(), agosto),
        const Dinero.deCentavos(15000),
      );
    });
  });

  group('escenario 2: con cuotas ya pagadas', () {
    test('tres meses después quedan 9 cuotas y S/ 1,350', () {
      final estado = calcularEstadoDeuda(deuda(), mesRef: const Mes(2026, 11));

      expect(estado.cuotasPagadas, 3);
      expect(estado.cuotasRestantes, 9);
      expect(estado.saldoPendiente, const Dinero.deCentavos(135000));
    });

    test('informa el mes de la última cuota', () {
      // Agosto 2026 más once meses.
      expect(
        calcularEstadoDeuda(deuda(), mesRef: agosto).mesUltimaCuota,
        const Mes(2027, 7),
      );
    });
  });

  group('escenario 3: dos deudas de la misma tarjeta', () {
    test('el compromiso del mes suma S/ 230', () {
      final compromiso = compromisoDeudasEnMes([
        deuda(cuotaCentavos: 15000),
        deuda(id: 2, cuotaCentavos: 8000),
      ], agosto);

      expect(compromiso, const Dinero.deCentavos(23000));
    });

    test('es desglosable deuda por deuda', () {
      // FR-017: la UI puede pedir la cuota de cada una para mostrar de qué se
      // compone el compromiso de la tarjeta.
      final primera = deuda(cuotaCentavos: 15000);
      final segunda = deuda(id: 2, cuotaCentavos: 8000);

      expect(
        cuotaVigenteEnMes(primera, agosto),
        const Dinero.deCentavos(15000),
      );
      expect(cuotaVigenteEnMes(segunda, agosto), const Dinero.deCentavos(8000));
    });
  });

  group('escenario 4: última cuota', () {
    test('el mes de la última cuota todavía aporta', () {
      expect(
        cuotaVigenteEnMes(deuda(), const Mes(2027, 7)),
        const Dinero.deCentavos(15000),
      );
    });

    test('al mes siguiente deja de aportar y queda saldada (FR-019)', () {
      const despues = Mes(2027, 8);

      expect(cuotaVigenteEnMes(deuda(), despues), Dinero.cero);

      final estado = calcularEstadoDeuda(deuda(), mesRef: despues);
      expect(estado.situacion, SituacionDeuda.saldada);
      expect(estado.cuotasRestantes, 0);
      expect(estado.saldoPendiente, Dinero.cero);
    });

    test('las cuotas pagadas nunca superan el total', () {
      final estado = calcularEstadoDeuda(deuda(), mesRef: const Mes(2030, 1));
      expect(estado.cuotasPagadas, 12);
    });
  });

  group('escenario 5: deuda que empieza en el futuro (FR-020)', () {
    final futura = deuda(mesInicio: const Mes(2026, 11));

    test('no aporta al presupuesto del mes actual', () {
      expect(cuotaVigenteEnMes(futura, agosto), Dinero.cero);
    });

    test('pero sí cuenta en el total adeudado', () {
      final estado = calcularEstadoDeuda(futura, mesRef: agosto);
      expect(estado.situacion, SituacionDeuda.futura);
      expect(estado.cuotasRestantes, 12);
      expect(estado.saldoPendiente, const Dinero.deCentavos(180000));
    });
  });

  group('escenario 7: edición retroactiva (FR-023)', () {
    test('cambiar el número de cuotas recalcula el saldo', () {
      final corregida = deuda(numCuotas: 10);
      final estado = calcularEstadoDeuda(corregida, mesRef: agosto);

      expect(estado.cuotasRestantes, 10);
      expect(estado.saldoPendiente, const Dinero.deCentavos(150000));
      expect(estado.mesUltimaCuota, const Mes(2027, 5));
    });

    test('cambiar la cuota recalcula los meses ya transcurridos', () {
      // Se recalcula solo: no hay filas de cuotas que reescribir (D3).
      final corregida = deuda(cuotaCentavos: 20000);
      expect(
        cuotaVigenteEnMes(corregida, const Mes(2026, 9)),
        const Dinero.deCentavos(20000),
      );
    });
  });

  group('escenario 8: saldada anticipadamente (FR-021)', () {
    final saldada = deuda(mesSaldadaAnticipada: const Mes(2026, 11));

    test('deja de aportar desde el mes en que se saldó, inclusive', () {
      expect(
        cuotaVigenteEnMes(saldada, const Mes(2026, 10)),
        const Dinero.deCentavos(15000),
      );
      expect(cuotaVigenteEnMes(saldada, const Mes(2026, 11)), Dinero.cero);
      expect(cuotaVigenteEnMes(saldada, const Mes(2026, 12)), Dinero.cero);
    });

    test('su saldo pendiente pasa a cero', () {
      final estado = calcularEstadoDeuda(saldada, mesRef: const Mes(2026, 11));
      expect(estado.situacion, SituacionDeuda.saldada);
      expect(estado.saldoPendiente, Dinero.cero);
      expect(estado.cuotasRestantes, 0);
    });

    test('antes de saldarla el saldo era el normal', () {
      final estado = calcularEstadoDeuda(saldada, mesRef: const Mes(2026, 10));
      expect(estado.saldoPendiente, const Dinero.deCentavos(150000));
    });
  });

  group('deuda de una sola cuota', () {
    test('se admite y vence el mismo mes', () {
      final unica = deuda(numCuotas: 1);

      expect(cuotaVigenteEnMes(unica, agosto), const Dinero.deCentavos(15000));
      expect(cuotaVigenteEnMes(unica, const Mes(2026, 9)), Dinero.cero);
      expect(calcularEstadoDeuda(unica, mesRef: agosto).mesUltimaCuota, agosto);
    });
  });

  group('panorama de deudas (FR-022)', () {
    test('total adeudado, compromiso del mes y mes libre de deudas', () {
      final panorama = calcularPanorama([
        deuda(cuotaCentavos: 15000, numCuotas: 12),
        deuda(id: 2, cuotaCentavos: 8000, numCuotas: 6),
      ], mesRef: agosto);

      expect(panorama.totalAdeudado, const Dinero.deCentavos(228000));
      expect(panorama.compromisoMensual, const Dinero.deCentavos(23000));
      // La más larga manda: agosto 2026 más once meses.
      expect(panorama.mesLibreDeDeudas, const Mes(2027, 7));
    });

    test('una deuda futura suma al total pero no al compromiso', () {
      final panorama = calcularPanorama([
        deuda(mesInicio: const Mes(2026, 11), cuotaCentavos: 15000),
      ], mesRef: agosto);

      expect(panorama.totalAdeudado, const Dinero.deCentavos(180000));
      expect(panorama.compromisoMensual, Dinero.cero);
    });

    test('las saldadas no cuentan en ningún total', () {
      final panorama = calcularPanorama([
        deuda(mesSaldadaAnticipada: const Mes(2026, 7)),
      ], mesRef: agosto);

      expect(panorama.totalAdeudado, Dinero.cero);
      expect(panorama.compromisoMensual, Dinero.cero);
      expect(panorama.mesLibreDeDeudas, isNull);
    });

    test('sin deudas no hay mes libre que informar', () {
      // La vista comunica el estado libre de deuda en vez de mostrarse vacía.
      final panorama = calcularPanorama(const [], mesRef: agosto);

      expect(panorama.totalAdeudado, Dinero.cero);
      expect(panorama.compromisoMensual, Dinero.cero);
      expect(panorama.mesLibreDeDeudas, isNull);
      expect(panorama.sinDeudas, isTrue);
    });
  });

  group('validación', () {
    test('rechaza menos de una cuota', () {
      expect(() => deuda(numCuotas: 0), throwsAssertionError);
    });
  });

  group('exactitud', () {
    test('el saldo de muchas cuotas es exacto al centavo', () {
      final larga = deuda(cuotaCentavos: 33333, numCuotas: 36);
      final estado = calcularEstadoDeuda(larga, mesRef: agosto);

      expect(estado.saldoPendiente, const Dinero.deCentavos(1199988));
    });
  });
}
