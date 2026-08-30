import 'package:finanzas/dominio/modelos/estado_captura.dart';
import 'package:finanzas/shared/constantes/origenes_reconocidos.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-003, FR-004: el estado de la captura se deriva del permiso real del
/// sistema y del interruptor de la app, nunca de lo que el usuario aceptó
/// alguna vez.
void main() {
  group('situacion', () {
    test('sin permiso y nunca activada: sinPermiso', () {
      const estado = EstadoCaptura(permisoConcedido: false, activaEnApp: false);
      expect(estado.situacion, SituacionCaptura.sinPermiso);
    });

    test('permiso concedido pero interruptor apagado: inactivaEnApp', () {
      const estado = EstadoCaptura(permisoConcedido: true, activaEnApp: false);
      expect(estado.situacion, SituacionCaptura.inactivaEnApp);
    });

    test(
      'se activó alguna vez pero el permiso ya no está: permisoRevocado',
      () {
        const estado = EstadoCaptura(
          permisoConcedido: false,
          activaEnApp: true,
        );
        expect(estado.situacion, SituacionCaptura.permisoRevocado);
      },
    );

    test('permiso concedido y activada: activa', () {
      const estado = EstadoCaptura(permisoConcedido: true, activaEnApp: true);
      expect(estado.situacion, SituacionCaptura.activa);
    });
  });

  group('motivo', () {
    test('cada situación tiene un texto explicativo distinto', () {
      final motivos = <String>{
        for (final permiso in [true, false])
          for (final activa in [true, false])
            EstadoCaptura(
              permisoConcedido: permiso,
              activaEnApp: activa,
            ).motivo,
      };

      // Cuatro combinaciones, cuatro textos: ninguno se repite entre sí.
      expect(motivos, hasLength(4));
      for (final motivo in motivos) {
        expect(motivo, isNotEmpty);
      }
    });
  });

  group('origenesQueCubre', () {
    test('activa: la lista completa de orígenes reconocidos', () {
      const estado = EstadoCaptura(permisoConcedido: true, activaEnApp: true);
      expect(estado.origenesQueCubre, origenesReconocidos);
      expect(estado.origenesQueCubre, isNotEmpty);
    });

    test('sin permiso: vacía', () {
      const estado = EstadoCaptura(permisoConcedido: false, activaEnApp: false);
      expect(estado.origenesQueCubre, isEmpty);
    });

    test('permiso revocado: vacía, no la última lista conocida', () {
      const estado = EstadoCaptura(permisoConcedido: false, activaEnApp: true);
      expect(estado.origenesQueCubre, isEmpty);
    });

    test('inactiva en la app: vacía', () {
      const estado = EstadoCaptura(permisoConcedido: true, activaEnApp: false);
      expect(estado.origenesQueCubre, isEmpty);
    });
  });

  group('igualdad por valor', () {
    test('dos estados con los mismos booleanos son iguales', () {
      expect(
        const EstadoCaptura(permisoConcedido: true, activaEnApp: false),
        const EstadoCaptura(permisoConcedido: true, activaEnApp: false),
      );
    });
  });
}
