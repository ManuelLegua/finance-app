import 'package:finanzas/dominio/interpretes/decision_captura.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/textos_capturados.dart';

/// T042 — qué hace el callback con cada notificación que llega.
///
/// La decisión vive acá, separada del callback, porque es la parte que
/// importa y la que no se puede probar con una base de datos de por medio ni
/// con Android corriendo. El callback que la usa se limita a persistir lo que
/// esta función decide.
///
/// Lo que más cuidan estas pruebas es lo que **no** se guarda: de un origen
/// ajeno no puede quedar rastro de ningún tipo (FR-008c), y de una
/// notificación entrante tampoco (FR-012). Un diagnóstico de más sería texto
/// de un correo personal guardado en la base.
const String _paqueteGmail = 'com.google.android.gm';

void main() {
  final recibidaEn = DateTime(2026, 9, 13, 21, 10, 27);

  DecisionCaptura decidir({
    String paquete = _paqueteGmail,
    String? titulo,
    bool esResumenDeGrupo = false,
    required String cuerpo,
    String notificacionId = 'clave-nativa-1',
  }) => decidirCaptura(
    paquete: paquete,
    titulo: titulo,
    esResumenDeGrupo: esResumenDeGrupo,
    cuerpo: cuerpo,
    notificacionId: notificacionId,
    recibidaEn: recibidaEn,
  );

  group('un consumo se guarda como pendiente', () {
    test('G5 produce un pendiente con sus datos', () {
      final decision = decidir(
        titulo: tituloG5G6Sip,
        cuerpo: cuerpoG5SipConsumoSoles,
      );

      expect(decision, isA<RegistrarPendiente>());
      final pendiente = (decision as RegistrarPendiente).pendiente;
      expect(pendiente.monto, const Dinero.deCentavos(3770));
      expect(pendiente.comercio, 'IKF 982 PV VENTANILLA');
      expect(pendiente.origenPaquete, _paqueteGmail);
      expect(pendiente.notificacionId, 'clave-nativa-1');
    });

    test('la fecha del pendiente es la del consumo, no la de captura', () {
      // El consumo fue el 13/09 a las 21:09 y la notificación llegó a las
      // 21:10. Da igual acá, pero no da igual con un correo que llega tarde:
      // el mes al que pertenece el gasto sale de la fecha del consumo.
      final decision = decidir(
        titulo: tituloG5G6Sip,
        cuerpo: cuerpoG5SipConsumoSoles,
      );

      final pendiente = (decision as RegistrarPendiente).pendiente;
      expect(pendiente.fecha, DateTime(2026, 9, 13));
      expect(pendiente.capturadoEn, recibidaEn);
    });

    test('no propone categoría: eso lo resuelve quien lo lee', () {
      // `EstadoPendientes.cargar()` le busca la asociación aprendida a
      // cualquier pendiente que llegue sin categoría. Consultarla acá sería
      // duplicar esa lógica en un isolate que no la necesita.
      final decision = decidir(
        titulo: tituloG5G6Sip,
        cuerpo: cuerpoG5SipConsumoSoles,
      );

      expect((decision as RegistrarPendiente).pendiente.categoriaPropuesta,
          isNull);
    });

    test('un envío de dinero también produce pendiente (D-N15)', () {
      final decision = decidir(
        titulo: tituloG2Sip,
        cuerpo: cuerpoG2SipSaliente,
      );

      expect(decision, isA<RegistrarPendiente>());
      expect(
        (decision as RegistrarPendiente).pendiente.monto,
        const Dinero.deCentavos(2000),
      );
    });
  });

  group('lo que no deja ningún rastro', () {
    test('una app no reconocida no genera nada, ni diagnóstico', () {
      final decision = decidir(
        paquete: 'com.whatsapp',
        titulo: 'Mamá',
        cuerpo: 'Te mandé S/ 50.00 ayer, avisame',
      );

      expect(decision, isA<NoRegistrarNada>());
      expect(
        (decision as NoRegistrarNada).motivo,
        MotivoDeIgnorar.origenNoReconocido,
      );
    });

    test('un correo personal tampoco, aunque venga por Gmail', () {
      // Este es el caso que justifica FR-008c: la app recibe el aviso de todo
      // correo del teléfono. Si un correo ajeno terminara en diagnóstico,
      // habría texto personal guardado en la base.
      final decision = decidir(
        titulo: 'Juan Pérez',
        cuerpo: 'Che, te debo S/ 200.00 del asado',
      );

      expect(decision, isA<NoRegistrarNada>());
      expect(
        (decision as NoRegistrarNada).motivo,
        MotivoDeIgnorar.origenNoReconocido,
      );
    });

    test('el resumen de grupo de Gmail se ignora', () {
      // Gmail publica dos notificaciones por correo. Sin esto, cada consumo
      // se guardaría dos veces con dos identificadores nativos distintos, así
      // que la deduplicación de D-N5 tampoco lo atajaría.
      final decision = decidir(
        titulo: tituloG5G6Sip,
        cuerpo: cuerpoG5SipConsumoSoles,
        esResumenDeGrupo: true,
      );

      expect(decision, isA<NoRegistrarNada>());
      expect(
        (decision as NoRegistrarNada).motivo,
        MotivoDeIgnorar.resumenDeGrupo,
      );
    });

    test('el dinero entrante se ignora sin dejar diagnóstico', () {
      // FR-012 y FR-013 mandan ignorarlo. No es un fallo de interpretación:
      // se entendió perfectamente y no corresponde registrarlo, así que
      // ensuciar el diagnóstico con esto lo volvería inútil.
      final decision = decidir(
        titulo: tituloG3Bcp,
        cuerpo: cuerpoG3BcpEntrante,
      );

      expect(decision, isA<NoRegistrarNada>());
      expect(
        (decision as NoRegistrarNada).motivo,
        MotivoDeIgnorar.noEsConsumo,
      );
    });
  });

  group('lo que no se pudo interpretar va a diagnóstico', () {
    test('un consumo en dólares deja constancia de por qué no entró', () {
      final decision = decidir(
        titulo: tituloG4Bcp,
        cuerpo: cuerpoG4BcpConsumoDolares,
      );

      expect(decision, isA<RegistrarDiagnostico>());
      final diagnostico = (decision as RegistrarDiagnostico).diagnostico;
      expect(diagnostico.motivo, MotivoDiagnostico.monedaExtranjera);
      expect(diagnostico.origenPaquete, _paqueteGmail);
      expect(diagnostico.textoCrudo, cuerpoG4BcpConsumoDolares);
    });

    test('el diagnóstico guarda el texto entero, no el recortado', () {
      // Lo que se guarda existe para entender por qué falló el
      // reconocimiento. Guardar el texto ya recortado escondería justamente
      // el tramo que podría estar causando el fallo.
      final decision = decidir(
        titulo: tituloG4Bcp,
        cuerpo: cuerpoG4BcpConsumoDolares,
      );

      expect(
        (decision as RegistrarDiagnostico).diagnostico.textoCrudo.length,
        cuerpoG4BcpConsumoDolares.length,
      );
    });

    test('un formato irreconocible de un origen conocido va a diagnóstico', () {
      final decision = decidir(
        titulo: tituloG3Bcp,
        cuerpo: 'Algo pasó con tu cuenta pero no decimos qué.',
      );

      expect(decision, isA<RegistrarDiagnostico>());
      expect(
        (decision as RegistrarDiagnostico).diagnostico.motivo,
        MotivoDiagnostico.formatoNoReconocido,
      );
    });
  });
}
