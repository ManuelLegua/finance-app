import 'package:finanzas/dominio/modelos/cobro_ingreso.dart';
import 'package:finanzas/shared/constantes/enums.dart';
import 'package:finanzas/shared/tipos/dinero.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:finanzas/ui/pantallas/ahorro/pantalla_ahorro.dart';
import 'package:finanzas/ui/pantallas/categorias/pantalla_desglose.dart';
import 'package:finanzas/ui/pantallas/deudas/pantalla_deudas.dart';
import 'package:finanzas/ui/pantallas/presupuesto/pantalla_presupuesto.dart';
import 'package:finanzas/ui/pantallas/resumen_mes/pantalla_resumen.dart';
import 'package:finanzas/ui/pantallas/transacciones/pantalla_transacciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../builders/aporte_ahorro_builder.dart';
import '../builders/deuda_builder.dart';
import '../builders/obligacion_builder.dart';
import '../builders/tarjeta_builder.dart';
import '../builders/transaccion_builder.dart';
import '../dobles/repositorios_en_memoria.dart';

/// Que un monto de siete cifras — el máximo que admite `validarMonto` — no
/// desborde ninguna pantalla (FR-048, T101).
///
/// `flutter test` no carga tipografía real ni conoce el ancho de un teléfono
/// real (ver el comentario sobre pruebas manuales en `CLAUDE.md`), así que
/// esto no reemplaza el recorrido en un dispositivo. Lo que sí puede
/// verificar, con un ancho angosto realista, es que ningún `Row` sin
/// `Expanded`/`Flexible` reviente con `RenderFlex overflowed`: ese error de
/// layout es real y determinista, no depende de qué tan angosta sea la
/// fuente.
void main() {
  const agosto = Mes(2026, 8);
  final quinceDeAgosto = DateTime(2026, 8, 15);
  const maximo = 999999999; // S/ 9,999,999.99, el tope de siete cifras.

  Future<void> montarAAnchoAngosto(WidgetTester tester, Widget pantalla) async {
    // 360×2340 físicos a densidad 3.0 → 360dp lógicos: un ancho angosto
    // habitual, más estricto que el "Pixel 7" (412dp) del emulador de
    // referencia del proyecto.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: pantalla));
    await tester.pumpAndSettle();
  }

  testWidgets('resumen: ingreso, comprometido y disponible al máximo', (
    tester,
  ) async {
    final repoCobrosIngreso = RepositorioCobrosIngresoEnMemoria();
    final repoObligaciones = RepositorioObligacionesEnMemoria();
    await repoCobrosIngreso.insertar(
      CobroIngreso(
        id: null,
        fecha: quinceDeAgosto,
        monto: const Dinero.deCentavos(maximo),
      ),
    );
    await repoObligaciones.insertar(
      ObligacionBuilder(mes: agosto, centavos: maximo - 1).build(),
    );
    final estado = EstadoMes(
      repoCobrosIngreso: repoCobrosIngreso,
      repoObligaciones: repoObligaciones,
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();
    final estadoAhorro = EstadoAhorro(
      repoAhorro: RepositorioAhorroEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      ahora: () => quinceDeAgosto,
    );

    await montarAAnchoAngosto(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EstadoMes>.value(value: estado),
          ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
        ],
        child: const PantallaResumen(),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('desglose: presupuestado y gastado al máximo en una categoría', (
    tester,
  ) async {
    final repoCobrosIngreso = RepositorioCobrosIngresoEnMemoria();
    final repoObligaciones = RepositorioObligacionesEnMemoria();
    final repoTransacciones = RepositorioTransaccionesEnMemoria();
    await repoCobrosIngreso.insertar(
      CobroIngreso(
        id: null,
        fecha: quinceDeAgosto,
        monto: const Dinero.deCentavos(maximo),
      ),
    );
    await repoObligaciones.insertar(
      ObligacionBuilder(
        mes: agosto,
        categoria: Categoria.comida,
        centavos: maximo,
      ).build(),
    );
    await repoTransacciones.insertar(
      TransaccionBuilder(
        categoria: Categoria.comida,
        centavos: maximo - 1,
        fecha: DateTime(2026, 8, 5),
        descripcion: '',
      ).build(),
    );
    final estado = EstadoMes(
      repoCobrosIngreso: repoCobrosIngreso,
      repoObligaciones: repoObligaciones,
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: repoTransacciones,
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();

    await montarAAnchoAngosto(
      tester,
      ChangeNotifierProvider<EstadoMes>.value(
        value: estado,
        child: const PantallaDesglose(),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('transacciones: gasto real total al máximo', (tester) async {
    final repoTransacciones = RepositorioTransaccionesEnMemoria();
    await repoTransacciones.insertar(
      TransaccionBuilder(
        categoria: Categoria.comida,
        centavos: maximo,
        fecha: DateTime(2026, 8, 5),
        descripcion: 'Un gasto con nombre bien largo para forzar el layout',
      ).build(),
    );
    final estado = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: repoTransacciones,
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();

    await montarAAnchoAngosto(
      tester,
      ChangeNotifierProvider<EstadoMes>.value(
        value: estado,
        child: const PantallaTransacciones(),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('presupuesto: ingreso y una obligación al máximo', (
    tester,
  ) async {
    final repoCobrosIngreso = RepositorioCobrosIngresoEnMemoria();
    final repoObligaciones = RepositorioObligacionesEnMemoria();
    await repoCobrosIngreso.insertar(
      CobroIngreso(
        id: null,
        fecha: quinceDeAgosto,
        monto: const Dinero.deCentavos(maximo),
      ),
    );
    await repoObligaciones.insertar(
      ObligacionBuilder(
        mes: agosto,
        nombre: 'Una obligación con nombre bien largo de verdad',
        centavos: maximo,
      ).build(),
    );
    final estado = EstadoMes(
      repoCobrosIngreso: repoCobrosIngreso,
      repoObligaciones: repoObligaciones,
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();

    await montarAAnchoAngosto(
      tester,
      ChangeNotifierProvider<EstadoMes>.value(
        value: estado,
        child: const PantallaPresupuesto(),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('deudas: una cuota de una sola exhibición al máximo', (
    tester,
  ) async {
    final repoDeudas = RepositorioDeudasEnMemoria();
    final repoTarjetas = RepositorioTarjetasEnMemoria();
    await repoTarjetas.insertar(TarjetaBuilder().build());
    await repoDeudas.insertar(
      DeudaBuilder(cuotaCentavos: maximo, numCuotas: 1).build(),
    );
    final estado = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: RepositorioConfiguracionEnMemoria(),
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: repoDeudas,
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();
    final estadoTarjetas = EstadoTarjetas(repoTarjetas: repoTarjetas);
    await estadoTarjetas.cargar();

    await montarAAnchoAngosto(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EstadoMes>.value(value: estado),
          ChangeNotifierProvider<EstadoTarjetas>.value(value: estadoTarjetas),
        ],
        child: const PantallaDeudas(),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ahorro: meta y aporte al máximo', (tester) async {
    final repoAhorro = RepositorioAhorroEnMemoria();
    final repoConfiguracion = RepositorioConfiguracionEnMemoria();
    await repoAhorro.guardarMeta(agosto, const Dinero.deCentavos(maximo));
    await repoAhorro.insertarAporte(
      AporteAhorroBuilder(
        fecha: DateTime(2026, 8, 5),
        centavos: maximo - 1,
      ).build(),
    );
    final estado = EstadoMes(
      repoCobrosIngreso: RepositorioCobrosIngresoEnMemoria(),
      repoObligaciones: RepositorioObligacionesEnMemoria(),
      repoConfiguracion: repoConfiguracion,
      repoTransacciones: RepositorioTransaccionesEnMemoria(),
      repoDeudas: RepositorioDeudasEnMemoria(),
      ahora: () => quinceDeAgosto,
      mesInicial: agosto,
    );
    await estado.cargar();
    final estadoAhorro = EstadoAhorro(
      repoAhorro: repoAhorro,
      repoConfiguracion: repoConfiguracion,
      ahora: () => quinceDeAgosto,
    );
    await estadoAhorro.cargar(agosto);

    await montarAAnchoAngosto(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EstadoMes>.value(value: estado),
          ChangeNotifierProvider<EstadoAhorro>.value(value: estadoAhorro),
        ],
        child: const PantallaAhorro(),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
