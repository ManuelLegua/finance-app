# Research: Respaldo y exportación de datos

Seis decisiones técnicas, en el mismo formato que `001-gestion-sueldo-ahorro/research.md`.

---

## D1 — El archivo de respaldo es el propio archivo SQLite, no un volcado a JSON

**Decisión**: el respaldo es una copia byte a byte de `finanzas.db` (previo
`PRAGMA wal_checkpoint(TRUNCATE)` para que no quede nada en el `-wal`), con un
nombre propuesto del estilo `finanzas-respaldo-2026-09-07.db`. Restaurar es
poner ese archivo en el lugar de la base actual y volver a abrirla.

**Por qué**: hace que FR-010 (restaurar un respaldo viejo en una app nueva)
salga **gratis y sin lógica nueva**. Un archivo SQLite lleva su propia versión
de esquema en `PRAGMA user_version`, que es exactamente el número que sqflite
compara contra `Esquema.version` al abrir: si el respaldo es de la v3 y la app
va por la v4, `onUpgrade` dispara `Migraciones.aplicar(...)` — los mismos pasos
ya escritos y ya probados en `test/datos/migracion_00X_test.dart`. No hay una
segunda escalera de migraciones que mantener sincronizada con la primera.

Un volcado a JSON obligaría a versionar el formato del JSON **además** del
esquema SQL, y a escribir un segundo juego de migraciones para ese formato.
Serían dos verdades sobre la misma forma de los datos, que es justo el tipo de
duplicación que este proyecto evita (mismo criterio que D3 de la spec 001: las
cuotas se derivan, no se almacenan dos veces).

**Alternativas consideradas**:

- **Volcado a JSON con su propia versión**: rechazada por lo anterior. Sería
  defendible si el archivo tuviera que leerse fuera de la app, pero la spec ya
  descarta ese caso por escrito (Assumptions: el archivo no está pensado para
  abrirse ni analizarse en otra herramienta).
- **`VACUUM INTO 'ruta'`**, que produce una copia limpia y consistente en una
  sola sentencia: rechazada por compatibilidad. Requiere SQLite 3.27+ (2019) y
  `sqflite` usa el SQLite **del sistema Android**, que en los niveles de API que
  este proyecto todavía admite puede ser bastante anterior. El checkpoint más
  copia de archivo funciona en cualquier versión.
- **Exportar a CSV/planilla**: es otra funcionalidad (análisis externo), no un
  respaldo restaurable. La spec la deja explícitamente fuera de alcance.

---

## D2 — El archivo se valida antes de tocar un solo dato, y sin abrirlo "con versión"

**Decisión**: antes de reemplazar nada, el candidato se copia a una ruta
temporal y se abre ahí con una conexión **sin `version:`**, para que sqflite
no dispare `onUpgrade` sobre un archivo que quizá se rechace. Sobre esa
conexión se comprueban tres cosas, en este orden:

1. `PRAGMA integrity_check` devuelve `ok` (descarta archivos corruptos o que
   ni siquiera son SQLite).
2. Están las tablas que el esquema espera (descarta una base de otra app que
   sí es SQLite válido).
3. `PRAGMA user_version` está entre 1 y `Esquema.version` inclusive.

**Por qué el orden importa**: un archivo que no es SQLite falla en el paso 1 y
nunca llega a que se le pregunte por tablas ni versiones, así que cada motivo
de rechazo se puede explicar con precisión (FR-009 pide un mensaje claro, no un
"archivo inválido" genérico).

**`user_version > Esquema.version`** es el caso "respaldo de una app más nueva"
del Edge Cases: se rechaza en vez de intentar leerlo, porque las migraciones
solo saben ir hacia adelante y no hay forma de saber qué columnas nuevas trae.

**`user_version == 0`** es un archivo SQLite sin esquema versionado: no es un
respaldo de esta app.

**Alternativas consideradas**: abrir el candidato directamente con
`version: Esquema.version` y dejar que sqflite valide migrando. Rechazada
porque eso **modifica el archivo del usuario** antes de haberlo aceptado, y
porque un archivo de otra app podría migrarse "con éxito" a un esquema
Frankenstein en vez de rechazarse.

---

## D3 — El reemplazo es todo o nada, con el archivo anterior a un rename de distancia

**Decisión**: la restauración sigue esta secuencia, y cualquier fallo en
cualquier paso deja al usuario exactamente como estaba:

1. Copiar el candidato a una ruta temporal y validarlo ahí (D2).
2. Cerrar la conexión viva (`BaseDatos.cerrar()`).
3. Renombrar `finanzas.db` a `finanzas.db.previo` — **renombrar, nunca
   borrar**: es la red de seguridad y es una operación barata en el mismo
   sistema de archivos.
4. Mover el candidato validado a `finanzas.db` y **borrar los `-wal` y `-shm`
   viejos**, que quedaron huérfanos del archivo anterior.
5. Reabrir con `BaseDatos.abrir()`, que aplica las migraciones si el respaldo
   venía de una versión anterior (D1).
6. Solo si el paso 5 salió bien, borrar `finanzas.db.previo`. Si falló,
   deshacer: restituir `.previo` a su lugar y volver a abrir.

**Por qué los sidecars del paso 4 no son un detalle**: un `finanzas.db-wal`
dejado al lado de un archivo principal distinto es corrupción silenciosa, no
un error visible. Es el modo de fallo más fácil de pasar por alto en este
diseño y por eso queda escrito acá y con su propia tarea de prueba.

**Alternativas consideradas**: copiar tabla por tabla dentro de una
transacción sobre la base viva (`DELETE FROM` + `INSERT` de cada tabla). Es la
forma "ortodoxa" de conseguir atomicidad, pero exige enumerar y mantener a mano
cada tabla y cada columna del esquema — otra vez, una segunda verdad sobre la
forma de los datos, que se desincroniza en cuanto alguien agregue una tabla y
se olvide de esta lista. El intercambio de archivos con respaldo previo da la
misma garantía sin conocer el esquema.

---

## D4 — Lo que **no** viaja en el respaldo se borra de la copia, no del original

**Decisión**: como el respaldo es una copia completa de la base (D1), lo que
FR-003 manda excluir hay que quitarlo **de la copia**, después de copiarla y
antes de entregársela al usuario. Dos tablas se vacían:

| Tabla | Por qué no viaja |
|---|---|
| `suscripcion_premium` | FR-003. Si viajara, un archivo de respaldo editado a mano sería una forma de fabricarse acceso pagado. El estado real siempre se vuelve a pedir a Google Play con "Restaurar suscripción" (spec 004, FR-014). |
| `notificacion_diagnostico` | No es dato que el usuario haya cargado (FR-002 enumera lo que sí), es un registro técnico de la captura. Además puede contener el texto crudo de notificaciones bancarias, y este archivo está pensado para que el usuario lo mande por correo o lo suba a donde quiera: cuanto menos contenido sensible lleve encima, mejor. |

**Al restaurar**, simétricamente: la fila de `suscripcion_premium` que venga en
el archivo (si alguien la puso a mano) se descarta y el estado se vuelve a
consultar contra Google Play. El acceso premium **nunca** sale de un archivo
local (SC-004).

**Alternativas consideradas**: dejar ambas tablas y filtrarlas al restaurar.
Rechazada: el archivo se le entrega al usuario y puede terminar en cualquier
lado, así que el contenido sensible se saca en el origen, no en el destino.

---

## D5 — Entrega y elección del archivo: la hoja de compartir y el selector del sistema

**Decisión**: exportar escribe el archivo en el directorio temporal privado de
la app y se lo pasa a la **hoja de compartir de Android** (`share_plus`); ahí
el usuario elige "Guardar en Archivos", Drive, correo o lo que tenga. Restaurar
usa el **selector de documentos del sistema** (`file_picker`, que sobre Android
usa el Storage Access Framework) para que el usuario señale el archivo.

**Por qué**: es lo que hace que FR-004 se cumpla al pie de la letra — la app no
elige destino ni lo sugiere, solo entrega el archivo — y es también lo que
mantiene la enmienda del Principio I (v3.0.0) dentro de su límite: nada sale
sin una acción explícita del usuario en ese momento, y el destino lo decide él,
fuera de la app.

Además **no requiere ningún permiso**: ni `WRITE_EXTERNAL_STORAGE` ni
`MANAGE_EXTERNAL_STORAGE`. Pedir acceso amplio al almacenamiento en una app de
finanzas es una mala señal para el usuario y una revisión extra en Play
Console, a cambio de nada que la hoja de compartir no resuelva.

**Justificación de las dos dependencias nuevas** (la constitución exige
justificar cada paquete): ambas son de mantenimiento activo y de amplio uso,
ninguna abre conexiones de red ni introduce telemetría — la comprobación
concreta contra el Principio I es tarea de la fase de implementación, y si
alguna la incumpliera se cae la dependencia, no el principio. La alternativa
—escribir a mano el canal de plataforma contra el Storage Access Framework— es
código nativo propio para reemplazar dos paquetes mantenidos, contra YAGNI.

Las versiones fijadas por `flutter pub add` (T001) son **`share_plus` 13.3.0**
y **`file_picker` 12.2.0**.

**Comprobación contra el Principio I (T002)** — hecha sobre el código de los
paquetes en el pub cache, no sobre su documentación:

| Qué se buscó | Resultado |
|---|---|
| `HttpClient`, `Socket`, `package:http` en el Dart de ambos paquetes | Ninguna aparición |
| `okhttp`, `java.net.URL`/`HttpURLConnection` en el Android de ambos | Una sola: `java.net.URLConnection` en `FileUtils.kt` de `android_file_picker`, usada como `guessContentTypeFromStream(ByteArrayInputStream)` para adivinar el MIME por número mágico. Es una función de la biblioteca estándar que no abre ninguna conexión |
| Analítica o telemetría (`Analytics`, `firebase`, `telemetry`) | Ninguna aparición |
| `android.permission.INTERNET` | Solo en la app de ejemplo de `share_plus`, que no forma parte de la librería y no se fusiona en el manifiesto de esta app. Los manifiestos de los plugins declaran únicamente un `FileProvider`, un `BroadcastReceiver` interno y un `<queries>` para `GET_CONTENT` |

Ninguna de las dos incumple el principio, así que ninguna se cae.

**Alternativas consideradas**: escribir directo a `/Downloads` con permiso de
almacenamiento (rechazada por el permiso), y dejar el archivo en el directorio
de la app para que el usuario lo saque por USB (rechazada: en Android moderno
ese directorio no es accesible sin root, así que el respaldo quedaría tan
atrapado como los datos que intenta salvar).

---

## D6 — El veredicto de validación es dominio puro; el manejo de archivos, no

**Decisión**: la operación de copiar, mover y abrir archivos vive entera en
`lib/datos/` (necesita `sqflite` y `dart:io`, prohibidos en el dominio). Pero
**la decisión de si un candidato es aceptable y por qué motivo no lo es** se
modela como una función pura del dominio, sobre datos ya leídos:

```dart
ResultadoValidacionRespaldo validarRespaldo({
  required bool integridadOk,
  required bool tablasEsperadasPresentes,
  required int versionDelArchivo,
  required int versionSoportada,
});
```

`ResultadoValidacionRespaldo` es un enum —`valido`, `corrupto`,
`noEsDeLaApp`, `deVersionMasNueva`— y no un `bool` con un mensaje al lado,
siguiendo la regla del proyecto de que un estado se nombra con un enum
exhaustivo: si mañana aparece un cuarto motivo de rechazo, el `switch` que
produce el mensaje deja de compilar hasta que alguien decida qué decirle al
usuario.

**Por qué partirlo así**: deja la única regla con criterio propio de esta
feature en Dart puro, probable sin archivos y sin emulador, como exige el
Principio III; y deja del otro lado, en `datos/`, un procedimiento sin
decisiones que se prueba con archivos reales en un directorio temporal
(`sqflite_common_ffi` ya permite correr SQLite de verdad en Windows, que es
como corre toda la suite).

**Alternativas consideradas**: meter la validación completa dentro del
repositorio, devolviendo un `bool`. Rechazada: dejaría la regla sin prueba
pura y obligaría a la UI a inventar el mensaje a partir de un booleano, que es
exactamente lo que la regla de enums del proyecto prohíbe.

---

## Nota de mantenimiento

`lib/datos/migraciones.dart` documenta hoy que las migraciones no pueden ser
destructivas porque *"la spec descarta backup y exportación en esta versión,
así que una migración destructiva sería una pérdida irreversible"*. Esa frase
queda desactualizada con esta feature. El motivo de fondo no cambia (una
migración destructiva sigue estando prohibida, y la constitución lo exige
igual), pero la justificación hay que reescribirla: ahora existe respaldo, y
aun así no se puede contar con que el usuario lo haya hecho.
