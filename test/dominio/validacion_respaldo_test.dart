import 'package:finanzas/dominio/calculos/validacion_respaldo.dart';
import 'package:finanzas/dominio/modelos/respaldo.dart';
import 'package:flutter_test/flutter_test.dart';

/// La única regla con criterio propio de la spec 005 (D6 de research.md).
///
/// Recibe hechos ya averiguados sobre el archivo y decide si se acepta y, si
/// no, por qué. El **orden de evaluación** es parte del contrato: cuando falla
/// más de una comprobación a la vez, es lo que decide qué motivo se le
/// reporta al usuario (data-model.md §2).
void main() {
  /// La versión de esquema vigente en las pruebas. Se fija acá y no se lee de
  /// `Esquema.version` a propósito: esto es dominio puro y no conoce la
  /// persistencia, y además la regla tiene que seguir valiendo cuando el
  /// esquema suba de número.
  const versionSoportada = 4;

  ResultadoValidacionRespaldo validar({
    bool integridadOk = true,
    bool tablasEsperadasPresentes = true,
    int versionDelArchivo = versionSoportada,
  }) => validarRespaldo(
    integridadOk: integridadOk,
    tablasEsperadasPresentes: tablasEsperadasPresentes,
    versionDelArchivo: versionDelArchivo,
    versionSoportada: versionSoportada,
  );

  group('caso normal', () {
    test('un respaldo íntegro, completo y de la versión actual es válido', () {
      expect(validar(), ResultadoValidacionRespaldo.valido);
    });

    test('un respaldo de una versión anterior también es válido', () {
      // FR-010: se acepta y se migra al restaurarlo. Rechazarlo dejaría sin
      // sentido a toda la feature apenas suba el esquema.
      expect(
        validar(versionDelArchivo: versionSoportada - 1),
        ResultadoValidacionRespaldo.valido,
      );
    });
  });

  group('casos límite', () {
    test('la versión igual a la soportada es válida', () {
      expect(
        validar(versionDelArchivo: versionSoportada),
        ResultadoValidacionRespaldo.valido,
      );
    });

    test('la versión 1, el mínimo posible, es válida', () {
      expect(validar(versionDelArchivo: 1), ResultadoValidacionRespaldo.valido);
    });
  });

  group('casos adversos', () {
    test('sin integridad es corrupto', () {
      expect(
        validar(integridadOk: false),
        ResultadoValidacionRespaldo.corrupto,
      );
    });

    test('sin las tablas esperadas no es de la app', () {
      expect(
        validar(tablasEsperadasPresentes: false),
        ResultadoValidacionRespaldo.noEsDeLaApp,
      );
    });

    test('la versión 0 no es de la app', () {
      // Un SQLite sin esquema versionado: válido como archivo, ajeno a esta
      // app. No es "corrupto" y decírselo así confundiría al usuario.
      expect(
        validar(versionDelArchivo: 0),
        ResultadoValidacionRespaldo.noEsDeLaApp,
      );
    });

    test('una versión mayor que la soportada se rechaza por más nueva', () {
      expect(
        validar(versionDelArchivo: versionSoportada + 1),
        ResultadoValidacionRespaldo.deVersionMasNueva,
      );
    });
  });

  group('orden de evaluación', () {
    test('la corrupción gana sobre cualquier otro motivo', () {
      // Un archivo que ni siquiera es SQLite no puede responder por sus
      // tablas ni por su versión: lo que se leyó de ellas no significa nada.
      expect(
        validar(
          integridadOk: false,
          tablasEsperadasPresentes: false,
          versionDelArchivo: versionSoportada + 1,
        ),
        ResultadoValidacionRespaldo.corrupto,
      );
    });

    test('faltar tablas gana sobre venir de una versión más nueva', () {
      // Si le faltan tablas del esquema, el `user_version` alto es de otra
      // app, no de una versión futura de esta.
      expect(
        validar(
          tablasEsperadasPresentes: false,
          versionDelArchivo: versionSoportada + 1,
        ),
        ResultadoValidacionRespaldo.noEsDeLaApp,
      );
    });
  });

  group('InformeRespaldo', () {
    test('un respaldo anterior avisa que se va a migrar', () {
      const informe = InformeRespaldo(
        resultado: ResultadoValidacionRespaldo.valido,
        versionDelArchivo: 3,
        versionSoportada: versionSoportada,
      );

      expect(informe.esValido, isTrue);
      expect(informe.requiereMigracion, isTrue);
    });

    test('un respaldo de la versión actual no requiere migración', () {
      const informe = InformeRespaldo(
        resultado: ResultadoValidacionRespaldo.valido,
        versionDelArchivo: versionSoportada,
        versionSoportada: versionSoportada,
      );

      expect(informe.requiereMigracion, isFalse);
    });

    test('un respaldo rechazado nunca requiere migración', () {
      const informe = InformeRespaldo(
        resultado: ResultadoValidacionRespaldo.corrupto,
        versionDelArchivo: 1,
        versionSoportada: versionSoportada,
      );

      expect(informe.esValido, isFalse);
      expect(informe.requiereMigracion, isFalse);
    });
  });
}
