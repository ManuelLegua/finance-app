# Feature Specification: Gestión de sueldo mensual y ahorro

**Feature Branch**: `001-gestion-sueldo-ahorro`

**Created**: 2026-08-26

**Status**: Draft

**Input**: User description: "Aplicación de finanzas personales de uso individual para administrar un sueldo mensual en soles peruanos (S/) y decidir cuánto ahorrar cada mes después de cubrir las obligaciones (tarjetas de crédito, alquiler, servicios, pasajes, comida)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar ingreso y obligaciones del mes (Priority: P1)

El usuario abre la app por primera vez en el mes y registra cuánto cobró de sueldo. Luego da de alta sus obligaciones recurrentes: el alquiler del departamento, la cuota de cada tarjeta de crédito, los servicios de luz, agua e internet, y lo que estima gastar en pasajes y comida. A cada una le asigna una categoría y un monto, e indica si el monto es el mismo todos los meses (fija) o si varía (variable).

**Why this priority**: sin ingreso ni obligaciones registradas no existe nada que calcular. Es la base de la que dependen todas las demás historias.

**Independent Test**: se prueba registrando un ingreso y varias obligaciones, cerrando la app y volviéndola a abrir para confirmar que todo sigue ahí. Ya entrega valor por sí sola: el usuario tiene su presupuesto mensual anotado en un solo lugar en vez de disperso.

**Acceptance Scenarios**:

1. **Given** que no hay ningún mes registrado, **When** el usuario ingresa su sueldo del mes, **Then** el sueldo queda guardado y visible como ingreso del mes en curso.
2. **Given** que existe un ingreso registrado, **When** el usuario añade una obligación con nombre, categoría, monto y tipo fijo, **Then** la obligación aparece en la lista del mes y se descuenta del saldo disponible.
3. **Given** una obligación ya registrada, **When** el usuario edita su monto o la elimina, **Then** los totales del mes se recalculan de inmediato.
4. **Given** obligaciones registradas en el mes anterior marcadas como fijas, **When** comienza un mes nuevo, **Then** esas obligaciones se proponen precargadas con el mismo monto para que el usuario solo confirme o ajuste.
5. **Given** que el usuario intenta guardar una obligación sin monto o con monto negativo, **When** confirma, **Then** la app rechaza el registro e indica qué corregir.

---

### User Story 2 - Ver el resumen del mes y saber si estoy en déficit (Priority: P1)

El usuario abre la app a mitad de mes y quiere saber, sin hacer cuentas, cuánto entró, cuánto está comprometido en obligaciones y cuánto le queda libre. Si sus obligaciones superan lo que gana, la app se lo dice de forma inequívoca.

**Why this priority**: es la pregunta central que motiva la app. Junto con la historia 1 constituye el MVP: registrar y ver el resultado.

**Independent Test**: se prueba cargando un ingreso y un conjunto de obligaciones conocidas y verificando que los tres totales coinciden con el cálculo manual, incluyendo el caso en que las obligaciones exceden el ingreso.

**Acceptance Scenarios**:

1. **Given** un ingreso de S/ 3,000.00 y obligaciones por S/ 1,800.00, **When** el usuario abre el resumen, **Then** ve ingreso S/ 3,000.00, comprometido S/ 1,800.00 y disponible S/ 1,200.00.
2. **Given** un ingreso de S/ 2,000.00 y obligaciones por S/ 2,350.00, **When** el usuario abre el resumen, **Then** la app señala explícitamente que está en déficit e indica el faltante de S/ 350.00.
3. **Given** obligaciones que igualan exactamente el ingreso, **When** el usuario abre el resumen, **Then** el disponible es S/ 0.00 y la app no lo reporta como déficit.
4. **Given** un mes sin ingreso registrado, **When** el usuario abre el resumen, **Then** la app indica que falta registrar el ingreso en vez de mostrar totales en cero como si fueran válidos.

---

### User Story 3 - Recibir una sugerencia de ahorro y fijar una meta (Priority: P2)

El usuario quiere saber cuánto debería apartar este mes. La app le sugiere un monto según la regla que él haya elegido: un porcentaje de su ingreso, o simplemente lo que sobre tras cubrir las obligaciones. Además puede fijarse una meta de ahorro y la app le dice si es alcanzable con sus números actuales.

**Why this priority**: es el valor diferencial de la app frente a una hoja de cálculo, pero requiere que el resumen del mes ya funcione.

**Independent Test**: se prueba configurando cada regla de ahorro por separado y comparando el monto sugerido contra el cálculo esperado; y fijando metas por encima y por debajo del disponible para verificar el veredicto de viabilidad.

**Acceptance Scenarios**:

1. **Given** la regla "porcentaje del ingreso" configurada al 20% y un ingreso de S/ 3,000.00, **When** el usuario ve la sugerencia, **Then** la app sugiere ahorrar S/ 600.00.
2. **Given** la regla "porcentaje del ingreso" al 20%, un ingreso de S/ 3,000.00 y obligaciones por S/ 2,700.00, **When** el usuario ve la sugerencia, **Then** la app advierte que el 20% (S/ 600.00) excede el disponible (S/ 300.00) y ofrece el disponible como monto alcanzable.
3. **Given** la regla "lo que sobre" y un disponible de S/ 1,200.00, **When** el usuario ve la sugerencia, **Then** la app sugiere ahorrar S/ 1,200.00.
4. **Given** una meta de ahorro de S/ 500.00 y un disponible de S/ 1,200.00, **When** el usuario consulta la meta, **Then** la app la reporta como alcanzable e indica el margen restante de S/ 700.00.
5. **Given** una meta de S/ 1,500.00 y un disponible de S/ 1,200.00, **When** el usuario consulta la meta, **Then** la app la reporta como no alcanzable e indica cuánto tendría que recortar en obligaciones (S/ 300.00).
6. **Given** que el usuario está en déficit, **When** consulta la sugerencia de ahorro, **Then** la app indica que no corresponde ahorrar este mes y remite a revisar las obligaciones.

---

### User Story 4 - Ver en qué se va el dinero por categoría (Priority: P3)

El usuario quiere identificar dónde recortar. Ve el desglose de sus obligaciones agrupadas por categoría, con el monto y el peso relativo de cada una sobre su ingreso, ordenadas de mayor a menor.

**Why this priority**: apoya la decisión de recorte, pero el usuario ya puede operar la app sin este desglose.

**Independent Test**: se prueba con obligaciones repartidas en varias categorías y verificando que los subtotales suman el total comprometido y que los porcentajes son correctos.

**Acceptance Scenarios**:

1. **Given** obligaciones en cuatro categorías distintas, **When** el usuario abre el desglose, **Then** ve una fila por categoría con su subtotal y su porcentaje sobre el ingreso, ordenadas de mayor a menor monto.
2. **Given** una categoría sin obligaciones registradas este mes, **When** el usuario abre el desglose, **Then** esa categoría no aparece, en lugar de mostrarse en S/ 0.00.
3. **Given** el desglose en pantalla, **When** el usuario suma los subtotales, **Then** el resultado coincide exactamente con el total comprometido del resumen, sin descuadres por redondeo.

---

### Edge Cases

- **Obligaciones que superan el ingreso**: la app entra en estado de déficit, muestra el faltante y suprime la sugerencia de ahorro.
- **Ingreso cero o ausente**: no se calculan porcentajes sobre el ingreso; la app pide registrar el ingreso antes de sugerir ahorro.
- **Mes sin datos**: al abrir un mes nuevo sin registros, la app ofrece precargar las obligaciones fijas del mes anterior.
- **Monto inválido**: montos negativos o no numéricos se rechazan al guardar.
- **Montos muy grandes**: la app debe formatear correctamente montos de hasta siete cifras (S/ 9,999,999.99) sin desbordar la interfaz.
- **Redondeo de porcentajes**: el ahorro sugerido por porcentaje se redondea al centavo; la suma de subtotales por categoría nunca debe diferir del total.
- **Cambio de regla de ahorro a mitad de mes**: la sugerencia se recalcula con la regla vigente, sin alterar los registros históricos de meses cerrados.
- **Edición retroactiva**: modificar un mes pasado recalcula solo ese mes.

## Requirements *(mandatory)*

### Functional Requirements

**Ingresos y obligaciones**

- **FR-001**: El sistema MUST permitir registrar un ingreso mensual asociado a un mes y año concretos.
- **FR-002**: El sistema MUST permitir registrar, editar y eliminar obligaciones, cada una con nombre, categoría, monto y tipo (fija o variable).
- **FR-003**: El sistema MUST ofrecer las categorías: tarjeta de crédito, departamento, servicios, pasajes, comida y otros.
- **FR-004**: El sistema MUST distinguir obligaciones fijas de variables y reflejar esa distinción en la interfaz.
- **FR-005**: El sistema MUST rechazar montos negativos o no numéricos, indicando el motivo.
- **FR-006**: El sistema MUST persistir todos los datos localmente en el dispositivo, disponibles tras cerrar y reabrir la app.
- **FR-007**: Al iniciar un mes nuevo, el sistema MUST ofrecer precargar las obligaciones fijas del mes anterior con sus montos, dejando al usuario confirmarlas o ajustarlas.

**Resumen y déficit**

- **FR-008**: El sistema MUST calcular y mostrar, para el mes en curso: ingreso total, total comprometido en obligaciones y saldo disponible.
- **FR-009**: El sistema MUST definir el saldo disponible como ingreso total menos total comprometido.
- **FR-010**: El sistema MUST señalar de forma inequívoca el estado de déficit cuando el total comprometido supere al ingreso, indicando el monto faltante.
- **FR-011**: El aviso de déficit MUST ser comprensible sin depender únicamente del color.
- **FR-012**: El sistema MUST tratar el saldo exactamente cero como situación sin déficit.

**Ahorro**

- **FR-013**: El sistema MUST permitir elegir la regla de ahorro entre "porcentaje del ingreso" y "lo que sobre tras las obligaciones".
- **FR-014**: El sistema MUST permitir configurar el porcentaje cuando la regla elegida sea por porcentaje.
- **FR-015**: El sistema MUST calcular el ahorro sugerido según la regla vigente.
- **FR-016**: Cuando el ahorro sugerido por porcentaje exceda el saldo disponible, el sistema MUST advertirlo y ofrecer el disponible como monto alcanzable.
- **FR-017**: El sistema MUST permitir fijar una meta de ahorro mensual y reportar si es alcanzable con el saldo disponible.
- **FR-018**: Cuando la meta no sea alcanzable, el sistema MUST indicar cuánto habría que recortar en obligaciones para lograrla.
- **FR-019**: En estado de déficit, el sistema MUST suprimir la sugerencia de ahorro e indicar que no corresponde ahorrar.

**Desglose por categoría**

- **FR-020**: El sistema MUST mostrar el total comprometido agrupado por categoría, ordenado de mayor a menor monto.
- **FR-021**: El sistema MUST mostrar el peso porcentual de cada categoría sobre el ingreso del mes.
- **FR-022**: Los subtotales por categoría MUST sumar exactamente el total comprometido, sin descuadres por redondeo.
- **FR-023**: El sistema MUST omitir del desglose las categorías sin obligaciones en el mes.

**Presentación de montos**

- **FR-024**: Todos los montos MUST presentarse en soles peruanos con el símbolo S/ y exactamente dos decimales.
- **FR-025**: Los cálculos monetarios MUST ser exactos al centavo, sin errores acumulados de redondeo.

**Historial**

- **FR-026**: El sistema MUST conservar los meses registrados y permitir consultarlos.
- **FR-027**: Editar un mes pasado MUST recalcular únicamente ese mes.

### Key Entities

- **Mes**: periodo de gestión identificado por mes y año. Agrupa un ingreso y un conjunto de obligaciones. Es la unidad sobre la que se calculan resumen, déficit y ahorro.
- **Ingreso**: monto que el usuario percibe en un mes determinado.
- **Obligación**: compromiso de pago del mes, con nombre, categoría, monto y tipo (fija o variable). Pertenece a un mes.
- **Categoría**: clasificación de una obligación, tomada de un conjunto cerrado (tarjeta de crédito, departamento, servicios, pasajes, comida, otros).
- **Regla de ahorro**: configuración que determina cómo se calcula el ahorro sugerido: por porcentaje del ingreso (con su porcentaje) o por remanente.
- **Meta de ahorro**: monto que el usuario se propone apartar en el mes, contra el cual se evalúa la viabilidad.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Desde la app abierta, el usuario conoce su saldo disponible del mes en un máximo de dos interacciones.
- **SC-002**: Registrar el ingreso y cinco obligaciones típicas toma menos de tres minutos en el primer uso, sin instrucciones externas.
- **SC-003**: En el segundo mes y siguientes, poner al día las obligaciones fijas toma menos de treinta segundos gracias a la precarga.
- **SC-004**: Los totales mostrados coinciden al centavo con el cálculo manual en el 100% de los casos de prueba, incluidos déficit, saldo cero y montos de siete cifras.
- **SC-005**: Ante un déficit, el usuario identifica correctamente que sus obligaciones superan su ingreso sin ayuda adicional.
- **SC-006**: El usuario identifica su categoría de mayor gasto en una sola pantalla, sin comparar cifras manualmente.
- **SC-007**: Los datos registrados sobreviven al cierre de la app y al reinicio del dispositivo en el 100% de los casos.
- **SC-008**: La app es completamente utilizable sin conexión a internet.

## Assumptions

- **Un solo usuario, un solo dispositivo**: no se contempla multiusuario, autenticación, ni sincronización entre dispositivos.
- **Moneda única**: todos los montos son en soles peruanos; no hay conversión ni soporte multimoneda.
- **Periodicidad mensual**: la unidad de gestión es el mes calendario. No se modelan quincenas, semanas ni sueldos con periodicidad distinta.
- **Un ingreso por mes**: se asume un sueldo mensual único. Ingresos adicionales o extraordinarios no están contemplados en esta versión.
- **Obligaciones estimadas, no transacciones**: la app registra compromisos y estimaciones del mes, no cada gasto individual conforme ocurre. No hay seguimiento de gastos reales contra lo presupuestado.
- **Sin integración bancaria**: no se importan movimientos ni se conecta con bancos o tarjetas; todo se ingresa manualmente.
- **Las tarjetas de crédito se modelan como una obligación mensual** (la cuota o pago del mes), no como una línea de crédito con saldo, interés y ciclo de facturación.
- **El ahorro es una sugerencia, no un movimiento**: la app calcula cuánto convendría ahorrar, pero no registra ni rastrea el ahorro efectivamente realizado ni su acumulado.
- **Sin respaldo ni exportación**: la versión inicial no contempla copia de seguridad, exportación ni restauración de datos.
- **Idioma español**: la interfaz está en español, con formato de montos y fechas según convención peruana.
