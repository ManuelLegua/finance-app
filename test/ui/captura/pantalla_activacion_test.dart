import 'package:finanzas/ui/estado/estado_captura.dart';
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

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EstadoCapturaNotificaciones>.value(
          value: estado,
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

  group('el permiso del aviso persistente (D-N13, T063)', () {
    testWidgets('activar lo pide antes de arrancar nada', (tester) async {
      // Sin este permiso Android mata el servicio apenas nace, así que
      // pedirlo es parte de activar, no un paso aparte que se pueda olvidar.
      servicio.permiso = true;
      await estado.cargar();
      await montar(tester);

      await tester.tap(find.text('Activar captura'));
      await tester.pumpAndSettle();

      expect(servicio.vecesQuePidioAvisoPersistente, 1);
      expect(find.text('Captura activa'), findsOneWidget);
    });

    testWidgets('si el usuario lo rechaza, no se enciende y se explica', (
      tester,
    ) async {
      servicio.permiso = true;
      servicio.concedeAvisoPersistente = false;
      await estado.cargar();
      await montar(tester);

      await tester.tap(find.text('Activar captura'));
      await tester.pumpAndSettle();

      // Lo peor sería encenderla igual: quedaría diciendo "activa" con una
      // captura que Android va a matar enseguida.
      expect(find.text('Captura activa'), findsNothing);
      expect(find.textContaining('mostrar una notificación'), findsOneWidget);
    });
  });

  group('el sistema detuvo el servicio (D-N13)', () {
    setUp(() async {
      // El caso observado en dispositivo: permiso concedido, interruptor
      // encendido, y Android mató el servicio.
      servicio.permiso = true;
      await servicio.activar();
      servicio.corriendo = false;
    });

    testWidgets('no dice que está activa, porque no lo está', (tester) async {
      await estado.cargar();
      await montar(tester);

      expect(find.text('Captura activa'), findsNothing);
      expect(find.textContaining('dejó de funcionar'), findsOneWidget);
    });

    testWidgets('dice que los consumos no se están registrando', (
      tester,
    ) async {
      // Lo que el usuario necesita entender no es que un servicio se cayó,
      // sino que sus gastos no se están capturando.
      await estado.cargar();
      await montar(tester);

      expect(find.textContaining('no se están registrando'), findsOneWidget);
    });

    testWidgets('ofrece reactivar acá mismo, sin mandar a ajustes', (
      tester,
    ) async {
      // El permiso sigue concedido: mandar al usuario a los ajustes de
      // Android sería hacerle buscar algo que ya está.
      await estado.cargar();
      await montar(tester);

      expect(find.text('Reactivar captura'), findsOneWidget);
      expect(find.text('Ir a ajustes de Android'), findsNothing);

      await tester.tap(find.text('Reactivar captura'));
      await tester.pumpAndSettle();

      expect(find.text('Captura activa'), findsOneWidget);
      expect(servicio.vecesQueAbrioAjustes, 0);
    });

    testWidgets('no despliega la lista de orígenes cubiertos', (tester) async {
      // El texto explicativo sí nombra "bancos y billeteras"; lo que no puede
      // aparecer es el desplegable que los enumera, porque ahora mismo no se
      // está cubriendo ninguno.
      await estado.cargar();
      await montar(tester);

      expect(find.byType(ExpansionTile), findsNothing);
    });
  });

  group('la captura no depende de ningún pago (spec 004 revisada)', () {
    // Acá vivía el grupo que verificaba lo contrario: sin suscripción
    // vigente, esta pantalla mostraba el paywall en vez del flujo de permiso.
    // La revisión a propina lo borró — la captura es gratis como todo lo
    // demás (FR-001), y este grupo es lo que impide que la guarda vuelva sin
    // pasar antes por la spec.
    testWidgets('sin el permiso de Android se ofrece ir a pedirlo', (
      tester,
    ) async {
      await estado.cargar();
      await montar(tester);

      expect(find.text('Ir a ajustes de Android'), findsOneWidget);
      expect(find.textContaining('parte de Finanzas'), findsNothing);
    });

    testWidgets('con el permiso concedido se ofrece activar', (tester) async {
      servicio.permiso = true;
      await estado.cargar();
      await montar(tester);

      expect(find.text('Activar captura'), findsOneWidget);
      expect(find.textContaining('parte de Finanzas'), findsNothing);
    });
  });
}
