import 'package:finanzas/dominio/modelos/estado_captura.dart';
import 'package:finanzas/shared/constantes/origenes_reconocidos.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-003, FR-004: el estado de la captura se deriva del permiso real del
/// sistema, del interruptor de la app y de que el servicio esté efectivamente
/// corriendo — nunca de lo que el usuario aceptó alguna vez.
///
/// **El tercer dato lo agregó D-N13 (2026-09-13)**, y no es un refinamiento
/// cosmético: durante la validación en dispositivo se vio la pantalla diciendo
/// "Captura activa" con el servicio muerto. Un usuario en esa situación cree
/// que sus consumos se están capturando mientras no se captura nada, que es
/// exactamente la confianza que el Principio IV protege.
void main() {
  group('situacion', () {
    test('sin permiso y nunca activada: sinPermiso', () {
      const estado = EstadoCaptura(
        permisoConcedido: false,
        activaEnApp: false,
        servicioCorriendo: false,
      );
      expect(estado.situacion, SituacionCaptura.sinPermiso);
    });

    test('permiso concedido pero interruptor apagado: inactivaEnApp', () {
      const estado = EstadoCaptura(
        permisoConcedido: true,
        activaEnApp: false,
        servicioCorriendo: false,
      );
      expect(estado.situacion, SituacionCaptura.inactivaEnApp);
    });

    test(
      'se activó alguna vez pero el permiso ya no está: permisoRevocado',
      () {
        const estado = EstadoCaptura(
          permisoConcedido: false,
          activaEnApp: true,
          servicioCorriendo: false,
        );
        expect(estado.situacion, SituacionCaptura.permisoRevocado);
      },
    );

    test('permiso, interruptor y servicio corriendo: activa', () {
      const estado = EstadoCaptura(
        permisoConcedido: true,
        activaEnApp: true,
        servicioCorriendo: true,
      );
      expect(estado.situacion, SituacionCaptura.activa);
    });

    test('todo en orden salvo el servicio: detenida, no activa (D-N13)', () {
      // El caso observado en dispositivo: permiso concedido, interruptor
      // encendido, y Android había matado el servicio. La app decía "activa".
      const estado = EstadoCaptura(
        permisoConcedido: true,
        activaEnApp: true,
        servicioCorriendo: false,
      );
      expect(estado.situacion, SituacionCaptura.detenida);
      expect(estado.situacion, isNot(SituacionCaptura.activa));
    });

    test('sin permiso, el servicio corriendo no alcanza para estar activa', () {
      // Android puede tener el servicio vinculado y aun así no entregarle
      // notificaciones si el permiso no está: el permiso manda.
      const estado = EstadoCaptura(
        permisoConcedido: false,
        activaEnApp: true,
        servicioCorriendo: true,
      );
      expect(estado.situacion, SituacionCaptura.permisoRevocado);
    });
  });

  group('motivo', () {
    test('cada situación tiene un texto explicativo distinto', () {
      final motivos = <String>{
        for (final situacion in SituacionCaptura.values)
          _estadoPara(situacion).motivo,
      };

      expect(motivos, hasLength(SituacionCaptura.values.length));
      for (final motivo in motivos) {
        expect(motivo, isNotEmpty);
      }
    });

    test('el de detenida no promete que se esté capturando', () {
      const estado = EstadoCaptura(
        permisoConcedido: true,
        activaEnApp: true,
        servicioCorriendo: false,
      );
      expect(estado.motivo, contains('dejó de'));
    });
  });

  group('origenesQueCubre', () {
    test('activa: la lista completa de orígenes reconocidos', () {
      const estado = EstadoCaptura(
        permisoConcedido: true,
        activaEnApp: true,
        servicioCorriendo: true,
      );
      expect(estado.origenesQueCubre, origenesReconocidos);
      expect(estado.origenesQueCubre, isNotEmpty);
    });

    test('detenida: vacía, porque no se está cubriendo ninguno', () {
      const estado = EstadoCaptura(
        permisoConcedido: true,
        activaEnApp: true,
        servicioCorriendo: false,
      );
      expect(estado.origenesQueCubre, isEmpty);
    });

    test('sin permiso: vacía', () {
      const estado = EstadoCaptura(
        permisoConcedido: false,
        activaEnApp: false,
        servicioCorriendo: false,
      );
      expect(estado.origenesQueCubre, isEmpty);
    });

    test('permiso revocado: vacía, no la última lista conocida', () {
      const estado = EstadoCaptura(
        permisoConcedido: false,
        activaEnApp: true,
        servicioCorriendo: false,
      );
      expect(estado.origenesQueCubre, isEmpty);
    });

    test('inactiva en la app: vacía', () {
      const estado = EstadoCaptura(
        permisoConcedido: true,
        activaEnApp: false,
        servicioCorriendo: false,
      );
      expect(estado.origenesQueCubre, isEmpty);
    });
  });

  group('igualdad por valor', () {
    test('dos estados con los mismos booleanos son iguales', () {
      expect(
        const EstadoCaptura(
          permisoConcedido: true,
          activaEnApp: false,
          servicioCorriendo: false,
        ),
        const EstadoCaptura(
          permisoConcedido: true,
          activaEnApp: false,
          servicioCorriendo: false,
        ),
      );
    });

    test(
      'el servicio corriendo distingue dos estados por lo demás iguales',
      () {
        expect(
          const EstadoCaptura(
            permisoConcedido: true,
            activaEnApp: true,
            servicioCorriendo: true,
          ),
          isNot(
            const EstadoCaptura(
              permisoConcedido: true,
              activaEnApp: true,
              servicioCorriendo: false,
            ),
          ),
        );
      },
    );
  });
}

/// Un estado que produce [situacion], para recorrer el enum sin repetir
/// combinaciones a mano.
EstadoCaptura _estadoPara(SituacionCaptura situacion) => switch (situacion) {
  SituacionCaptura.sinPermiso => const EstadoCaptura(
    permisoConcedido: false,
    activaEnApp: false,
    servicioCorriendo: false,
  ),
  SituacionCaptura.permisoRevocado => const EstadoCaptura(
    permisoConcedido: false,
    activaEnApp: true,
    servicioCorriendo: false,
  ),
  SituacionCaptura.inactivaEnApp => const EstadoCaptura(
    permisoConcedido: true,
    activaEnApp: false,
    servicioCorriendo: false,
  ),
  SituacionCaptura.detenida => const EstadoCaptura(
    permisoConcedido: true,
    activaEnApp: true,
    servicioCorriendo: false,
  ),
  SituacionCaptura.activa => const EstadoCaptura(
    permisoConcedido: true,
    activaEnApp: true,
    servicioCorriendo: true,
  ),
};
