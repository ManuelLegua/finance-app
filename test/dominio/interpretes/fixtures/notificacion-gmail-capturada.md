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

---

## G2 — Yape/Sip, operación **saliente** (yapeo enviado)

```
paquete:     com.google.android.gm
title:       "Operaciones Sip"              (15 caracteres)
text:        "Realizaste una operación"     (24 caracteres)
bigText:     301 caracteres
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
bigText:     1024 caracteres
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

## Lo que estos tres dejan decidido

1. **El remitente viene en `title`**, no en el paquete. Para Gmail el
   `packageName` siempre es `com.google.android.gm`, así que el filtro por
   paquete de D-N10 no alcanza: hay que filtrar por `title` (`BCP
   Notificaciones`, `Operaciones Sip`, `YAPE Notificaciones`).
2. **Hay que descartar la notificación agrupada** (G1) o cada consumo se
   contaría dos veces. La regla es `bigText == null && textLines != null`.
3. **El monto está en su propia línea**, separado de la etiqueta que lo
   nombra. Un parser que busque `S/` en la misma línea que "Monto" falla en
   G2 y en G3.
4. **`bigText` se corta a los 1024 caracteres.** En estos dos el dato útil
   entra en los primeros ~200, pero un correo de consumo que ponga el comercio
   más abajo lo perdería. **Sin verificar** hasta tener un consumo real.
5. **`subText` trae la cuenta de correo**, útil si algún día hubiera más de una
   configurada.

## Lo que todavía falta

Los tres capturados son **movimientos de dinero entre cuentas**, no consumos
con tarjeta — que es lo único que la spec 002 registra (FR-012, FR-013 mandan
ignorar todo lo entrante). Falta capturar un **consumo real** para confirmar
que el comercio aparece, en qué renglón, y si cae antes del corte de 1024
caracteres.

Hasta entonces T034 sigue sin cerrarse: lo que hay prueba que el mecanismo
funciona y cómo viene armado, no que el dato que la spec necesita esté ahí.
