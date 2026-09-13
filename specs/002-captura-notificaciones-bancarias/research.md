# Phase 0 — Research: Captura automática de consumos desde notificaciones bancarias

**Feature**: 002-captura-notificaciones-bancarias | **Fecha**: 2026-08-30 | **Revisado**: 2026-08-30 (alcance genérico)

**Depende de**: 001-gestion-sueldo-ahorro (Transaccion, Categoria, Deuda) y de la constitución v2.0.0.

**Nota de revisión**: la primera versión de este documento asumía un intérprete de texto escrito a mano por banco (BCP, Yape, Plin, SIP). El usuario pidió cubrir cualquier banco o billetera, presentes o futuros, sin que agregar uno nuevo exija código nuevo. D-N2, D-N9, D-N10 y D-N11 son los que cambian de fondo; D-N1, D-N3 a D-N8 siguen vigentes tal como estaban.

---

## D-N1 — Escucha de notificaciones: `flutter_notification_listener`

**Decisión**: `flutter_notification_listener` (jiusanzhou, v1.4.0). Registra un `NotificationListenerService` nativo que, al recibir una notificación, invoca un callback Dart marcado `@pragma('vm:entry-point')` corriendo en un **isolate headless** — sin depender de que la UI o siquiera el proceso principal de la app estén vivos.

**Rationale**: FR-011 exige capturar consumos "aunque la app esté cerrada o en segundo plano". Eso descarta cualquier enfoque basado en un `Stream` que solo emite mientras el engine de Flutter de la app abierta sigue corriendo. Se compararon las tres alternativas con presencia real en pub.dev a agosto 2026:

| Paquete | Pub points | Última publicación | Ejecuta con la app cerrada | Licencia |
|---|---|---|---|---|
| `notification_listener_service` | 160 | hace 2 meses | **No documentado** — API de `Stream`, sin isolate headless | MIT |
| `flutter_notification_listener` | 140 | hace 6 meses | **Sí** — servicio nativo + callback headless + reinicio por `BOOT_COMPLETED` | Apache 2.0 en el repo de GitHub, pero pub.dev lo marca "unknown" |
| Hand-rolled (Kotlin + `MethodChannel` propio) | — | — | Sí, si se implementa bien | — |

`notification_listener_service` tiene mejor puntaje y publicación más reciente, pero es exactamente el tipo de ventaja que no importa acá: si no sobrevive el cierre de la app, no cumple el requisito no negociable de la spec. `flutter_notification_listener` sí resuelve el problema difícil (el puente nativo↔isolate headless, el registro del receptor de `BOOT_COMPLETED`), que es la parte que más se tarda en acertar a mano y la que más fácil se rompe entre versiones de Android.

**Riesgo verificado (2026-08-30)**: pub.dev muestra la licencia como "unknown" pese a que el repositorio de GitHub trae un archivo `LICENSE` de Apache 2.0. Confirmado leyendo el archivo tal como quedó instalado en `.pub-cache/hosted/pub.dev/flutter_notification_listener-1.4.0/LICENSE`: es Apache 2.0, sin ambigüedad. Era un problema de detección de esa página de pub.dev, no una ausencia real de licencia.

**Alternativas consideradas**: sin cambios respecto a la primera versión de este documento — ver el detalle en el historial de git si hace falta. Esta decisión no depende de si el reconocimiento es genérico o por banco: escuchar la notificación es un paso previo e independiente de interpretarla.

---

## D-N2 — El reconocimiento es un único parser genérico, no un intérprete por banco

**Decisión** *(reemplaza la versión original de esta sección)*: `lib/dominio/interpretes/` deja de tener un archivo por banco. Un solo `interprete_generico.dart` interpreta el texto de **cualquier** origen reconocido con el mismo conjunto de reglas: extraer un monto en soles, decidir si el dinero salió o entró (D-N11), y tomar como comercio el fragmento de texto que sobra tras quitar las partes reconocidas del monto y las palabras clave. Sigue siendo Dart puro, en el mismo directorio, con la misma guarda de pureza.

**Rationale**: es la decisión que el usuario pidió explícitamente — agregar un banco nuevo no debe requerir escribir ni desplegar un intérprete nuevo (FR-008a, SC-011). Un parser por banco da mejor precisión por banco, pero ata cada banco nuevo a una tarea de desarrollo con notificaciones reales de ese banco en particular (D-N9 original). Un parser genérico cambia el trato: precisión un poco menor por banco individual, a cambio de que cubrir un banco nuevo sea agregar su paquete de Android a una lista (D-N10), no escribir código.

**Qué no cambia**: sigue sin haber "inteligencia artificial" ni servicio externo de por medio — es un conjunto de expresiones regulares y listas de palabras clave, Dart puro, corriendo en el dispositivo (Principio I y V).

**Alternativas consideradas**:
- **Un intérprete por banco** (versión original de este documento): mejor precisión por banco, pero cada banco nuevo es una tarea de desarrollo. Rechazada tras la decisión explícita del usuario de priorizar cobertura automática sobre precisión máxima por banco.
- **Escuchar y "adivinar" en cualquier app instalada, sin lista de orígenes**: se consideró y se rechazó — ver D-N10.

---

## D-N3 — El monto se extrae como texto, nunca como `double`

**Decisión**: el parser genérico extrae la porción numérica del monto con una expresión regular (p. ej. `S/\s*([\d,]+\.\d{2})`) y la compone a `Dinero` con la misma aritmética entera que ya usa `validarMonto` en `lib/dominio/calculos/presupuesto.dart` (D2 de 001): separar parte entera y decimal como texto, nunca `double.parse` seguido de `* 100`.

**Rationale**: Principio II es no negociable, y una notificación de banco es una fuente de datos externa igual de "sucia" que un campo de texto escrito por el usuario. Se extrae la lógica de "texto decimal → `Dinero`" a una función compartida (`Dinero.deTextoDecimal`) para que el parser genérico y la validación de formularios usen exactamente el mismo camino. Sin cambios respecto a la versión original de este documento — esta regla aplica igual de fuerte a un parser compartido que a uno por banco.

---

## D-N4 — Persistencia del servicio: modo foreground + exención de optimización de batería

Sin cambios. Ver la versión original: el servicio corre en modo *foreground* y la activación pide excluir la app de la optimización de batería del fabricante, porque `flutter_notification_listener` documenta que sin eso puede no reiniciar tras un reboot, y es una limitación de Android en general, no del alcance de bancos.

---

## D-N5 — Deduplicación: por identidad nativa de la notificación, no por contenido

Sin cambios. Cada `ConsumoPendiente` guarda el identificador nativo de la notificación que lo originó. Una notificación reeditada con el mismo identificador no genera un segundo pendiente (FR-015); dos notificaciones distintas — mismo monto y comercio o no — siempre generan pendientes distintos (FR-016). Esto es independiente de si el texto se interpretó con un parser por banco o genérico.

---

## D-N6 — Categorización aprendida: tabla de asociación, no aprendizaje automático

Sin cambios. `comercio_categoria` sigue siendo una tabla simple `comercio_normalizado → categoria`. El parser genérico alimenta el mismo campo `comercio` que antes alimentaba cada intérprete por banco — el resto del flujo de aprendizaje no se entera del cambio.

---

## D-N7 — Normalización de comercio: función pura determinística

Sin cambios en el mecanismo. Con un parser genérico, el texto crudo del comercio puede venir menos limpio que con un intérprete afinado a mano por banco (el parser no sabe, por ejemplo, exactamente dónde termina el nombre del comercio y empieza un código de referencia bancaria), así que `normalizarComercio` gana peso: es la última línea de defensa antes de que un mismo comercio aparezca como dos distintos. Se ajusta con ejemplos reales de varios bancos (D-N9), no de uno solo.

---

## D-N8 — Exclusividad de Android: verificación en tiempo de ejecución, sin flavors

Sin cambios. FR-007 sigue exigiendo que la funcionalidad se omita por completo de la interfaz fuera de Android, independientemente de cuántos orígenes reconozca el parser.

---

## D-N9 — Validación con notificaciones reales: una muestra representativa, no exhaustiva

**Decisión** *(reemplaza la versión original — antes exigía fixtures de cada banco soportado, uno por uno, como bloqueo de cada intérprete)*: el parser genérico se construye y valida contra notificaciones reales de **una muestra de bancos y billeteras variados** — se recomiendan al menos 3 orígenes distintos (p. ej. un banco tradicional, una billetera como Yape/Plin, y un emisor de tarjeta como SIP), con varios ejemplos cada uno (consumo normal, dinero recibido, consumo rechazado si es posible). No hace falta una muestra de cada banco de la lista de orígenes reconocidos (D-N10) antes de que el parser empiece a funcionar para todos ellos — esa es justamente la ventaja de un reconocimiento genérico sobre uno por banco.

**Rationale**: sigue sin existir documentación pública del formato de ningún banco, así que el parser genérico no puede escribirse ni probarse sin texto real de al menos algunos bancos — pero ya no hace falta multiplicar ese esfuerzo por cada origen de la lista. La spec original convertía cada banco nuevo en un bloqueo de desarrollo (D-N9 original); acá el bloqueo es una sola vez, al construir y validar el parser, y después la cobertura de bancos nuevos es casi gratis.

**Implicación para `tasks.md`**: una sola tarea manual de recolección de fixtures (varios orígenes, no uno por uno), en vez de una por banco. El registro de diagnóstico sigue siendo la señal de que el parser genérico falla con algún banco puntual — y ajustarlo ahí beneficia a todos los orígenes a la vez, no solo al que falló.

---

## D-N10 — Lista de orígenes reconocidos: datos, no código

**Decisión**: una constante `List<OrigenReconocido>` (paquete de Android + nombre para mostrar), sembrada con los emisores peruanos que la app ya conoce por `EntidadesPeru` de 001 (BCP, Interbank, BBVA, Scotiabank, Falabella, Ripley, Pichincha, BanBif, Mibanco, Banco de la Nación, Caja Arequipa, Caja Huancayo, Oh!/SIP) más Yape y Plin. El servicio de escucha (`datos/notificaciones/servicio_escucha.dart`) descarta de entrada cualquier notificación cuyo paquete no esté en esta lista — nunca llega al parser genérico ni se guarda en ningún lado (edge case "app no reconocida en absoluto").

**Rationale**: el usuario pidió que agregar un banco no exija código nuevo, no que la app escuche literalmente cualquier notificación de cualquier app del teléfono. Sin esta lista, el parser genérico tendría que decidir "¿esto es una notificación bancaria?" mirando *cualquier* texto del sistema — WhatsApp, un juego, una app de compras — con mucho más riesgo de generar pendientes ruidosos (FR-017 prohíbe datos inventados, pero un falso positivo que sí matchea el patrón de monto igual sería un pendiente basura, y una bandeja llena de basura rompe SC-002 aunque nada se registre mal). Acotar por paquete conocido es la diferencia entre "genérico dentro de las apps financieras que ya identificamos" y "genérico sin límite", y es lo que de verdad resuelve la pregunta original del usuario ("si agrego una tarjeta, ¿la lee?"): sí, para cualquier banco ya sembrado en esta lista — que cubre los 15 emisores que la app ya conoce — sin escribir nada nuevo; para un banco fuera de esa lista, agregarlo es una línea de datos (paquete + nombre), no una tarea de desarrollo.

**Riesgo a verificar en implementación**: el paquete de Android real de cada banco (`com.bcp.bank...`, etc.) no está documentado públicamente — hay que observarlo en un dispositivo real con cada app instalada, igual que antes había que observar el formato de texto. Es un insumo más liviano que antes (un identificador de paquete, no un formato de texto completo por banco), pero sigue siendo manual.

**Alternativas consideradas**:
- **Sin lista, escuchar cualquier app**: rechazada — ver Rationale. El costo de un parser realmente abierto es ruido, no solo imprecisión.
- **Lista fija de 4 (versión original)**: rechazada por el usuario explícitamente.
- **Lista configurable por el usuario desde la UI** (agregar/quitar apps a mano): posible mejora futura, no un requisito de esta spec — la lista sembrada ya cubre todo lo que la app conoce de 001. Se puede reconsiderar si en el uso real aparece un banco fuera de la lista.

---

## D-N11 — Detectar si el dinero salió o entró: palabras clave, no la app de origen

**Decisión**: el parser genérico clasifica cada notificación como saliente o entrante buscando palabras clave en el texto, no asumiéndolo por la app (FR-008b). Palabras que indican salida: "consumo", "compra", "cargo", "pagaste", "pago realizado". Palabras que indican entrada: "abono", "depósito", "te enviaron", "recibiste", "ingreso", "transferencia recibida". Una notificación sin ninguna de las dos listas, o con señales de ambas, no se interpreta como consumo — pasa a diagnóstico (FR-017: mejor no capturar que inventar la dirección del dinero).

**Rationale**: con un intérprete por banco, la dirección del dinero se podía inferir en parte de qué tipo de notificación manda esa app (p. ej. Yape distingue "recibiste" de "pagaste" en textos muy estables). Con un parser genérico y multi-banco, esa certeza se pierde — hay que decidirlo del texto mismo, banco por notificación, no una vez por banco. Es la pieza más nueva de este diseño y la que más se va a ajustar con la muestra de D-N9: las palabras clave de arriba son un punto de partida razonable, no una lista cerrada.

**Riesgo**: una billetera que redacte "cargo" para un movimiento que en realidad es un abono (o viceversa) produciría una clasificación incorrecta. Como toda captura pasa por confirmación explícita (FR-020), el peor caso es que un pendiente entrante aparezca donde no debería — el usuario lo descarta al confirmar, nunca se registra solo. No es un problema de exactitud de datos financieros (Principio II), es, en el peor caso, una fila de más en una bandeja que ya exige revisión humana.

**Referencia de patrones típicos** (aportada por el usuario 2026-08-30, **no reemplaza la captura real de D-N9** — los textos exactos cambian entre versiones de cada app):

| Origen | Título típico | Cuerpo típico | Dirección |
|---|---|---|---|
| Yape | "Yape!" | "[Nombre] te yapeó S/ [monto]" | entrante |
| Plin | "Plin" / "[Banco]" | "¡Recibiste un Plin! [Nombre] te envió S/ [monto]" | entrante |
| BCP | "Alerta BCP" | "Transferencia recibida por S/ [monto] de [Nombre]. Cta: *[dígitos]" | entrante |
| BCP (de un correo real del usuario) | — | "Realizaste un consumo de S/ [monto] con tu Tarjeta de Débito/Crédito BCP en [Comercio]" | **saliente** |
| Interbank | "Interbank" | "Consumo por S/ [monto] realizado con tu tarjeta *[dígitos] en [Establecimiento]" | **saliente** |
| BBVA | "BBVA Perú" | "Abono recibido por S/ [monto] en tu Cuenta [Tipo]" | entrante |

Confirma la estructura de tres campos (título, cuerpo, y a veces `subText`) y da un primer borrador razonable para las palabras clave de dirección: **saliente** → "consumo", "realizaste un consumo", "yapeaste" / "acabas de yapear"; **entrante** → "recibiste", "te yapeó", "te envió", "abono recibido", "transferencia recibida". El borrador se ajusta contra los fixtures reales de T034, no se fija acá.

---

## D-N12 — Gmail como origen: el evento sí trae el correo completo *(2026-09-13)*

**Estado**: hallazgo verificado, **decisión de alcance todavía abierta**. Falta
un consumo con tarjeta real para cerrarla (ver "Lo que falta" al final).

**Qué se verificó**: `NotificationEvent.text` expone únicamente `EXTRA_TEXT` —el
preview que Gmail trunca justo sobre el comercio, lo que el 2026-09-12 parecía
matar esta feature—, pero el lado Android del plugin reenvía además
`EXTRA_BIG_TEXT` y `EXTRA_TEXT_LINES`, que llegan a Dart en `evento.raw`. Medido
en el teléfono de referencia: `bigText` trajo **301 y 1024 caracteres** contra
**24 y 79** del preview. Los volcados completos están en
`test/dominio/interpretes/fixtures/notificacion-gmail-capturada.md`, capturados
por la propia app y no transcritos a mano.

**Por qué importa**: la salida que el hallazgo del 2026-09-12 dejaba planteada
—"reconocer Gmail como origen y filtrar por remitente"— **es técnicamente
viable y no saca un solo dato del teléfono**. La alternativa que obligaba a
mandar el insumo a un servicio externo (spec 006) deja de ser la única.

**Cuatro consecuencias sobre el diseño del parser**, ninguna anticipable sin
estas capturas:

1. **El filtro por paquete de D-N10 no alcanza.** Para Gmail el `packageName`
   es siempre `com.google.android.gm`; el remitente viene en `title` (`BCP
   Notificaciones`, `Operaciones Sip`, `YAPE Notificaciones`). El filtro tiene
   que ser por remitente, no por paquete — lo que convierte a
   `origenesReconocidos` en una lista de remitentes, no de apps.
2. **Gmail publica dos notificaciones por correo**: una agrupada (`textLines`
   con un renglón por correo, sin `bigText`) y una individual por correo (con
   `bigText`). Procesar ambas duplicaría cada consumo. Regla de descarte:
   `bigText == null && textLines != null`.
3. **El monto va en su propia línea**, separado de la etiqueta que lo nombra.
   Un parser que busque `S/` en el mismo renglón que "Monto" falla en los dos
   correos capturados.
4. **`bigText` se corta a los 1024 caracteres exactos**, a mitad de palabra.

**Riesgo abierto**: si un correo de consumo pone el comercio después del
carácter 1024, se pierde. En lo capturado el dato útil entraba en los primeros
200, pero ninguno de los tres es un consumo con tarjeta.

**Lo que falta para decidir**: capturar un consumo real. Los tres correos
obtenidos son movimientos entre cuentas (un yapeo enviado, uno recibido y un
aviso), y FR-012/FR-013 mandan ignorar todo lo entrante. Hasta tenerlo, T034
sigue abierta: lo que hay prueba que el mecanismo funciona y cómo viene armado,
no que el dato que la spec necesita esté ahí.

---

## D-N13 — La captura no corre en Android 13+ tal como está implementada *(2026-09-13)*

**Hallazgo, no decisión**: durante el recorrido de D-N12 se descubrió que la
captura **nunca había funcionado** en el teléfono de referencia, por tres
defectos de implementación independientes del parser. Se documentan acá porque
cualquier decisión de alcance sobre esta spec tiene que contarlos como trabajo
pendiente, no darlos por hechos.

1. **Falta pedir `POST_NOTIFICATIONS` en tiempo de ejecución.** Desde Android
   13 un servicio en primer plano está obligado a publicar una notificación;
   sin ese permiso Android lo mata con ANR, y el log del dispositivo lo dijo
   con todas las letras nombrando el servicio del plugin:
   `Context.startForegroundService() did not then call Service.startForeground()`.

   **Precisión sobre la causalidad**, porque importa: conceder el permiso
   **no alcanzó** para que la captura funcionara. Hizo falta además que
   `activar()` se ejecutara con el servicio ya vinculado, porque el motor de
   Flutter del plugin solo termina de inicializar por esa vía y hasta entonces
   los eventos se encolan sin llegar a Dart. El permiso es necesario, no
   suficiente: son dos defectos que se manifestaban igual.
2. **"Desactivar" puede dejar la feature inutilizable.** El plugin deshabilita
   el componente del servicio a nivel de sistema (`setComponentEnabledSetting`);
   Android entonces revoca el acceso a notificaciones y saca la app de la lista
   de ajustes — la misma lista adonde la app te manda a arreglarlo. No hay
   salida por interfaz: hay que desinstalar. Solo la propia app puede
   reactivar el componente; `adb` responde `SecurityException`.
3. **`EstadoCaptura` informa un estado que no verifica.** "Captura activa" se
   deriva del permiso más el interruptor guardado, sin comprobar que el
   servicio exista. Se observó la pantalla diciendo "activa" con el servicio
   muerto. Es el más grave: un usuario creería que sus consumos se capturan
   mientras no se captura nada — exactamente la confianza que el Principio IV
   protege.

**Además, de operación**: tras reinstalar el APK hay que volver a conceder el
permiso **y** hacer el ciclo Desactivar → Activar, porque el identificador de
callback que Android guarda apunta al build anterior. Sin eso el callback no
corre y no hay ninguna señal visible de que algo ande mal.


---

## D-N14 — `permission_handler` para el único permiso que la app pide *(2026-09-13)*

**Decisión**: usar `permission_handler` (MIT, Baseflow, 13.0.2) para pedir
`POST_NOTIFICATIONS` en tiempo de ejecución, en vez de escribir un canal de
plataforma propio.

**Por qué**: es el único permiso que esta app pide desde su propio código —el
de leer notificaciones se concede en los ajustes de Android, no con un
diálogo—, y resolverlo a mano significa código Kotlin en `MainActivity` más un
`MethodChannel` más el puente del resultado asincrónico de
`onRequestPermissionsResult`. Son unas sesenta líneas nativas, en un proyecto
que hasta hoy no tiene ninguna, para reproducir algo que un paquete mantenido
hace en tres líneas de Dart.

Frente a las Restricciones Técnicas de la constitución: está activamente
mantenido, es MIT, y **no abre ninguna conexión** — solo habla con el
`PackageManager` del propio dispositivo, así que no roza el Principio I.

**Alternativas consideradas**:
- **Canal de plataforma propio**: control total y cero dependencias, pero
  introduce código nativo que hay que mantener y probar sin poder cubrirlo con
  `flutter test`. Rechazada por desproporcionada frente a un solo permiso.
- **No pedirlo y activar igual**: es el estado anterior, y es justamente el
  defecto D-N13.1. Rechazada.
- **`flutter_local_notifications`**, que también sabe pedirlo: trae un
  paquete mucho más grande para usar una sola función suya, y la app no
  publica notificaciones propias fuera del aviso del servicio. Rechazada por
  Principio V.
