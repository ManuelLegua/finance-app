import 'dart:typed_data';

import 'package:finanzas/dominio/interpretes/volcado_notificacion.dart';
import 'package:flutter_test/flutter_test.dart';

/// El instrumento temporal que busca el insumo de T034 y T041 (spec 002).
///
/// Se prueba aunque sea temporal por dos motivos concretos: si el volcado
/// deja afuera `bigText` la salida sería engañosa y daríamos por cerrada una
/// decisión de diseño con un dato falso, y si el filtro de paquetes fallara
/// volcaría el contenido de todas las notificaciones del teléfono a un log.
void main() {
  const gmail = 'com.google.android.gm';

  group('qué paquetes se vuelcan', () {
    test('un paquete que no está bajo observación no produce volcado', () {
      final volcado = volcadoDeTexto(
        paquete: 'com.whatsapp',
        crudo: <Object?, Object?>{'text': 'Mensaje privado de alguien'},
      );

      expect(volcado, isNull);
    });

    test('Gmail sí, que es de donde llegan los consumos en este teléfono', () {
      final volcado = volcadoDeTexto(
        paquete: gmail,
        crudo: <Object?, Object?>{'text': 'Realizaste un consumo'},
      );

      expect(volcado, isNotNull);
      expect(volcado, contains(gmail));
    });

    test('de cualquier notificación se registra solo el paquete', () {
      // T041 necesita los nombres de paquete; ninguna otra cosa de una
      // notificación ajena tiene por qué quedar escrita en ningún lado.
      expect(lineaDeOrigen('com.bcp.bank.android'), contains('com.bcp'));
      expect(lineaDeOrigen('com.bcp.bank.android'), startsWith(marcaDeVolcado));
    });
  });

  group('qué se vuelca de una notificación bajo observación', () {
    test(
      'incluye bigText y textLines, que son la razón de existir de esto',
      () {
        final volcado = volcadoDeTexto(
          paquete: gmail,
          crudo: <Object?, Object?>{
            'title': 'Banco',
            'text': 'Realizaste un consumo por S/ 45.50 en ESVI…',
            'bigText':
                'Realizaste un consumo por S/ 45.50 en ESVISALUD SAC el '
                '12/09/2026 con tu tarjeta terminada en 1234.',
            'textLines': <String>['Primera línea', 'Segunda línea'],
          },
        );

        expect(volcado, contains('ESVISALUD SAC'));
        expect(volcado, contains('[0] Primera línea'));
        expect(volcado, contains('[1] Segunda línea'));
      },
    );

    test('nunca incluye binarios, aunque vengan en el mapa', () {
      // El ícono grande viaja como bytes dentro de `raw`. Volcarlo llenaría
      // el log de basura y escondería lo único que importa.
      final volcado = volcadoDeTexto(
        paquete: gmail,
        crudo: <Object?, Object?>{
          'text': 'Realizaste un consumo',
          'largeIcon': Uint8List.fromList(<int>[1, 2, 3, 4]),
        },
      );

      expect(volcado, isNot(contains('largeIcon')));
      expect(volcado, isNot(contains('[1, 2, 3, 4]')));
    });

    test('un campo ausente se dice, no se omite', () {
      // Que `bigText` falte es un resultado, no un hueco: tiene que verse.
      final volcado = volcadoDeTexto(
        paquete: gmail,
        crudo: <Object?, Object?>{'text': 'Realizaste un consumo'},
      );

      expect(volcado, contains('bigText: (ausente)'));
    });
  });

  group('el veredicto, que es la respuesta que se fue a buscar', () {
    test('sin bigText dice que el preview es todo lo que llega', () {
      final volcado = volcadoDeTexto(
        paquete: gmail,
        crudo: <Object?, Object?>{'text': 'Realizaste un consumo en ESVI…'},
      );

      expect(volcado, contains('no hay bigText'));
    });

    test('con un bigText más largo dice que trae más que el preview', () {
      final volcado = volcadoDeTexto(
        paquete: gmail,
        crudo: <Object?, Object?>{
          'text': 'Realizaste un consumo',
          'bigText': 'Realizaste un consumo por S/ 45.50 en ESVISALUD SAC',
        },
      );

      expect(volcado, contains('trae más que el preview'));
    });

    test('con un bigText igual de corto dice que no agrega nada', () {
      // El caso que decide que esta vía está muerta: Gmail manda bigText,
      // pero truncado igual que el preview.
      final volcado = volcadoDeTexto(
        paquete: gmail,
        crudo: <Object?, Object?>{
          'text': 'Realizaste un consumo',
          'bigText': 'Realizaste un consumo',
        },
      );

      expect(volcado, contains('no agrega nada'));
    });

    test('un bigText vacío cuenta como ausente', () {
      // Android completa algunos extras con cadena vacía; tratarlos como
      // presentes daría un veredicto falso.
      final volcado = volcadoDeTexto(
        paquete: gmail,
        crudo: <Object?, Object?>{
          'text': 'Realizaste un consumo',
          'bigText': '',
        },
      );

      expect(volcado, contains('no hay bigText'));
    });
  });
}
