import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/ui/estado/estado_diagnostico.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_diagnostico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación del registro de diagnóstico (spec 002, FR-018).
void main() {
  late RepositorioDiagnosticoEnMemoria repoDiagnostico;
  late EstadoDiagnostico estado;

  NotificacionDiagnostico entrada({
    MotivoDiagnostico motivo = MotivoDiagnostico.formatoNoReconocido,
    String texto = 'Texto sin interpretar',
  }) => NotificacionDiagnostico(
    id: null,
    origenPaquete: 'com.ejemplo.banco',
    motivo: motivo,
    textoCrudo: texto,
    fecha: DateTime(2026, 8, 10),
  );

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoDiagnostico>.value(
          value: estado,
          child: const PantallaDiagnostico(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    repoDiagnostico = RepositorioDiagnosticoEnMemoria();
    estado = EstadoDiagnostico(repoDiagnostico: repoDiagnostico);
  });

  testWidgets('sin entradas comunica que no hay nada sin interpretar', (
    tester,
  ) async {
    await estado.cargar();
    await montar(tester);

    expect(find.text('Nada sin interpretar'), findsOneWidget);
  });

  testWidgets('muestra el texto crudo y el motivo de cada entrada', (
    tester,
  ) async {
    await repoDiagnostico.insertar(
      entrada(
        motivo: MotivoDiagnostico.monedaExtranjera,
        texto: 'Consumo por USD 12.00',
      ),
    );
    await estado.cargar();
    await montar(tester);

    expect(find.text('Moneda extranjera'), findsOneWidget);
    expect(find.text('Consumo por USD 12.00'), findsOneWidget);
  });

  testWidgets('aclara que no se registró ningún gasto ni sale del teléfono', (
    tester,
  ) async {
    await estado.cargar();
    await montar(tester);

    expect(find.textContaining('No se registró ningún gasto'), findsOneWidget);
    expect(find.textContaining('sale de tu teléfono'), findsOneWidget);
  });

  testWidgets('vaciar el registro pide confirmación y lo borra (FR-018)', (
    tester,
  ) async {
    await repoDiagnostico.insertar(entrada());
    await estado.cargar();
    await montar(tester);

    await tester.tap(find.text('Borrar todo el registro'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar el registro?'), findsOneWidget);

    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(estado.entradas, isEmpty);
    expect(find.text('Nada sin interpretar'), findsOneWidget);
  });

  testWidgets(
    'un fallo al vaciar el registro se muestra, no se traga en silencio',
    (tester) async {
      await repoDiagnostico.insertar(entrada());
      await estado.cargar();
      await montar(tester);

      repoDiagnostico.errorEnLaProximaEscritura = Exception('disco lleno');
      await tester.tap(find.text('Borrar todo el registro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();

      // Texto e ícono, no solo un color (mismo patrón que el resto de la
      // feature): FR-057-style de la constitución sobre no comunicar solo
      // con color.
      expect(find.textContaining('Ocurrió un problema'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // La entrada sigue ahí: el fallo no se tragó silenciosamente.
      expect(estado.entradas, hasLength(1));
    },
  );
}
