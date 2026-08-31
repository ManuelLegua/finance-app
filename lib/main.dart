import 'dart:io' show Platform;

import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/notificaciones/servicio_escucha.dart';
import 'package:finanzas/datos/repositorios/repositorio_ahorro_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_asociaciones_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_cobros_ingreso_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_configuracion_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_deudas_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_diagnostico_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_meses_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_obligaciones_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_pendientes_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_tarjetas_sqlite.dart';
import 'package:finanzas/datos/repositorios/repositorio_transacciones_sqlite.dart';
import 'package:finanzas/dominio/repositorios/repositorio_ahorro.dart';
import 'package:finanzas/dominio/repositorios/repositorio_asociaciones.dart';
import 'package:finanzas/dominio/repositorios/repositorio_cobros_ingreso.dart';
import 'package:finanzas/dominio/repositorios/repositorio_configuracion.dart';
import 'package:finanzas/dominio/repositorios/repositorio_deudas.dart';
import 'package:finanzas/dominio/repositorios/repositorio_diagnostico.dart';
import 'package:finanzas/dominio/repositorios/repositorio_meses.dart';
import 'package:finanzas/dominio/repositorios/repositorio_obligaciones.dart';
import 'package:finanzas/dominio/repositorios/repositorio_pendientes.dart';
import 'package:finanzas/dominio/repositorios/repositorio_tarjetas.dart';
import 'package:finanzas/dominio/repositorios/repositorio_transacciones.dart';
import 'package:finanzas/shared/estilos/tema.dart';
import 'package:finanzas/shared/tipos/mes.dart';
import 'package:finanzas/ui/cascaron.dart';
import 'package:finanzas/ui/estado/estado_ahorro.dart';
import 'package:finanzas/ui/estado/estado_asociaciones.dart';
import 'package:finanzas/ui/estado/estado_captura.dart';
import 'package:finanzas/ui/estado/estado_diagnostico.dart';
import 'package:finanzas/ui/estado/estado_mes.dart';
import 'package:finanzas/ui/estado/estado_pendientes.dart';
import 'package:finanzas/ui/estado/estado_tarjetas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppFinanzas());
}

/// Raíz de la app.
///
/// Locale fijo `es_PE`: la app es monolingüe por decisión (D7). No hay ARB ni
/// generación de traducciones porque ningún requisito lo pide, y montar esa
/// infraestructura sería trabajo sin respaldo (Principio V).
class AppFinanzas extends StatelessWidget {
  const AppFinanzas({super.key});

  static const Locale _peru = Locale('es', 'PE');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanzas',
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.oscuro(),
      locale: _peru,
      supportedLocales: const <Locale>[_peru, Locale('es')],
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Arranque(),
    );
  }
}

/// Abre la base antes de montar la app.
///
/// Si la apertura falla se muestra el motivo, en vez de arrancar con datos
/// vacíos: el usuario tiene que poder distinguir "no pude leer tus datos" de
/// "no tenés datos".
class _Arranque extends StatefulWidget {
  const _Arranque();

  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  final BaseDatos _baseDatos = BaseDatos();
  late final Future<Database> _apertura = _baseDatos.abrir();

  @override
  void dispose() {
    _baseDatos.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _apertura,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PantallaErrorArranque(error: snapshot.error!);
        }
        final conexion = snapshot.data;
        if (conexion == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return MultiProvider(
          providers: [
            Provider<RepositorioCobrosIngreso>(
              create: (_) => RepositorioCobrosIngresoSqlite(conexion),
            ),
            Provider<RepositorioObligaciones>(
              create: (_) => RepositorioObligacionesSqlite(conexion),
            ),
            Provider<RepositorioConfiguracion>(
              create: (_) => RepositorioConfiguracionSqlite(conexion),
            ),
            Provider<RepositorioTransacciones>(
              create: (_) => RepositorioTransaccionesSqlite(conexion),
            ),
            Provider<RepositorioDeudas>(
              create: (_) => RepositorioDeudasSqlite(conexion),
            ),
            Provider<RepositorioTarjetas>(
              create: (_) => RepositorioTarjetasSqlite(conexion),
            ),
            Provider<RepositorioMeses>(
              create: (_) => RepositorioMesesSqlite(conexion),
            ),
            Provider<RepositorioAhorro>(
              create: (_) => RepositorioAhorroSqlite(conexion),
            ),
            ChangeNotifierProvider<EstadoMes>(
              create: (contexto) => EstadoMes(
                repoCobrosIngreso: contexto.read<RepositorioCobrosIngreso>(),
                repoObligaciones: contexto.read<RepositorioObligaciones>(),
                repoConfiguracion: contexto.read<RepositorioConfiguracion>(),
                repoTransacciones: contexto.read<RepositorioTransacciones>(),
                repoDeudas: contexto.read<RepositorioDeudas>(),
                repoMeses: contexto.read<RepositorioMeses>(),
              )..cargar(),
            ),
            ChangeNotifierProvider<EstadoTarjetas>(
              create: (contexto) => EstadoTarjetas(
                repoTarjetas: contexto.read<RepositorioTarjetas>(),
              )..cargar(),
            ),
            ChangeNotifierProvider<EstadoAhorro>(
              // El mismo mes inicial que EstadoMes (hoy): así la tarjeta de
              // sugerencia en Resumen ya tiene la regla y el porcentaje
              // reales desde el primer render, sin esperar a que el usuario
              // visite la pestaña de Ahorro.
              create: (contexto) => EstadoAhorro(
                repoAhorro: contexto.read<RepositorioAhorro>(),
                repoConfiguracion: contexto.read<RepositorioConfiguracion>(),
              )..cargar(Mes.deFecha(DateTime.now())),
            ),
            // Captura de notificaciones bancarias: exclusiva de Android
            // (D-N8, FR-007). El paquete que la implementa ni siquiera
            // declara soporte para otra plataforma.
            if (Platform.isAndroid) ...[
              Provider<RepositorioPendientes>(
                create: (_) => RepositorioPendientesSqlite(conexion),
              ),
              Provider<RepositorioDiagnostico>(
                create: (_) => RepositorioDiagnosticoSqlite(conexion),
              ),
              Provider<RepositorioAsociaciones>(
                create: (_) => RepositorioAsociacionesSqlite(conexion),
              ),
              ChangeNotifierProvider<EstadoCapturaNotificaciones>(
                create: (contexto) => EstadoCapturaNotificaciones(
                  repoConfiguracion: contexto.read<RepositorioConfiguracion>(),
                  servicio: ServicioEscuchaNotificacionesAndroid(
                    contexto.read<RepositorioConfiguracion>(),
                  ),
                )..cargar(),
              ),
              ChangeNotifierProvider<EstadoPendientes>(
                create: (contexto) => EstadoPendientes(
                  repoPendientes: contexto.read<RepositorioPendientes>(),
                  repoAsociaciones: contexto.read<RepositorioAsociaciones>(),
                  estadoMes: contexto.read<EstadoMes>(),
                )..cargar(),
              ),
              ChangeNotifierProvider<EstadoDiagnostico>(
                create: (contexto) => EstadoDiagnostico(
                  repoDiagnostico: contexto.read<RepositorioDiagnostico>(),
                )..cargar(),
              ),
              ChangeNotifierProvider<EstadoAsociaciones>(
                create: (contexto) => EstadoAsociaciones(
                  repoAsociaciones: contexto.read<RepositorioAsociaciones>(),
                )..cargar(),
              ),
            ],
          ],
          child: const Cascaron(),
        );
      },
    );
  }
}

class _PantallaErrorArranque extends StatelessWidget {
  const _PantallaErrorArranque({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                'No se pudieron abrir tus datos',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'La información sigue guardada en el dispositivo, pero la app '
                'no puede leerla en este momento.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
