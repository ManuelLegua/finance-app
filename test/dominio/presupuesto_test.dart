import 'package:finanzas/dominio/calculos/presupuesto.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../builders/obligacion_builder.dart';

/// FR-005 (validación de montos) y FR-006 (precarga de obligaciones fijas).
void main() {
  group('validarMonto', () {
    test('acepta un monto normal', () {
      final resultado = validarMonto('900.00');
      expect(resultado.esValido, isTrue);
      expect(resultado.monto, const Dinero.deCentavos(90000));
      expect(resultado.error, isNull);
    });

    test('acepta sin decimales y con un solo decimal', () {
      expect(validarMonto('900').monto, const Dinero.deCentavos(90000));
      expect(validarMonto('900.5').monto, const Dinero.deCentavos(90050));
    });

    test('acepta separador de miles y espacios alrededor', () {
      expect(validarMonto(' 1,234.56 ').monto, const Dinero.deCentavos(123456));
    });

    test('acepta coma como separador decimal', () {
      // El teclado numérico de Android ofrece coma en locales hispanos.
      expect(validarMonto('900,50').monto, const Dinero.deCentavos(90050));
    });

    test('rechaza vacío indicando el motivo', () {
      final resultado = validarMonto('');
      expect(resultado.esValido, isFalse);
      expect(resultado.monto, isNull);
      expect(resultado.error, isNotNull);
      expect(resultado.error, contains('monto'));
    });

    test('rechaza solo espacios', () {
      expect(validarMonto('   ').esValido, isFalse);
    });

    test('rechaza texto no numérico', () {
      final resultado = validarMonto('novecientos');
      expect(resultado.esValido, isFalse);
      expect(resultado.error, isNotNull);
    });

    test('rechaza negativos (FR-005)', () {
      final resultado = validarMonto('-50');
      expect(resultado.esValido, isFalse);
      expect(resultado.error, contains('negativo'));
    });

    test('rechaza cero: una obligación de S/ 0.00 no es una obligación', () {
      final resultado = validarMonto('0');
      expect(resultado.esValido, isFalse);
    });

    test('rechaza más de dos decimales', () {
      final resultado = validarMonto('10.005');
      expect(resultado.esValido, isFalse);
      expect(resultado.error, contains('decimales'));
    });

    test('acepta hasta siete cifras enteras', () {
      final resultado = validarMonto('9999999.99');
      expect(resultado.esValido, isTrue);
      expect(resultado.monto, const Dinero.deCentavos(999999999));
    });

    test('rechaza más de siete cifras enteras', () {
      final resultado = validarMonto('10000000.00');
      expect(resultado.esValido, isFalse);
    });

    test('no pierde centavos en montos con decimales exactos', () {
      // El caso que rompería si el parseo pasara por double.
      expect(validarMonto('0.10').monto, const Dinero.deCentavos(10));
      expect(validarMonto('0.20').monto, const Dinero.deCentavos(20));
      expect(
        validarMonto('1234567.89').monto,
        const Dinero.deCentavos(123456789),
      );
    });
  });

  group('proponerFijasDelMesAnterior', () {
    const agosto = Mes(2026, 8);
    const julio = Mes(2026, 7);

    Obligacion crear(String nombre, int centavos, TipoObligacion tipo) =>
        ObligacionBuilder(
          mes: julio,
          nombre: nombre,
          categoria: Categoria.servicios,
          centavos: centavos,
          tipo: tipo,
        ).build();

    test('propone las fijas con el mismo monto', () {
      final propuestas = proponerFijasDelMesAnterior(
        mesDestino: agosto,
        obligacionesMesAnterior: [
          crear('Alquiler', 90000, TipoObligacion.fija),
          crear('Luz', 12000, TipoObligacion.fija),
        ],
      );

      expect(propuestas, hasLength(2));
      expect(propuestas.map((obligacion) => obligacion.nombre), [
        'Alquiler',
        'Luz',
      ]);
      expect(propuestas.first.monto, const Dinero.deCentavos(90000));
    });

    test('las propuestas apuntan al mes destino, no al anterior', () {
      final propuestas = proponerFijasDelMesAnterior(
        mesDestino: agosto,
        obligacionesMesAnterior: [
          crear('Alquiler', 90000, TipoObligacion.fija),
        ],
      );
      expect(propuestas.single.mes, agosto);
    });

    test('las propuestas no tienen id: todavía no están guardadas', () {
      // FR-006: la app propone, el usuario confirma. Nunca escribe sola.
      final propuestas = proponerFijasDelMesAnterior(
        mesDestino: agosto,
        obligacionesMesAnterior: [
          crear('Alquiler', 90000, TipoObligacion.fija),
        ],
      );
      expect(propuestas.single.id, isNull);
    });

    test('omite las variables: son estimaciones, no se repiten solas', () {
      final propuestas = proponerFijasDelMesAnterior(
        mesDestino: agosto,
        obligacionesMesAnterior: [
          crear('Alquiler', 90000, TipoObligacion.fija),
          crear('Comida', 60000, TipoObligacion.variable),
          crear('Pasajes', 20000, TipoObligacion.variable),
        ],
      );
      expect(propuestas, hasLength(1));
      expect(propuestas.single.nombre, 'Alquiler');
    });

    test('sin mes anterior devuelve lista vacía', () {
      expect(
        proponerFijasDelMesAnterior(
          mesDestino: agosto,
          obligacionesMesAnterior: const [],
        ),
        isEmpty,
      );
    });

    test('conserva la categoría de cada obligación', () {
      final propuestas = proponerFijasDelMesAnterior(
        mesDestino: agosto,
        obligacionesMesAnterior: [
          ObligacionBuilder(id: 1, mes: julio, nombre: 'Alquiler').build(),
        ],
      );
      expect(propuestas.single.categoria, Categoria.departamento);
    });
  });

  group('totalComprometido', () {
    const agosto = Mes(2026, 8);

    Obligacion crear(int centavos) => ObligacionBuilder(
      mes: agosto,
      nombre: 'x',
      categoria: Categoria.otros,
      centavos: centavos,
    ).build();

    test('suma las obligaciones del mes', () {
      final total = totalObligaciones([
        crear(90000),
        crear(12000),
        crear(20000),
        crear(60000),
      ]);
      expect(total, const Dinero.deCentavos(182000)); // S/ 1,820.00
    });

    test('sin obligaciones el total es cero, no null', () {
      expect(totalObligaciones(const []), Dinero.cero);
    });
  });
}
