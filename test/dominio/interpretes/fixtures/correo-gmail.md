# Fixtures — notificaciones de Gmail (correo del banco)

**Estas NO son notificaciones de apps bancarias.** Son las notificaciones que
manda **Gmail** (`com.google.android.gm`) cuando llega el correo del banco: el
encabezado de cada una es `Gmail • <cuenta>`, y traen las acciones ARCHIVAR /
MARCAR COMO LEÍDO / RESPONDER.

Capturadas por el usuario el 2026-09-10 y 2026-09-11 en su teléfono (Android,
operador Claro), y transcritas acá desde las capturas de pantalla.

**Por qué se guardan igual, si T034 pide explícitamente lo contrario**: en este
teléfono las apps de BCP, Yape y Sip **solo notifican por push el dinero
entrante** (transferencias recibidas, yapeos recibidos). Los consumos —lo único
que la spec 002 captura (FR-012, FR-013)— llegan únicamente por correo. Es
decir: el insumo que T034 pide **no existe en este dispositivo**, y eso es un
hallazgo de diseño, no una captura fallida. Ver la decisión pendiente al pie.

**Advertencia de uso**: el cuerpo que se ve en la barra es el *preview* que arma
Gmail, y está **truncado** (`...`) justo donde suele estar el comercio.

**Verificado el 2026-09-13 — y la respuesta cambia la decisión**: el
`NotificationEvent` **sí trae el cuerpo completo**, en `raw['bigText']` (301 y
1024 caracteres, contra 24 y 79 del preview). El truncamiento era un artefacto
de leer solo `NotificationEvent.text`. Los volcados reales, capturados por la
propia app en vez de transcritos a mano, están en
[notificacion-gmail-capturada.md](./notificacion-gmail-capturada.md), junto con
las cuatro cosas que dejan decididas sobre cómo tendría que ser el parser.

---

## Salientes (serían consumos)

### C1 — BCP, tarjeta de débito, con comercio

- **Capturado**: 2026-09-10, 12:58
- **Remitente**: `BCP Notificaciones`
- **Asunto**: `Realizaste un consumo con tu Tarjeta de Débito BCP - Servicio de Notificaciones BCP`
- **Cuerpo (truncado)**:
  ```
  Hola Manuel Alexander,
  Realizaste un consumo de S/ 9.50 con tu Tarjeta de Débito BCP en ESVISALUD SAC....
  ```
- **Esperado**: saliente, monto `S/ 9.50`, comercio `ESVISALUD SAC`.
- **Nota**: confirma casi literal el patrón de referencia de research.md D-N11.
  La palabra clave `consumo` aparece en asunto y cuerpo.

### C2 — BCP, tarjeta de crédito, con comercio

- **Capturado**: 2026-09-11, 3:20
- **Remitente**: `BCP Notificaciones`
- **Asunto**: `Realizaste un consumo con tu Tarjeta de Crédito BCP - Servicio de Notificaciones BCP`
- **Cuerpo (truncado)**:
  ```
  Hola Manuel Alexander,
  Realizaste un consumo de S/ 41.50 con tu Tarjeta de Crédito BCP en ESVISALUD S.A.C.....
  ```
- **Esperado**: saliente, monto `S/ 41.50`, comercio `ESVISALUD S.A.C.`
- **Nota**: mismo comercio que C1 escrito distinto (`ESVISALUD SAC` vs
  `ESVISALUD S.A.C.`). Es exactamente el caso que `normalizarComercio` tiene que
  unificar (D-N8), y vale como prueba de esa función independientemente del
  parser. Ojo con los puntos suspensivos del truncado pegados al punto final de
  `S.A.C.`: son cinco puntos seguidos, no una abreviatura.

### C3 — Yape saliente, monto en líneas separadas

- **Capturado**: 2026-09-10, 12:58
- **Remitente**: `YAPE Notificaciones`
- **Asunto**: `Por tu seguridad, te notificaremos por cada yapeo que realices`
- **Cuerpo (truncado)**:
  ```
  ¡Hola, Manuel Leg*!
  ¡Acabas de yapear exitosamente!
  Monto de yapeo*
  S/
  171.70
  Yapero...
  ```
- **Esperado**: saliente, monto `S/ 171.70`.
- **HALLAZGO IMPORTANTE**: el símbolo `S/` y la cifra están en **líneas
  distintas**. Un parser que busque `S/` pegado al número —o el propio
  `Dinero.deTextoDecimal`— falla acá. Queda por confirmar si es un salto de
  línea real del correo o el ajuste de línea de la barra de notificaciones, pero
  el ancho disponible sugiere que es real.
- **Nota**: confirma `acabas de yapear` como palabra clave saliente (D-N11 la
  listaba como suposición). `yapeo` a secas es **ambiguo**: aparece igual en el
  asunto de este saliente y en el entrante E1.

### C4 — Yape saliente, segundo ejemplo

- **Capturado**: 2026-09-10, 11:06
- **Remitente**: `YAPE Notificaciones`
- **Asunto**: `Por tu seguridad, te notificaremos por cada yapeo que realices`
- **Cuerpo (truncado)**:
  ```
  Monto de yapeo*
  S/
  12.80
  Yapero
  Manuel Leg*
  Tu número de celular...
  ```
- **Esperado**: saliente, monto `S/ 12.80`.
- **Nota**: acá el preview **no incluye** `¡Acabas de yapear exitosamente!` —
  arranca directo en el monto. Mismo tipo de correo, preview distinto según lo
  que Gmail decida mostrar. Confirma que **el preview no es estable**: la misma
  plantilla puede llegar con o sin la palabra clave que define la dirección.

### C5 — Sip, tarjeta de crédito, comercio truncado

- **Capturado**: 2026-09-10, 1:55
- **Remitente**: `Sip`
- **Asunto**: `Sip, realizaste un consumo con tu Tarjeta de Crédito Sip`
- **Cuerpo (truncado)**:
  ```
  Hola, MANUEL.
  Has realizado una transacción con tu Tarjeta de Crédito Sip.
  Tarjeta Titular: XXXXXXXXXXXX2145
  Establecimiento:...
  ```
- **Esperado**: saliente, pero **sin monto ni comercio en el preview** — el
  truncado corta justo en `Establecimiento:`. Con solo este texto, lo correcto
  es `NoInterpretable(formatoNoReconocido)`, nunca inventar un dato (FR-017).
- **Nota**: `transacción` no está en ninguna lista de D-N11; `consumo` sí, pero
  solo en el asunto.

### C6 — BCP, pago de servicios, sin monto

- **Capturado**: 2026-09-11, 2:53
- **Remitente**: `BCP Notificaciones`
- **Asunto**: `ENVIO AUTOMATICO - CONSTANCIA DE PAGO DE SERVICIO - BANCA MOVIL BCP`
- **Cuerpo (truncado)**:
  ```
  Hola MANUEL ALEXANDER,
  ¡Tu operación se realizó con éxito!
  Operación realizada: Pago de servicios
  Número de operación:...
  ```
- **Esperado**: saliente por sentido, pero **sin monto visible** →
  `NoInterpretable`. `pago de servicios` no está en D-N11.

---

## Entrantes (no deben generar pendiente — FR-013)

### E1 — BCP, yapeo recibido

- **Capturado**: 2026-09-10, 1:28
- **Remitente**: `BCP Notificaciones`
- **Asunto**: `Constancia de recepción de Yapeo a celular BCP - Servicio de Notificaciones BCP`
- **Cuerpo (truncado)**:
  ```
  Hola Manuel Alexander,
  Recibiste un yapeo de S/ 72.11 de Manuel Alexander Legua Mendoza.
  Por tu seguridad te enviamos los datos...
  ```
- **Esperado**: `NoEsConsumo`. Confirma `recibiste` como palabra clave entrante.

---

## Caso que la spec no contempla: el traspaso entre cuentas propias

E1 (entrante, `S/ 72.11`, 1:28) y esta saliente llegaron **con dos minutos de
diferencia y por el mismo monto**:

- **Remitente**: `Operaciones Sip`
- **Asunto**: `Realizaste una operación`
- **Cuerpo (truncado)**:
  ```
  Hola Manuel Alexander
  Por tu seguridad, te enviamos los datos de tu operación.
  Operación realizada: Enviar a celular
  Monto
  S/ 72.11...
  ```

Es **el mismo movimiento visto desde los dos extremos**: dinero que salió de la
cuenta Sip y entró a la cuenta BCP, ambas del usuario. Ni gasto ni ingreso — un
traspaso propio.

La deduplicación actual (D-N7) no lo agarra: son dos orígenes distintos y
direcciones opuestas, así que las trata como dos eventos sin relación. El
saliente generaría un `ConsumoPendiente` de S/ 72.11 que **no es un gasto**.
`Enviar a celular` tampoco está en las listas de D-N11, así que hoy caería en
diagnóstico por suerte, no por diseño.

Queda anotado como caso a resolver si esta vía sigue adelante; no hay requisito
que lo cubra.

---

## Palabras clave: qué confirma y qué falta en D-N11

| Frase real observada | Dirección | ¿Está en D-N11? |
|---|---|---|
| `realizaste un consumo` | saliente | sí (`consumo`) |
| `acabas de yapear` | saliente | sí — estaba como suposición, queda confirmada |
| `recibiste un yapeo` | entrante | sí (`recibiste`) |
| `has realizado una transacción` | saliente | **falta** |
| `operación realizada: pago de servicios` | saliente | **falta** |
| `operación realizada: enviar a celular` | saliente (traspaso) | **falta** |
| `yapeo` a secas, en el asunto | **ambigua** | aparece en saliente y en entrante |

---

## Decisión pendiente antes de usar nada de esto

Estos textos **no cumplen T034** y no habilitan T041: el `packageName` de todos
es el de Gmail, no el de cada banco, así que el filtro por paquete de D-N10 no
discrimina nada acá. Usarlos exige antes revisar D-N10 y D-N11 en research.md
—reconocer Gmail como origen y filtrar por remitente— con todo lo que eso
implica para el alcance de lectura de la app. Es un cambio de alcance, y va
primero a la spec, no al código.
