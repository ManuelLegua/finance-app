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

> **Afinada por D-N12 (2026-09-13)**: los correos del BCP traen un `Número de
> operación`, mejor clave que monto+fecha para el caso del mismo movimiento
> avisado dos veces. Sigue sin resolver el traspaso entre cuentas propias, que
> genera dos notificaciones opuestas por el mismo monto. **Esta es la decisión
> de deduplicación**: `CLAUDE.md` y el fixture la llamaban "D-N7" por error de
> arrastre; D-N7 es la normalización de comercio.

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

> **Enmendada por D-N12 (2026-09-13)**: el mecanismo de filtrado ya **no es
> solo por paquete de Android**. Los consumos llegan por correo y para todo
> correo el paquete es `com.google.android.gm`, así que el filtro pasó a tener
> dos modos —paquete **o** remitente (el `title`)—. El fundamento de esta
> sección sigue en pie sin cambios: lista cerrada, datos y no código, y agregar
> un origen no exige escribir interpretación nueva. Leer D-N12 antes de tocar
> `origenesReconocidos`.

**Decisión**: una constante `List<OrigenReconocido>` (paquete de Android + nombre para mostrar), sembrada con los emisores peruanos que la app ya conoce por `EntidadesPeru` de 001 (BCP, Interbank, BBVA, Scotiabank, Falabella, Ripley, Pichincha, BanBif, Mibanco, Banco de la Nación, Caja Arequipa, Caja Huancayo, Oh!/SIP) más Yape y Plin. El servicio de escucha (`datos/notificaciones/servicio_escucha.dart`) descarta de entrada cualquier notificación cuyo paquete no esté en esta lista — nunca llega al parser genérico ni se guarda en ningún lado (edge case "app no reconocida en absoluto").

**Rationale**: el usuario pidió que agregar un banco no exija código nuevo, no que la app escuche literalmente cualquier notificación de cualquier app del teléfono. Sin esta lista, el parser genérico tendría que decidir "¿esto es una notificación bancaria?" mirando *cualquier* texto del sistema — WhatsApp, un juego, una app de compras — con mucho más riesgo de generar pendientes ruidosos (FR-017 prohíbe datos inventados, pero un falso positivo que sí matchea el patrón de monto igual sería un pendiente basura, y una bandeja llena de basura rompe SC-002 aunque nada se registre mal). Acotar por paquete conocido es la diferencia entre "genérico dentro de las apps financieras que ya identificamos" y "genérico sin límite", y es lo que de verdad resuelve la pregunta original del usuario ("si agrego una tarjeta, ¿la lee?"): sí, para cualquier banco ya sembrado en esta lista — que cubre los 15 emisores que la app ya conoce — sin escribir nada nuevo; para un banco fuera de esa lista, agregarlo es una línea de datos (paquete + nombre), no una tarea de desarrollo.

**Riesgo a verificar en implementación**: el paquete de Android real de cada banco (`com.bcp.bank...`, etc.) no está documentado públicamente — hay que observarlo en un dispositivo real con cada app instalada, igual que antes había que observar el formato de texto. Es un insumo más liviano que antes (un identificador de paquete, no un formato de texto completo por banco), pero sigue siendo manual.

**Alternativas consideradas**:
- **Sin lista, escuchar cualquier app**: rechazada — ver Rationale. El costo de un parser realmente abierto es ruido, no solo imprecisión.
- **Lista fija de 4 (versión original)**: rechazada por el usuario explícitamente.
- **Lista configurable por el usuario desde la UI** (agregar/quitar apps a mano): posible mejora futura, no un requisito de esta spec — la lista sembrada ya cubre todo lo que la app conoce de 001. Se puede reconsiderar si en el uso real aparece un banco fuera de la lista.

---

## D-N11 — Detectar si el dinero salió o entró: palabras clave, no la app de origen

> **Ampliada por D-N15 (2026-09-13)**: las palabras de **salida** de esta
> sección se escribieron pensando en compras con tarjeta y dejaban afuera los
> envíos de dinero, que también son consumos. Ver D-N15 para la lista ampliada
> y para el falso positivo que introduce.
>
> **Acotada por D-N12 (2026-09-13)**: las palabras clave **no se buscan en todo
> el texto**. El pie fijo del correo del BCP contiene "compras", "rechazada" y
> "tarjeta de débito o crédito", y un clasificador que lea el `bigText` entero
> encuentra señales contradictorias y manda a diagnóstico un consumo
> inequívoco. La zona que se lee termina en el primer renglón que empieza con
> `¿`. Ver el punto 3 de D-N12.

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

## D-N12 — Gmail como origen: el consumo entra por correo, no por push *(2026-09-13, cerrada)*

**Estado**: **decidida**, y ampliada la noche del 2026-09-13 con dos capturas
de un segundo emisor (G5 y G6, Sip) que corrigieron el punto 3 y agregaron los
puntos 10 a 12. El hallazgo del 2026-09-12 dejó planteada una pregunta
de alcance —por dónde entran los consumos, si las apps de banco solo mandan push
del dinero entrante— y las capturas de
`test/dominio/interpretes/fixtures/notificacion-gmail-capturada.md` la
responden. La última, G4, es un consumo con tarjeta real y es la que cierra la
decisión.

**Decisión**: **Gmail se reconoce como origen, y el filtro de orígenes pasa a
tener dos modos en vez de uno**: por paquete de Android (las apps que sí
notifican por su cuenta — el push de Yape dio su paquete) y por **remitente**,
que para un correo es el `title` de la notificación de Gmail (`BCP
Notificaciones`, `Operaciones Sip`, `YAPE Notificaciones`). Una notificación es
de origen reconocido si calza por cualquiera de los dos modos.

**Por qué el filtro de D-N10 no alcanza**: para todo correo el `packageName` es
`com.google.android.gm`. Filtrar por paquete deja exactamente dos resultados
posibles, los dos malos: si Gmail no está en la lista no entra ningún consumo
—que es la situación de hoy—, y si está, entra **toda** notificación de correo
del teléfono sin distinguir el banco de nada. El remitente es el único dato del
evento que separa un correo del banco de uno cualquiera. Esto **enmienda D-N10**
en su mecanismo (el filtro ya no es solo por paquete) sin tocar su fundamento:
sigue habiendo una lista cerrada de orígenes, sigue siendo datos y no código, y
agregar un banco sigue sin exigir escribir interpretación nueva (FR-008a).

**Qué se verificó**: `NotificationEvent.text` expone únicamente `EXTRA_TEXT` —el
preview que Gmail trunca justo sobre el comercio, lo que el 2026-09-12 parecía
matar esta feature—, pero el lado Android del plugin reenvía además
`EXTRA_BIG_TEXT` y `EXTRA_TEXT_LINES`, que llegan a Dart en `evento.raw`. Medido
en el teléfono de referencia: `bigText` trajo **301, 1024 y 1024 caracteres**
contra **24, 79 y 84** del preview. En G4 el correo entrega el consumo entero
—comercio, monto, fecha, últimos cuatro dígitos de la tarjeta y número de
operación— dentro de los primeros **511** caracteres. Los volcados los capturó
la propia app; no están transcritos a mano.

### La raya de privacidad, que es la parte cara de esta decisión

Reconocer Gmail significa que el servicio de escucha **recibe la notificación de
todo correo que llegue al teléfono**, no solo la del banco. Android entrega
primero y filtra después; no hay forma de suscribirse a un remitente.

Eso **no** es una salida de datos y por lo tanto **no necesita enmienda a la
constitución**: nada sale del dispositivo, y el Principio I sigue intacto. Pero
sí amplía lo que la app ve, así que la regla queda escrita acá y es vinculante
para T042:

1. El filtro por remitente se aplica **primero**, antes de leer `bigText`, antes
   de interpretar y antes de escribir nada.
2. De una notificación que no calza no se guarda **nada** — ni pendiente, ni
   registro de diagnóstico (FR-018 cubre los orígenes reconocidos, no los
   ajenos), ni línea de log.
3. El registro de diagnóstico sigue siendo solo para orígenes reconocidos que no
   se pudieron interpretar. Un correo personal nunca puede terminar ahí.

Es la misma raya que ya respeta el instrumento de volcado, que anota el texto
completo únicamente de `paquetesBajoObservacion` y de todo lo demás solo el
nombre del paquete.

### Lo que queda decidido sobre el parser

Nueve cosas, ninguna anticipable sin las capturas. El detalle largo con las
posiciones exactas está en el fixture; acá va lo que obliga a hacer:

1. **El remitente viene en `title`**, no en el paquete (ver arriba).
2. **El resumen de grupo de Gmail se descarta por `evento.isGroup`**, nunca por
   la forma del texto. Gmail publica dos notificaciones por correo y G4 mostró
   que, cuando hay un solo correo sin leer, el resumen **copia el `bigText`
   entero y no trae `textLines`**. La regla que dejaron G1–G3 —`bigText == null
   && textLines != null`— es **falsa** y contaría cada consumo dos veces.
   `isGroup` es un campo tipado del plugin, no una inferencia sobre el texto.
3. **El parser tiene que acotar la zona que lee, pero `¿` no es la marca.**
   El pie fijo del BCP dice *"¿Problemas con tus **compras**? Si tu compra fue
   **rechazada**, cancelada o duplicada…"* y *"…número de tu **tarjeta de
   débito o crédito**…"*. Un clasificador que recorra el `bigText` entero ve
   señales de compra, de rechazo y de las dos clases de tarjeta a la vez y, por
   la propia regla de D-N11 —señales contradictorias, no se interpreta—,
   mandaría a diagnóstico un consumo que está inequívoco en sus primeros 200
   caracteres. **El problema es real; la solución que se escribió acá el
   2026-09-13 a la tarde no lo era.**

   > **Corregido esa misma noche por G5 y G6** (los consumos con tarjeta de
   > Sip). Se había fijado como regla "acotar hasta el primer renglón que
   > empiece con `¿`", deducida de los dos únicos correos disponibles, los dos
   > del BCP. **El correo de Sip no contiene un solo `¿`**: su pie arranca con
   > *"Si no reconoces la operación, comunícate de inmediato al…"*. Un parser
   > que dependa de ese corte lee el pie de Sip entero.
   >
   > **Por dónde va la salida**, sin fijarla todavía como regla: el campo
   > `text` —el asunto del correo— dice la operación en una línea corta y sin
   > pie que la contamine ("Realizaste un consumo con tu Tarjeta de Crédito
   > BCP", "Sip, realizaste un consumo con tu Tarjeta de Crédito Sip").
   > Clasificar la dirección por el asunto y usar el `bigText` solo para
   > extraer los datos esquiva el problema sin depender de cómo cada emisor
   > separa su pie. No alcanza para todo —el asunto de G2 es "Realizaste una
   > operación", que no dice la dirección— así que hace falta un respaldo, pero
   > como primera fuente es mucho más limpio que el cuerpo. **Que se haya
   > necesitado un segundo emisor para descubrir esto es exactamente lo que
   > D-N9 predecía**: una regla deducida de un solo banco se lee como general y
   > no lo es.
4. **El monto va en su propia línea**, separado de la etiqueta que lo nombra.
   Un parser que busque la cifra en el mismo renglón que "Monto" falla en G2, G3
   y G4. En G4 el monto aparece además dos veces: en la frase de apertura y bajo
   `Total del consumo`.
5. **El comercio también aparece dos veces**: en la frase (`… en ANTHROPIC*
   CLAUDE SUB.`) y bajo la etiqueta `Empresa`. La etiqueta es la fuente
   confiable; la frase termina en punto y habría que recortarlo.
6. **El asterisco de `ANTHROPIC* CLAUDE SUB` es parte del nombre** tal como lo
   manda el adquirente, no un separador. `normalizarComercio` no debe partir el
   nombre ahí.
7. **Hay un `Número de operación`** (`0000510200`), clave de deduplicación
   bastante mejor que monto+fecha. Afina **D-N5**, no D-N7 — ver la nota de
   numeración al final de esta sección.
8. **El BCP escribe `setiembre` y `septiembre`** indistintamente, el mismo día y
   desde el mismo remitente. El parseo de fecha tiene que aceptar las dos
   grafías.
9. **`subText` trae la cuenta de correo**, útil el día que haya más de una
   configurada.

**Tres más, que aportaron G5 y G6 (Sip, 2026-09-13 de noche)** y que ningún
correo del BCP habría mostrado:

10. **Un emisor usa más de un nombre de remitente.** Sip firma `Operaciones
    Sip` un envío de dinero y `Sip` —tres caracteres— un consumo con tarjeta.
    Un origen necesita un **conjunto** de remitentes, no uno solo: con uno solo
    se descartaban justo los consumos, que es lo único que esta spec captura.
11. **El sol se escribe `S/.` con punto.** El BCP escribe `S/ 23.60`, Sip
    escribe `S/. 37.70`. La expresión regular que D-N3 propone de ejemplo
    —`S/\s*([\d,]+\.\d{2})`— no reconoce la segunda.
12. **Las etiquetas no coinciden entre emisores.** Sip escribe `Monto:` y
    `Establecimiento:` con dos puntos; el BCP, `Monto` y `Empresa` sin ellos.
    Lo único que se mantiene es que el valor va en el renglón siguiente.

### Riesgos abiertos, anotados y no resueltos

- **El corte a los 1024 caracteres.** En G4 lo útil entra en los primeros 511,
  pero un comercio de nombre largo o un correo con renglones de más podría
  empujar el bloque `Empresa` más allá del corte. Sin verificar. Mitigación
  barata: como el comercio viene dos veces (punto 5), la frase de apertura
  —mucho más arriba— sirve de respaldo cuando falta la etiqueta.
- **El traspaso entre cuentas propias** genera dos notificaciones opuestas por
  el mismo monto que la deduplicación no relaciona. Sigue abierto; el número de
  operación no lo resuelve, porque son dos operaciones distintas de verdad.
- **Depender de Gmail** ata la captura a que el usuario reciba los avisos del
  banco por correo y tenga encendidas las notificaciones de Gmail. Es frágil, y
  es la opción que hay.

### Alternativas consideradas

- **Activar alertas push de consumo en la app del banco**: era la salida más
  limpia —dejaba D-N10 intacto— y se descartó porque en el teléfono de
  referencia BCP, Yape y Sip no ofrecen ese ajuste: solo notifican dinero
  entrante.
- **Aceptar que la feature no se sostiene** y cerrar la spec 002: era la tercera
  salida del hallazgo del 2026-09-12, y deja de estar justificada ahora que hay
  un camino verificado de punta a punta.
- **Filtrar Gmail por paquete y clasificar después por texto**: rechazada por lo
  de la raya de privacidad — el filtro tiene que poder descartar un correo
  personal sin haberlo leído, y por paquete no se puede.

**Nota de numeración**: tanto `CLAUDE.md` como el fixture atribuyen la
deduplicación a "D-N7". Es un error de arrastre: la deduplicación es **D-N5**;
D-N7 es la normalización de comercio. Corregido acá y en los dos documentos.

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

**Decisión**: usar `permission_handler` para pedir `POST_NOTIFICATIONS` en
tiempo de ejecución, en vez de escribir un canal de plataforma propio.

**Versión fijada en `^12.0.0`, y el motivo importa**: la 13.0.2 arrastra
`permission_handler_android` 14.1.0, que exige `compileSdk 37`. El proyecto
compila contra 36, que además es el máximo recomendado para el Android Gradle
Plugin 9.1.0 que usa este Flutter. Con la 13 el `flutter build apk` falla en
`checkReleaseAarMetadata` — y **la suite no lo detecta**, porque `flutter test`
no compila el lado Android. Subir a la 13 obliga a subir antes AGP y
`compileSdk`, que es un cambio de infraestructura con su propio riesgo y
ningún beneficio acá: la 12 pide el mismo permiso igual de bien.

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

---

## D-N15 — Un envío de dinero es un consumo: "sale" no quiere decir "con tarjeta" *(2026-09-13)*

**Decisión**: un yapeo enviado, una transferencia a un tercero y un pago de
servicios son **consumos** a los efectos de esta spec, igual que una compra con
tarjeta. Lo que define un consumo es que **el dinero sale de una cuenta del
usuario y le baja el saldo**, no el instrumento con que salió.

**Estado**: aclaración, **no** cambio de alcance. La spec dice desde su primera
línea "solo captura consumos (**dinero que sale**); nunca dinero recibido", y
FR-008b opone "consumo" a "movimiento entrante", no a "transferencia". La
decisión existe porque la implementación se estaba desviando de eso: las
palabras clave de D-N11 se escribieron pensando en compras con tarjeta
("consumo", "compra", "cargo", "pagaste") y no reconocen ninguna de las frases
con que las billeteras anuncian un envío.

**Qué lo destapó**: G2 del fixture —un envío por Sip de S/ 20.00, con las
frases "Realizaste una operación" y "Operación realizada: Enviar a celular"— no
calzaba con ninguna de las dos listas de D-N11 y terminaba en
`NoInterpretable(formatoNoReconocido)`, es decir en diagnóstico. Un gasto real,
perfectamente legible, que la app no registraba.

### Consecuencias

1. **Las palabras de salida de D-N11 se amplían** con las formas de envío:
   "enviar a celular", "enviaste", "yapeaste", "acabas de yapear", "te
   yapeaste", "transferencia realizada", "pago de servicios", "pagaste". Siguen
   siendo un punto de partida ajustable contra fixtures, no una lista cerrada.
2. **"Comercio" deja de significar siempre un comercio.** En un envío a una
   persona el campo se llena con el destinatario ("Enviado a: [Nombre]"). El
   modelo no cambia —sigue siendo una cadena que `normalizarComercio` limpia y
   que alimenta la categorización aprendida de US3— pero el nombre del campo
   queda más angosto que su contenido. No se renombra: renombrarlo tocaría el
   esquema, los repositorios y la UI para ganar precisión de vocabulario, y
   FR-032 funciona igual aprendiendo "Juan Pérez → familia" que "Plaza Vea →
   mercado".
3. **Aparece un falso positivo estructural: el traspaso entre cuentas propias.**
   Es el riesgo que el fixture ya tenía anotado y que esta decisión vuelve
   concreto — G2 y G3 son exactamente eso, el mismo usuario moviéndose S/ 20.00
   de una cuenta a otra a las 00:29. Con esta decisión G2 pasa a proponerse como
   gasto de S/ 20.00, y no lo es.

**Por qué se acepta ese falso positivo**: no hay forma de distinguirlo en el
texto. Las dos notificaciones son legítimas y ninguna dice "esto es tuyo": la
única señal sería reconocer que el destinatario es el propio usuario, y la app
no conoce su nombre ni sus números de cuenta (no pide registro — Principio I).
Como toda captura pasa por confirmación explícita (FR-020), el costo es una fila
de más en una bandeja que ya exige revisión humana, y el usuario la descarta de
un toque. Es el mismo trato que D-N11 ya había aceptado para una clasificación
errada, y sigue siendo preferible a la alternativa: perder todos los envíos
reales para no proponer los propios.

**Alternativas consideradas**:

- **Dejar los envíos fuera y capturar solo consumos con tarjeta**: es lo que
  hacía la implementación sin haberlo decidido nunca. Rechazada por el usuario
  el 2026-09-13 — "una salida de un Yape cuenta como gasto, ya que es un pago y
  descuenta del saldo". Además contradecía el texto de la propia spec.
- **Relacionar las dos notificaciones de un traspaso propio y anularlas**:
  exigiría emparejar por monto y ventana de tiempo, que es justamente lo que
  D-N5 rechazó como clave de deduplicación por poco confiable — y anularía por
  error dos operaciones legítimas del mismo monto en el mismo minuto. Peor
  falla, y silenciosa.
- **Pedirle al usuario su nombre o sus cuentas para detectar lo propio**: pedir
  datos personales para mejorar una heurística que ya tiene confirmación humana
  no se justifica, y la app no pide registro por diseño.

---

## D-N16 — Sin monto no hubo movimiento: el diagnóstico es para lo que falló, no para lo que no era *(2026-09-13)*

**Decisión**: si el texto de una notificación no menciona **ninguna cifra de
dinero**, en ninguna moneda, se resuelve como `NoEsConsumo` y no deja rastro.
No va al registro de diagnóstico.

**Qué lo motivó**: la primera prueba en la que la captura funcionó de punta a
punta dejó, además del pendiente esperado, una fila de diagnóstico con el aviso
recurrente de Yape ("Por tu seguridad, te notificaremos por cada yapeo que
realices"). Está transcrito como G7 en el fixture, y es el primero que no vino
de un instrumento sino de la app trabajando.

Ese correo confirma un yapeo —dice beneficiario, fecha y número de operación—
**pero no dice de cuánto**. Sin cifra, el parser no encontraba palabras de
dirección y devolvía `NoInterpretable(formatoNoReconocido)`.

**Por qué eso estaba mal, por partida doble**:

1. **Afirmaba algo falso.** El formato se entendió perfectamente; no había nada
   que reconocer. Llamar "fallo de reconocimiento" a un texto sin dinero
   adentro le dice al usuario que la app falló donde no falló.
2. **Rompía el registro que existe para otra cosa.** El diagnóstico sirve para
   encontrar consumos mal interpretados y ajustar el reconocimiento (FR-018).
   Este aviso llega **cada vez que el usuario yapea**, así que en una semana de
   uso normal el registro queda lleno de filas rutinarias. Un registro así se
   deja de mirar, y entonces los fallos de verdad no los ve nadie.

**Dónde se aplica**: es la primera pregunta del parser, antes de clasificar la
dirección. Es la más barata y la que más casos descarta.

### Por qué el monto y no otra señal

Porque es la única condición **necesaria** de un consumo. Un movimiento puede
no decir el comercio, puede no decir la fecha, puede redactar la dirección de
mil formas — pero si baja el saldo, dice cuánto. La ausencia de cifra es lo más
cerca que se puede estar de una prueba de que ahí no hubo movimiento.

La contracara es igual de importante y está probada: **con una cifra y sin
dirección clara, sí va a diagnóstico**. Si hay dinero en el texto, hubo un
movimiento, y no haber podido clasificarlo es exactamente lo que hay que
registrar.

### Por qué no un tipo nuevo de resultado

Se evaluó agregar una cuarta salida al contrato —algo como `NoEsMovimiento`—
junto a `ConsumoExtraido`, `NoEsConsumo` y `NoInterpretable`. Se rechazó:

- **El contrato ya lo cubría.** `NoEsConsumo` está documentado desde el
  principio como "se interpretó, pero no es un consumo que registrar: dinero
  entrante, un consumo rechazado o extornado, **una promoción**, etc.". Un
  aviso sin monto cae ahí sin forzar nada.
- **Nadie ramificaría por el caso nuevo.** Ni el callback ni la interfaz tratan
  distinto un entrante de una promoción: los dos no dejan rastro. Un tipo que
  nadie distingue es exactamente lo que el Principio V prohíbe.

### El riesgo que se acepta, por escrito

Si un correo de consumo llegara con el monto **más allá del corte de los 1024
caracteres** que aplica Android, esta regla lo silenciaría en vez de dejarlo en
diagnóstico. Es el riesgo abierto que ya anota D-N12, visto desde otro ángulo.

Se acepta por dos razones. La primera es que un diagnóstico sin cifra tampoco
permitiría entender qué pasó: se vería un texto truncado sin dinero, idéntico a
un aviso cualquiera. La segunda es la comparación de costos — el ruido degrada
el registro **todos los días**, y este caso es hipotético y no se ha observado
ni una vez en los siete correos capturados.

Si alguna vez aparece, la señal no será una fila de diagnóstico sino un consumo
que el usuario esperaba y no llegó, y el arreglo será el mismo que ya reclama
D-N12: leer más allá del corte, no volver a ensuciar el diagnóstico.
