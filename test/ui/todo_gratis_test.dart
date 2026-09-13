import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_propinas.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/cascaron.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_respaldo.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/ahorro/pantalla_ahorro.dart';
import 'package:finanzas/ui/pantallas/ajustes/pantalla_ajustes.dart';
import 'package:finanzas/ui/pantallas/categorias/pantalla_desglose.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_deudas.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_tarjetas.dart';
import 'package:finanzas/ui/pantallas/presupuesto/pantalla_presupuesto.dart';
import 'package:finanzas/ui/pantallas/resumen_mes/pantalla_resumen.dart';
import 'package:finanzas/ui/pantallas/transacciones/pantalla_transacciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/cobro_ingreso_builder.dart';
import '../builders/obligacion_builder.dart';
import '../builders/transaccion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// La app entera es gratis y completa (US1, spec 004 revisada).
///
/// **Esta es la prueba central de la revisión de 2026-09-12**, y está escrita
/// en negativo a propósito: no verifica que algo funcione, verifica que una
/// condición de acceso **no exista en ningún lado**. Antes de la revisión,
/// Deudas y Ahorro se sustituían por un paywall sin suscripción vigente; el
/// modelo de propina borró esa guarda y esta prueba es lo que impide que
/// vuelva sin pasar antes por la spec (FR-001, FR-002, SC-001, SC-002).
void main() {
  late RepositorioObligacionesEnMemoria repoObligaciones;
  late RepositorioTransaccionesEnMemoria repoTransacciones;
  late RepositorioCobrosIngresoEnMemoria repoCobrosIngreso;
  late RepositorioConfiguracionEnMemoria repoConfiguracion;
  late EstadoMes estadoMes;
  late EstadoAhorro estadoAhorro;
  late EstadoTarjetas estadoTarjetas;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  /// **Todos** los destinos de la app, con cómo se llega y qué pantalla tiene
  /// que quedar en el cuerpo. Deudas y Ahorro están en la misma lista que el
  /// resto porque ya no se distinguen en nada: esa es la revisión.
  ///
  /// La lista está escrita a mano porque `_frecuentes` y `_ocasionales` son
  /// privados del cascarón: si mañana se suma un destino, hay que sumarlo
  /// también acá. Los cuatro de la captura (Pendientes, Captura, Diagnóstico,
  /// Comercios) solo existen en Android y la suite corre en el escritorio.
  const destinos = <({String etiqueta, bool enElDrawer, Type pantalla})>[
    (etiqueta: 'Resumen', enElDrawer: false, pantalla: PantallaResumen),
    (etiqueta: 'Presupuesto', enElDrawer: false, pantalla: PantallaPresupuesto),
    (etiqueta: 'Gastos', enElDrawer: false, pantalla: PantallaTransacciones),
    (etiqueta: 'Deudas', enElDrawer: false, pantalla: PantallaDeudas),
    (etiqueta: 'Ahorro', enElDrawer: false, pantalla: PantallaAhorro),
    (etiqueta: 'Categorías', enElDrawer: true, pantalla: PantallaDesglose),
    (etiqueta: 'Tarjetas', enElDrawer: true, pantalla: PantallaTarjetas),
    (etiqueta: 'Ajustes', enElDrawer: true, pantalla: PantallaAjustes),
  ];

  /// Palabras que no pueden aparecer en ninguna pantalla que no sea la de
  /// apoyo (FR-006, SC-002).
  const palabrasDePago = <String>[
    'Suscribirme',
    'suscripción',
    'Premium',
    'premium',
    'Desbloquear',
    'desbloquea',
  ];

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EstadoRespaldo>(
            create: (_) =>
                EstadoRespaldo(repoRespaldo: RepositorioRespaldoEnMemoria()),
          ),
          Provider<RepositorioConfiguracion>.value(value: repoConfiguracion),
          Provider<RepositorioPropinas>(
            create: (_) => RepositorioPropinasEnMemoria(),
          ),
          ChangeNotifierProvider<EstadoMes>.value(value: estadoMes),
          ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
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
  });

  group('ningún destino está condicionado a un pago (FR-001, SC-001)', () {
    testWidgets('los ocho destinos muestran su pantalla real', (tester) async {
      await estadoMes.cargar();
      await montar(tester);

      for (final destino in destinos) {
        await irA(tester, destino.etiqueta, enElDrawer: destino.enElDrawer);

        expect(
          find.byType(destino.pantalla),
          findsOneWidget,
          reason: '${destino.etiqueta} debería mostrar su pantalla real',
        );
      }
    });

    testWidgets('ninguna pantalla salvo Ajustes menciona pagar (SC-002)', (
      tester,
    ) async {
      await estadoMes.cargar();
      await montar(tester);

      for (final destino in destinos.where(
        (destino) => destino.etiqueta != 'Ajustes',
      )) {
        await irA(tester, destino.etiqueta, enElDrawer: destino.enElDrawer);

        for (final palabra in palabrasDePago) {
          expect(
            find.textContaining(palabra),
            findsNothing,
            reason: '${destino.etiqueta} no debería hablar de pagos',
          );
        }
      }
    });

    testWidgets('el apoyo vive en Ajustes y no bloquea nada', (tester) async {
      await estadoMes.cargar();
      await montar(tester);

      await irA(tester, 'Ajustes', enElDrawer: true);

      // Se ofrece, pero como una fila más entre los ajustes: el resto de la
      // pantalla sigue completo y utilizable (FR-006).
      expect(find.text('Apoyar esta app'), findsOneWidget);
      expect(find.text('Plazo para pagos rezagados'), findsOneWidget);
    });
  });

  group('sin límite de cantidad (Acceptance Scenario 3)', () {
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
    });

    testWidgets('los sesenta gastos se suman completos en el resumen', (
      tester,
    ) async {
      await montar(tester);

      await irA(tester, 'Resumen', enElDrawer: false);

      // 60 × S/ 10.00.
      expect(find.text('S/ 600.00'), findsWidgets);
    });

    testWidgets('recorrer un año hacia atrás no bloquea nada', (tester) async {
      await montar(tester);
      await irA(tester, 'Resumen', enElDrawer: false);

      for (var mes = 0; mes < 12; mes++) {
        await estadoMes.irAlMesAnterior();
        await tester.pumpAndSettle();

        expect(find.byType(PantallaResumen), findsOneWidget);
      }
    });
  });
}
