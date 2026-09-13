# Feature Specification: Montos en moneda extranjera

**Feature Branch**: `006-moneda-extranjera`

**Created**: 2026-09-13

**Status**: Draft — bloqueada por una enmienda a la constitución que todavía no está aprobada (ver **Requiere**)

**Input**: User description: "Aceptar montos en moneda extranjera (empezando por el dólar) sin abandonar el sol como moneda de cuenta, con un diseño que permita agregar otras monedas después sin tocar la aritmética financiera"

**Depende de**: [001-gestion-sueldo-ahorro](../001-gestion-sueldo-ahorro/spec.md) —
de la que toma el presupuesto, los gastos reales y la noción de mes— y
[002-captura-notificaciones-bancarias](../002-captura-notificaciones-bancarias/spec.md),
cuyo FR-014 esta especificación **reemplaza**: lo que hoy se descarta por venir
en otra moneda, pasa a registrarse.

**Requiere**: una enmienda al **Principio II** de la constitución, que hoy dice
literalmente *"La moneda es siempre el sol peruano (S/)"*, y al **Principio V**,
que prohíbe construir multimoneda *"mientras no exista un requisito
especificado que lo pida"* — este documento es ese requisito. Redefinir un
principio no negociable es un cambio MAJOR según la governance: **v4.0.0**.
**La enmienda no está aprobada todavía**; sin ella esta especificación no pasa
a plan.

**Qué la disparó**: el 2026-09-13 la captura de notificaciones registró un
consumo real con tarjeta de crédito por **$ 23.60** (una suscripción
internacional). Con las reglas vigentes ese consumo no se puede registrar de
ninguna forma: ni a mano ni desde la bandeja de pendientes. El dato existe, el
usuario lo va a pagar, y la app no tiene dónde ponerlo.

## Aclaración de alcance: qué NO es esta funcionalidad

Vale la pena decirlo antes que nada, porque "multimoneda" nombra tres cosas
distintas y solo una está acá:

- **No** son cuentas ni saldos por moneda. No existe "mi saldo en dólares".
- **No** son totales por moneda. Sigue habiendo **un solo** disponible del mes,
  un solo comprometido, un solo déficit.
- **Sí** es poder registrar un movimiento cuyo importe está expresado en otra
  moneda, convertirlo una vez con un tipo de cambio que el usuario informa, y
  no perder de vista el importe original.

La razón es que así funciona el instrumento real: la tarjeta es una tarjeta en
soles, el banco convierte a su tipo de cambio y factura soles. El importe en
dólares es **cómo se originó el gasto**, no cómo se paga.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar un gasto en moneda extranjera (Priority: P1)

El usuario anota un gasto que le cobraron en dólares. Elige la moneda, escribe
el importe tal como se lo cobraron y el tipo de cambio que le aplicaron, y la
app guarda el gasto. En el resumen del mes ese gasto pesa como cualquier otro,
en soles; en su ficha sigue diciendo cuántos dólares fueron.

**Why this priority**: es el caso que disparó la funcionalidad y el único que
tiene valor por sí solo. Sin esto, nada de lo demás sirve.

**Independent Test**: se prueba registrando un gasto en dólares y comprobando
que (a) el total del mes lo incluye convertido, (b) la ficha del gasto muestra
el importe original, y (c) ninguna pantalla muestra un total mezclando monedas.

**Acceptance Scenarios**:

1. **Given** un mes abierto con gastos ya registrados, **When** el usuario
   registra un gasto de 23.60 dólares con un tipo de cambio informado,
   **Then** el gasto queda guardado, el total del mes crece en el equivalente
   en soles, y el gasto se muestra con las dos cifras.
2. **Given** un gasto en dólares a medio cargar, **When** el usuario no
   informa el tipo de cambio, **Then** la app no lo deja guardar y explica qué
   falta.
3. **Given** un tipo de cambio informado como cero o negativo, **When** el
   usuario intenta guardar, **Then** la app lo rechaza con un motivo concreto.
4. **Given** un gasto registrado en dólares, **When** el usuario corrige el
   tipo de cambio, **Then** el importe en soles se recalcula solo y los
   totales del mes se ajustan, sin tocar ningún otro dato.
5. **Given** un gasto registrado en soles, **When** el usuario lo abre,
   **Then** no ve ningún dato de conversión ni ruido de moneda: la app se ve
   igual que antes de esta funcionalidad para quien nunca gasta en otra
   moneda.

---

### User Story 2 - Confirmar un consumo capturado en moneda extranjera (Priority: P2)

Llega una notificación de un consumo en dólares. En vez de descartarse —que es
lo que manda hoy FR-014 de la spec 002—, aparece en la bandeja de pendientes
con su importe original y su moneda, marcado como incompleto: le falta el tipo
de cambio. El usuario lo completa al confirmar y el consumo queda registrado.

**Why this priority**: es el camino por el que el caso real va a llegar la
mayoría de las veces, pero necesita que US1 exista primero — la bandeja
termina llamando al mismo registro.

**Independent Test**: se prueba alimentando la bandeja con un consumo en
moneda extranjera y comprobando que aparece, que no se puede confirmar sin
tipo de cambio, y que al confirmarlo produce el mismo resultado que US1.

**Acceptance Scenarios**:

1. **Given** una notificación de consumo cuyo importe está en dólares,
   **When** la app la interpreta, **Then** genera un pendiente con el importe
   original y su moneda, y no lo descarta.
2. **Given** ese pendiente, **When** el usuario intenta confirmarlo sin
   informar el tipo de cambio, **Then** la app no lo registra y le pide el
   dato que falta.
3. **Given** ese pendiente, **When** el usuario informa el tipo de cambio y
   confirma, **Then** el consumo queda registrado igual que si lo hubiera
   cargado a mano.
4. **Given** una notificación en una moneda que la app no reconoce, **When**
   la interpreta, **Then** no inventa ni la moneda ni el importe: queda en
   diagnóstico con su motivo.

---

### User Story 3 - Una obligación recurrente en moneda extranjera (Priority: P3)

El usuario tiene una suscripción que le cobran todos los meses en dólares y
quiere que aparezca en su presupuesto como el compromiso mensual que es, no
como una sorpresa al final del mes.

**Why this priority**: es el caso natural siguiente —la suscripción que originó
todo esto es recurrente— pero agrega una pregunta que US1 y US2 no tienen: el
tipo de cambio cambia todos los meses, así que un compromiso en dólares es un
importe en soles **distinto cada mes**. Vale la pena tenerlo separado y
decidirlo aparte.

**Independent Test**: se prueba cargando una obligación en moneda extranjera y
comprobando qué muestra el presupuesto de dos meses distintos.

**Acceptance Scenarios**:

1. **Given** una obligación mensual expresada en dólares, **When** el usuario
   abre el presupuesto del mes, **Then** ve cuánto pesa en soles y con qué
   tipo de cambio se calculó.
2. **Given** esa obligación, **When** el usuario pasa a un mes distinto,
   **Then** la app no le presenta como certeza un importe en soles que
   todavía no se conoce.

---

### Edge Cases

- **¿Qué pasa si el usuario informa un tipo de cambio absurdo** (por ejemplo
  3752.3 en vez de 3.7523)? La app no puede saber que está mal, pero sí puede
  mostrar el resultado de la conversión **antes** de guardar, para que el error
  salte a la vista.
- **¿Qué pasa con un mes ya cerrado?** Las reglas de cierre vigentes se aplican
  igual; esta funcionalidad no abre ninguna puerta nueva para editar el pasado.
- **¿Qué pasa al restaurar un respaldo anterior a esta funcionalidad?** Todo lo
  que traiga se lee como moneda de cuenta, sin conversión y sin preguntar nada.
- **¿Qué pasa si una moneda no tiene centavos** (yen, peso chileno)? Hoy no hay
  ninguna en uso, pero el diseño no puede dar por sentado que toda moneda se
  divide en cien.
- **¿Qué pasa si el mismo comercio cobra a veces en soles y a veces en
  dólares?** Son gastos distintos con importes distintos; la categoría
  aprendida (spec 002, US3) sigue valiendo porque depende del comercio, no de
  la moneda.
- **¿Qué pasa si el usuario cambia la moneda de un gasto ya guardado?** El
  importe original y la conversión tienen que quedar coherentes o no guardarse:
  nunca un gasto con la moneda de una cosa y el tipo de cambio de otra.

## Requirements *(mandatory)*

### Functional Requirements

#### Moneda de cuenta y totales

- **FR-001**: El sistema MUST expresar todo total, saldo, presupuesto,
  comprometido, déficit y meta en **una única moneda de cuenta**.
- **FR-002**: La moneda de cuenta es el **sol peruano**.
- **FR-003**: El sistema MUST NOT mostrar nunca un total en moneda extranjera,
  ni una cifra que sume importes de dos monedas distintas.

#### Registro de un importe en otra moneda

- **FR-004**: Los usuarios MUST poder registrar un gasto real cuyo importe esté
  expresado en una moneda distinta de la moneda de cuenta.
- **FR-005**: Al registrar un importe en moneda extranjera, el sistema MUST
  pedirle al usuario el tipo de cambio aplicado.
- **FR-006**: El sistema MUST NOT obtener el tipo de cambio de ninguna fuente
  externa. No hay red, no hay servicio de cotizaciones, no hay valor
  precargado que pretenda ser el del día.
- **FR-007**: El sistema MUST guardar, para cada movimiento en moneda
  extranjera: el importe en moneda de cuenta, el importe original, la moneda
  original y el tipo de cambio aplicado.
- **FR-008**: El sistema MUST tratar esos cuatro datos como un todo: o el
  movimiento tiene los cuatro, o es un movimiento en moneda de cuenta. Nunca
  un estado intermedio guardado.
- **FR-009**: El sistema MUST rechazar un tipo de cambio que no sea mayor que
  cero, con un motivo concreto.
- **FR-010**: El sistema MUST mostrar el resultado de la conversión antes de
  guardar, para que un tipo de cambio mal tipeado se vea a tiempo.

#### Exactitud (Principio II)

- **FR-011**: La conversión MUST hacerse con aritmética exacta, sin punto
  flotante en ningún punto del camino.
- **FR-012**: El redondeo MUST ocurrir una sola vez, al centavo más cercano de
  la moneda de cuenta, con el mismo criterio que ya usa el resto de la app.
- **FR-013**: El tipo de cambio MUST admitir al menos cuatro decimales
  (p. ej. 3.7523) sin perder precisión.

#### Que se entienda de un vistazo (Principio IV)

- **FR-014**: Donde se muestre un movimiento registrado en moneda extranjera,
  el sistema MUST mostrar el importe en moneda de cuenta **y** el importe
  original con su símbolo.
- **FR-015**: El sistema MUST permitir ver el tipo de cambio con el que se
  calculó un movimiento. Una cifra convertida no puede aparecer sin
  explicación posible.
- **FR-016**: Un movimiento en moneda extranjera MUST distinguirse de uno en
  moneda de cuenta por algo más que el color.
- **FR-017**: Para un usuario que nunca registra en otra moneda, la app MUST
  verse y comportarse igual que antes de esta funcionalidad.

#### Corrección y cierre

- **FR-018**: Corregir el tipo de cambio de un movimiento MUST recalcular su
  importe en moneda de cuenta y los totales que lo incluyen, sin obligar a
  reescribir ningún otro dato.
- **FR-019**: Las reglas de cierre de mes vigentes MUST aplicarse sin cambios a
  los movimientos en moneda extranjera.

#### Captura de notificaciones (reemplaza FR-014 de la spec 002)

- **FR-020**: Una notificación cuyo consumo esté expresado en una moneda
  extranjera **reconocida** MUST generar un pendiente con su importe original y
  su moneda, en lugar de descartarse.
- **FR-021**: Ese pendiente MUST NOT poder confirmarse sin que el usuario
  informe el tipo de cambio.
- **FR-022**: El sistema MUST NOT inventar, estimar ni heredar un tipo de
  cambio de otro movimiento sin que el usuario lo confirme para ese pendiente.
- **FR-023**: Una notificación en una moneda **no reconocida** MUST quedar en
  diagnóstico con su motivo, sin registrar nada.

#### Extensibilidad (el pedido explícito del usuario)

- **FR-024**: Agregar una moneda nueva MUST NOT requerir modificar ninguna
  regla de cálculo financiero ya existente.
- **FR-025**: El sistema MUST admitir monedas cuya subdivisión no sea de cien
  unidades (monedas sin centavos), aunque hoy no haya ninguna en uso.
- **FR-026**: El conjunto de monedas aceptadas MUST estar declarado en un solo
  lugar, junto con el símbolo y la cantidad de decimales de cada una.

#### Datos que ya existen

- **FR-027**: Todo lo registrado antes de esta funcionalidad MUST seguir
  leyéndose como moneda de cuenta, sin conversión, sin preguntar nada al
  usuario y sin ninguna acción manual de migración.
- **FR-028**: Restaurar un respaldo generado antes de esta funcionalidad MUST
  seguir funcionando (spec 005).

#### Pendiente de decisión

- **FR-029**: El sistema MUST permitir registrar en moneda extranjera
  [NEEDS CLARIFICATION: ¿solo los gastos reales, o también las obligaciones
  recurrentes del presupuesto? Una obligación en dólares pesa distinto cada
  mes porque el tipo de cambio cambia, lo que obliga a decidir de dónde sale
  el tipo de cambio de un mes futuro].
- **FR-030**: El tipo de cambio MUST informarse
  [NEEDS CLARIFICATION: ¿en cada movimiento por separado, o hay un tipo de
  cambio por mes que el usuario configura una vez y se aplica por defecto a
  todos los movimientos de ese mes? Lo primero es más fiel a lo que cobró el
  banco; lo segundo ahorra tipeo y se parece al estado de cuenta].

### Key Entities

- **Moneda**: una moneda que la app sabe mostrar y aceptar. La identifica su
  código internacional; lleva además el símbolo con que se muestra y en cuántas
  unidades menores se divide. Es la única pieza que hay que tocar para aceptar
  una moneda más.
- **Importe original**: el importe tal como lo cobraron, con su moneda. Existe
  solo en los movimientos que no se originaron en la moneda de cuenta. No
  participa de ningún total.
- **Tipo de cambio aplicado**: cuántas unidades de la moneda de cuenta
  equivalen a una unidad de la moneda original, para **ese** movimiento. Lo
  informa el usuario y queda guardado con el movimiento, no en una tabla de
  cotizaciones.
- **Movimiento**: cualquier registro con importe —un gasto real, y según la
  decisión de FR-029 quizá también una obligación—. Siempre tiene un importe
  en moneda de cuenta; opcionalmente, un importe original y su tipo de cambio.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Registrar un gasto en moneda extranjera toma menos de **25
  segundos**, contra los 15 que SC-002 de la spec 001 pide para un gasto
  normal. Los 10 de diferencia son elegir la moneda y escribir el tipo de
  cambio, y nada más.
- **SC-002**: El resumen del mes sigue comunicando la situación con **un solo
  número** de disponible. Ninguna pantalla muestra dos disponibles ni obliga al
  usuario a sumar de cabeza.
- **SC-003**: **El 100%** de los movimientos registrados en moneda extranjera
  muestran, donde se los ve, su importe original además del convertido.
- **SC-004**: **Cero** discrepancias de centavos entre lo que la app muestra,
  lo que guarda y lo que suma, en toda la batería de pruebas de conversión
  —incluidos los importes de siete cifras y los tipos de cambio de cuatro
  decimales.
- **SC-005**: Aceptar una moneda adicional se resuelve **en un solo lugar del
  producto**, sin tocar ninguna regla de cálculo ya escrita. Se verifica
  agregando una tercera moneda de prueba y comprobando que ninguna prueba de
  cálculo financiero cambia.
- **SC-006**: Un usuario que nunca registra en otra moneda **no ve ninguna
  diferencia** respecto de la versión anterior: mismos campos, mismos pasos,
  mismas pantallas.

## Assumptions

Cada una de estas es un supuesto razonable tomado para no multiplicar las
preguntas abiertas. Todas son reversibles y están planteadas como preguntas de
sí o no en el análisis que acompaña a esta especificación.

- **La moneda de cuenta queda fija en el sol**, no es configurable. Cambiarla
  después re-cotizaría todo el historial, que es un problema distinto y mayor.
- **Las deudas en cuotas quedan fuera de alcance.** El banco factura la cuota
  en soles aunque la compra haya sido en dólares, así que la deuda ya nace en
  moneda de cuenta. Meter moneda extranjera ahí reabriría D14 de la spec 001
  (replicar la amortización del banco), que se rechazó por escrito.
- **El ahorro y los cobros de ingreso quedan fuera de alcance.** El sueldo
  llega en soles; no hay caso que lo pida.
- **Las monedas aceptadas al arrancar son dos**: el sol como moneda de cuenta y
  el dólar estadounidense. El euro y cualquier otra se agregan cuando exista un
  movimiento real que lo pida, no antes (Principio V).
- **La app recuerda el último tipo de cambio usado y lo ofrece como valor
  inicial**, pero el usuario siempre lo puede cambiar y nunca se guarda sin que
  lo vea. Ofrecerlo no es lo mismo que inventarlo (FR-022).
- **Ningún dato sale del dispositivo por esta funcionalidad.** No hay consulta
  de cotizaciones ni ninguna otra salida: el Principio I no se toca, y esta
  spec no pide ninguna excepción nueva.
