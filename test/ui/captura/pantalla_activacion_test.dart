import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/ui/estado/estado_captura.dart';
import 'package:finanzas/ui/estado/estado_suscripcion.dart';
import 'package:finanzas/ui/pantallas/captura/pantalla_activacion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../dobles/repositorios_en_memoria.dart';

/// Reglas de presentación de la activación de la captura (HU1, spec 002).
void main() {
  late RepositorioConfiguracionEnMemoria repoConfiguracion;
  late ServicioEscuchaNotificacionesEnMemoria servicio;
  late EstadoCapturaNotificaciones estado;
  late RepositorioSuscripcionEnMemoria repoSuscripcion;
  late EstadoSuscripcionPremium estadoSuscripcion;

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<EstadoCapturaNotificaciones>.value(
              value: estado,
            ),
            ChangeNotifierProvider<EstadoSuscripcionPremium>.value(
              value: estadoSuscripcion,
            ),
          ],
          child: const PantallaActivacion(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repoConfiguracion = RepositorioConfiguracionEnMemoria();
    servicio = ServicioEscuchaNotificacionesEnMemoria(repoConfiguracion);
    estado = EstadoCapturaNotificaciones(
      repoConfiguracion: repoConfiguracion,
      servicio: servicio,
    );
    // La captura es premium (spec 004, FR-003). Salvo en el grupo que prueba
    // justamente eso, estas pruebas parten de una suscripción vigente: lo que
    // verifican es el permiso de Android, no el cobro.
    repoSuscripcion = RepositorioSuscripcionEnMemoria(
      inicial: EstadoSuscripcion(
        situacion: SituacionSuscripcion.activa,
        plan: PlanSuscripcion.mensual,
        vigenteHasta: null,
        ultimaVerificacion: DateTime(2026, 8, 30),
      ),
    );
    estadoSuscripcion = EstadoSuscripcionPremium(
      repoSuscripcion: repoSuscripcion,
    );
    await estadoSuscripcion.cargar();
  });

  group('sin permiso (FR-001, FR-003)', () {
    testWidgets('explica qué se va a leer antes de pedir el permiso', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      expect(find.textContaining('Qué va a leer la app'), findsOneWidget);
      expect(find.textContaining('Nada sale de tu teléfono'), findsOneWidget);
      expect(find.text('Ir a ajustes de Android'), findsOneWidget);
    });

    testWidgets('tocar el botón dirige a los ajustes de Android (FR-002)', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      await tester.tap(find.text('Ir a ajustes de Android'));
      await tester.pumpAndSettle();

      expect(servicio.vecesQueAbrioAjustes, 1);
    });
  });

  group('permiso revocado (FR-004)', () {
    testWidgets('se explica distinto de "nunca se pidió", con ícono', (
      tester,
    ) async {
      // Se activó alguna vez: el interruptor de la app quedó en true.
      await repoConfiguracion.guardar(
        (await repoConfiguracion.obtener()).copiarCon(
          capturaNotificacionesActiva: true,
        ),
      );
      servicio.permiso = false;
      await estado.cargar();
      await montar(tester);

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('Le quitaste'), findsOneWidget);
    });
  });

  group('permiso concedido pero apagada en la app', () {
    testWidgets('ofrece activar sin volver a pedir el permiso', (tester) async {
      servicio.permiso = true;
      await estado.cargar();
      await montar(tester);

      expect(find.text('Activar captura'), findsOneWidget);

      await tester.tap(find.text('Activar captura'));
      await tester.pumpAndSettle();

      expect(find.text('Captura activa'), findsOneWidget);
    });
  });

  group('captura activa', () {
    testWidgets('muestra los orígenes reconocidos y permite desactivar', (
      tester,
    ) async {
      servicio.permiso = true;
      await servicio.activar();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Captura activa'), findsOneWidget);
      expect(find.textContaining('bancos y billeteras'), findsOneWidget);

      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();

      expect(find.text('Ir a ajustes de Android'), findsNothing);
      expect(find.text('Activar captura'), findsOneWidget);
    });
  });

  group('sin suscripción no se ofrece el permiso (spec 004, FR-003)', () {
    setUp(() async {
      repoSuscripcion.fijar(
        EstadoSuscripcion.nunca(ultimaVerificacion: DateTime(2026, 8, 30)),
      );
      await estadoSuscripcion.cargar();
    });

    testWidgets('muestra el aviso de suscripción en vez de la activación', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      expect(
        find.textContaining('La captura automática es parte de Finanzas'),
        findsOneWidget,
      );
      expect(find.text('Ir a ajustes de Android'), findsNothing);
      expect(find.text('Activar captura'), findsNothing);
    });

    testWidgets('no hay forma de disparar la solicitud de permiso', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      // Pedirle a Android un permiso tan sensible para algo que después va a
      // estar bloqueado sería tomarle el pelo al usuario.
      expect(servicio.vecesQueAbrioAjustes, 0);
    });

    testWidgets('con el permiso ya concedido antes, tampoco se ofrece', (
      tester,
    ) async {
      // Caso real: se suscribió, activó la captura, y después venció.
      servicio.permiso = true;
      await servicio.activar();
      await estado.cargar();
      await montar(tester);

      expect(find.text('Captura activa'), findsNothing);
      expect(
        find.textContaining('La captura automática es parte de Finanzas'),
        findsOneWidget,
      );
    });
  });
}
