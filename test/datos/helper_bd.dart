import 'dart:io';

import 'package:finanzas/datos/base_datos.dart';
import 'package:finanzas/datos/esquema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Infraestructura de las pruebas de datos.
///
/// D8: se corre contra SQLite **real** vía `sqflite_common_ffi`, no contra un
/// doble. Los `CHECK`, las claves foráneas y el comportamiento de las
/// transacciones son justamente lo que hay que verificar, y un mock los
/// daría por buenos. Además permite correr la suite en Windows sin emulador.

/// Se llama una vez por archivo de prueba, antes de abrir ninguna base.
void inicializarSqfliteFfi() {
  sqfliteFfiInit();
}

/// Abre una base en memoria con el esquema ya creado.
///
/// Cada prueba recibe una base limpia: nada se filtra de un test al siguiente.
Future<BaseDatos> abrirBaseEnMemoria() async {
  final baseDatos = BaseDatos(
    rutaOverride: inMemoryDatabasePath,
    factoryOverride: databaseFactoryFfi,
  );
  await baseDatos.abrir();
  return baseDatos;
}

// --- Spec 005: respaldo y exportación. Pruebas con archivos de verdad. ---
//
// La base en memoria no sirve para probar el respaldo: toda la feature
// consiste en copiar, renombrar y reemplazar el **archivo** de la base, y un
// `:memory:` no tiene archivo que mover. Estas ayudas montan bases reales en
// un directorio temporal que se borra al terminar cada prueba.

/// Un directorio temporal propio de esta prueba, que se borra al terminar.
Directory crearDirectorioTemporal() {
  final directorio = Directory.systemTemp.createTempSync('finanzas_respaldo_');
  addTearDown(() {
    if (directorio.existsSync()) directorio.deleteSync(recursive: true);
  });
  return directorio;
}

/// Abre una base **en un archivo real** dentro de [directorio], con el
/// esquema actual ya creado.
Future<BaseDatos> abrirBaseEnArchivo(Directory directorio) async {
  final baseDatos = BaseDatos(
    rutaOverride: p.join(directorio.path, BaseDatos.nombreArchivo),
    factoryOverride: databaseFactoryFfi,
  );
  await baseDatos.abrir();
  addTearDown(baseDatos.cerrar);
  return baseDatos;
}

/// Crea en [ruta] una base con el esquema de la **versión 3** (specs 001, 002
/// y 003).
///
/// Sirve para probar que un respaldo viejo restaurado en la app de hoy queda
/// migrado (FR-010).
///
/// Es `Esquema.creacion` entero, sin excepciones: la v4 agregó
/// `suscripcion_premium` y la v5 la borró (spec 004 revisada, D9), así que el
/// conjunto de tablas de la v3 y el de hoy terminaron siendo el mismo. Lo que
/// cambia entre una y otra es solo el `user_version`, que es lo que dispara
/// las migraciones al restaurar.
Future<void> crearBaseEnVersion3(
  String ruta, {
  required Future<void> Function(Database conexion) sembrar,
}) async {
  final conexion = await databaseFactoryFfi.openDatabase(
    ruta,
    options: OpenDatabaseOptions(
      version: 3,
      onCreate: (conexion, version) async {
        final lote = conexion.batch();
        for (final sentencia in Esquema.creacion) {
          lote.execute(sentencia);
        }
        await lote.commit(noResult: true);
      },
    ),
  );
  await sembrar(conexion);
  await conexion.close();
}

/// Siembra una fila en cada tabla que el usuario carga, más la que **no**
/// viaja en el respaldo (D4), para poder comprobar que se vacía.
///
/// Los montos son centavos enteros, como en toda la app (Principio II).
Future<void> sembrarDatosDeEjemplo(Database conexion) async {
  await conexion.insert('cobro_ingreso', <String, Object?>{
    'fecha': '2026-09-15',
    'mes_ordinal': 24332,
    'monto_centavos': 180000,
  });
  await conexion.insert('obligacion', <String, Object?>{
    'mes_ordinal': 24332,
    'nombre': 'Alquiler',
    'categoria': 'departamento',
    'monto_centavos': 90000,
    'tipo': 'fija',
  });
  await conexion.insert('transaccion', <String, Object?>{
    'fecha': '2026-09-03',
    'mes_ordinal': 24332,
    'categoria': 'comida',
    'monto_centavos': 4550,
    'descripcion': 'Menú del día',
  });
  final tarjetaId = await conexion.insert('tarjeta', <String, Object?>{
    'nombre': 'Visa BCP',
    'entidad': 'BCP',
    'tipo': 'credito',
  });
  await conexion.insert('deuda', <String, Object?>{
    'descripcion': 'Laptop',
    'tarjeta_id': tarjetaId,
    'cuota_centavos': 15000,
    'num_cuotas': 12,
    'mes_inicio_ordinal': 24332,
  });
  await conexion.insert('aporte_ahorro', <String, Object?>{
    'fecha': '2026-09-16',
    'mes_ordinal': 24332,
    'monto_centavos': 30000,
  });
  await conexion.insert('meta_ahorro', <String, Object?>{
    'mes_ordinal': 24332,
    'monto_centavos': 50000,
  });
  await conexion.insert('comercio_categoria', <String, Object?>{
    'comercio_normalizado': 'TOTTUS',
    'categoria': 'comida',
    'actualizado_en': '2026-09-02',
  });
  await conexion.insert('configuracion', <String, Object?>{
    'id': 1,
    'regla': 'porcentaje',
    'porcentaje_bp': 2000,
    'dias_gracia_cierre': 5,
    'captura_notificaciones_activa': 0,
  });

  // La que no viaja (D4). Se siembra justamente para comprobar que la copia
  // sale sin ella y que el original la conserva.
  await conexion.insert('notificacion_diagnostico', <String, Object?>{
    'origen_paquete': 'com.bcp.innovacxion.yapeapp',
    'motivo': 'formato_no_reconocido',
    'texto_crudo': 'Pagaste S/ 45.50 en TOTTUS',
    'fecha': '2026-09-03',
  });
}
