import 'package:finanzas/dominio/modelos/consumo_pendiente.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/cascaron.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_respaldo.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/suscripcion/pantalla_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/aporte_ahorro_builder.dart';
import '../builders/deuda_builder.dart';
import '../builders/tarjeta_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// La suscripción vence o se cancela (US4, spec 004).
///
/// La promesa de esta historia es una sola: **cancelar se siente como perder
/// acceso, nunca como perder datos**. Por eso las pruebas no se conforman con
/// mirar la pantalla: leen los repositorios después del cambio de estado
/// (FR-011, SC-003) y reactivan la suscripción para comprobar que vuelve
/// exactamente lo mismo que había (Acceptance Scenario 2).
///
/// Va en archivo propio y no dentro de `pantalla_paywall_test.dart` —que es
/// lo que pedía T031— porque acá se siembran deudas, aportes, asociaciones y
/// consumos pendientes: el escenario es el vencimiento, no el paywall. Mismo
/// criterio que el archivo aparte de T009.
void main() {
  late RepositorioDeudasEnMemoria repoDeudas;
  late RepositorioAhorroEnMemoria repoAhorro;
  late RepositorioTarjetasEnMemoria repoTarjetas;
  late RepositorioAsociacionesEnMemoria repoAsociaciones;
  late RepositorioPendientesEnMemoria repoPendientes;
  late RepositorioConfiguracionEnMemoria repoConfiguracion;
  late RepositorioSuscripcionEnMemoria repoSuscripcion;
  late EstadoMes estadoMes;
  late EstadoAhorro estadoAhorro;
  late EstadoTarjetas estadoTarjetas;
  late EstadoSuscripcionPremium estadoSuscripcion;

  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);

  EstadoSuscripcion conSituacion(SituacionSuscripcion situacion) =>
      EstadoSuscripcion(
        situacion: situacion,
        plan: PlanSuscripcion.mensual,
        vigenteHasta: DateTime(2026, 9, 15),
        ultimaVerificacion: quinceDeAgosto,
      );

  /// Cambia lo que Google Play informa y deja que la app se entere, que es lo
  /// que pasa de verdad cuando una suscripción vence: nadie toca la app, el
  /// estado cambia del otro lado.
  Future<void> pasarA(
    WidgetTester tester,
    SituacionSuscripcion situacion,
  ) async {
    repoSuscripcion.fijar(conSituacion(situacion));
    await estadoSuscripcion.refrescar();
    await tester.pumpAndSettle();
  }

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

  Future<void> irA(WidgetTester tester, String destino) async {
    await tester.tap(find.text(destino).last);
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repoDeudas = RepositorioDeudasEnMemoria();
    repoAhorro = RepositorioAhorroEnMemoria();
    repoTarjetas = RepositorioTarjetasEnMemoria();
    repoAsociaciones = RepositorioAsociacionesEnMemoria();
    repoPendientes = RepositorioPendientesEnMemoria();
    repoConfiguracion = RepositorioConfiguracionEnMemoria();

    // Todo lo que el usuario cargó mientras pagaba, en las cuatro zonas que
    // FR-011 nombra.
    await repoTarjetas.insertar(TarjetaBuilder().build());
    await repoDeudas.insertar(
      DeudaBuilder(
        descripcion: 'Celular',
        cuotaCentavos: 15000,
        numCuotas: 12,
        mesInicio: agosto,
      ).build(),
    );
    await repoAhorro.insertarAporte(
      AporteAhorroBuilder(fecha: quinceDeAgosto, centavos: 30000).build(),
    );
    await repoAsociaciones.asociar('rappi', Categoria.comida);
    await repoPendientes.insertar(
      ConsumoPendiente(
        id: null,
        origenPaquete: 'com.ejemplo.banco',
        notificacionId: 'notif-1',
        monto: const Dinero.deCentavos(4500),
        comercio: 'Rappi',
        fecha: DateTime(2026, 8, 10),
        categoriaPropuesta: Categoria.comida,
        capturadoEn: DateTime(2026, 8, 10, 12),
      ),
    );

    estadoMes = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: repoDeudas,
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estadoMes.cargar();
    estadoAhorro = EstadoAhorro(
      repoAhorro: repoAhorro,
      repoConfiguracion: repoConfiguracion,
      ahora: () => quinceDeAgosto,
    );
    await estadoAhorro.cargar(agosto);
    estadoTarjetas = EstadoTarjetas(repoTarjetas: repoTarjetas);
    await estadoTarjetas.cargar();

    // Se arranca pagando: esta historia empieza con una suscripción vigente.
    repoSuscripcion = RepositorioSuscripcionEnMemoria(
      inicial: conSituacion(SituacionSuscripcion.activa),
    );
    estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: repoSuscripcion,
    );
    await estadoSuscripcion.cargar();
  });

  group('al vencer, lo premium se bloquea de nuevo (FR-010)', () {
    testWidgets('vencida vuelve a mostrar el aviso en Deudas', (tester) async {
      await montar(tester);
      await irA(tester, 'Deudas');
      expect(find.text('Celular'), findsOneWidget);

      await pasarA(tester, SituacionSuscripcion.vencida);

      // Sin navegar ni reiniciar: la pantalla que estaba abierta se bloquea.
      expect(find.byType(PantallaPaywall), findsOneWidget);
      expect(find.text('Celular'), findsNothing);
    });

    testWidgets('cancelada vuelve a mostrar el aviso en Ahorro', (
      tester,
    ) async {
      await montar(tester);
      await irA(tester, 'Ahorro');
      expect(find.text('Aportes de este mes'), findsOneWidget);

      await pasarA(tester, SituacionSuscripcion.cancelada);

      expect(find.byType(PantallaPaywall), findsOneWidget);
      expect(find.text('Aportes de este mes'), findsNothing);
    });

    testWidgets('el aviso dice que venció, no que algo falló', (tester) async {
      await montar(tester);
      await irA(tester, 'Deudas');

      await pasarA(tester, SituacionSuscripcion.vencida);

      // La ficha de estado va arriba del aviso cuando hubo suscripción antes
      // (FR-009), y aclara que los datos siguen guardados (FR-011).
      expect(find.text(SituacionSuscripcion.vencida.etiqueta), findsOneWidget);
      expect(find.textContaining('siguen guardados'), findsOneWidget);
    });
  });

  group('el período de gracia no corta el acceso (FR-013)', () {
    testWidgets('un cobro fallido mantiene Deudas accesible', (tester) async {
      await montar(tester);
      await irA(tester, 'Deudas');

      // Google todavía no dio por perdida la suscripción: reintenta el cobro
      // durante un margen que fija la tienda, no la app.
      await pasarA(tester, SituacionSuscripcion.enGracia);

      expect(find.byType(PantallaPaywall), findsNothing);
      expect(find.text('Celular'), findsOneWidget);
    });

    testWidgets('recién cuando pasa a vencida se bloquea', (tester) async {
      await montar(tester);
      await irA(tester, 'Deudas');
      await pasarA(tester, SituacionSuscripcion.enGracia);

      await pasarA(tester, SituacionSuscripcion.vencida);

      expect(find.byType(PantallaPaywall), findsOneWidget);
    });
  });

  group('vencer no borra ni un dato (FR-011, SC-003)', () {
    testWidgets('los repositorios quedan igual que antes del vencimiento', (
      tester,
    ) async {
      await montar(tester);
      await irA(tester, 'Deudas');
      final deudasAntes = await repoDeudas.todas();
      final aportesAntes = await repoAhorro.aportesPorMes(agosto);
      final asociacionesAntes = await repoAsociaciones.todas();
      final pendientesAntes = await repoPendientes.todos();

      await pasarA(tester, SituacionSuscripcion.vencida);

      // Se leen los repositorios, no la pantalla: que el paywall tape los
      // datos no prueba que sigan estando.
      expect(await repoDeudas.todas(), deudasAntes);
      expect(await repoAhorro.aportesPorMes(agosto), aportesAntes);
      expect(await repoAsociaciones.todas(), asociacionesAntes);
      expect(await repoPendientes.todos(), pendientesAntes);
    });

    testWidgets('reactivar devuelve exactamente lo que había', (tester) async {
      await montar(tester);
      await pasarA(tester, SituacionSuscripcion.vencida);
      await irA(tester, 'Deudas');
      expect(find.byType(PantallaPaywall), findsOneWidget);

      await pasarA(tester, SituacionSuscripcion.activa);

      // Acceptance Scenario 2: la misma deuda, sin recargar nada a mano.
      expect(find.text('Celular'), findsOneWidget);
      expect(find.text('Debés en total'), findsOneWidget);
    });

    testWidgets('y el ahorro también vuelve intacto', (tester) async {
      await montar(tester);
      await pasarA(tester, SituacionSuscripcion.vencida);
      await irA(tester, 'Ahorro');

      await pasarA(tester, SituacionSuscripcion.activa);

      expect(find.text('Aportes de este mes'), findsOneWidget);
      expect(find.textContaining('S/ 300.00'), findsWidgets);
    });
  });
}
