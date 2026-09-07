# Feature Specification: Suscripción premium

**Feature Branch**: `004-suscripcion-premium`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "Monetizar la app mediante una suscripción paga dentro de la app (Google Play Billing) que desbloquea tres funcionalidades: Deudas en cuotas (feature 001, US4), Ahorro (feature 001, US5) y la captura automática de consumos por notificaciones bancarias (feature 002, completa). El resto de la app sigue siendo gratis, sin límite de tiempo ni de uso. Es una suscripción recurrente, no un pago único. Al vencer o cancelarse, los datos ya cargados en Deudas y Ahorro NO se borran, pero esas pantallas y la captura de notificaciones vuelven a mostrarse bloqueadas hasta renovar. La app debe ofrecer restaurar la suscripción."

**Depende de**: [001-gestion-sueldo-ahorro](../001-gestion-sueldo-ahorro/spec.md) (US4 Deudas, US5 Ahorro) y [002-captura-notificaciones-bancarias](../002-captura-notificaciones-bancarias/spec.md) — esta especificación no cambia lo que esas funcionalidades hacen, solo bajo qué condición quedan accesibles.

**Requiere**: la enmienda ya aprobada al Principio I de la constitución del proyecto (v2.0.0), que permite que la verificación de una compra de Google Play Billing se conecte a los servidores de Google sin que ningún dato financiero del usuario salga del dispositivo.

## Contexto y alcance

Hasta ahora toda la app es gratuita. Esta funcionalidad introduce una
suscripción paga que desbloquea las tres partes más elaboradas de la app —
Deudas, Ahorro y la captura automática de consumos— mientras que el uso
básico (registrar el sueldo, presupuestar, ver el resumen del mes y anotar
gastos a mano) sigue siendo gratis para siempre, sin límite de tiempo ni de
cantidad de uso.

**Dos límites que definen el alcance:**

- **No es un cambio de esas funcionalidades, es una condición de acceso.**
  Deudas, Ahorro y la captura de notificaciones se comportan exactamente como
  ya especifican 001 y 002; lo único nuevo es la comprobación de si hay una
  suscripción activa antes de mostrarlas.
- **Los datos del usuario nunca son la moneda de cambio.** Vencer o cancelar
  la suscripción bloquea el acceso a esas pantallas, nunca borra lo que el
  usuario ya cargó en ellas.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Descubrir qué se desbloquea (Priority: P1)

Un usuario sin suscripción toca la pestaña Deudas o Ahorro, o intenta activar
la captura automática de notificaciones. En vez de la pantalla habitual, ve
una explicación de qué se desbloquea con la suscripción y su precio, con una
opción clara para suscribirse.

**Why this priority**: es el primer contacto con la monetización; si no
comunica bien qué se compra, no hay conversión posible.

**Independent Test**: se prueba entrando a Deudas o Ahorro sin suscripción
activa y verificando que se muestra el aviso en vez de la pantalla real, con
el precio visible.

**Acceptance Scenarios**:

1. **Given** un usuario sin suscripción activa, **When** toca la pestaña Deudas, **Then** ve una pantalla que explica que Deudas es parte de lo premium, junto con Ahorro y la captura de notificaciones, con el precio mensual, el precio anual y que el primer mes es gratis en cualquiera de los dos.
2. **Given** esa misma situación, **When** toca la pestaña Ahorro, **Then** ve el mismo tipo de aviso, específico para Ahorro.
3. **Given** un usuario sin suscripción, **When** intenta activar la captura automática de notificaciones (feature 002), **Then** ve el aviso de suscripción en vez del flujo de activación del permiso.
4. **Given** el aviso de suscripción, **When** el usuario lo cierra sin suscribirse, **Then** vuelve a la pantalla anterior sin que se le haya cobrado ni pedido nada.

---

### User Story 2 - Elegir un plan, probar gratis y desbloquear al instante (Priority: P1)

El usuario decide suscribirse, elige entre pagar mes a mes o pagar anual (más
conveniente), y arranca un mes de prueba gratis sin que se le cobre todavía.
Al volver a la app ve Deudas y Ahorro disponibles de inmediato, sin tener que
reiniciarla. Al terminar el mes de prueba, Google le cobra automáticamente el
plan que eligió, salvo que haya cancelado antes.

**Why this priority**: es el momento que genera el ingreso; tiene que ser
confiable, dejar claro qué se está por cobrar y no dejar al usuario pagando
sin recibir lo que compró.

**Independent Test**: se prueba completando una suscripción de prueba en cada
plan y verificando que las pantallas premium quedan accesibles sin reiniciar
la app, que no hay cobro durante el mes de prueba, que una compra cancelada o
fallida no desbloquea nada, y que al vencer la prueba se cobra el plan
elegido si no se canceló antes.

**Acceptance Scenarios**:

1. **Given** el aviso de suscripción, **When** el usuario elige el plan mensual o el anual, **Then** ve con claridad el precio de ese plan y que el primer mes es gratis antes del primer cobro.
2. **Given** un plan elegido, **When** el usuario completa la suscripción en Google Play, **Then** Deudas, Ahorro y la activación de captura de notificaciones quedan disponibles de inmediato, sin salir ni reiniciar la app, y sin ningún cobro todavía.
3. **Given** una compra en curso, **When** el usuario la cancela antes de completarla, **Then** ninguna función premium se desbloquea y no se le cobra nada.
4. **Given** una compra que Google rechaza (tarjeta declinada, etc.), **When** el usuario vuelve a la app, **Then** sigue viendo el aviso de suscripción, sin acceso premium.
5. **Given** una suscripción en período de prueba, **When** el usuario consulta su estado dentro de la app, **Then** ve que está en prueba gratis, qué plan cobrará y desde cuándo.
6. **Given** el mes de prueba llega a su fin sin que el usuario cancele, **When** Google procesa el primer cobro, **Then** la suscripción sigue activa sin que el usuario tenga que hacer nada, con el plan y el precio que eligió.

---

### User Story 3 - Lo básico sigue gratis sin límite (Priority: P1)

Un usuario que nunca se suscribe sigue registrando su sueldo, presupuestando,
viendo su resumen mensual y anotando gastos a mano, sin límite de tiempo ni
de cantidad, y sin que la app le muestre avisos de pago en esas pantallas.

**Why this priority**: es la garantía de que la monetización no degrada el
producto que ya existe; sin esto, la app deja de cumplir lo que prometía
antes de monetizar.

**Independent Test**: se prueba usando la app intensivamente sin suscribirse
—muchos meses, muchas obligaciones, muchos gastos— y verificando que ninguna
de esas pantallas exige pago ni deja de funcionar con el tiempo.

**Acceptance Scenarios**:

1. **Given** un usuario sin suscripción, **When** usa Presupuesto, Resumen y Gastos durante varios meses, **Then** ninguna de esas pantallas se bloquea ni muestra avisos de pago.
2. **Given** un usuario sin suscripción, **When** registra una gran cantidad de obligaciones o gastos, **Then** no encuentra ningún límite de cantidad.

---

### User Story 4 - La suscripción vence o se cancela (Priority: P2)

Un usuario suscripto deja de pagar (cancela, o falla el cobro y se agota el
período de gracia de Google). Deudas y Ahorro vuelven a mostrarse bloqueadas,
pero el resumen del mes no cambia ni una cifra: las cuotas se siguen contando
en el presupuesto, porque esa plata se debe igual. Lo que se pierde es la
gestión, nunca los datos ni el cálculo del mes.

**Why this priority**: sin esto, cancelar se sentiría como perder datos, lo
que es exactamente lo que el Principio I y la confianza del usuario no
permiten arriesgar.

**Independent Test**: se prueba suscribiendo, cargando datos en Deudas y
Ahorro, simulando el vencimiento, y verificando que los datos siguen intactos
al reactivar la suscripción más tarde.

**Acceptance Scenarios**:

1. **Given** una suscripción vencida o cancelada, **When** el usuario abre Deudas, **Then** ve el aviso de suscripción en vez de sus deudas, no una pantalla vacía.
2. **Given** esa misma situación, **When** el usuario reactiva la suscripción, **Then** vuelve a ver exactamente las deudas y aportes de ahorro que tenía antes de que venciera.
3. **Given** una suscripción vencida, **When** el usuario consulta el resumen del mes, **Then** ve exactamente el mismo presupuesto y el mismo desglose por categoría que antes de que venciera —las cuotas de deuda siguen contadas y el detalle de tarjeta de crédito se sigue pudiendo abrir—, sin que ninguna cifra cambie por el estado de la suscripción.
4. **Given** la captura de notificaciones activa antes de vencer, **When** la suscripción vence, **Then** la captura deja de procesar notificaciones nuevas, y los consumos pendientes de confirmar que ya existían no se pierden.

---

### User Story 5 - Restaurar la suscripción (Priority: P2)

El usuario reinstala la app, o la instala en otro dispositivo con la misma
cuenta de Google. Sin volver a pagar, restaura la suscripción y recupera el
acceso a Deudas y Ahorro.

**Why this priority**: es una exigencia de la política de Google Play para
cualquier compra dentro de la app, y sin esto un usuario legítimo se sentiría
estafado.

**Independent Test**: se prueba instalando la app de nuevo (o en otro
dispositivo) con una cuenta de Google que ya tiene la suscripción activa, y
verificando que restaurarla no requiere pagar de nuevo.

**Acceptance Scenarios**:

1. **Given** una cuenta de Google con la suscripción activa, **When** el usuario instala la app en un dispositivo nuevo y pide restaurar, **Then** recupera el acceso premium sin pagar de nuevo.
2. **Given** una cuenta de Google sin ninguna suscripción, **When** el usuario pide restaurar, **Then** la app le informa que no encontró ninguna suscripción activa para esa cuenta.

---

### Edge Cases

- **Sin conexión al abrir Deudas o Ahorro con suscripción activa comprada antes**: la app usa el último estado de suscripción conocido localmente y permite el acceso; no exige red cada vez que se abre la pantalla.
- **Reembolso otorgado por Google**: la próxima vez que la app consulta el estado, vuelve a bloquear el acceso, igual que un vencimiento normal.
- **La misma cuenta de Google con la suscripción activa en dos dispositivos**: ambos la reconocen, porque la suscripción pertenece a la cuenta, no a un dispositivo.
- **El usuario cambia de cuenta de Google en el mismo dispositivo**: la suscripción no se transfiere sola; si la nueva cuenta no la tiene, debe suscribirse o restaurar con la cuenta correcta.
- **Compra completada pero la confirmación de Google tarda**: la app no debe cobrar dos veces ni desbloquear dos veces; muestra el acceso premium en cuanto confirma la compra, sin duplicar nada.
- **Google otorga un período de gracia tras un cobro fallido**: el acceso premium se mantiene durante ese período, no se corta de inmediato al primer fallo de cobro.
- **El usuario cancela durante el mes de prueba**: no se le cobra nada, y conserva el acceso premium hasta que termine el mes de prueba ya iniciado, no menos.
- **El usuario cancela y vuelve a suscribirse más adelante**: si Google ya no le ofrece otro período de prueba a esa cuenta (una cuenta solo tiene derecho a probar gratis una vez por suscripción), la app se lo cobra desde el primer día, sin prometerle una segunda prueba gratis.
- **El usuario quiere cambiar de plan mensual a anual (o al revés) con la suscripción activa**: Google Play gestiona el cambio de plan y el prorrateo; la app refleja el plan vigente después del cambio, sin lógica propia de facturación.

## Requirements *(mandatory)*

### Functional Requirements

**Acceso y bloqueo**

- **FR-001**: El sistema MUST mostrar un aviso de suscripción, en vez de la pantalla real, al intentar entrar a Deudas sin una suscripción activa.
- **FR-002**: El sistema MUST mostrar un aviso de suscripción, en vez de la pantalla real, al intentar entrar a Ahorro sin una suscripción activa.
- **FR-003**: El sistema MUST exigir una suscripción activa para activar la captura automática de notificaciones (feature 002); sin suscripción, el flujo de activación de ese permiso MUST NOT iniciarse.
- **FR-004**: El sistema MUST permitir el uso completo e ilimitado en el tiempo y en la cantidad de Presupuesto, Resumen, Gastos y Categorías sin ninguna suscripción.
- **FR-005**: El aviso de suscripción MUST explicar qué funcionalidades desbloquea, el precio del plan mensual, el precio del plan anual, y que el primer mes es gratis en cualquiera de los dos, antes de iniciar cualquier compra.

**Compra**

- **FR-006**: El sistema MUST permitir suscribirse mediante el mecanismo de compras de Google Play, ofreciendo un plan mensual y un plan anual a elección del usuario.
- **FR-006a**: El sistema MUST ofrecer un mes de prueba sin cobro al iniciar la suscripción, sin importar el plan elegido.
- **FR-007**: Al completarse la compra (o al iniciar el mes de prueba), el sistema MUST desbloquear el acceso premium sin requerir que el usuario reinicie la app.
- **FR-008**: El sistema MUST permitir cancelar una compra en curso sin efecto: sin cobro y sin desbloqueo.
- **FR-009**: El sistema MUST mostrar el estado vigente de la suscripción en un lugar accesible de la app: si está en prueba gratis, activa y hasta cuándo, o no activa, y con qué plan.

**Vencimiento y datos**

- **FR-010**: Cuando la suscripción vence, se cancela, o se reembolsa, el sistema MUST bloquear de nuevo el acceso a Deudas, Ahorro y la captura de notificaciones, de la misma forma que si nunca se hubiera suscrito.
- **FR-011**: Ningún dato ya guardado en Deudas o Ahorro, ni las asociaciones comercio-categoría o los consumos pendientes de la captura de notificaciones, MUST perderse ni borrarse por el vencimiento o la cancelación de la suscripción.
- **FR-012**: El resumen del mes MUST mostrar el presupuesto completo —cuotas de deuda incluidas— y su desglose por categoría, esté vigente la suscripción o no: ninguna cifra financiera puede cambiar según el estado de pago de la app. Lo que la suscripción bloquea es *gestionar* deudas y ahorro, no verlas contadas en el mes (D6 de research.md; revisado 2026-08-31, antes exigía avisar de una omisión que no ocurre).
- **FR-013**: El sistema MUST respetar cualquier período de gracia que Google Play otorgue tras un cobro fallido, sin bloquear el acceso antes de que ese período termine.

**Restauración**

- **FR-014**: El sistema MUST ofrecer una acción explícita para restaurar una suscripción ya comprada con la cuenta de Google actual.
- **FR-015**: El sistema MUST informar con claridad cuando la cuenta de Google actual no tiene ninguna suscripción para restaurar.

**Privacidad**

- **FR-016**: La verificación y restauración de la suscripción MUST NOT transmitir ningún dato financiero del usuario (sueldo, gastos, deudas, ahorro); solo interactúa con el mecanismo de compras de Google para conocer el identificador del producto y el estado de la licencia.

### Key Entities

- **Suscripción premium**: el plan pago que el usuario contrata a través de Google Play. Tiene un plan elegido (mensual o anual), un estado (en prueba gratis, activa, en gracia, vencida, cancelada) y una fecha hasta la cual cubre el período vigente. Es una sola cuenta de Google Play la que la posee, no un dispositivo.
- **Alcance premium**: el conjunto de partes de la app que dependen de una suscripción activa — Deudas (001, US4), Ahorro (001, US5) y la captura automática de notificaciones (002) — frente a todo lo demás, que es y seguirá siendo gratis. Es el mismo alcance premium sin importar qué plan haya elegido el usuario.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario sin suscripción que toca Deudas o Ahorro ve el aviso de suscripción de inmediato, nunca una pantalla vacía o con datos parciales.
- **SC-002**: Completar la compra desbloquea el acceso premium sin reiniciar la app, en el 100% de los casos de prueba.
- **SC-003**: Ningún dato cargado en Deudas o Ahorro se pierde al vencer, cancelar o reembolsarse la suscripción, verificable reactivándola y comparando los datos antes y después.
- **SC-004**: Restaurar la suscripción en un dispositivo nuevo con la misma cuenta de Google desbloquea el acceso sin pagar de nuevo, en el 100% de los casos.
- **SC-005**: Ninguna pantalla de Presupuesto, Resumen, Gastos o Categorías muestra un aviso de pago ni deja de funcionar, sin importar cuánto tiempo o cuánto use la app un usuario sin suscripción.

## Assumptions

- **Dos planes, un solo alcance premium**: mensual y anual desbloquean exactamente lo mismo (Deudas, Ahorro y captura de notificaciones); no hay niveles de funcionalidad distintos según el plan, solo distinta forma de pago. Ofrecer un tercer plan o niveles de funcionalidad separados sería un cambio de alcance nuevo.
- **Precio exacto pendiente**: los montos concretos del plan mensual y del anual se definen más adelante, en el plan técnico o directamente en Google Play Console; esta spec fija la estructura (dos planes, un mes de prueba en ambos), no los números.
- **Una sola prueba gratis por cuenta de Google**: es una regla de la propia plataforma de suscripciones, no una decisión de la app — quien ya usó su mes de prueba y cancela no tiene derecho a otro al volver a suscribirse.
- **La cancelación se gestiona en Google Play, no en la app**: el usuario cancela desde la propia interfaz de suscripciones de Google Play; la app solo refleja el estado resultante, no construye una pantalla propia de cancelación.
- **El período de gracia y los reintentos de cobro los gestiona Google Play Billing**: la app reacciona al estado que Google le informa, no implementa su propia lógica de reintento de cobro.
- **Verificación offline con el último estado conocido**: la app no exige conexión cada vez que se abre una pantalla premium; confía en el último estado de suscripción que pudo verificar, y lo actualiza cuando hay conexión disponible.
