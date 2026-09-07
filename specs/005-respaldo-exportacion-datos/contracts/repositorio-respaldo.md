# Contrato: `RepositorioRespaldo`

**Feature**: 005-respaldo-exportacion-datos

Sigue las mismas reglas transversales que
`001-gestion-sueldo-ahorro/contracts/repositorios.md`: interfaz en
`lib/dominio/repositorios/`, implementación con sufijo `Sqlite` en
`lib/datos/repositorios/`, y **ningún repositorio decide reglas de negocio** —
si un archivo es aceptable lo decide `validarRespaldo(...)` en el dominio (D6
de [research.md](./research.md)), no este repositorio.

**Particularidad de este repositorio frente a los demás**: es el único que
opera sobre el **archivo** de la base y no sobre sus filas. Por eso es también
el único que necesita cerrar y reabrir la conexión viva, y el que carga con la
garantía de todo-o-nada de D3.

```dart
Future<ArchivoRespaldo>  exportar();
Future<InformeRespaldo>  inspeccionar(String rutaCandidato);
Future<void>             restaurar(String rutaCandidato);
```

| Método | Garantía |
|---|---|
| `exportar()` | Consolida el WAL, copia la base a una ruta temporal privada, vacía en **la copia** las tablas que no viajan (D4) y devuelve la ruta y el nombre propuesto del archivo listo para entregar. No modifica la base viva de ninguna forma. Funciona con la base recién creada y sin datos (FR-012). |
| `inspeccionar(ruta)` | Copia el candidato a una ruta temporal, lo abre **sin `version:`** para no dispararle migraciones a un archivo que quizá se rechace, junta los tres hechos que pide `validarRespaldo` y devuelve el `InformeRespaldo`. **No modifica ningún dato del usuario, pase lo que pase.** |
| `restaurar(ruta)` | Ejecuta la secuencia de intercambio de D3. Al terminar, la base abierta es la del respaldo, ya migrada al esquema actual si venía de una versión anterior (FR-010), y sin ninguna fila de suscripción heredada del archivo (D4). |

**Todo o nada (FR-008, FR-009)**: si `restaurar` falla en cualquier punto,
MUST dejar la base tal como estaba antes de llamarlo y volver a dejarla
abierta y usable. La red de seguridad es el rename a `finanzas.db.previo`, que
solo se borra después de que la base nueva abrió bien.

**Orden obligatorio**: `restaurar` MUST llamarse solo después de que
`inspeccionar` haya devuelto `valido` para ese mismo archivo. La UI no puede
saltarse ese paso, porque además entre uno y otro va la confirmación explícita
del usuario que exige FR-007.

**Privacidad (Principio I, enmienda v3.0.0)**: ningún método de esta interfaz
sube, envía ni transmite nada. `exportar` deja un archivo en el
almacenamiento privado de la app y devuelve su ruta; **quién lo recibe después
lo decide el usuario fuera de la app**, a través de la hoja de compartir del
sistema (D5). Este repositorio no conoce destinos.

**Lo que este contrato deja explícitamente fuera**: no hay `exportarAutomatico`
ni programación de respaldos. La enmienda a la constitución autoriza la salida
de datos **solo** cuando el usuario la pide en ese momento, así que una API que
permitiera exportar sin intervención suya contradiría el principio que habilita
esta feature.
