import 'package:finanzas/dominio/interpretes/interprete.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/textos_capturados.dart';

/// T038a — la parte de T038 que los fixtures capturados ya cubren.
///
/// **Estas pruebas están en rojo a propósito.** `interpretar()` todavía lanza
/// `UnimplementedError`: T039 la implementa hasta que esto pase. Es el orden
/// que pide la constitución para una regla que decide qué se registra como
/// gasto, no un descuido.
///
/// El camino feliz ya está cubierto: G5 y G6, dos consumos con tarjeta de
/// crédito en soles capturados la noche del 2026-09-13, cerraron T034.
void main() {
  /// La fecha de recepción entra siempre como parámetro (Dart puro, sin
  /// reloj). Es el momento en que llegó la notificación, no el del consumo.
  final recibidaEn = DateTime(2026, 9, 13, 10, 54);

  group('dinero entrante — FR-012, FR-013', () {
    test('un yapeo recibido no es un consumo', () {
      final resultado = interpretar(
        titulo: tituloG3Bcp,
        contenido: cuerpoG3BcpEntrante,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<NoEsConsumo>());
    });

    test('un yapeo recibido nunca produce un consumo, ni siquiera parcial', () {
      // El texto trae un monto perfectamente legible (`S/ 20.00`). Lo que lo
      // descalifica es la dirección del dinero, no la falta de datos — así
      // que es justo el caso donde un parser apurado inventaría un gasto.
      final resultado = interpretar(
        titulo: tituloG3Bcp,
        contenido: cuerpoG3BcpEntrante,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isNot(isA<ConsumoExtraido>()));
    });
  });

  group('moneda extranjera — FR-014', () {
    test('un consumo en dólares no se registra', () {
      final resultado = interpretar(
        titulo: tituloG4Bcp,
        contenido: cuerpoG4BcpConsumoDolares,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<NoInterpretable>());
      expect(
        (resultado as NoInterpretable).motivo,
        MotivoDiagnostico.monedaExtranjera,
      );
    });

    test('no se convierte a soles ni se adivina un monto', () {
      // La regla 5 del proyecto no admite multimoneda y D14 de la spec 001
      // rechazó traer tipos de cambio de ninguna parte. Registrar `$ 23.60`
      // como `S/ 23.60` sería peor que no registrarlo.
      final resultado = interpretar(
        titulo: tituloG4Bcp,
        contenido: cuerpoG4BcpConsumoDolares,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isNot(isA<ConsumoExtraido>()));
    });
  });

  group('el pie del correo no envenena la clasificación — D-N12, punto 3', () {
    test('el motivo es la moneda, no el formato', () {
      // Esta es la prueba que justifica acotar la lectura. El texto que entra
      // son los 1024 caracteres completos, pie incluido: "¿Problemas con tus
      // compras? Si tu compra fue rechazada..." y "...tu tarjeta de débito o
      // crédito...". Un parser que lea todo ve señales de compra y de rechazo
      // a la vez y, por la propia regla de D-N11, devuelve
      // `formatoNoReconocido` — mandando a diagnóstico un consumo que es
      // inequívoco en sus primeros 200 caracteres.
      //
      // Que el motivo sea `monedaExtranjera` prueba dos cosas de una: que el
      // parser llegó a leer el monto, y que no se dejó confundir por el pie.
      final resultado = interpretar(
        titulo: tituloG4Bcp,
        contenido: cuerpoG4BcpConsumoDolares,
        recibidaEn: recibidaEn,
      );

      expect(
        resultado,
        isA<NoInterpretable>(),
        reason: 'el consumo en dólares es interpretable, solo que rechazable',
      );
      expect(
        (resultado as NoInterpretable).motivo,
        isNot(MotivoDiagnostico.formatoNoReconocido),
        reason: 'si sale formatoNoReconocido, el parser leyó el pie del correo',
      );
    });
  });

  group('un envío de dinero también es un consumo — FR-008d, D-N15', () {
    test('un envío por Sip se registra como consumo', () {
      // Baja el saldo igual que una compra con tarjeta, así que es un gasto.
      // Las frases de G2 —"Realizaste una operación", "Enviar a celular"— no
      // estaban en las listas de D-N11, escritas pensando solo en tarjetas, y
      // este gasto terminaba en diagnóstico.
      final resultado = interpretar(
        titulo: tituloG2Sip,
        contenido: cuerpoG2SipSaliente,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<ConsumoExtraido>());
      expect((resultado as ConsumoExtraido).monto, const Dinero.deCentavos(2000));
    });

    test('el destinatario ocupa el lugar del comercio', () {
      // En un envío a una persona no hay comercio: el campo se llena con quien
      // recibe. `normalizarComercio` lo trata igual y la categorización
      // aprendida funciona lo mismo con "Juan Pérez → familia" que con
      // "Plaza Vea → mercado" (punto 2 de D-N15).
      final resultado = interpretar(
        titulo: tituloG2Sip,
        contenido: cuerpoG2SipSaliente,
        recibidaEn: recibidaEn,
      );

      expect(
        (resultado as ConsumoExtraido).comercio,
        contains('Manuel Alexander Legua Mendoza'),
      );
    });

    test(
      'un traspaso entre cuentas propias se propone igual, y está bien',
      () {
        // G2 y G3 son el mismo usuario moviéndose S/ 20.00 de una cuenta a
        // otra a las 00:29: la salida se propone como gasto aunque no lo sea.
        // No hay forma de saberlo del texto —la app no conoce el nombre ni
        // las cuentas del usuario— y perder todos los envíos reales para
        // evitar este caso sería peor. Lo atrapa la confirmación (FR-020).
        //
        // La prueba fija la decisión: si algún día esto devuelve
        // `NoEsConsumo`, alguien intentó adivinar lo que no se puede saber.
        final salida = interpretar(
          titulo: tituloG2Sip,
          contenido: cuerpoG2SipSaliente,
          recibidaEn: recibidaEn,
        );
        final entrada = interpretar(
          titulo: tituloG3Bcp,
          contenido: cuerpoG3BcpEntrante,
          recibidaEn: recibidaEn,
        );

        expect(salida, isA<ConsumoExtraido>());
        expect(entrada, isA<NoEsConsumo>());
      },
    );
  });

  group('sin monto no hay movimiento — D-N16', () {
    test('un aviso de Yape sin cifra no va a diagnóstico', () {
      // G7 confirma un yapeo pero no dice de cuánto. Antes caía en
      // `formatoNoReconocido`, que era mentira por partida doble: el formato
      // se entendió perfectamente, y llamar "fallo de reconocimiento" a algo
      // donde no había nada que reconocer llenaba de ruido el registro que
      // existe para encontrar consumos mal interpretados. Llega cada vez que
      // el usuario yapea.
      final resultado = interpretar(
        titulo: tituloG7Yape,
        contenido: cuerpoG7YapeAvisoSinMonto,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<NoEsConsumo>());
    });

    test('una promoción sin cifra tampoco', () {
      final resultado = interpretar(
        titulo: tituloG3Bcp,
        contenido: 'Conocé los beneficios de tu tarjeta. Ingresá y descubrí '
            'todas las promociones que tenemos para vos.',
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<NoEsConsumo>());
    });

    test('con cifra y sin dirección clara, sí va a diagnóstico', () {
      // La contracara, y la razón de que la regla mire el monto y no otra
      // cosa: si hay una cifra, hubo un movimiento, y no haber podido
      // clasificarlo es exactamente lo que el diagnóstico tiene que registrar.
      final resultado = interpretar(
        titulo: tituloG3Bcp,
        contenido: 'Se ha procesado una operación por S/ 80.00 en tu cuenta.',
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<NoInterpretable>());
      expect(
        (resultado as NoInterpretable).motivo,
        MotivoDiagnostico.formatoNoReconocido,
      );
    });

    test('un texto vacío es un no-movimiento, no un fallo', () {
      final resultado = interpretar(
        titulo: tituloG3Bcp,
        contenido: '',
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<NoEsConsumo>());
    });
  });

  group('sin palabras clave de dirección — D-N11, FR-017', () {
    test('un texto con señales de las dos direcciones va a diagnóstico', () {
      final resultado = interpretar(
        titulo: tituloG3Bcp,
        contenido: 'Realizaste un consumo de S/ 50.00. Abono recibido.',
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<NoInterpretable>());
      expect(
        (resultado as NoInterpretable).motivo,
        MotivoDiagnostico.formatoNoReconocido,
      );
    });
  });

  group('el camino feliz — un consumo con tarjeta en soles', () {
    test('G5 produce un consumo con su monto, comercio y fecha', () {
      final resultado = interpretar(
        titulo: tituloG5G6Sip,
        contenido: cuerpoG5SipConsumoSoles,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<ConsumoExtraido>());
      final consumo = resultado as ConsumoExtraido;
      expect(consumo.monto, const Dinero.deCentavos(3770));
      expect(consumo.comercio, contains('IKF 982 PV VENTANILLA'));
      expect(consumo.fecha, DateTime(2026, 9, 13));
    });

    test('el sol se escribe `S/.` con punto, no solo `S/`', () {
      // El BCP escribe `S/ 23.60` y Sip escribe `S/. 37.70`. La expresión
      // regular que D-N3 propone de ejemplo —`S/\s*([\d,]+\.\d{2})`— no
      // reconoce la segunda. Esta prueba existe para que no se escriba así.
      final resultado = interpretar(
        titulo: tituloG5G6Sip,
        contenido: cuerpoG6SipConsumoSoles,
        recibidaEn: recibidaEn,
      );

      expect((resultado as ConsumoExtraido).monto, const Dinero.deCentavos(1590));
    });

    test('el pie de Sip no lleva `¿` y el parser no puede depender de eso', () {
      // El corte del pie que sirve para el BCP —el primer renglón que empieza
      // con `¿`— no existe en el correo de Sip, que arranca su pie con "Si no
      // reconoces la operación". El cuerpo entero entra igual y tiene que
      // interpretarse bien.
      expect(cuerpoG5SipConsumoSoles.contains('¿'), isFalse);

      final resultado = interpretar(
        titulo: tituloG5G6Sip,
        contenido: cuerpoG5SipConsumoSoles,
        recibidaEn: recibidaEn,
      );

      expect(resultado, isA<ConsumoExtraido>());
    });

    test('dos consumos distintos del mismo minuto no se confunden', () {
      final primero = interpretar(
        titulo: tituloG5G6Sip,
        contenido: cuerpoG5SipConsumoSoles,
        recibidaEn: recibidaEn,
      ) as ConsumoExtraido;
      final segundo = interpretar(
        titulo: tituloG5G6Sip,
        contenido: cuerpoG6SipConsumoSoles,
        recibidaEn: recibidaEn,
      ) as ConsumoExtraido;

      expect(primero.monto, isNot(segundo.monto));
      expect(primero.comercio, isNot(segundo.comercio));
    });
  });
}
