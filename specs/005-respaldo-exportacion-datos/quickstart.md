# Quickstart: Respaldo y exportación de datos

Cómo verificar que esta feature funciona, primero con la suite y después a
mano. A diferencia de la spec 004, acá **casi todo se puede automatizar**: la
suite corre SQLite real en Windows con `sqflite_common_ffi`, así que el
intercambio de archivos, las migraciones y el todo-o-nada se prueban sin
emulador. Lo único que exige un dispositivo es la entrega del archivo (hoja de
compartir) y su elección (selector del sistema).

## Validación automática

```powershell
$env:PATH = "C:\Users\manue\dev\flutter\bin;$env:PATH"
flutter test
flutter analyze
```

Lo que la suite tiene que cubrir, de más importante a menos:

| Qué se prueba | Dónde | Por qué importa |
|---|---|---|
| `validarRespaldo` en sus cuatro veredictos, con caso límite (`version == soportada` y `== 1`) y adverso (`0`, `soportada + 1`) | `test/dominio/` | Es la única regla con criterio propio de la feature (D6) |
| Exportar y restaurar de ida y vuelta deja los mismos datos | `test/datos/` | Es SC-001 en su forma verificable |
| Un respaldo de esquema **v3** restaurado en la app v4 queda migrado y con sus datos | `test/datos/` | FR-010, el motivo por el que el formato es el propio archivo SQLite (D1) |
| `suscripcion_premium` y `notificacion_diagnostico` viajan **vacías** | `test/datos/` | FR-003 y D4 |
| Un archivo corrupto, uno de otra app y uno de versión más nueva se rechazan **sin tocar los datos actuales** | `test/datos/` | FR-009 y SC-003; se verifica leyendo los repositorios después del intento fallido, no mirando la pantalla |
| Un fallo a mitad del reemplazo deja la base como estaba y abierta | `test/datos/` | FR-008, la garantía de D3 |
| Los `-wal`/`-shm` viejos no sobreviven al reemplazo | `test/datos/` | El modo de fallo silencioso que D3 marca como el más fácil de pasar por alto |
| Restaurar con datos ya cargados exige confirmación aparte, y cancelar no cambia nada | `test/ui/` | FR-007, US3 |
| Exportar con la base vacía genera igual un archivo válido | `test/datos/` | FR-012 |

## Validación manual (dispositivo o emulador)

Lo que la suite no puede tocar: la hoja de compartir y el selector de archivos
son componentes del sistema operativo.

```powershell
$env:PATH = "C:\Users\manue\dev\flutter\bin;$env:PATH"
flutter run
```

1. **Cargar datos de verdad**: sueldo en dos cobros, dos o tres obligaciones,
   algunos gastos, una tarjeta de crédito y una deuda en cuotas, un aporte de
   ahorro. Anotá el disponible del mes que muestra el Resumen — es la cifra
   que tiene que sobrevivir a todo el recorrido.
2. **Ajustes → Exportar respaldo**: tiene que abrirse la hoja de compartir de
   Android. Guardalo en "Archivos" o mandátelo por correo a vos mismo. Si el
   archivo no se puede sacar del teléfono, la feature no cumple su propósito.
3. **Confirmación**: al volver de la hoja de compartir, la app tiene que decir
   con claridad que terminó bien (FR-005), no dejarte con la duda.
4. **Simular el desastre**: `adb shell pm clear com.example.finanzas`. La app
   queda como recién instalada, sin nada.
5. **Ajustes → Restaurar respaldo**: elegí el archivo del paso 2 con el
   selector del sistema. Al terminar, el Resumen tiene que mostrar
   **exactamente** el mismo disponible del paso 1, con sus deudas, sus cuotas y
   sus aportes (SC-001).
6. **Restaurar sobre datos existentes**: sin limpiar nada, registrá un gasto
   nuevo y volvé a restaurar el mismo archivo. Tiene que avisarte con todas las
   letras que va a reemplazar lo que tenés ahora, y pedirte confirmar aparte
   (FR-007). Cancelá: el gasto nuevo sigue ahí. Confirmá: el gasto nuevo
   desaparece, porque el respaldo es anterior — que es lo que el aviso decía.
7. **Archivo inválido**: elegí cualquier otro archivo del teléfono (una foto,
   un PDF) en Restaurar. Tiene que rechazarlo diciendo por qué, y tus datos
   tienen que seguir intactos (FR-009, SC-003).
8. **Suscripción**: si tenías premium activo, después de restaurar el estado
   se vuelve a consultar contra Google Play, no sale del archivo (SC-004, D4).
   Y un respaldo hecho **con** premium restaurado en una instalación **sin**
   premium no desbloquea nada.

## Lo que no hace falta probar

- Respaldos automáticos o programados: no existen, y la enmienda a la
  constitución (v3.0.0) no los autoriza — nada sale sin que el usuario lo pida.
- Abrir el archivo de respaldo en otra herramienta: no es su propósito
  (Assumptions de [spec.md](./spec.md)).
