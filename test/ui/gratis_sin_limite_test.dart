import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/cascaron.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/ajustes/pantalla_ajustes.dart';
import 'package:finanzas/ui/pantallas/categorias/pantalla_desglose.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_tarjetas.dart';
import 'package:finanzas/ui/pantallas/presupuesto/pantalla_presupuesto.dart';
import 'package:finanzas/ui/pantallas/resumen_mes/pantalla_resumen.dart';
import 'package:finanzas/ui/pantallas/suscripcion/pantalla_paywall.dart';
import 'package:finanzas/ui/pantallas/transacciones/pantalla_transacciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/cobro_ingreso_builder.dart';
import '../builders/obligacion_builder.dart';
import '../builders/transaccion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Lo básico sigue gratis y sin límite (US3, spec 004).
///
/// La monetización no puede degradar lo que la app ya prometía antes de
/// existir: quien nunca se suscribe presupuesta, mira su resumen y anota
/// gastos sin tope de cantidad ni de meses, y sin encontrarse un aviso de
/// pago en el camino (FR-004, SC-005).
void main() {
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late RepositorioCobrosIngresoEnMemoria repoCobrosIngreso;
  late RepositorioConfiguracionEnMemoria repoConfiguracion;
  late EstadoMes estadoMes;
  late EstadoAhorro estadoAhorro;
  late EstadoTarjetas estadoTarjetas;
  late EstadoSuscripcionPremium estadoSuscripcion;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  /// Todo lo que se usa sin pagar, con cómo se llega y qué pantalla tiene que
  /// quedar en el cuerpo.
  ///
  /// La lista está escrita a mano porque `_frecuentes` y `_ocasionales` son
  /// privados del cascarón: si mañana se suma un destino gratis, hay que
  /// sumarlo también acá.
  const destinosGratis = <({String etiqueta, bool enElDrawer, Type pantalla})>[
    (etiqueta: 'Resumen', enElDrawer: false, pantalla: PantallaResumen),
    (etiqueta: 'Presupuesto', enElDrawer: false, pantalla: PantallaPresupuesto),
    (etiqueta: 'Gastos', enElDrawer: false, pantalla: PantallaTransacciones),
    (etiqueta: 'Categorías', enElDrawer: true, pantalla: PantallaDesglose),
    (etiqueta: 'Tarjetas', enElDrawer: true, pantalla: PantallaTarjetas),
    (etiqueta: 'Ajustes', enElDrawer: true, pantalla: PantallaAjustes),
  ];

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RepositorioConfiguracion>.value(value: repoConfiguracion),
          ChangeNotifierProvider<EstadoMes>.value(value: estadoMes),
          ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
          ChangeNotifierProvider<EstadoSuscripcionPremium>.value(
            value: estadoSuscripcion,
          ),
          ChangeNotifierProvider<EstadoTarjetas>.value(value: estadoTarjetas),
        ],
        child: const MaterialApp(home: Cascaron()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> irA(
    WidgetTester tester,
    String etiqueta, {
    required bool enElDrawer,
  }) async {
    if (enElDrawer) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(etiqueta).last);
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repoObligaciones = RepositorioObligacionesEnMemoria();
    repoTransacciones = RepositorioTransaccionesEnMemoria();
    repoCobrosIngreso = RepositorioCobrosIngresoEnMemoria();
    repoConfiguracion = RepositorioConfiguracionEnMemoria();
    estadoMes = EstadoMes(
      repoCobrosIngreso: repoCobrosIngreso,
      repoObligaciones: repoObligaciones,
      repoConfiguracion: repoConfiguracion,
      repoTransacciones: repoTransacciones,
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    estadoAhorro = EstadoAhorro(
      repoAhorro: RepositorioAhorroEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      ahora: () => quinceDeAgosto,
    );
    await estadoAhorro.cargar(agosto);
    estadoTarjetas = EstadoTarjetas(
      repoTarjetas: RepositorioTarjetasEnMemoria(),
    );
    await estadoTarjetas.cargar();
    // El punto de partida de toda esta historia: nadie se suscribió nunca.
    estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: RepositorioSuscripcionEnMemoria(),
    );
    await estadoSuscripcion.cargar();
  });

  group('ningún destino gratis pide pago (FR-004, SC-005)', () {
    testWidgets('las seis pantallas se ven enteras, sin aviso', (tester) async {
      await estadoMes.cargar();
      await montar(tester);

      for (final destino in destinosGratis) {
        await irA(tester, destino.etiqueta, enElDrawer: destino.enElDrawer);

        expect(
          find.byType(PantallaPaywall),
          findsNothing,
          reason: '${destino.etiqueta} no debería pedir suscripción',
        );
        expect(
          find.byType(destino.pantalla),
          findsOneWidget,
          reason: '${destino.etiqueta} debería mostrar su pantalla real',
        );
      }
    });

    testWidgets('la guarda sí alcanza a Deudas y a Ahorro', (tester) async {
      await estadoMes.cargar();
      await montar(tester);

      // El contraste es lo que le da sentido a la prueba de arriba: la guarda
      // existe y funciona, pero llega hasta acá y no más (T030).
      for (final premium in ['Deudas', 'Ahorro']) {
        await irA(tester, premium, enElDrawer: false);

        expect(
          find.byType(PantallaPaywall),
          findsOneWidget,
          reason: '$premium sí es premium',
        );
      }
    });

    testWidgets('en Ajustes el estado de la suscripción informa, no bloquea', (
      tester,
    ) async {
      await estadoMes.cargar();
      await montar(tester);

      await irA(tester, 'Ajustes', enElDrawer: true);

      // La ficha de FR-009 vive acá y dice "Nunca suscripto", pero Ajustes
      // sigue siendo una pantalla gratis y completamente utilizable.
      expect(find.text(SituacionSuscripcion.nunca.etiqueta), findsOneWidget);
      expect(find.byType(PantallaPaywall), findsNothing);
      expect(find.text('Plazo para pagos rezagados'), findsOneWidget);
    });
  });

  group('sin límite de cantidad (Acceptance Scenario 2)', () {
    /// Volumen deliberadamente incómodo para una pantalla de teléfono.
    const cuantasObligaciones = 40;
    const cuantosGastos = 60;

    setUp(() async {
      await repoCobrosIngreso.insertar(
        CobroIngresoBuilder(fecha: quinceDeAgosto, centavos: 500000).build(),
      );
      await repoObligaciones.insertarLote([
        for (var numero = 1; numero <= cuantasObligaciones; numero++)
          ObligacionBuilder(
            nombre: 'Obligación $numero',
            categoria: Categoria.otros,
            centavos: 10000,
            tipo: TipoObligacion.variable,
          ).build(),
      ]);
      for (var numero = 1; numero <= cuantosGastos; numero++) {
        await repoTransacciones.insertar(
          TransaccionBuilder(
            fecha: quinceDeAgosto,
            categoria: Categoria.comida,
            centavos: 1000,
            descripcion: 'Gasto $numero',
          ).build(),
        );
      }
      await estadoMes.cargar();
    });

    testWidgets('las cuarenta obligaciones se presupuestan enteras', (
      tester,
    ) async {
      await montar(tester);

      await irA(tester, 'Presupuesto', enElDrawer: false);

      // 40 × S/ 100.00. Que el total dé exacto es la prueba de que no se
      // recortó ninguna por el camino.
      expect(find.text('S/ 4,000.00'), findsWidgets);
      expect(find.byType(PantallaPaywall), findsNothing);
    });

    testWidgets('los sesenta gastos se suman completos en el resumen', (
      tester,
    ) async {
      await montar(tester);

      await irA(tester, 'Resumen', enElDrawer: false);

      // 60 × S/ 10.00.
      expect(find.text('S/ 600.00'), findsWidgets);
      expect(find.byType(PantallaPaywall), findsNothing);
    });

    testWidgets('recorrer un año hacia atrás no bloquea nada', (tester) async {
      await montar(tester);
      await irA(tester, 'Resumen', enElDrawer: false);

      for (var mes = 0; mes < 12; mes++) {
        await estadoMes.irAlMesAnterior();
        await tester.pumpAndSettle();

        expect(
          find.byType(PantallaPaywall),
          findsNothing,
          reason: 'el mes ${estadoMes.mes} no debería pedir suscripción',
        );
      }
      expect(find.byType(PantallaResumen), findsOneWidget);
    });
  });
}
