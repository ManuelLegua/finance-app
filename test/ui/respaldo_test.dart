import 'package:finanzas/dominio/modelos/transaccion.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_respaldo.dart';
import 'package:finanzas/ui/pantallas/ajustes/seccion_respaldo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/transaccion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Restaurar sobre datos existentes exige confirmación aparte (US3, spec 005).
///
/// **Qué se verifica y cómo**: que nada cambió no se mira en la pantalla sino
/// leyendo el repositorio de gastos. Una prueba que solo comprobara que el
/// aviso sigue en pantalla pasaría igual si la restauración ya hubiera
/// arrasado con todo por detrás.
void main() {
  late RepositorioRespaldoEnMemoria repoRespaldo;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late EstadoRespaldo estadoRespaldo;

  const septiembre = Mes(2026, 9);
  const rutaElegidaPorDefecto = '/descargas/finanzas-respaldo-2026-09-01.db';
  String? rutaQueDevuelveElSelector = rutaElegidaPorDefecto;

  Future<List<Transaccion>> gastosGuardados() =>
      repoTransacciones.porMes(septiembre);

  setUp(() async {
    rutaQueDevuelveElSelector = rutaElegidaPorDefecto;
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    await repoTransacciones.insertar(
      TransaccionBuilder(
        fecha: DateTime(2026, 9, 5),
        centavos: 7800,
        descripcion: 'Gasto de hoy',
      ).build(),
    );

    repoRespaldo = RepositorioRespaldoEnMemoria()
      // Restaurar de verdad reemplaza todo: el doble lo simula borrando los
      // gastos, que es lo que la prueba después va a buscar.
      ..efectoDeRestaurar = () async {
        for (final gasto in await repoTransacciones.porMes(septiembre)) {
          await repoTransacciones.eliminar(gasto.id!);
        }
      };

    estadoRespaldo = EstadoRespaldo(repoRespaldo: repoRespaldo);
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoRespaldo>.value(
          value: estadoRespaldo,
          child: Scaffold(
            body: SingleChildScrollView(
              child: SeccionRespaldo(
                elegirArchivo: () async => rutaQueDevuelveElSelector,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> elegirArchivo(WidgetTester tester) async {
    await tester.tap(find.text('Restaurar respaldo'));
    await tester.pumpAndSettle();
  }

  group('antes de tocar nada', () {
    testWidgets('elegir un archivo válido avisa que reemplaza todo', (
      tester,
    ) async {
      await montar(tester);
      await elegirArchivo(tester);

      expect(find.text('Esto reemplaza todos tus datos'), findsOneWidget);
      expect(find.text('Reemplazar todo'), findsOneWidget);

      // FR-007: el archivo se inspeccionó, pero no se restauró nada todavía.
      expect(repoRespaldo.inspeccionados, <String>[rutaElegidaPorDefecto]);
      expect(repoRespaldo.restaurados, isEmpty);
      expect(await gastosGuardados(), hasLength(1));
    });

    testWidgets('cancelar deja los datos como estaban', (tester) async {
      await montar(tester);
      await elegirArchivo(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Esto reemplaza todos tus datos'), findsNothing);
      expect(repoRespaldo.restaurados, isEmpty);

      final gastos = await gastosGuardados();
      expect(gastos, hasLength(1));
      expect(gastos.single.descripcion, 'Gasto de hoy');
    });

    testWidgets('cerrar el selector sin elegir nada no hace nada', (
      tester,
    ) async {
      rutaQueDevuelveElSelector = null;
      await montar(tester);
      await elegirArchivo(tester);

      expect(find.text('Esto reemplaza todos tus datos'), findsNothing);
      expect(repoRespaldo.inspeccionados, isEmpty);
      expect(await gastosGuardados(), hasLength(1));
    });

    testWidgets('confirmar aparte es lo único que reemplaza', (tester) async {
      await montar(tester);
      await elegirArchivo(tester);

      await tester.tap(find.text('Reemplazar todo'));
      await tester.pumpAndSettle();

      expect(repoRespaldo.restaurados, <String>[rutaElegidaPorDefecto]);
      expect(await gastosGuardados(), isEmpty);
      expect(find.text('Datos restaurados desde el respaldo.'), findsOneWidget);
    });
  });

  group('archivos rechazados', () {
    /// Los tres motivos de rechazo, con lo que cada uno tiene que decir.
    const motivos = <ResultadoValidacionRespaldo>[
      ResultadoValidacionRespaldo.corrupto,
      ResultadoValidacionRespaldo.noEsDeLaApp,
      ResultadoValidacionRespaldo.deVersionMasNueva,
    ];

    for (final motivo in motivos) {
      testWidgets('$motivo se explica y no toca los datos', (tester) async {
        repoRespaldo.veredicto = motivo;
        await montar(tester);
        await elegirArchivo(tester);

        // FR-009: el motivo concreto, no un "archivo inválido" genérico.
        expect(find.text(mensajeDeRechazo(motivo)), findsOneWidget);
        expect(find.text('Reemplazar todo'), findsNothing);

        // SC-003: lo que el usuario tenía sigue intacto.
        expect(repoRespaldo.restaurados, isEmpty);
        expect(await gastosGuardados(), hasLength(1));
      });
    }

    test('cada motivo dice algo distinto', () {
      final mensajes = motivos.map(mensajeDeRechazo).toSet();
      expect(mensajes, hasLength(motivos.length));
      expect(mensajes.any((mensaje) => mensaje.isEmpty), isFalse);
    });
  });

  group('cuando el reemplazo falla', () {
    testWidgets('se informa y se dice que los datos quedaron como estaban', (
      tester,
    ) async {
      // El doble aplica el efecto y **después** falla, que es el caso feo: a
      // mitad de camino. Lo que la pantalla tiene que comunicar es el fallo,
      // no un éxito a medias.
      repoRespaldo
        ..efectoDeRestaurar = null
        ..errorAlRestaurar = Exception('se cortó el reemplazo');

      await montar(tester);
      await elegirArchivo(tester);
      await tester.tap(find.text('Reemplazar todo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ocurrió un problema'), findsOneWidget);
      expect(find.text('Datos restaurados desde el respaldo.'), findsNothing);
      expect(await gastosGuardados(), hasLength(1));
    });
  });
}
