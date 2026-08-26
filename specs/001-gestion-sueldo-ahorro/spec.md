# Feature Specification: Gestión de sueldo, gasto real, deudas y ahorro

**Feature Branch**: `001-gestion-sueldo-ahorro`

**Created**: 2026-08-26

**Last Updated**: 2026-08-26 (revisión 2: se añaden transacciones reales, seguimiento de ahorro y deudas en cuotas)

**Status**: Draft

**Input**: User description: "Aplicación de finanzas personales de uso individual para administrar un sueldo mensual en soles peruanos (S/) y decidir cuánto ahorrar cada mes después de cubrir las obligaciones (tarjetas de crédito, alquiler, servicios, pasajes, comida). Incluye registro de transacciones reales, seguimiento del ahorro efectivamente realizado, y deudas de tarjeta de crédito a largo plazo con pagos mensuales en cuotas."

## Conceptos base

Tres conceptos que atraviesan toda la especificación y conviene fijar antes:

- **Presupuestado**: lo que el usuario planea o se compromete a pagar en el mes.
  Incluye obligaciones fijas (alquiler), variables estimadas (comida) y las
  cuotas de deuda vigentes del mes.
- **Real**: lo que el usuario efectivamente gastó, registrado transacción por
  transacción conforme ocurre.
- **Deuda en cuotas**: una compra financiada con tarjeta que genera un pago
  mensual durante varios meses. Su cuota entra automáticamente en el
  presupuesto de cada mes que le corresponde, sin que el usuario la reescriba.

La app muestra **presupuestado y real en paralelo**: al inicio del mes proyecta
cuánto podrá ahorrar; conforme avanza el mes contrasta esa proyección con la
realidad y avisa cuando una categoría se desvía.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar ingreso y presupuesto del mes (Priority: P1)

El usuario abre la app al inicio del mes y registra cuánto cobró de sueldo.
Luego arma su presupuesto: el alquiler del departamento, los servicios de luz,
agua e internet, y lo que estima gastar en pasajes y comida. A cada partida le
asigna una categoría y un monto, e indica si es fija (mismo monto cada mes) o
variable (estimación).

**Why this priority**: sin ingreso ni presupuesto no hay nada que calcular ni
contra qué comparar el gasto real. Es la base de todo lo demás.

**Independent Test**: se prueba registrando un ingreso y varias obligaciones,
cerrando la app y reabriéndola para confirmar que persisten. Ya entrega valor:
el usuario tiene su presupuesto mensual en un solo lugar.

**Acceptance Scenarios**:

1. **Given** que no hay ningún mes registrado, **When** el usuario ingresa su sueldo del mes, **Then** el sueldo queda guardado como ingreso del mes en curso.
2. **Given** un ingreso registrado, **When** el usuario añade una obligación con nombre, categoría, monto y tipo fija, **Then** la obligación aparece en el presupuesto del mes y reduce el disponible proyectado.
3. **Given** una obligación registrada, **When** el usuario edita su monto o la elimina, **Then** los totales del mes se recalculan de inmediato.
4. **Given** obligaciones fijas del mes anterior, **When** comienza un mes nuevo, **Then** se proponen precargadas con el mismo monto para que el usuario solo confirme o ajuste.
5. **Given** que el usuario intenta guardar una obligación sin monto o con monto negativo, **When** confirma, **Then** la app rechaza el registro e indica qué corregir.

---

### User Story 2 - Ver el resumen del mes y saber si estoy en déficit (Priority: P1)

El usuario quiere saber, sin hacer cuentas, cuánto entró, cuánto está
comprometido y cuánto le queda libre. Si sus compromisos superan lo que gana, la
app se lo dice de forma inequívoca.

**Why this priority**: es la pregunta central que motiva la app. Junto con la
historia 1 constituye el MVP.

**Independent Test**: se prueba cargando un ingreso y obligaciones conocidas y
verificando que los totales coinciden con el cálculo manual, incluido el caso en
que los compromisos exceden el ingreso.

**Acceptance Scenarios**:

1. **Given** un ingreso de S/ 3,000.00 y un presupuesto de S/ 1,800.00, **When** el usuario abre el resumen, **Then** ve ingreso S/ 3,000.00, comprometido S/ 1,800.00 y disponible proyectado S/ 1,200.00.
2. **Given** un ingreso de S/ 2,000.00 y un presupuesto de S/ 2,350.00, **When** el usuario abre el resumen, **Then** la app señala explícitamente el déficit e indica el faltante de S/ 350.00.
3. **Given** un presupuesto que iguala exactamente el ingreso, **When** el usuario abre el resumen, **Then** el disponible es S/ 0.00 y la app no lo reporta como déficit.
4. **Given** un mes sin ingreso registrado, **When** el usuario abre el resumen, **Then** la app indica que falta registrar el ingreso, en vez de mostrar totales en cero como si fueran válidos.

---

### User Story 3 - Registrar gastos reales y contrastarlos con el presupuesto (Priority: P1)

Durante el mes el usuario va anotando lo que realmente gasta: el almuerzo, los
pasajes del día, el recibo de luz cuando llega. Cada gasto lleva monto, fecha,
categoría y una descripción corta. La app le muestra, por categoría, cuánto
presupuestó y cuánto lleva gastado, y le avisa cuando se está pasando.

**Why this priority**: es lo que convierte la app en una herramienta de uso
diario en vez de una planilla que se llena una vez al mes. Junto a las historias
1 y 2 forma el núcleo funcional.

**Independent Test**: se prueba registrando gastos en categorías con presupuesto
conocido y verificando que los acumulados por categoría, el total real y las
alertas de sobregiro son correctos.

**Acceptance Scenarios**:

1. **Given** un presupuesto de comida de S/ 600.00 sin gastos aún, **When** el usuario registra un gasto de S/ 45.00 en comida, **Then** la categoría comida muestra S/ 45.00 gastados de S/ 600.00 presupuestados y S/ 555.00 restantes.
2. **Given** un presupuesto de pasajes de S/ 200.00 con S/ 190.00 ya gastados, **When** el usuario registra un gasto de S/ 25.00 en pasajes, **Then** la app señala que la categoría superó su presupuesto en S/ 15.00.
3. **Given** varios gastos registrados en el mes, **When** el usuario abre el resumen, **Then** ve en paralelo el disponible proyectado (según presupuesto) y el disponible real (ingreso menos gasto efectivo).
4. **Given** un gasto registrado por error, **When** el usuario lo edita o elimina, **Then** los acumulados de su categoría y los totales del mes se recalculan.
5. **Given** un gasto en una categoría sin presupuesto asignado, **When** el usuario lo registra, **Then** el gasto se contabiliza en el total real y la app indica que esa categoría no estaba presupuestada.
6. **Given** gastos registrados en distintas fechas, **When** el usuario consulta el listado del mes, **Then** los ve ordenados por fecha, del más reciente al más antiguo.

---

### User Story 4 - Administrar deudas de tarjeta en cuotas (Priority: P2)

El usuario compró un celular en 12 cuotas y un electrodoméstico en 6. Registra
cada deuda una sola vez —descripción, tarjeta, cuota mensual, número de cuotas y
mes en que empieza— y la app se encarga del resto: cada mes suma automáticamente
las cuotas vigentes al presupuesto, y en cualquier momento el usuario puede ver
cuánto debe en total, cuántas cuotas le faltan y en qué mes termina de pagar.

**Why this priority**: es la diferencia entre ver el mes y ver el año. Sin esto
el usuario tendría que reescribir las cuotas cada mes a mano y no tendría
visibilidad de su deuda total. Requiere que el presupuesto mensual ya funcione.

**Independent Test**: se prueba registrando deudas con distintos meses de inicio
y plazos, y verificando que la cuota correcta aparece en cada mes, que el saldo
pendiente decrece cuota a cuota y que la deuda desaparece del presupuesto al
vencer la última cuota.

**Acceptance Scenarios**:

1. **Given** ninguna deuda registrada, **When** el usuario registra una deuda de 12 cuotas de S/ 150.00 con inicio en el mes en curso, **Then** el presupuesto del mes incluye S/ 150.00 en la categoría tarjeta de crédito y el saldo pendiente de la deuda es S/ 1,800.00.
2. **Given** la deuda anterior con 3 cuotas ya pagadas, **When** el usuario consulta la deuda, **Then** ve 9 cuotas restantes, saldo pendiente S/ 1,350.00 y el mes en que pagará la última.
3. **Given** dos deudas activas de S/ 150.00 y S/ 80.00 en la misma tarjeta, **When** el usuario abre el presupuesto del mes, **Then** la tarjeta aparece con un compromiso de S/ 230.00, desglosable en las dos deudas que lo componen.
4. **Given** una deuda cuya última cuota corresponde al mes en curso, **When** comienza el mes siguiente, **Then** esa deuda ya no aporta ningún monto al presupuesto y queda marcada como saldada.
5. **Given** una deuda que empieza en un mes futuro, **When** el usuario consulta el mes en curso, **Then** esa deuda no aporta monto al presupuesto actual, pero sí figura en el total de deuda pendiente.
6. **Given** varias deudas activas, **When** el usuario abre la vista de deudas, **Then** ve el total que adeuda, el compromiso mensual agregado y el mes en que quedará libre de deudas.
7. **Given** una deuda registrada con datos equivocados, **When** el usuario corrige la cuota o el número de cuotas, **Then** los presupuestos de los meses afectados y el saldo pendiente se recalculan.
8. **Given** que el usuario cancela anticipadamente una deuda, **When** la marca como saldada, **Then** deja de aportar cuotas a los meses siguientes y su saldo pendiente pasa a cero.

---

### User Story 5 - Decidir cuánto ahorrar y registrar lo que ahorro (Priority: P2)

El usuario quiere saber cuánto debería apartar este mes. La app se lo sugiere
según la regla que eligió: un porcentaje de su ingreso, o lo que sobre tras
cubrir sus compromisos. Puede fijarse una meta mensual y saber si es realista. Y
cuando efectivamente aparta dinero, lo registra, de modo que la app lleva la
cuenta de cuánto ha ahorrado en total.

**Why this priority**: es el objetivo declarado de la app, pero depende de que
el resumen del mes y los compromisos ya funcionen.

**Independent Test**: se prueba configurando cada regla y comparando el monto
sugerido contra el cálculo esperado; fijando metas por encima y por debajo del
disponible; y registrando aportes para verificar el acumulado y el progreso.

**Acceptance Scenarios**:

1. **Given** la regla "porcentaje del ingreso" al 20% y un ingreso de S/ 3,000.00, **When** el usuario ve la sugerencia, **Then** la app sugiere ahorrar S/ 600.00.
2. **Given** esa misma regla con un ingreso de S/ 3,000.00 y compromisos de S/ 2,700.00, **When** el usuario ve la sugerencia, **Then** la app advierte que el 20% (S/ 600.00) excede el disponible (S/ 300.00) y ofrece el disponible como monto alcanzable.
3. **Given** la regla "lo que sobre" y un disponible de S/ 1,200.00, **When** el usuario ve la sugerencia, **Then** la app sugiere ahorrar S/ 1,200.00.
4. **Given** una meta mensual de S/ 500.00 y un disponible de S/ 1,200.00, **When** el usuario consulta la meta, **Then** la app la reporta como alcanzable e indica el margen de S/ 700.00.
5. **Given** una meta de S/ 1,500.00 y un disponible de S/ 1,200.00, **When** el usuario consulta la meta, **Then** la app la reporta como no alcanzable e indica que tendría que recortar S/ 300.00 en compromisos.
6. **Given** estado de déficit, **When** el usuario consulta la sugerencia, **Then** la app indica que no corresponde ahorrar este mes y remite a revisar los compromisos.
7. **Given** una meta mensual de S/ 500.00, **When** el usuario registra un aporte de ahorro de S/ 300.00, **Then** la app muestra S/ 300.00 de S/ 500.00 y S/ 200.00 pendientes para la meta.
8. **Given** un aporte de S/ 300.00 ya registrado este mes, **When** el usuario registra otro de S/ 250.00, **Then** el ahorro del mes es S/ 550.00 y la app indica que superó la meta en S/ 50.00.
9. **Given** aportes registrados en meses anteriores, **When** el usuario consulta su ahorro, **Then** ve el acumulado histórico total y el aporte de cada mes.
10. **Given** un aporte registrado por error, **When** el usuario lo edita o elimina, **Then** el ahorro del mes y el acumulado histórico se recalculan.
11. **Given** un mes cerrado sin ningún aporte registrado, **When** el usuario consulta el historial, **Then** ese mes figura con S/ 0.00 ahorrado, no como si la meta se hubiera cumplido.

---

### User Story 6 - Ver en qué se va el dinero por categoría (Priority: P3)

El usuario quiere identificar dónde recortar. Ve sus categorías con lo
presupuestado y lo realmente gastado, el peso de cada una sobre su ingreso, y
cuáles se desviaron más de lo previsto.

**Why this priority**: apoya la decisión de recorte, pero el usuario ya puede
operar la app sin este desglose.

**Independent Test**: se prueba con gastos repartidos en varias categorías,
verificando que los subtotales suman el total, que los porcentajes son correctos
y que el orden refleja el criterio pedido.

**Acceptance Scenarios**:

1. **Given** obligaciones y gastos en cuatro categorías, **When** el usuario abre el desglose, **Then** ve una fila por categoría con presupuestado, gastado, diferencia y porcentaje sobre el ingreso, ordenadas de mayor a menor gasto.
2. **Given** una categoría sin presupuesto ni gasto en el mes, **When** el usuario abre el desglose, **Then** esa categoría no aparece, en lugar de mostrarse en S/ 0.00.
3. **Given** el desglose en pantalla, **When** se suman los subtotales de gasto, **Then** el resultado coincide exactamente con el gasto real total del mes, sin descuadres por redondeo.
4. **Given** categorías que excedieron su presupuesto, **When** el usuario abre el desglose, **Then** esas categorías están señaladas de forma que se distingan sin depender únicamente del color.

---

### Edge Cases

**Ingreso y déficit**

- **Compromisos que superan el ingreso**: la app entra en déficit, muestra el faltante y suprime la sugerencia de ahorro.
- **Ingreso cero o ausente**: no se calculan porcentajes sobre el ingreso; la app pide registrar el ingreso antes de sugerir ahorro.
- **Mes sin datos**: al abrir un mes nuevo, la app ofrece precargar las obligaciones fijas del mes anterior; las cuotas de deuda vigentes se cargan automáticamente sin preguntar.

**Gasto real**

- **Gasto sin categoría presupuestada**: se contabiliza igual en el total real y se señala como no presupuestado.
- **Gasto con fecha fuera del mes**: se asigna al mes de su fecha, no al mes que el usuario tenga abierto.
- **Gasto que deja una categoría en negativo**: no se bloquea el registro; se señala el sobregiro. La app no impide al usuario gastar, solo se lo informa.

**Deudas en cuotas**

- **Deuda con inicio en mes futuro**: no aporta al presupuesto actual pero sí al saldo total adeudado.
- **Última cuota**: al mes siguiente la deuda queda saldada y desaparece del presupuesto.
- **Cancelación anticipada**: el usuario puede marcar una deuda como saldada; deja de generar cuotas y su saldo pasa a cero.
- **Edición retroactiva de una deuda**: recalcula los meses afectados sin alterar los gastos reales ya registrados.
- **Deuda de una sola cuota**: se admite; equivale a una obligación de un único mes.
- **Sin deudas activas**: la vista de deudas comunica el estado libre de deuda en vez de mostrarse vacía.

**Ahorro**

- **Aporte mayor que el disponible**: se admite y se registra; la app informa que el aporte excede el disponible del mes, sin bloquearlo.
- **Aportes múltiples en un mes**: se suman para el total del mes.
- **Meta no fijada**: la app muestra el ahorro acumulado sin veredicto de progreso.

**Montos y cálculo**

- **Monto inválido**: montos negativos o no numéricos se rechazan al guardar.
- **Montos grandes**: se formatean correctamente hasta siete cifras (S/ 9,999,999.99) sin desbordar la interfaz.
- **Redondeo**: los porcentajes se redondean al centavo; la suma de subtotales por categoría nunca difiere del total.
- **Edición de un mes pasado**: recalcula solo ese mes y, si afecta aportes de ahorro, el acumulado histórico.

## Requirements *(mandatory)*

### Functional Requirements

**Ingreso y presupuesto**

- **FR-001**: El sistema MUST permitir registrar un ingreso mensual asociado a un mes y año concretos.
- **FR-002**: El sistema MUST permitir registrar, editar y eliminar obligaciones presupuestadas con nombre, categoría, monto y tipo (fija o variable).
- **FR-003**: El sistema MUST ofrecer las categorías: tarjeta de crédito, departamento, servicios, pasajes, comida y otros.
- **FR-004**: El sistema MUST distinguir obligaciones fijas de variables y reflejar esa distinción en la interfaz.
- **FR-005**: El sistema MUST rechazar montos negativos o no numéricos, indicando el motivo.
- **FR-006**: Al iniciar un mes nuevo, el sistema MUST ofrecer precargar las obligaciones fijas del mes anterior con sus montos, dejando al usuario confirmarlas o ajustarlas.

**Gasto real**

- **FR-007**: El sistema MUST permitir registrar, editar y eliminar transacciones de gasto con monto, fecha, categoría y descripción.
- **FR-008**: El sistema MUST asignar cada transacción al mes correspondiente a su fecha.
- **FR-009**: El sistema MUST acumular el gasto real por categoría y en total para cada mes.
- **FR-010**: El sistema MUST mostrar, por categoría, el monto presupuestado, el gastado y la diferencia entre ambos.
- **FR-011**: El sistema MUST señalar las categorías cuyo gasto real supere su presupuesto, indicando el exceso.
- **FR-012**: El sistema MUST registrar gastos en categorías sin presupuesto asignado, señalándolos como no presupuestados, sin impedir el registro.
- **FR-013**: El sistema MUST listar las transacciones de un mes ordenadas por fecha descendente.
- **FR-014**: El sistema MUST NOT bloquear el registro de un gasto por exceder el presupuesto; solo informarlo.

**Deudas en cuotas**

- **FR-015**: El sistema MUST permitir registrar una deuda en cuotas con descripción, tarjeta asociada, monto de la cuota mensual, número total de cuotas y mes de inicio.
- **FR-016**: El sistema MUST incorporar automáticamente al presupuesto de cada mes la suma de las cuotas vigentes en ese mes, en la categoría tarjeta de crédito.
- **FR-017**: El sistema MUST permitir desglosar el compromiso mensual de una tarjeta en las deudas individuales que lo componen.
- **FR-018**: El sistema MUST calcular, para cada deuda, las cuotas pagadas, las restantes, el saldo pendiente y el mes de la última cuota.
- **FR-019**: El sistema MUST dejar de incorporar cuotas al presupuesto una vez pagada la última cuota, marcando la deuda como saldada.
- **FR-020**: El sistema MUST excluir del presupuesto del mes en curso las deudas cuyo inicio sea posterior, incluyéndolas en el total adeudado.
- **FR-021**: El sistema MUST permitir marcar una deuda como saldada anticipadamente, cesando sus cuotas futuras y poniendo su saldo pendiente en cero.
- **FR-022**: El sistema MUST mostrar el total adeudado, el compromiso mensual agregado por deudas y el mes en que quedarán todas saldadas.
- **FR-023**: Editar una deuda MUST recalcular los presupuestos de los meses afectados y su saldo pendiente.
- **FR-024**: El sistema MUST registrar la cuota mensual tal como la informa el banco, sin calcular intereses ni tasas.

**Resumen y déficit**

- **FR-025**: El sistema MUST calcular y mostrar, para cada mes: ingreso total, total comprometido (obligaciones más cuotas vigentes), gasto real total, disponible proyectado y disponible real.
- **FR-026**: El disponible proyectado MUST definirse como ingreso total menos total comprometido.
- **FR-027**: El disponible real MUST definirse como ingreso total menos gasto real total.
- **FR-028**: El sistema MUST señalar de forma inequívoca el estado de déficit cuando el total comprometido supere al ingreso, indicando el faltante.
- **FR-029**: El aviso de déficit MUST ser comprensible sin depender únicamente del color.
- **FR-030**: El sistema MUST tratar el saldo exactamente cero como situación sin déficit.

**Ahorro**

- **FR-031**: El sistema MUST permitir elegir la regla de ahorro entre "porcentaje del ingreso" y "lo que sobre tras los compromisos".
- **FR-032**: El sistema MUST permitir configurar el porcentaje cuando la regla sea por porcentaje.
- **FR-033**: El sistema MUST calcular el ahorro sugerido según la regla vigente.
- **FR-034**: Cuando el ahorro sugerido por porcentaje exceda el disponible proyectado, el sistema MUST advertirlo y ofrecer el disponible como monto alcanzable.
- **FR-035**: El sistema MUST permitir fijar una meta de ahorro mensual y reportar si es alcanzable con el disponible proyectado.
- **FR-036**: Cuando la meta no sea alcanzable, el sistema MUST indicar cuánto habría que recortar en compromisos para lograrla.
- **FR-037**: En estado de déficit, el sistema MUST suprimir la sugerencia de ahorro e indicar que no corresponde ahorrar.
- **FR-038**: El sistema MUST permitir registrar, editar y eliminar aportes de ahorro con monto y fecha.
- **FR-039**: El sistema MUST admitir varios aportes en un mismo mes y sumarlos como ahorro del mes.
- **FR-040**: El sistema MUST mostrar el progreso del ahorro del mes contra la meta, indicando lo pendiente o el excedente.
- **FR-041**: El sistema MUST mantener y mostrar el ahorro acumulado histórico y el aporte de cada mes.
- **FR-042**: El sistema MUST admitir aportes que excedan el disponible del mes, informándolo sin bloquear el registro.
- **FR-043**: Los meses sin aportes MUST figurar con S/ 0.00 ahorrado en el historial.

**Desglose por categoría**

- **FR-044**: El sistema MUST mostrar el gasto agrupado por categoría, ordenado de mayor a menor monto gastado.
- **FR-045**: El sistema MUST mostrar el peso porcentual de cada categoría sobre el ingreso del mes.
- **FR-046**: Los subtotales por categoría MUST sumar exactamente el total, sin descuadres por redondeo.
- **FR-047**: El sistema MUST omitir del desglose las categorías sin presupuesto ni gasto en el mes.

**Presentación y persistencia**

- **FR-048**: Todos los montos MUST presentarse en soles peruanos con el símbolo S/ y exactamente dos decimales.
- **FR-049**: Los cálculos monetarios MUST ser exactos al centavo, sin errores acumulados de redondeo.
- **FR-050**: El sistema MUST persistir todos los datos localmente en el dispositivo, disponibles tras cerrar y reabrir la app.
- **FR-051**: El sistema MUST conservar los meses registrados y permitir consultarlos.
- **FR-052**: Editar un mes pasado MUST recalcular únicamente ese mes y, cuando corresponda, el acumulado histórico de ahorro.

### Key Entities

- **Mes**: periodo de gestión identificado por mes y año. Agrupa ingreso, obligaciones presupuestadas, transacciones reales y aportes de ahorro. Es la unidad sobre la que se calculan resumen, déficit y ahorro.
- **Ingreso**: monto que el usuario percibe en un mes determinado.
- **Obligación presupuestada**: partida planificada del mes, con nombre, categoría, monto y tipo (fija o variable). Pertenece a un mes.
- **Transacción**: gasto real ocurrido, con monto, fecha, categoría y descripción. Se asigna al mes de su fecha. Es el registro de la realidad, frente a la obligación que es la previsión.
- **Categoría**: clasificación de obligaciones y transacciones, tomada de un conjunto cerrado (tarjeta de crédito, departamento, servicios, pasajes, comida, otros).
- **Tarjeta**: medio de pago que agrupa deudas en cuotas. Permite ver el compromiso mensual consolidado por tarjeta.
- **Deuda en cuotas**: compra financiada, con descripción, tarjeta, cuota mensual, número total de cuotas y mes de inicio. Genera automáticamente el compromiso de cada mes en que tiene cuotas vigentes. Deriva saldo pendiente, cuotas restantes y mes de término.
- **Regla de ahorro**: configuración de cómo se calcula el ahorro sugerido: por porcentaje del ingreso (con su porcentaje) o por remanente.
- **Meta de ahorro**: monto que el usuario se propone apartar en el mes, contra el cual se evalúa viabilidad y progreso.
- **Aporte de ahorro**: monto efectivamente apartado, con fecha. Varios aportes componen el ahorro de un mes; su suma histórica es el acumulado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Desde la app abierta, el usuario conoce su saldo disponible del mes en un máximo de dos interacciones.
- **SC-002**: Registrar un gasto del día toma menos de quince segundos, de modo que anotarlo en el momento sea sostenible como hábito diario.
- **SC-003**: Registrar el ingreso y cinco obligaciones típicas toma menos de tres minutos en el primer uso, sin instrucciones externas.
- **SC-004**: En el segundo mes y siguientes, poner al día el presupuesto toma menos de treinta segundos, gracias a la precarga de fijas y a la carga automática de cuotas.
- **SC-005**: Una deuda en cuotas se registra una sola vez y aparece correctamente en todos los meses que le corresponden, sin intervención posterior del usuario.
- **SC-006**: El usuario conoce su deuda total pendiente y el mes en que quedará libre de deudas en una sola pantalla.
- **SC-007**: Los totales mostrados coinciden al centavo con el cálculo manual en el 100% de los casos de prueba, incluidos déficit, saldo cero, cuotas parciales y montos de siete cifras.
- **SC-008**: Ante un déficit, el usuario identifica correctamente que sus compromisos superan su ingreso sin ayuda adicional.
- **SC-009**: El usuario identifica su categoría de mayor gasto, y aquellas donde se pasó del presupuesto, en una sola pantalla.
- **SC-010**: El usuario consulta cuánto ha ahorrado en total desde que usa la app en una sola interacción.
- **SC-011**: Los datos registrados sobreviven al cierre de la app y al reinicio del dispositivo en el 100% de los casos.
- **SC-012**: La app es completamente utilizable sin conexión a internet.

## Assumptions

**Sobre el alcance**

- **Un solo usuario, un solo dispositivo**: no se contempla multiusuario, autenticación ni sincronización entre dispositivos.
- **Moneda única**: todos los montos son en soles peruanos; no hay conversión ni soporte multimoneda.
- **Periodicidad mensual**: la unidad de gestión es el mes calendario. No se modelan quincenas, semanas ni sueldos con periodicidad distinta.
- **Un ingreso por mes**: se asume un sueldo mensual único. Ingresos adicionales, gratificaciones o extraordinarios no están contemplados en esta versión.
- **Sin integración bancaria**: no se importan movimientos ni se conecta con bancos o tarjetas; todo se ingresa manualmente.
- **Sin respaldo ni exportación**: la versión inicial no contempla copia de seguridad, exportación ni restauración de datos.
- **Idioma español**: interfaz en español, con formato de montos y fechas según convención peruana.

**Sobre las deudas**

- **La cuota la informa el banco**: el usuario registra el monto de la cuota mensual tal como se lo cobran. La app no modela tasas de interés, TEA ni el cálculo de amortización, porque replicar el cálculo del banco introduciría discrepancias de centavos frente al estado de cuenta real.
- **Cuotas de monto constante**: se asume que todas las cuotas de una deuda son iguales. Planes con cuota inicial distinta o montos escalonados no están contemplados.
- **Las deudas son la fuente de la categoría tarjeta de crédito**: el compromiso mensual de tarjeta se deriva de las cuotas vigentes, no se escribe a mano. El consumo de tarjeta no financiado se registra como transacción normal.
- **Sin línea de crédito ni saldo revolvente**: no se modela cupo disponible, pago mínimo, ni intereses por revolver.

**Sobre el gasto y el ahorro**

- **Presupuesto y gasto conviven**: el disponible proyectado guía la decisión de ahorro a inicio de mes; el disponible real refleja lo ocurrido. La app muestra ambos y no fuerza a elegir uno.
- **El ahorro se registra manualmente**: la app no detecta transferencias ni movimientos; el usuario anota lo que apartó. Se asume que prefiere un registro fiel a uno automático pero potencialmente falso.
- **El ahorro es un acumulado, no una cuenta**: se lleva el total apartado, sin modelar retiros, rendimientos, intereses ni varias cuentas de ahorro separadas.
- **Las transacciones son gastos**: no se registran ingresos extraordinarios ni devoluciones como transacciones positivas en esta versión.
