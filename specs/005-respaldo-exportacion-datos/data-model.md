# Data Model: Respaldo y exportación de datos

Esta feature **no agrega ninguna tabla ni sube `Esquema.version`**. Es la
primera del proyecto que no toca el esquema: opera sobre el archivo de base de
datos completo, no sobre su contenido fila por fila (D1 de [research.md](./research.md)).

## 1. Entidades del dominio

### `ResultadoValidacionRespaldo` (enum, `lib/dominio/modelos/`)

El veredicto sobre un archivo candidato a restaurarse. Cada valor corresponde a
un motivo distinto que el usuario tiene que poder distinguir (FR-009).

| Valor | Cuándo | Qué se le dice al usuario |
|---|---|---|
| `valido` | Pasa las tres comprobaciones de D2 | Nada: se sigue al aviso de reemplazo (FR-007) |
| `corrupto` | `integrity_check` no devuelve `ok`, o el archivo ni siquiera es SQLite | Que el archivo está dañado o no es un respaldo |
| `noEsDeLaApp` | Es SQLite válido pero le faltan tablas del esquema, o `user_version` es 0 | Que ese archivo no es un respaldo de esta app |
| `deVersionMasNueva` | `user_version > Esquema.version` | Que el respaldo es de una versión más nueva de la app, y que hay que actualizarla para poder leerlo |

### `InformeRespaldo` (`lib/dominio/modelos/`)

Lo que la app sabe decir de un archivo candidato **antes** de tocar nada:
el resultado de la validación y la versión de esquema que trae. Sirve para que
la UI pueda explicar el rechazo con precisión y, cuando es válido, mostrar si
el respaldo viene de una versión anterior (se va a migrar al restaurar).

## 2. Regla pura

```dart
ResultadoValidacionRespaldo validarRespaldo({
  required bool integridadOk,
  required bool tablasEsperadasPresentes,
  required int versionDelArchivo,
  required int versionSoportada,
});
```

Orden de evaluación, que es parte del contrato porque decide **qué** motivo se
reporta cuando falla más de una cosa a la vez (D2):

1. `!integridadOk` → `corrupto`
2. `!tablasEsperadasPresentes || versionDelArchivo == 0` → `noEsDeLaApp`
3. `versionDelArchivo > versionSoportada` → `deVersionMasNueva`
4. En otro caso → `valido`

Es Dart puro: recibe hechos ya averiguados, no abre archivos ni consulta
`sqflite`. Se prueba con casos normal, límite (`versionDelArchivo ==
versionSoportada`, y `== 1`, el mínimo válido) y adverso (`0`, y
`versionSoportada + 1`).

## 3. El archivo de respaldo

No es una entidad persistida en la base: es un artefacto que sale de ella.

| Aspecto | Definición |
|---|---|
| Formato | Un archivo SQLite, copia de `finanzas.db` con el WAL ya consolidado (D1) |
| Versión de esquema | La que ya lleva el propio archivo en `PRAGMA user_version` — no se inventa un número de versión aparte |
| Nombre propuesto | `finanzas-respaldo-AAAA-MM-DD.db`; el usuario puede renombrarlo, la restauración no depende del nombre |
| Contenido | Todas las tablas de `Esquema.creacion` **menos** las dos vaciadas abajo |
| Dónde nace | Directorio temporal privado de la app; de ahí va a la hoja de compartir (D5). La app nunca elige un destino final |

### Tablas que se vacían en la copia antes de entregarla (D4)

| Tabla | Motivo |
|---|---|
| `suscripcion_premium` | FR-003: un respaldo no puede ser una vía para fabricarse acceso pagado. El estado real se pide siempre a Google Play |
| `notificacion_diagnostico` | No es dato cargado por el usuario, y puede contener texto crudo de notificaciones bancarias. El archivo puede terminar en cualquier lado: lo sensible se saca en el origen |

### Tablas que sí viajan (FR-002)

`obligacion`, `transaccion`, `tarjeta`, `deuda`, `aporte_ahorro`,
`meta_ahorro`, `cobro_ingreso`, `comercio_categoria`, `configuracion`, y la
tabla `ingreso` de la v1 en las instalaciones que vengan de una versión
anterior (sigue existiendo intacta, D-C2/D-C5 de la spec 003).

Al ser una copia del archivo entero, esta lista **no se mantiene a mano en el
código**: es lo que queda después de vaciar las dos de arriba. Está escrita acá
para poder verificarla en una prueba, no para replicarla en una constante.

## 4. Estados de la operación

Tanto exportar como restaurar son operaciones de una sola pasada, y la UI
necesita distinguir sus fases para cumplir FR-005 y FR-007:

```text
inactivo → enCurso → (completado | fallido)
```

La restauración agrega un paso previo que **no toca datos**:

```text
inactivo → validando → (rechazado(motivo) | esperandoConfirmacion) → reemplazando → (completado | fallido)
```

`esperandoConfirmacion` es donde vive FR-007: el archivo ya se validó, pero
todavía no se tocó ningún dato del usuario, y hace falta que confirme el
reemplazo. Cancelar desde ahí no deja nada a medias porque todavía no empezó
nada.

## 5. Qué NO cambia

- `Esquema.version` sigue en **4**. Esta feature no agrega ni altera tablas.
- Ningún repositorio existente cambia de interfaz.
- `Dinero` y el resto de los tipos del dominio no participan: el respaldo mueve
  el archivo entero, nunca deserializa montos. Por eso el Principio II
  (exactitud monetaria) no corre riesgo acá — no hay ninguna conversión de
  centavos de por medio en todo el camino.
