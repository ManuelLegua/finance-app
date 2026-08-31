import 'package:finanzas/dominio/interpretes/normalizador_comercio.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-032, D-N7: variantes de mayúsculas, espacios y sufijos de sucursal
/// normalizan igual, para que un mismo comercio no aparezca como dos
/// asociaciones distintas.
void main() {
  group('mayúsculas y espacios', () {
    test('mayúsculas y minúsculas normalizan igual', () {
      expect(normalizarComercio('tottus'), normalizarComercio('TOTTUS'));
      expect(normalizarComercio('Tottus'), 'TOTTUS');
    });

    test('espacios repetidos y en los extremos se recortan', () {
      expect(
        normalizarComercio('  Tottus   San Isidro  '),
        normalizarComercio('Tottus San Isidro'),
      );
      expect(normalizarComercio('  KFC  '), 'KFC');
    });
  });

  group('sufijo de sucursal por código numérico', () {
    test('un código de local al final se recorta', () {
      expect(normalizarComercio('TOTTUS 0234'), 'TOTTUS');
      expect(normalizarComercio('kfc 45'), 'KFC');
    });

    test('dos códigos numéricos distintos del mismo comercio son iguales', () {
      expect(
        normalizarComercio('Bembos 102'),
        normalizarComercio('BEMBOS 987'),
      );
    });

    test('un número que es parte del nombre, sin separador, no se toca', () {
      // Caso límite: "7ELEVEN" no tiene un espacio antes del dígito, así que
      // no se confunde con un código de sucursal.
      expect(normalizarComercio('7Eleven'), '7ELEVEN');
    });
  });

  group('sufijo de sucursal por palabra "SUC"/"SUCURSAL"', () {
    test('recorta el segmento que sigue a "SUC" o "SUCURSAL"', () {
      expect(normalizarComercio('Tottus SUC San Isidro'), 'TOTTUS');
      expect(normalizarComercio('Tottus Sucursal 234'), 'TOTTUS');
    });

    test('dos sucursales del mismo comercio normalizan igual', () {
      expect(
        normalizarComercio('Plaza Vea SUC Surco'),
        normalizarComercio('Plaza Vea Sucursal San Miguel'),
      );
    });
  });

  group('determinismo', () {
    test('la misma entrada produce siempre la misma salida', () {
      const entrada = 'Tottus SUC San Isidro';
      expect(normalizarComercio(entrada), normalizarComercio(entrada));
    });

    test(
      'normalizar un comercio ya normalizado no lo cambia (idempotente)',
      () {
        final normalizado = normalizarComercio('Tottus SUC San Isidro');
        expect(normalizarComercio(normalizado), normalizado);
      },
    );
  });

  group('límite del alcance actual (documentado, no un bug)', () {
    test(
      'un nombre de sucursal pegado sin separador reconocible sigue '
      'distinguiendo comercios (D-N7: se ajusta con fixtures reales, T034)',
      () {
        expect(
          normalizarComercio('Plaza Vea Surco'),
          isNot(normalizarComercio('Plaza Vea San Isidro')),
        );
      },
    );

    test('un comercio distinto con guion no se fusiona con otro', () {
      // "UBER *EATS" es un servicio distinto de "UBER" a secas: no es una
      // sucursal, así que no se recorta el separador "*".
      expect(normalizarComercio('Uber *Eats'), isNot('UBER'));
    });
  });
}
