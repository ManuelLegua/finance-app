# Fixtures — notificaciones de Gmail capturadas por la app

**Capturadas el 2026-09-13 por el propio callback headless**, no transcritas
desde capturas de pantalla. Es la diferencia con
[correo-gmail.md](./correo-gmail.md), que es un anexo hecho a mano: estos son
los campos exactos que recibe `NotificationEvent`, con sus longitudes reales.

Instrumento: `lib/dominio/interpretes/volcado_notificacion.dart` (temporal) +
el cuerpo de `callback_headless.dart`, leídos con
`adb logcat -d | Select-String "FINANZAS-VOLCADO"`.

---

## El hallazgo: `bigText` trae el correo completo

`correo-gmail.md` dejó planteada la pregunta que bloqueaba toda la decisión —
si el evento trae el cuerpo entero o solo el preview truncado— y la marcó como
"el primer paso de cualquier decisión". **Respuesta: trae el cuerpo entero.**

| Correo | `text` (preview) | `bigText` |
|---|---|---|
| Operaciones Sip | 24 caracteres | **301** |
| BCP Notificaciones | 79 caracteres | **1024** |

El truncamiento que parecía matar la spec 002 era un artefacto de leer solo
`NotificationEvent.text`, que expone únicamente `EXTRA_TEXT`. El lado Android
del plugin reenvía además `EXTRA_BIG_TEXT` y `EXTRA_TEXT_LINES`, que llegan a
Dart en `evento.raw['bigText']` y `raw['textLines']`.

---

## G1 — Gmail agrupado: **no** es un correo, es el resumen

Gmail publica **dos** notificaciones por cada correo que llega: esta agrupada,
y una individual por correo (G2, G3). Si el parser las tomara a las dos,
contaría cada consumo dos veces.

```
paquete:     com.google.android.gm
title:       "3 mensajes nuevos"            (17 caracteres)
text:        (ausente)
bigText:     (ausente)
textLines:   3 líneas
  [0] BCP Notificaciones  Constancia de recepción de Yapeo a celular BCP - Servicio de Notificaciones BCP
  [1] Operaciones Sip   Realizaste una operación
  [2] YAPE Notificaciones  Por tu seguridad, te notificaremos por cada yapeo que realices
subText:     "manublieydark@gmail.com"      (23 caracteres)
summaryText: (ausente)
infoText:    (ausente)
```

**Cómo se reconoce**: `bigText` ausente + `textLines` presente. El `title` de
la agrupada es un contador ("2 mensajes nuevos", "3 mensajes nuevos"), no un
remitente.

> **Esta regla no alcanza.** Vale para el resumen que agrupa varios correos,
> como este, pero no para el que resume uno solo: ese copia el `bigText` del
> correo y no trae `textLines`. Ver G4 — la regla que sí distingue los dos
> casos es `evento.isGroup`.

---

## G2 — Yape/Sip, operación **saliente** (yapeo enviado)

```
paquete:     com.google.android.gm
title:       "Operaciones Sip"              (15 caracteres)
text:        "Realizaste una operación"     (24 caracteres)
bigText:     301 caracteres (el bloque de abajo transcribe 254 — ver la auditoría al final)
textLines:   (ausente)
subText:     "manublieydark@gmail.com"
```

Cuerpo completo de `bigText`:

```
Realizaste una operación

Hola Manuel Alexander
Por tu seguridad, te enviamos
los datos de tu operación.
Operación realizada: Enviar a celular
Monto
S/ 20.00
Enviado a
Manuel Alexander Legua Mendoza
*** ***992
Destino
Yape
Fecha y Hora
13/09/2026 - 00:29
```

**Qué aporta**: monto (`S/ 20.00`), tipo de operación (`Enviar a celular`),
contraparte y fecha (`13/09/2026 - 00:29`), todo en etiquetas fijas y en
renglones propios. El monto va en una línea sola, separado de su etiqueta.

---

## G3 — BCP, operación **entrante** (yapeo recibido)

```
paquete:     com.google.android.gm
title:       "BCP Notificaciones"           (18 caracteres)
text:        "Constancia de recepción de Yapeo a celular BCP - Servicio de Notificaciones BCP"  (79 caracteres)
bigText:     1024 caracteres (el bloque de abajo transcribe 706 — ver la auditoría al final)
textLines:   (ausente)
subText:     "manublieydark@gmail.com"
```

Cuerpo completo de `bigText`, **cortado por Android a los 1024 caracteres**:

```
Constancia de recepción de Yapeo a celular BCP - Servicio de Notificaciones BCP

Hola Manuel Alexander,
Recibiste un yapeo de S/ 20.00 de Manuel Alexander Legua Mendoza.
Monto
Monto recibido
S/ 20.00
Datos de la operación
Operación realizada
Yapeo a celular
Fecha y hora
13 de septiembre de 2026 - 12:29 AM
Enviado por
Manuel Alexander Legua Mendoza
¿No reconoces esta operación?
Comunícate inmediatamente con nosotros al
(01)​ 311​-9898 anexo *911 para ayudarte a verificarla.
¡Seguimos transformando tus planes en realidad!
Juntos somos más seguros
El BCP nunca te solicitará datos confidenciales por correo, tales como tu clave secreta de cajero de 4 dígitos, clave de internet de 6 dígitos, número de t
```

Fijarse dónde corta: a mitad de la palabra `t[arjeta]`. El corte es duro, a los
1024 caracteres exactos.

---

## G4 — BCP, **consumo con tarjeta de crédito** — capturado el 2026-09-13 10:54

El que faltaba: el primer movimiento que la spec 002 sí registraría. Llega,
como los otros tres, por correo y a través de Gmail — la app del BCP no mandó
ningún push por este consumo, tal como decía el hallazgo del 2026-09-12.

```
paquete:     com.google.android.gm
title:       "BCP Notificaciones"           (18 caracteres)
text:        "Realizaste un consumo con tu Tarjeta de Crédito BCP - Servicio de Notificaciones BCP"  (84 caracteres)
bigText:     1024 caracteres
textLines:   (ausente)
subText:     "manublieydark@gmail.com"
isGroup:     false
flags:       17
key:         0|com.google.android.gm|-2017694605|gig:140398783:PRIORITY_INBOX_ALL_MAIL|10145
```

Cuerpo completo de `bigText`, **cortado por Android a los 1024 caracteres**:

```
Realizaste un consumo con tu Tarjeta de Crédito BCP - Servicio de Notificaciones BCP
 
Hola Manuel Alexander,
Realizaste un consumo de $ 23.60 con tu Tarjeta de Crédito BCP en ANTHROPIC* CLAUDE SUB.
Por tu seguridad, te enviamos los datos de tu operación.
Monto
Total del consumo
$ 23.60
Datos de la operación
Operación realizada
Consumo Tarjeta de Crédito
Fecha y hora
13 de setiembre de 2026 - 10:54 AM
Número de Tarjeta de Crédito
************6140
Empresa
ANTHROPIC* CLAUDE SUB
Número de operación
0000510200
¿Problemas con tus compras?
Si tu compra fue rechazada, cancelada o duplicada, el tiempo estimado de devolución será de 3 a 7 días.
¿No reconoces esta operación?
Comunícate inmediatamente con nosotros al
(01)​ 311​-9898 anexo *911 para ayudarte a verificarla.
¡Seguimos mejorando para ti!
Juntos somos más seguros
El BCP nunca te solicitará datos confidenciales por correo, tales como tu clave secreta de cajero de 4 dígitos, clave de internet de 6 dígitos, número de tu tarjeta de débito o crédito, fecha de ven
```

### Dónde cae cada dato dentro de los 1024 caracteres

La duda 4 de los tres primeros —si el comercio sobrevive al corte— **queda
respondida para este formato**: todo lo útil termina en el carácter 511, menos
de la mitad del presupuesto.

| Dato | Valor | Posición en `bigText` |
|---|---|---|
| Monto (en la frase) | `$ 23.60` | 135 |
| Comercio (en la frase) | `ANTHROPIC* CLAUDE SUB` | 176 |
| Fecha | `13 de setiembre de 2026 - 10:54 AM` | 365 |
| Tarjeta | `************6140` | 434 |
| Etiqueta `Empresa` → comercio | `ANTHROPIC* CLAUDE SUB` | 451 → 459 |
| Etiqueta `Número de operación` → valor | `0000510200` | 481 → 501 |
| El corte | a mitad de `fecha de ven[cimiento]` | 1024 |

Sigue **sin verificar** si un consumo con un comercio de nombre largo, o un
correo que agregue renglones arriba, empuja el bloque `Empresa` más allá del
corte.

### Gmail publicó **dos** notificaciones con el mismo `bigText`

A las 10:54:10.180 y 10:54:10.187, con 7 milisegundos de diferencia, el mismo
correo llegó dos veces:

| | Resumen del grupo | El correo |
|---|---|---|
| `id` | `0` | `-2017694605` |
| `isGroup` | **`true`** | `false` |
| `flags` | `528` (`FLAG_GROUP_SUMMARY` 512 + `FLAG_AUTO_CANCEL` 16) | `17` |
| `bigText` | los mismos 1024 caracteres | los mismos 1024 caracteres |
| `textLines` | **ausente** | ausente |

**Esto invalida la regla de descarte que dejaron G1–G3** (`bigText == null &&
textLines != null`). Esa regla se dedujo de un resumen que agrupaba tres
correos; cuando hay **un solo correo sin leer**, el resumen del grupo no
resume nada: copia el correo entero, `bigText` incluido y sin `textLines`. Un
parser que use esa regla contaría este consumo **dos veces**, que es
exactamente lo que se quería evitar.

La regla correcta es descartar cuando `evento.isGroup == true`. Es un campo
tipado del plugin (`NotificationEvent.isGroup`, que sale de `map["isGroup"]`),
no una inferencia sobre el texto, y distingue bien los dos casos. El `key`
completo sirve de desempate si alguna vez hiciera falta: el del resumen lleva
`|0|` donde el del correo lleva su `id`.

---

## Lo que dejan decidido los cuatro

1. **El remitente viene en `title`**, no en el paquete. Para Gmail el
   `packageName` siempre es `com.google.android.gm`, así que el filtro por
   paquete de D-N10 no alcanza: hay que filtrar por `title` (`BCP
   Notificaciones`, `Operaciones Sip`, `YAPE Notificaciones`).
2. **El resumen del grupo se descarta por `isGroup`**, no por la forma del
   texto (ver G4). Con un solo correo sin leer, el resumen trae el mismo
   `bigText` que el correo y ninguna regla basada en `textLines` los separa.
3. **El monto está en su propia línea**, separado de la etiqueta que lo
   nombra. Un parser que busque la cifra en la misma línea que "Monto" falla
   en G2, G3 y G4. En G4 el monto además aparece **dos veces**: en la frase de
   apertura y bajo `Total del consumo`.
4. **El comercio también aparece dos veces**: en la frase (`... en ANTHROPIC*
   CLAUDE SUB.`) y bajo la etiqueta `Empresa`. La etiqueta es la fuente
   confiable — la frase termina en punto, que habría que recortar. El
   asterisco de `ANTHROPIC* CLAUDE SUB` es parte del nombre tal como lo manda
   el adquirente, no un separador, y el normalizador de comercio (T040) tiene
   que dejarlo pasar sin partir el nombre ahí.
5. **`bigText` se corta a los 1024 caracteres.** En G4 lo útil entra en los
   primeros 511, pero el margen no está garantizado para todo consumo.
6. **`subText` trae la cuenta de correo**, útil si algún día hubiera más de
   una configurada. G4 llegó a `manublieydark@gmail.com`.
7. **El BCP escribe el mes de las dos maneras**: `13 de setiembre de 2026` en
   G4 y `13 de septiembre de 2026` en G3, el mismo día y desde el mismo
   remitente. El parseo de fecha tiene que aceptar las dos grafías.
8. **Hay un identificador de operación** (`Número de operación: 0000510200`),
   candidato bastante mejor que monto+fecha para la deduplicación de D-N5. No
   resuelve el caso del traspaso entre cuentas propias que D-N5 tampoco
   relaciona, pero sí el doble registro del mismo movimiento.
9. **El pie del correo envenena las palabras clave de D-N11.** Después del
   dato útil, el BCP agrega boilerplate fijo que contiene *“¿Problemas con tus
   compras? Si tu **compra** fue **rechazada**, cancelada o duplicada…”* y
   *“…número de tu **tarjeta de débito o crédito**…”*. Un clasificador que
   recorra el `bigText` entero ve ahí señales de compra, de rechazo y de las
   dos clases de tarjeta a la vez, y por la propia regla de D-N11 —señales
   contradictorias, no se interpreta— mandaría a diagnóstico un consumo que
   está perfectamente claro en sus primeros 200 caracteres. El parser tiene
   que **acotar la zona que lee**: hasta el primer renglón que empiece con
   `¿`, que en los dos correos del BCP marca dónde termina la operación y
   empieza el pie.

---

## La moneda: lo que este consumo obliga a decidir

**El consumo vino en dólares** (`$ 23.60`), no en soles. No es una rareza
—cualquier suscripción internacional cobrada a una tarjeta peruana llega
así— y toca de frente dos cosas ya escritas:

- **FR-014 lo previó**: moneda extranjera produce
  `NoInterpretable(monedaExtranjera)`, y T038 tiene que probarlo. Este fixture
  es el primer texto real para esa prueba, y confirma que la señal está en el
  símbolo (`$` contra `S/`) y en ningún otro lado: el resto del correo es
  idéntico al que tendría un consumo en soles.
- **La regla 5 del proyecto (sin multimoneda)** es lo que hace que `$ 23.60`
  no se pueda registrar: convertir a soles exigiría un tipo de cambio, y D14
  de la spec 001 ya rechazó traer tasas de ninguna parte. Lo correcto es que
  la app no lo registre y lo diga, sin inventar el dato (FR-017).

Queda entonces **un renglón abierto de T034**: falta un consumo con tarjeta
**en soles**, que es el camino feliz que T038 necesita. Este cierra el caso de
moneda extranjera, no el otro.

---

---

## G5 — Sip, **consumo con tarjeta de crédito EN SOLES** — capturado el 2026-09-13 21:10

**El que faltaba para cerrar T034.** Un consumo con tarjeta de crédito, en
soles, con comercio y monto legibles. Llega por correo vía Gmail como los
cuatro anteriores — la app de Sip tampoco mandó push por este consumo.

```
paquete:     com.google.android.gm
title:       "Sip"                            (3 caracteres)
text:        "Sip, realizaste un consumo con tu Tarjeta de Crédito Sip"  (56 caracteres)
bigText:     667 caracteres (medido: 667 — **coincide**, no está truncado)
textLines:   (ausente)
subText:     "manublieydark@gmail.com"
```

Cuerpo completo de `bigText`:

```
Sip, realizaste un consumo con tu Tarjeta de Crédito Sip
Hola, MANUEL.
Has realizado una transacción 
con tu Tarjeta de Crédito Sip.
Tarjeta Titular:
XXXXXXXXXXXX2145
Establecimiento:
IKF 982 PV VENTANILLA
Monto:
S/. 37.70
Fecha de operación:
13/09/2026 a las 21:09
Si no reconoces la operación, comunícate de inmediato al (01) 619-3100.
Para tu seguridad: 
Sip jamás solicitará el número, fecha de 
vencimiento, CVV o claves de tu tarjeta, ni 
pedirá que la entregues mediante visitas.
Este correo electrónico fue enviado por: InFinance XP S.A.
Avenida Aviación 2405 Piso 9, Lima, Lima, San Borja Peru 
Privacy Policy 
Update Profile Manage Subscriptions Unsubscribe
```

---

## G6 — Sip, **consumo con tarjeta de crédito EN SOLES** — capturado el 2026-09-13 21:14

Cuatro minutos después del anterior, en el mismo comercio de la misma zona.
Sirve de segundo ejemplo del mismo formato y, sobre todo, **de par para probar
la deduplicación**: dos consumos distintos, de montos distintos, con la misma
tarjeta y a minutos de distancia.

```
paquete:     com.google.android.gm
title:       "Sip"                            (3 caracteres)
text:        "Sip, realizaste un consumo con tu Tarjeta de Crédito Sip"  (56 caracteres)
bigText:     665 caracteres (medido: 665 — **coincide**, no está truncado)
textLines:   (ausente)
subText:     "manublieydark@gmail.com"
```

Cuerpo completo de `bigText`:

```
Sip, realizaste un consumo con tu Tarjeta de Crédito Sip
Hola, MANUEL.
Has realizado una transacción 
con tu Tarjeta de Crédito Sip.
Tarjeta Titular:
XXXXXXXXXXXX2145
Establecimiento:
231 PVEA VENTANILLA
Monto:
S/. 15.90
Fecha de operación:
13/09/2026 a las 21:14
Si no reconoces la operación, comunícate de inmediato al (01) 619-3100.
Para tu seguridad: 
Sip jamás solicitará el número, fecha de 
vencimiento, CVV o claves de tu tarjeta, ni 
pedirá que la entregues mediante visitas.
Este correo electrónico fue enviado por: InFinance XP S.A.
Avenida Aviación 2405 Piso 9, Lima, Lima, San Borja Peru 
Privacy Policy 
Update Profile Manage Subscriptions Unsubscribe
```

---

## Lo que G5 y G6 cambian *(2026-09-13, noche)*

Son el primer consumo con tarjeta en soles, así que cierran T034 — pero además
contradicen cuatro cosas que se habían dado por decididas con los cuatro
primeros. Ninguna se podía anticipar sin un correo de un emisor distinto al BCP.

1. **El remitente de Sip no es `Operaciones Sip`: es `Sip`, tres caracteres.**
   Un mismo emisor usa **más de un nombre de remitente** según el tipo de
   correo — `Operaciones Sip` para un envío de dinero (G2), `Sip` para un
   consumo con tarjeta. Un origen no puede tener un único remitente: necesita
   un conjunto. Tal como quedó sembrada la lista tras T041a, **estos dos
   consumos se descartaban por origen no reconocido**.

2. **El símbolo del sol se escribe `S/.` con punto.** El BCP escribe `S/ 23.60`
   y Sip escribe `S/. 37.70`. Una expresión regular del tipo `S/\s*([\d,]+\.\d{2})`
   —la que propone D-N3 como ejemplo— **no reconoce el monto de Sip**. El punto
   después de la barra es opcional y hay que contemplarlo.

3. **La regla de acotar el pie en el primer renglón que empieza con `¿` no
   generaliza.** Es una particularidad del BCP. El pie de Sip arranca con *"Si
   no reconoces la operación, comunícate de inmediato al…"*, sin signo de
   apertura en ningún lado: el `bigText` de G5 no contiene un solo `¿`. Un
   parser que dependa de ese corte lee el pie de Sip entero.

4. **Las etiquetas no coinciden entre emisores.** Sip escribe `Monto:` y
   `Establecimiento:` con dos puntos; el BCP escribe `Monto` y `Empresa` sin
   ellos. El valor sigue yendo en el renglón siguiente en los dos casos, que es
   lo único que sí se mantiene.

**Una salida que estas capturas hacen visible**: el campo `text` —el asunto del
correo— dice la operación en una línea corta y **sin pie que lo contamine**:
"Realizaste un consumo con tu Tarjeta de Crédito BCP", "Sip, realizaste un
consumo con tu Tarjeta de Crédito Sip". Clasificar la dirección por el asunto y
usar el `bigText` solo para extraer los datos evitaría el problema del punto 3
sin depender de cómo cada banco separa su pie. No alcanza para todo —el asunto
de G2 es "Realizaste una operación", que no dice la dirección— pero como primera
fuente es mucho más limpio que el cuerpo.

**Un detalle para `normalizarComercio`**: los establecimientos vienen con código
de tienda pegado al nombre — `IKF 982 PV VENTANILLA` y `231 PVEA VENTANILLA`.
El segundo es una tienda de Plaza Vea. Dos compras en el mismo comercio con
códigos distintos tienen que normalizar igual, o FR-032 aprende una categoría
por sucursal.

**Procedencia**: leídos con `adb logcat` desde el teléfono conectado por Wi-Fi,
no transcritos. Los dos cuerpos miden exactamente lo que el volcado declaró
(667 y 665), así que no les falta nada — a diferencia de G2 y G3, ver la
auditoría de largos más arriba. El build instalado sigue siendo anterior a
`5fa0148`, así que cada línea aparece dos veces en el log; y como es un build
de **release**, `run-as` no pudo leer el archivo local y el log fue la única
vía.

---

## Auditoría de los largos declarados *(2026-09-13)*

Al extraer estos cuerpos a `textos_capturados.dart` se midieron los bloques y
**dos de los tres no coinciden con el largo que declara su ficha**:

| | Declarado | Transcrito | Diferencia |
|---|---|---|---|
| G2 | 301 | 254 | −47 |
| G3 | 1024 | 706 | **−318** |
| G4 | 1024 | 1024 | — |

**El número declarado es el correcto y el que falla es la transcripción**, al
menos en G3, y se puede demostrar sin volver a capturar nada. G3 y G4 son los
dos correos del BCP y comparten el mismo pie fijo, que empieza con *"El BCP
nunca te solicitará datos confidenciales…"*:

- En **G4** el pie arranca en el carácter 826 y el bloque termina en 1024: son
  198 caracteres de pie.
- En **G3** el pie arranca mucho antes, en el 551 —el bloque de datos de un
  yapeo recibido es más corto que el de un consumo con tarjeta—, así que si
  Android hubiera cortado también en 1024 tendría que haber **473** caracteres
  de pie. Tiene 155.

Un corte en 1024 no puede producir *menos* pie en el correo que llega antes al
pie. La explicación que queda es que al bloque de G3 le faltan unos 318
caracteres del final del pie, perdidos al reconstruirlo a mano del log —
recordar que G2 y G3 se capturaron con el build anterior a `5fa0148`, que
duplicaba cada línea y obligaba a rearmarlas.

**Por qué no importa para el parser, y por qué se anota igual.** Lo que falta es
boilerplate legal, después del renglón que empieza con `¿` donde el parser
tiene que dejar de leer (punto 3 de D-N12): ningún dato útil está ahí. Pero un
fixture que declara un largo que su propio bloque no tiene es una trampa para
quien venga a probar el corte de los 1024 caracteres contra estos textos — ese
riesgo solo se puede probar contra **G4**, que es el único íntegro.

De G2 no se puede decidir cuál de los dos números es el bueno: termina en una
fecha, sin corte a la vista, así que los 47 caracteres que faltan podrían ser
una línea de cierre perdida o un largo mal anotado. Queda como está, anotado.

## Procedencia y condiciones de la captura

- Instrumento: `lib/dominio/interpretes/volcado_notificacion.dart` más el
  cuerpo de `callback_headless.dart`, leído con
  `adb logcat -d | Select-String "FINANZAS-VOLCADO"`.
- El build instalado en el teléfono al capturar era **anterior a `5fa0148`**,
  que quitó del volcado el hack de la excepción sin capturar. Por eso cada
  línea aparece dos veces en el log: una como `I/flutter` y otra dentro de un
  `Unhandled Exception: Bad state:`. **No afecta al contenido** —la excepción
  se lanza después del `print`, y el bloque reconstruido mide exactamente los
  1024 caracteres que el propio volcado reportó—, pero explica el ruido y
  conviene reinstalar antes de la próxima captura.
- Insumo colateral para **T041**: el push de Yape del 00:29 (dinero recibido,
  `Confirmación de Pago`) confirma el paquete real
  `com.bcp.innovacxion.yapeapp`. Es el único origen de `origenesReconocidos`
  que publicó algo por su cuenta en todo el período observado.
