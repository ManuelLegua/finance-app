import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda del Principio III de la constitución: `lib/dominio/` es Dart puro.
///
/// La regla es fácil de romper sin querer — basta un autocompletado que importe
/// `package:flutter/material.dart` para traer un `Color` — y el daño no se nota
/// hasta que las pruebas del dominio dejan de correr sin levantar Flutter.
/// Esta prueba convierte la convención en algo que la suite verifica.
void main() {
  // Todo lo que la capa de dominio puede importar tiene que ser tan puro
  // como ella. Al mover los tipos y los enums a shared/ hubo que extender la
  // guarda: si solo mirara lib/dominio/, bastaria con poner un import de
  // Flutter en shared/constantes/ para saltearla sin que nadie se entere.
  final directoriosPuros = <Directory>[
    Directory('lib/dominio'),
    Directory('lib/shared/tipos'),
    Directory('lib/shared/constantes'),
    Directory('lib/shared/formato'),
  ];

  group('el dominio y lo compartido puro son Dart puro', () {
    test('los directorios puros existen', () {
      for (final directorio in directoriosPuros) {
        expect(
          directorio.existsSync(),
          isTrue,
          reason: 'Falta ${directorio.path} según la estructura del plan.',
        );
      }
    });

    test('ningún archivo importa Flutter, sqflite ni dart:io', () {
      final prohibidos = <String, String>{
        'package:flutter/': 'la lógica financiera no puede depender de la UI',
        'package:sqflite': 'el dominio no conoce la persistencia',
        'package:provider': 'el dominio no conoce el estado de la UI',
        'dart:io': 'el dominio no toca el sistema de archivos',
        'dart:ui': 'el dominio no conoce la capa de render',
        'package:finanzas/ui/': 'lo puro no puede depender de la interfaz',
        'package:finanzas/datos/': 'lo puro no conoce la persistencia',
      };

      final violaciones = <String>[];

      for (final archivo in directoriosPuros.expand(_archivosDart)) {
        final lineas = archivo.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final linea = lineas[i].trim();
          if (!linea.startsWith('import ') && !linea.startsWith('export ')) {
            continue;
          }
          for (final entrada in prohibidos.entries) {
            if (linea.contains(entrada.key)) {
              violaciones.add(
                '${archivo.path}:${i + 1}  ->  ${entrada.key}  '
                '(${entrada.value})',
              );
            }
          }
        }
      }

      expect(
        violaciones,
        isEmpty,
        reason:
            'El dominio debe ser Dart puro (Principio III).\n'
            'Violaciones encontradas:\n  ${violaciones.join('\n  ')}',
      );
    });

    test('ningún archivo llama a DateTime.now()', () {
      // La fecha entra como parámetro. Si el dominio lee el reloj, sus reglas
      // dejan de ser deterministas y la ventana de gracia del cierre de meses
      // se vuelve imposible de probar sin manipular la hora del sistema (D13).
      final violaciones = <String>[];

      for (final archivo in directoriosPuros.expand(_archivosDart)) {
        final lineas = archivo.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          if (_sinComentario(lineas[i]).contains('DateTime.now()')) {
            violaciones.add('${archivo.path}:${i + 1}');
          }
        }
      }

      expect(
        violaciones,
        isEmpty,
        reason:
            'El dominio recibe la fecha como parámetro, no la lee del reloj.\n'
            'Violaciones encontradas:\n  ${violaciones.join('\n  ')}',
      );
    });
  });
}

/// Descarta el comentario de línea, si lo hay.
///
/// La guarda inspecciona código, no prosa: los propios comentarios que
/// explican por qué el dominio no llama a `DateTime.now()` contienen esa
/// cadena, y marcarlos sería castigar la documentación de la regla.
String _sinComentario(String linea) {
  final inicio = linea.indexOf('//');
  return inicio == -1 ? linea : linea.substring(0, inicio);
}

Iterable<File> _archivosDart(Directory directorio) {
  if (!directorio.existsSync()) return const <File>[];
  return directorio
      .listSync(recursive: true)
      .whereType<File>()
      .where((archivo) => archivo.path.endsWith('.dart'));
}
