# Feature Specification: Ciclo de facturación de las tarjetas de crédito

**Feature Branch**: `007-ciclo-facturacion-tarjeta`

**Created**: 2026-09-13

**Status**: Draft

**Depends on**: [001-gestion-sueldo-ahorro](../001-gestion-sueldo-ahorro/spec.md) — define `Tarjeta`, `Transaccion`, `Deuda` y el cierre de meses. Toca de cerca a [002-captura-notificaciones-bancarias](../002-captura-notificaciones-bancarias/spec.md), que produce transacciones de tarjeta sin intervención manual.

**Input**: User description: "Hay que añadir las fechas claves de las tarjetas, ya que si se captura un pago con tarjeta de crédito, hay que saber si ese pago cuenta para el presente mes o para el siguiente."

## Contexto y alcance

Hoy un gasto pesa en el mes de su fecha, sin excepción. Para el efectivo y el
débito eso es exacto: el dinero salió ese día. **Para una tarjeta de crédito es
falso**, y la diferencia no es un detalle contable sino la que hace que el
disponible del mes mienta.

Una compra del 20 de setiembre con una tarjeta que cierra el 15 no entra en el
estado de cuenta de setiembre: entra en el de octubre. El usuario que mira su
disponible de setiembre ve descontado un gasto que su banco todavía no le
cobró, y cuando llegue octubre verá el mes siguiente más holgado de lo que es.
Con dos o tres tarjetas de ciclos distintos, el disponible deja de ser
comparable con la realidad — que es la única cosa que esta app promete.

Esta funcionalidad le enseña a la app **cuándo cierra cada tarjeta**, y usa ese
dato para poner cada consumo en el mes donde el banco lo va a cobrar.

**Lo que no hace**: no calcula intereses, no replica la amortización del banco
ni trae datos de ninguna parte (D14 de la 001 sigue vigente). Las tres fechas
las informa el usuario.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cargar las fechas de una tarjeta (Priority: P1)

El usuario abre una de sus tarjetas de crédito y anota tres datos que lee de su
estado de cuenta o de la app del banco: qué día cierra, qué día vence el pago y
cuánto es el pago mínimo.

**Why this priority**: sin este dato ninguna de las otras historias existe. Y
por sí sola ya entrega valor: tener a mano cuándo vence el pago y cuánto es el
mínimo evita la mora, que es el error más caro que comete quien usa tarjeta.

**Independent Test**: se carga una tarjeta con sus tres datos, se cierra la app,
se vuelve a abrir y siguen ahí, visibles en la ficha de la tarjeta.

**Acceptance Scenarios**:

1. **Given** una tarjeta de crédito sin fechas cargadas, **When** el usuario
   anota día de cierre 15, día de vencimiento 5 y pago mínimo S/ 150.00,
   **Then** la ficha de la tarjeta muestra los tres datos.
2. **Given** una tarjeta de **débito**, **When** el usuario abre su ficha,
   **Then** no se le ofrece ninguno de los tres campos, porque una tarjeta de
   débito no tiene ciclo de facturación.
3. **Given** una tarjeta de crédito con fechas cargadas, **When** el usuario
   corrige el día de cierre, **Then** el cambio se guarda sin pedirle rehacer
   ningún gasto.

---

### User Story 2 - Un consumo cae en el mes que le corresponde (Priority: P1)

Cuando se registra un gasto con una tarjeta de crédito —lo anote el usuario a
mano o lo capture la app de una notificación— el gasto pesa en el mes del
estado de cuenta donde va a caer, no en el mes de la compra.

**Why this priority**: es el objetivo de la funcionalidad. Sin esto, cargar las
fechas es decorativo.

**Independent Test**: con una tarjeta que cierra el 15, se registra un gasto con
fecha 20 de setiembre y se comprueba que el resumen de **octubre** lo cuenta y
el de setiembre no.

**Acceptance Scenarios**:

1. **Given** una tarjeta que cierra el día 15, **When** se registra un gasto del
   20 de setiembre con esa tarjeta, **Then** el gasto pesa en el presupuesto de
   **octubre**.
2. **Given** la misma tarjeta, **When** se registra un gasto del 10 de
   setiembre, **Then** el gasto pesa en el presupuesto de **setiembre**.
3. **Given** un gasto en efectivo o con tarjeta de débito del 20 de setiembre,
   **When** se registra, **Then** pesa en setiembre — el ciclo de facturación no
   lo alcanza.
4. **Given** una tarjeta de crédito **sin fechas cargadas**, **When** se
   registra un gasto del 20 de setiembre con ella, **Then** pesa en setiembre,
   igual que antes de esta funcionalidad.
5. **Given** un gasto ya registrado que cayó en octubre por el cierre del 15,
   **When** el usuario corrige el día de cierre a 25, **Then** el gasto pasa a
   pesar en setiembre sin que el usuario tenga que volver a tocarlo.

---

### User Story 3 - Ver por qué un gasto está donde está (Priority: P2)

Un gasto que aparece en un mes distinto al de su fecha se explica solo: al
mirarlo, el usuario ve que la compra fue el 20 de setiembre y que cuenta para
octubre porque su tarjeta cerró el 15.

**Why this priority**: sin esta explicación la funcionalidad se siente como un
error. Un usuario que ve una compra de setiembre listada en octubre y no
entiende por qué desconfía del total, y desconfiar del total es peor que tener
el total mal — el Principio IV existe para esto.

**Independent Test**: se abre el detalle de un gasto desplazado y se comprueba
que menciona las dos fechas y el motivo.

**Acceptance Scenarios**:

1. **Given** un gasto del 20 de setiembre que pesa en octubre, **When** el
   usuario lo mira en la lista de octubre, **Then** ve que la compra fue el 20
   de setiembre y por qué cuenta en octubre.
2. **Given** un gasto cuya fecha y mes coinciden, **When** el usuario lo mira,
   **Then** no se le agrega ninguna explicación que no haga falta.

---

### User Story 4 - Saber cuándo y cuánto hay que pagar (Priority: P3)

Con el día de vencimiento y el pago mínimo cargados, la app le muestra al
usuario cuánto suma su consumo del ciclo en curso de cada tarjeta y para qué
fecha tiene que pagarlo.

**Why this priority**: es valor real pero derivado: depende de que las historias
1 y 2 estén hechas, y la app sigue siendo útil sin esto.

**Independent Test**: con una tarjeta cargada y tres gastos del ciclo, se
comprueba que la ficha muestra el total del ciclo y la fecha de vencimiento.

**Acceptance Scenarios**:

1. **Given** una tarjeta con vencimiento el día 5 y tres consumos en el ciclo en
   curso, **When** el usuario abre su ficha, **Then** ve la suma de los tres y
   la fecha de vencimiento del pago.
2. **Given** una tarjeta con pago mínimo cargado, **When** el usuario abre su
   ficha, **Then** ve el pago mínimo junto al total del ciclo.

---

### Edge Cases

- **Día de cierre 29, 30 o 31 en un mes que no lo tiene.** Una tarjeta que
  cierra el 31 tiene que cerrar en febrero igual. Se resuelve con el último día
  del mes: en febrero de un año común, el 28.
- **Una compra exactamente el día del cierre.** Ver FR-005 — es la ambigüedad
  que hay que confirmar con el banco antes de implementar.
- **El mes destino ya está cerrado.** Registrar en noviembre una compra del 20
  de setiembre la manda a octubre, que puede estar cerrado (D13 de la 001). Se
  aplica la misma regla de cierre que a cualquier otro gasto, evaluada sobre el
  **mes destino** y no sobre la fecha de la compra.
- **El usuario borra las fechas de una tarjeta que ya tenía gastos desplazados.**
  Los gastos vuelven al mes de su fecha, por la misma regla de FR-008 que los
  había movido.
- **Un gasto registrado sin tarjeta.** Sigue pesando en el mes de su fecha. No
  se fuerza a elegir tarjeta en cada gasto: obligar a hacerlo rompería el
  registro en quince segundos que promete SC-002 de la 001.
- **Una deuda en cuotas sobre una tarjeta con ciclo.** Las cuotas se siguen
  derivando de su mes de inicio (D3, D4 de la 001). El ciclo **no** las
  recalcula: ver FR-011.

## Requirements *(mandatory)*

### Functional Requirements

**Las fechas de la tarjeta**

- **FR-001**: El sistema MUST permitir registrar, para cada tarjeta de crédito,
  un día de cierre del estado de cuenta, un día de vencimiento del pago y un
  monto de pago mínimo.
- **FR-002**: El sistema MUST tratar los tres datos como opcionales. Una tarjeta
  sin ellos sigue funcionando exactamente como antes de esta funcionalidad.
- **FR-003**: El sistema MUST NOT ofrecer estos tres datos en una tarjeta de
  débito, que no tiene ciclo de facturación.
- **FR-004**: El sistema MUST aceptar como día de cierre y de vencimiento
  cualquier día del 1 al 31, y MUST resolverlos al último día del mes cuando el
  mes no llegue a ese número.

**A qué mes pertenece un consumo**

- **FR-005**: El sistema MUST asignar cada consumo con tarjeta de crédito al mes
  del estado de cuenta en que cae: si la compra ocurre después del día de
  cierre, pertenece al mes siguiente al de la compra; si ocurre antes,
  pertenece al mes de la compra. [NEEDS CLARIFICATION: una compra hecha
  exactamente **el día** del cierre, ¿entra en el estado que cierra ese día o en
  el siguiente? Los bancos difieren y el usuario puede confirmarlo en su
  contrato; es un caso límite que la constitución exige probar.]
- **FR-006**: El sistema MUST aplicar la regla de FR-005 a **todas** las
  transacciones de tarjeta de crédito, las capturadas de una notificación y las
  anotadas a mano por igual. No puede haber dos comportamientos para el mismo
  gasto según cómo entró.
- **FR-007**: El sistema MUST seguir asignando al mes de su fecha todo gasto que
  no sea con tarjeta de crédito, y todo gasto con una tarjeta de crédito que no
  tenga día de cierre cargado.
- **FR-008**: El sistema MUST **derivar** el mes de cada consumo cada vez que lo
  necesite, y MUST NOT fijarlo en el momento de registrarlo. Cambiar el día de
  cierre de una tarjeta MUST reubicar los consumos ya registrados de esa
  tarjeta, sin que el usuario tenga que reescribir ninguno.
- **FR-009**: El sistema MUST registrar con qué tarjeta se hizo cada gasto,
  cuando el gasto se haya hecho con una.
- **FR-010**: El sistema MUST NOT obligar a elegir una tarjeta para registrar un
  gasto.
- **FR-011**: El sistema MUST seguir derivando las cuotas de una deuda de su mes
  de inicio, sin que el ciclo de facturación las desplace. Cuando el usuario
  cree una deuda sobre una tarjeta con día de cierre cargado, el sistema MAY
  **proponer** como mes de inicio el que resulta del ciclo, pero el usuario
  decide: la cuota y su calendario los informa el banco (D14 de la 001).

**Que se entienda**

- **FR-012**: Cuando un gasto pese en un mes distinto al de su fecha, el sistema
  MUST mostrar la fecha de la compra y el motivo del desplazamiento.
- **FR-013**: El sistema MUST NOT comunicar el desplazamiento solo por color o
  posición.
- **FR-014**: El sistema MUST seguir aplicando la regla de cierre de meses (D13
  de la 001) evaluándola sobre el mes al que el gasto termina perteneciendo, no
  sobre la fecha de la compra.

**El ciclo en curso**

- **FR-015**: El sistema MUST poder mostrar, para cada tarjeta de crédito con
  día de cierre cargado, la suma de los consumos del ciclo en curso.
- **FR-016**: El sistema MUST poder mostrar la fecha de vencimiento del próximo
  pago y el pago mínimo registrado, cuando estén cargados.
- **FR-017**: El sistema MUST presentar el pago mínimo como lo que es — un dato
  que el usuario anotó — y MUST NOT presentarlo como un cálculo propio.
  [NEEDS CLARIFICATION: el pago mínimo real cambia con cada estado de cuenta.
  ¿Se guarda un único monto que el usuario actualiza cuando quiere, o uno por
  estado de cuenta? Un único monto es mucho más simple y encaja con YAGNI; uno
  por ciclo es más fiel pero agrega una entidad nueva.]

### Key Entities

- **Tarjeta** *(existente, se amplía)*: suma tres datos opcionales, solo para
  las de crédito — día de cierre del estado de cuenta, día de vencimiento del
  pago y monto del pago mínimo.
- **Transacción** *(existente, se amplía)*: suma la tarjeta con la que se hizo
  el gasto, que puede no haberla. El mes al que pertenece **deja de ser siempre
  el de su fecha** y pasa a derivarse de la fecha más el ciclo de la tarjeta.
- **Ciclo de facturación** *(derivado, no se guarda)*: el período entre dos
  cierres de una tarjeta, y el mes de presupuesto al que ese período
  corresponde. Se calcula de la fecha y del día de cierre, igual que el cierre
  de meses se calcula de la fecha (D13).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario con una tarjeta cuyo cierre no es fin de mes ve, en el
  resumen de cada mes, el mismo total que le va a cobrar su banco en el estado
  de cuenta de ese mes.
- **SC-002**: Cargar las tres fechas de una tarjeta lleva menos de treinta
  segundos.
- **SC-003**: Registrar un gasto sigue llevando menos de quince segundos
  (SC-002 de la 001), sin importar que ahora se pueda asociar una tarjeta.
- **SC-004**: Ante un gasto listado en un mes distinto al de su fecha, el
  usuario entiende por qué sin abrir ninguna ayuda ni ajuste.
- **SC-005**: Corregir el día de cierre de una tarjeta reubica todos sus
  consumos sin que el usuario edite ninguno.
- **SC-006**: Un usuario sin ninguna fecha cargada no percibe ningún cambio
  respecto de cómo funcionaba la app antes.

## Assumptions

- **La regla la decide el día de cierre, no el de vencimiento.** El estado de
  cuenta define el compromiso del mes; la fecha de vencimiento dice cuándo se
  paga, y se usa para avisar, no para asignar el mes. Decisión del usuario el
  2026-09-13.
- **El mes se deriva, nunca se persiste.** Es la misma regla que ya rige para
  las cuotas de deuda (D3) y para el cierre de meses (D13) en la especificación
  001. Fijarlo al registrar el gasto haría que corregir un día de cierre dejara
  los gastos viejos donde estaban, que es exactamente el error que D3 evita.
- **La tarjeta en un gasto es opcional.** Obligar a elegirla en cada registro
  chocaría de frente con el registro en quince segundos de SC-002 de la 001. Un
  gasto sin tarjeta se comporta como hoy.
- **Un solo día de cierre por tarjeta, sin historial.** Si el banco cambia el
  ciclo, el usuario corrige el dato y todo se reubica. Guardar la vigencia
  histórica de cada día de cierre sería más fiel y no responde a ningún
  requisito vigente (YAGNI, Principio V).
- **Las tres fechas las informa el usuario.** No hay ninguna vía para obtenerlas
  automáticamente sin red, y traerlas de un servicio está descartado desde D14
  de la 001 y por el Principio I.
- **Esta funcionalidad no toca el cálculo de intereses ni el de la deuda
  total.** Ninguno de los dos existe en la app y nada acá los introduce.
- **Requiere ampliar el esquema.** Hoy una transacción no guarda con qué tarjeta
  se pagó — solo las deudas apuntan a una tarjeta. FR-009 lo cambia, y eso
  implica una migración de base de datos y un campo nuevo en el formulario de
  gasto.

## Dependencies

- **Especificación 001** para `Tarjeta`, `Transaccion`, `Deuda`, la regla de
  cierre de meses (D13) y la derivación de cuotas (D3, D4).
- **Especificación 002** produce transacciones de tarjeta sin intervención
  manual. FR-006 obliga a que esas transacciones pasen por la misma regla, así
  que el flujo de confirmación de un pendiente tiene que poder decir con qué
  tarjeta se hizo el consumo. La 002 ya pide la tarjeta cuando el consumo es en
  cuotas; con esto la va a necesitar también cuando no lo sea.
