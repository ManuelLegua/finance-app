# Feature Specification: Cobros parciales de ingreso

**Feature Branch**: `003-cobros-parciales-ingreso`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "Modificar el registro de ingreso mensual (feature 001-gestion-sueldo-ahorro) para admitir que el sueldo llegue en varios cobros parciales dentro del mes, en vez de un único monto. Caso real del usuario: sueldo de S/2,000.00 mensual que se cobra en dos partes, S/960.00 a mitad de mes (quincena) y S/1,040.00 a fin de mes. El usuario quiere trackear cada cobro por separado (con su fecha), no solo cargar el total de una vez."

**Depende de**: `001-gestion-sueldo-ahorro`. Esta feature reemplaza cómo se registra el ingreso mensual (FR-001 de esa spec) sin tocar ningún otro requisito: todo lo que hoy consume "el ingreso del mes" (disponible proyectado, disponible real, déficit, sugerencia de ahorro) sigue funcionando igual, porque sigue recibiendo un único total por mes — ese total ahora se deriva de sus cobros en vez de ser un dato suelto.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar el sueldo en más de un cobro (Priority: P1)

El usuario cobra su sueldo en dos partes dentro del mes (por ejemplo, quincena y fin de mes) y quiere anotar cada cobro con su propia fecha y monto, en vez de cargar un solo total a mano.

**Why this priority**: es el caso real que motiva la funcionalidad; sin esto, el usuario sigue haciendo la suma por su cuenta antes de entrar a la app, que es exactamente el trabajo manual que la app existe para evitar.

**Independent Test**: se prueba registrando dos cobros en el mismo mes con fechas y montos distintos, y comprobando que el ingreso total del mes (el que usa el resumen y la sugerencia de ahorro) es la suma exacta de ambos.

**Acceptance Scenarios**:

1. **Given** un mes sin ningún cobro registrado, **When** el usuario registra un cobro de S/ 960.00 con fecha 15 y otro de S/ 1,040.00 con fecha 30 del mismo mes, **Then** el ingreso del mes que se usa en el resumen es S/ 2,000.00.
2. **Given** un mes con un único cobro de S/ 2,000.00, **When** el usuario consulta el resumen del mes, **Then** el comportamiento es idéntico al de un ingreso único de hoy: nada obliga a partir el sueldo en más de un cobro.

---

### User Story 2 - Ver el detalle de los cobros del mes (Priority: P2)

El usuario quiere ver, además del total, la lista de los cobros que lo componen (fecha y monto de cada uno), igual que ya puede ver el detalle de sus gastos o de sus aportes de ahorro.

**Why this priority**: sin el detalle, el usuario no puede verificar que el total es correcto ni detectar un cobro cargado con el monto o la fecha equivocada.

**Independent Test**: se prueba registrando dos cobros y comprobando que la pantalla de presupuesto lista ambos por separado, con su fecha, además del total.

**Acceptance Scenarios**:

1. **Given** dos cobros registrados en el mes, **When** el usuario abre la sección de ingreso del presupuesto, **Then** ve ambos cobros listados con su fecha y monto, y el total en la parte superior.

---

### User Story 3 - Corregir o eliminar un cobro puntual (Priority: P3)

El usuario anotó un cobro con el monto o la fecha equivocada y quiere corregirlo o borrarlo sin tener que volver a cargar los demás cobros del mes.

**Why this priority**: es la misma garantía que ya existe para gastos y aportes de ahorro (FR-007 y FR-038 de la spec 001); omitirla dejaría el ingreso como la única cosa de la app que no se puede corregir en detalle.

**Independent Test**: se prueba editando el monto de uno de dos cobros registrados y comprobando que el otro cobro y el total se recalculan correctamente.

**Acceptance Scenarios**:

1. **Given** dos cobros registrados, S/ 960.00 y S/ 1,040.00, **When** el usuario corrige el segundo a S/ 1,000.00, **Then** el total del mes pasa a ser S/ 1,960.00 y el primer cobro no se modifica.
2. **Given** dos cobros registrados, **When** el usuario elimina uno, **Then** el ingreso del mes queda como el monto del cobro restante, no en cero ni sin registrar.
3. **Given** el único cobro de un mes, **When** el usuario lo elimina, **Then** el mes vuelve al estado "ingreso sin registrar", igual que si nunca se hubiera cargado nada (no se muestra un total de S/ 0.00, que se confundiría con un sueldo real de cero).

---

### Edge Cases

- Un mes sin ningún cobro se comporta como "ingreso sin registrar" (estado ya definido en la spec 001, HU2 escenario 4): no se muestra un disponible calculado sobre cero.
- Un cobro con fecha del mes anterior, dentro de la ventana de gracia configurada, se puede registrar igual que un gasto rezagado (FR-055 de la spec 001); fuera de esa ventana, no. Un cobro ya guardado en la ventana de gracia queda inmutable, igual que un gasto (FR-056 de la spec 001).
- Los ingresos ya guardados con el esquema anterior (un monto único por mes, sin fecha propia) se preservan como un cobro equivalente por mes, con el primer día de ese mes como fecha (ver Assumptions): ningún dato existente se pierde.
- Dos cobros con la misma fecha en el mismo mes son válidos y se suman igual que dos gastos del mismo día.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir registrar uno o más cobros de ingreso por mes, cada uno con fecha y monto, en reemplazo del monto único mensual de la spec 001.
- **FR-002**: El sistema MUST derivar el mes de un cobro a partir de su fecha, no del mes que el usuario tenga abierto en ese momento (mismo criterio que un gasto real, FR-008 de la spec 001).
- **FR-003**: El sistema MUST sumar todos los cobros de un mes para obtener su ingreso total, y ese total MUST ser el valor que usan sin cambios el disponible proyectado, el disponible real, el estado de déficit y la sugerencia de ahorro de la spec 001.
- **FR-004**: El sistema MUST permitir editar y eliminar un cobro individual sin afectar a los demás cobros del mes.
- **FR-005**: Un mes sin ningún cobro registrado MUST figurar como "ingreso sin registrar", nunca como un ingreso de S/ 0.00.
- **FR-006**: El sistema MUST aplicar a los cobros la misma regla de cierre de meses que a los gastos reales (FR-052, FR-055, FR-056 de la spec 001): no se admite registrar ni editar un cobro de un mes cerrado, salvo registrar uno dentro de la ventana de gracia, y lo registrado en gracia queda inmutable.
- **FR-007**: El sistema MUST seguir admitiendo que todo el sueldo se cargue en un único cobro, sin exigirle a quien no divide su pago que registre más de uno.
- **FR-008**: El sistema MUST mostrar el detalle de los cobros del mes (fecha y monto de cada uno), además del total.
- **FR-009**: Los ingresos ya guardados con el esquema de un monto único por mes MUST migrarse a un cobro equivalente por mes, sin perder ningún dato existente.

### Key Entities

- **CobroIngreso**: un cobro de sueldo. Tiene fecha y monto; el mes al que pertenece se deriva de la fecha, igual que una `Transaccion` o un `AporteAhorro`. Reemplaza a la fila única `Ingreso` por mes de la spec 001; el ingreso total de un mes pasa a ser un valor derivado (suma de sus `CobroIngreso`), no un dato guardado directamente.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario cuyo sueldo llega en dos partes registra ambas y ve el total mensual correcto sin hacer la suma a mano.
- **SC-002**: Registrar un cobro adicional toma menos de 15 segundos, el mismo estándar que registrar un gasto (SC-002 de la spec 001).
- **SC-003**: El disponible proyectado, el disponible real y la sugerencia de ahorro dan el mismo resultado que si el ingreso se hubiera cargado en un solo monto igual a la suma de los cobros — cero diferencia de comportamiento para quien no divide su sueldo.
- **SC-004**: Migrar una instalación existente conserva el ingreso de cada mes ya registrado, sin que el usuario tenga que volver a cargarlo.

## Assumptions

- Un cobro no lleva un nombre ni una etiqueta ("quincena", "fin de mes"): alcanza con su fecha y monto, igual que un aporte de ahorro (`AporteAhorro`, spec 001) — no se agrega un campo de descripción porque ningún escenario lo pide.
- No hay un límite de cantidad de cobros por mes.
- El formulario para registrar un cobro sigue el mismo patrón que el de un gasto o un aporte de ahorro: monto y fecha, con la fecha precargada en hoy.
- Al migrar los datos existentes, cada `Ingreso` guardado con el esquema anterior se convierte en un `CobroIngreso` con fecha el primer día de ese mes: es la única fecha razonable cuando el dato original nunca tuvo una.
- Esta funcionalidad NO incluye un seguimiento de disponible por fecha dentro del mes (por ejemplo, "cuánto tengo ya cobrado hoy" antes de que llegue el segundo cobro): eso sería una funcionalidad distinta, de flujo de caja diario, que ningún escenario actual pide (Principio V, YAGNI). El disponible sigue siendo una cifra mensual, como en la spec 001.
