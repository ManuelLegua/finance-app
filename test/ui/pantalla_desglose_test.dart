import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/pantallas/categorias/pantalla_desglose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/obligacion_builder.dart';
import '../builders/transaccion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación del desglose por categoría (HU6).
void main() {
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late EstadoMes estado;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  setUp(() {
    repoObligaciones = RepositorioObligacionesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    estado = EstadoMes(
      repoIngreso: RepositorioIngresoEnMemoria(),
      repoObligaciones: repoObligaciones,
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: repoTransacciones,
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoMes>.value(
          value: estado,
          child: const PantallaDesglose(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('orden por gasto descendente (FR-044)', () {
    testWidgets('las filas van de mayor a menor gasto', (tester) async {
      await repoObligaciones.insertar(
        ObligacionBuilder(
          nombre: 'Otros',
          categoria: Categoria.otros,
          centavos: 1000,
          tipo: TipoObligacion.variable,
        ).build(),
      );
      await repoTransacciones.insertar(
        TransaccionBuilder(
          categoria: Categoria.servicios,
          centavos: 10000,
          fecha: DateTime(2026, 8, 5),
          descripcion: '',
        ).build(),
      );
      await repoTransacciones.insertar(
        TransaccionBuilder(
          categoria: Categoria.comida,
          centavos: 50000,
          fecha: DateTime(2026, 8, 5),
          descripcion: '',
        ).build(),
      );
      await repoTransacciones.insertar(
        TransaccionBuilder(
          categoria: Categoria.pasajes,
          centavos: 30000,
          fecha: DateTime(2026, 8, 5),
          descripcion: '',
        ).build(),
      );
      await estado.cargar();
      await montar(tester);

      final etiquetas = <String>{
        Categoria.comida.etiqueta,
        Categoria.pasajes.etiqueta,
        Categoria.servicios.etiqueta,
        Categoria.otros.etiqueta,
      };
      final encontradas = tester
          .widgetList<Text>(find.byType(Text))
          .map((texto) => texto.data)
          .where(etiquetas.contains)
          .toList();

      expect(encontradas, [
        Categoria.comida.etiqueta,
        Categoria.pasajes.etiqueta,
        Categoria.servicios.etiqueta,
        Categoria.otros.etiqueta,
      ]);
    });
  });

  group('categorías sin actividad (FR-047)', () {
    testWidgets('una categoría sin presupuesto ni gasto no aparece', (
      tester,
    ) async {
      await repoTransacciones.insertar(
        TransaccionBuilder(
          categoria: Categoria.comida,
          centavos: 4500,
          fecha: DateTime(2026, 8, 5),
          descripcion: '',
        ).build(),
      );
      await estado.cargar();
      await montar(tester);

      expect(find.text(Categoria.comida.etiqueta), findsOneWidget);
      expect(find.text(Categoria.pasajes.etiqueta), findsNothing);
      expect(find.text(Categoria.servicios.etiqueta), findsNothing);
      expect(find.text(Categoria.otros.etiqueta), findsNothing);
    });

    testWidgets('un mes sin presupuesto ni gastos invita a registrar algo', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      expect(find.textContaining('Nada que desglosar'), findsOneWidget);
    });
  });

  group('sobregiro (FR-029)', () {
    testWidgets('una categoría sobregirada se marca con ícono y texto', (
      tester,
    ) async {
      await repoObligaciones.insertar(
        ObligacionBuilder(
          nombre: 'Pasajes',
          categoria: Categoria.pasajes,
          centavos: 20000,
          tipo: TipoObligacion.variable,
        ).build(),
      );
      await repoTransacciones.insertar(
        TransaccionBuilder(
          categoria: Categoria.pasajes,
          centavos: 21500,
          fecha: DateTime(2026, 8, 5),
          descripcion: '',
        ).build(),
      );
      await estado.cargar();
      await montar(tester);

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      expect(find.textContaining('Te pasaste por'), findsOneWidget);
    });
  });
}
