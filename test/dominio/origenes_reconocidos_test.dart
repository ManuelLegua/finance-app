import 'package:finanzas/shared/constantes/origenes_reconocidos.dart';
import 'package:flutter_test/flutter_test.dart';

/// T041a — el filtro de orígenes, con los dos modos que decidió D-N12.
///
/// Lo que estas pruebas cuidan no es que el filtro reconozca al BCP: es que
/// **no reconozca nada más**. Reconocer el correo como vía hace que la app
/// reciba el aviso de todo correo del teléfono, y FR-008c exige descartar lo
/// ajeno sin leerlo. Un falso positivo acá no es un pendiente de más: es un
/// correo personal leído.
const String _paqueteGmail = 'com.google.android.gm';

void main() {
  group('OrigenReconocido — dos modos de identificación (D-N12)', () {
    test('un origen con remitente verificado es utilizable sin paquete', () {
      // Banco Falabella es el caso inverso: tiene paquete y ningún remitente,
      // porque su app sí notifica por su cuenta.
      final falabella = origenesReconocidos.firstWhere(
        (origen) => origen.nombre == 'Banco Falabella',
      );

      expect(falabella.paqueteVerificado, isTrue);
      expect(falabella.remitenteVerificado, isFalse);
      expect(falabella.utilizable, isTrue);
    });

    test('un origen sin ninguno de los dos verificados no es utilizable', () {
      final interbank = origenesReconocidos.firstWhere(
        (origen) => origen.nombre == 'Interbank',
      );

      expect(interbank.utilizable, isFalse);
    });

    test('Yape tiene los dos modos verificados', () {
      final yape = origenesReconocidos.firstWhere(
        (origen) => origen.nombre == 'Yape',
      );

      expect(yape.paquete, 'com.bcp.innovacxion.yapeapp');
      expect(yape.remitentes, {'YAPE Notificaciones'});
    });

    test('un emisor puede firmar con más de un remitente', () {
      // Sip firma `Operaciones Sip` un envío de dinero y `Sip` a secas un
      // consumo con tarjeta (G5, G6). Con un solo remitente por origen, los
      // consumos —lo único que esta spec captura— se descartaban.
      final sip = origenesReconocidos.firstWhere(
        (origen) => origen.nombre == 'Oh! / Sip',
      );

      expect(sip.remitentes, containsAll(<String>['Operaciones Sip', 'Sip']));
    });
  });

  group('filtrarNotificacion — por remitente, el caso del correo', () {
    test('un correo del BCP se reconoce por el título, no por el paquete', () {
      final decision = filtrarNotificacion(
        paquete: _paqueteGmail,
        titulo: 'BCP Notificaciones',
        esResumenDeGrupo: false,
      );

      expect(decision, isA<ProcesarComo>());
      expect((decision as ProcesarComo).origen.nombre, 'BCP');
    });

    test('los cuatro remitentes observados el 2026-09-13 se reconocen', () {
      const observados = {
        'BCP Notificaciones': 'BCP',
        'Operaciones Sip': 'Oh! / Sip',
        'Sip': 'Oh! / Sip',
        'YAPE Notificaciones': 'Yape',
      };

      for (final entrada in observados.entries) {
        final decision = filtrarNotificacion(
          paquete: _paqueteGmail,
          titulo: entrada.key,
          esResumenDeGrupo: false,
        );

        expect(
          decision,
          isA<ProcesarComo>(),
          reason: '${entrada.key} tendría que reconocerse',
        );
        expect((decision as ProcesarComo).origen.nombre, entrada.value);
      }
    });

    test('un correo personal se descarta por origen no reconocido', () {
      final decision = filtrarNotificacion(
        paquete: _paqueteGmail,
        titulo: 'Juan Pérez',
        esResumenDeGrupo: false,
      );

      expect(decision, isA<Descartar>());
      expect(
        (decision as Descartar).motivo,
        MotivoDescarte.origenNoReconocido,
      );
    });

    test(
      'el título se compara exacto: contener el nombre del banco no alcanza',
      () {
        // Si esto calzara, un correo de alguien llamado "BCP" o un boletín
        // publicitario entrarían al parser — y el filtro es lo único que
        // separa el correo del banco del resto de la bandeja.
        const titulosQueNoSonElBanco = [
          'Ofertas BCP Notificaciones y más',
          'bcp notificaciones',
          'BCP',
          'Notificaciones',
        ];

        for (final titulo in titulosQueNoSonElBanco) {
          final decision = filtrarNotificacion(
            paquete: _paqueteGmail,
            titulo: titulo,
            esResumenDeGrupo: false,
          );

          expect(
            decision,
            isA<Descartar>(),
            reason: '"$titulo" no es el remitente del banco',
          );
        }
      },
    );

    test('un título con espacios de más sí calza, porque se recorta', () {
      final decision = filtrarNotificacion(
        paquete: _paqueteGmail,
        titulo: '  BCP Notificaciones  ',
        esResumenDeGrupo: false,
      );

      expect(decision, isA<ProcesarComo>());
    });

    test('sin título no hay forma de reconocer un correo', () {
      for (final titulo in <String?>[null, '', '   ']) {
        final decision = filtrarNotificacion(
          paquete: _paqueteGmail,
          titulo: titulo,
          esResumenDeGrupo: false,
        );

        expect(decision, isA<Descartar>());
      }
    });
  });

  group('filtrarNotificacion — por paquete, el caso del push', () {
    test('los cuatro paquetes observados el 2026-09-13 se reconocen', () {
      const observados = {
        'com.bcp.bank.bcp': 'BCP',
        'com.bcp.innovacxion.yapeapp': 'Yape',
        'pe.solera.tarjetaoh': 'Oh! / Sip',
        'com.falabella.falabellaApp': 'Banco Falabella',
      };

      for (final entrada in observados.entries) {
        final decision = filtrarNotificacion(
          paquete: entrada.key,
          titulo: 'lo que sea',
          esResumenDeGrupo: false,
        );

        expect(decision, isA<ProcesarComo>(), reason: entrada.key);
        expect((decision as ProcesarComo).origen.nombre, entrada.value);
      }
    });

    test('el push de Yape se reconoce por su paquete', () {
      final decision = filtrarNotificacion(
        paquete: 'com.bcp.innovacxion.yapeapp',
        titulo: 'Confirmación de Pago',
        esResumenDeGrupo: false,
      );

      expect(decision, isA<ProcesarComo>());
      expect((decision as ProcesarComo).origen.nombre, 'Yape');
    });

    test('una app cualquiera del teléfono se descarta', () {
      final decision = filtrarNotificacion(
        paquete: 'com.whatsapp',
        titulo: 'Mamá',
        esResumenDeGrupo: false,
      );

      expect(decision, isA<Descartar>());
      expect(
        (decision as Descartar).motivo,
        MotivoDescarte.origenNoReconocido,
      );
    });

    test('un origen sin verificar no se escucha, y eso no rompe nada', () {
      // Interbank está sembrado sin paquete ni remitente. La cadena vacía no
      // puede calzar con el paquete real de ninguna notificación.
      final decision = filtrarNotificacion(
        paquete: '',
        titulo: '',
        esResumenDeGrupo: false,
      );

      expect(decision, isA<Descartar>());
    });
  });

  group('filtrarNotificacion — el resumen de grupo de Gmail (D-N12)', () {
    test('se descarta aunque el remitente sea un banco reconocido', () {
      // El caso de G4: a las 10:54 Gmail publicó dos notificaciones con el
      // mismo título y el mismo `bigText`, con 7 ms de diferencia. Procesar
      // las dos registraría el consumo dos veces.
      final decision = filtrarNotificacion(
        paquete: _paqueteGmail,
        titulo: 'BCP Notificaciones',
        esResumenDeGrupo: true,
      );

      expect(decision, isA<Descartar>());
      expect((decision as Descartar).motivo, MotivoDescarte.resumenDeGrupo);
    });

    test(
      'el descarte no depende de la forma del texto, solo de isGroup',
      () {
        // La regla que dejaron G1–G3 —`bigText == null && textLines != null`—
        // era falsa: el resumen de un solo correo sin leer copia el `bigText`
        // entero y no trae `textLines`, así que por texto es indistinguible
        // del correo. Esta prueba existe para que esa regla no vuelva.
        final resumen = filtrarNotificacion(
          paquete: _paqueteGmail,
          titulo: 'BCP Notificaciones',
          esResumenDeGrupo: true,
        );
        final correo = filtrarNotificacion(
          paquete: _paqueteGmail,
          titulo: 'BCP Notificaciones',
          esResumenDeGrupo: false,
        );

        expect(resumen, isA<Descartar>());
        expect(correo, isA<ProcesarComo>());
      },
    );
  });
}
