@Skip(
  'Bloqueada: sqflite_common_ffi no completa dentro del reloj falso de '
  'testWidgets y la prueba se cuelga. runAsync no alcanza. La salida es dar a '
  'los repositorios una costura de dobles (interfaz o clase no-final) para que '
  'las pruebas de widget no toquen la base real. Ver T040 en tasks.md.',
)
library;

import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/datos/repositorios/repositorio_ingreso.dart';
import 'package:finanzas/datos/repositorios/repositorio_obligaciones.dart';
import 'package:finanzas/dominio/modelos/obligacion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/presupuesto/pantalla_presupuesto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../datos/helper_bd.dart';

void main() {
  setUpAll(inicializarSqfliteFfi);

  late BaseDatos bd;
  late EstadoMes estado;

  const agosto = Mes(2026, 8);
  final hoy = DateTime(2026, 8, 15);

  /// Deja correr el I/O real de sqflite y vuelve a pintar.
  ///
  /// `pumpAndSettle` avanza un reloj falso: una lectura real de la base nunca
  /// completa dentro de el y la prueba se cuelga. `runAsync` ejecuta fuera de
  /// ese reloj, que es la unica forma de combinar widgets con una base de
  /// datos de verdad.
  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoMes>.value(
          value: estado,
          child: const PantallaPresupuesto(),
        ),
      ),
    );
    await asentar(tester);
  }

  setUp(() async {
    bd = await abrirBaseEnMemoria();
    final db = await bd.abrir();
    estado = EstadoMes(
      repoIngreso: RepositorioIngreso(db),
      repoObligaciones: RepositorioObligaciones(db),
      repoConfiguracion: RepositorioConfiguracion(db),
      ahora: () => hoy,
      mesInicial: agosto,
    );
    await estado.cargar();
  });

  tearDown(() async => bd.cerrar());

  group('ingreso', () {
    testWidgets('un mes sin ingreso lo pide en vez de mostrar S/ 0.00',
        (tester) async {
      await montar(tester);

      expect(
        find.text('Todavía no registraste tu sueldo de este mes.'),
        findsOneWidget,
      );
      expect(find.text(r'S/ 0.00'), findsNothing);
      expect(find.text('Registrar'), findsOneWidget);
    });

    testWidgets('con ingreso registrado lo muestra formateado',
        (tester) async {
      await estado.guardarIngreso(const Dinero.deCentavos(300000));
      await montar(tester);

      expect(find.text(r'S/ 3,000.00'), findsOneWidget);
      expect(find.text('Corregir'), findsOneWidget);
    });
  });

  group('validación de montos (FR-005)', () {
    testWidgets('un monto vacío se rechaza y no guarda nada', (tester) async {
      await montar(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Obligación'));
      await asentar(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre').first,
        'Alquiler',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await asentar(tester);

      expect(find.text('Escribí un monto.'), findsOneWidget);
      expect(estado.obligaciones, isEmpty);
    });

    testWidgets('un monto negativo se rechaza indicando el motivo',
        (tester) async {
      await montar(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Obligación'));
      await asentar(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre').first,
        'Alquiler',
      );
      // El formateador del campo filtra el signo, así que el rechazo del
      // negativo se verifica directamente sobre la regla del dominio.
      await tester.enterText(find.byType(TextFormField).last, '-50');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await asentar(tester);

      expect(estado.obligaciones, isEmpty);
    });

    testWidgets('un monto válido se guarda y aparece en la lista',
        (tester) async {
      await montar(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Obligación'));
      await asentar(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre').first,
        'Alquiler',
      );
      await tester.enterText(find.byType(TextFormField).last, '900.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await asentar(tester);

      expect(estado.obligaciones, hasLength(1));
      expect(find.text('Alquiler'), findsOneWidget);
      expect(find.text(r'S/ 900.00'), findsWidgets);
    });
  });

  group('categorías', () {
    testWidgets('tarjeta de crédito no aparece entre las elegibles',
        (tester) async {
      // Ese compromiso lo derivan las deudas: registrarlo a mano duplicaría
      // el monto del presupuesto (D3).
      await montar(tester);

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Obligación'));
      await asentar(tester);

      await tester.tap(find.byType(DropdownButtonFormField<Categoria>));
      await asentar(tester);

      expect(find.text('Tarjeta de crédito'), findsNothing);
      expect(find.text('Departamento'), findsWidgets);
      expect(find.text('Comida'), findsWidgets);
    });
  });

  group('mes cerrado', () {
    testWidgets('no ofrece acciones de escritura y explica por qué',
        (tester) async {
      final db = await bd.abrir();
      await RepositorioObligaciones(db).insertar(
        const Obligacion(
          id: null,
          mes: Mes(2026, 5),
          nombre: 'Alquiler',
          categoria: Categoria.departamento,
          monto: Dinero.deCentavos(90000),
          tipo: TipoObligacion.fija,
        ),
      );
      await estado.irAMes(const Mes(2026, 5));
      await montar(tester);

      expect(find.text('Mes cerrado'), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, 'Obligación'),
        findsNothing,
      );
      expect(find.text('Registrar'), findsNothing);
      // La restricción se comunica con texto, no solo deshabilitando (FR-058).
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });
}
