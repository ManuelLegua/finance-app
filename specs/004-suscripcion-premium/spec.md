# Feature Specification: Apoyo voluntario (propina)

**Feature Branch**: `004-suscripcion-premium`

**Created**: 2026-08-29

**Revisada**: 2026-09-12 — **cambio de alcance mayor**: de suscripción paga con
funcionalidades bloqueadas a **propina voluntaria sin nada bloqueado**. Ver
[Revisión 2026-09-12](#revisión-2026-09-12-de-suscripción-a-propina).

**Status**: Draft

**Input original (2026-08-29)**: "Monetizar la app mediante una suscripción paga dentro de la app (Google Play Billing) que desbloquea tres funcionalidades: Deudas en cuotas (feature 001, US4), Ahorro (feature 001, US5) y la captura automática de consumos por notificaciones bancarias (feature 002, completa)."

**Input de la revisión (2026-09-12)**: "No quiero cobrar por usar el apk, pero quiero generar algún tipo de ingreso."

**Depende de**: [001-gestion-sueldo-ahorro](../001-gestion-sueldo-ahorro/spec.md) y [002-captura-notificaciones-bancarias](../002-captura-notificaciones-bancarias/spec.md) — tras esta revisión la dependencia es **solo de contexto**: esta especificación ya no condiciona el acceso a ninguna de las dos.

**Requiere**: la enmienda ya aprobada al Principio I de la constitución del proyecto (v2.0.0), que permite que una compra de Google Play Billing se conecte a los servidores de Google sin que ningún dato financiero del usuario salga del dispositivo. La revisión **no necesita una enmienda nueva**: reduce lo que sale del dispositivo, no lo amplía.

## Revisión 2026-09-12: de suscripción a propina

La versión anterior de esta especificación bloqueaba Deudas, Ahorro y la
captura de notificaciones detrás de una suscripción mensual o anual. Se
descarta ese modelo por decisión del dueño del producto: **la app se reparte
completa y gratis**, y el ingreso, si existe, es un aporte voluntario de quien
quiera hacerlo.

**Por qué el cambio no es un capricho de alcance.** El modelo anterior cobraba
por algo que no le cuesta nada servir: Deudas y Ahorro corren enteras en el
teléfono del usuario, sin servidor ni costo marginal. La fricción que
introducía el bloqueo —un usuario que instala la app y encuentra dos de cinco
pestañas cerradas— pesaba más que un ingreso que, con el público real de la
app, todavía es cero. La propina conserva la posibilidad de ingreso y elimina
toda la fricción.

**Qué se conserva del trabajo ya hecho**: el mecanismo de compras de Google
Play (T001–T016 de `tasks.md`), el aislamiento del SDK dentro de un
repositorio, el patrón de estado para la UI y el criterio de que ningún dato
financiero viaja en una compra. Lo que se descarta es todo lo que **bloquea**:
el paywall, la guarda del cascarón, el estado cacheado de vigencia y la tabla
que lo guardaba.

**Qué pasó con cada requisito anterior:**

| FR anterior | Destino |
|---|---|
| FR-001, FR-002, FR-003 (bloquear Deudas, Ahorro, captura) | **Eliminados e invertidos**: FR-001 de esta versión prohíbe bloquear nada. |
| FR-004 (lo básico gratis sin límite) | **Ampliado**: ahora aplica a la app entera (FR-001). |
| FR-005 (explicar qué desbloquea y su precio) | **Reemplazado** por FR-004/FR-005: explicar qué es la propina y que no desbloquea nada. |
| FR-006, FR-006a (planes y mes de prueba) | **Eliminados**: no hay planes ni prueba, hay montos de propina (FR-003). |
| FR-007 (desbloquear sin reiniciar) | **Eliminado**: no hay nada que desbloquear. |
| FR-008 (cancelar sin efecto) | **Conservado** como FR-008. |
| FR-009 (mostrar estado de la suscripción) | **Eliminado**: una propina no tiene estado vigente que mostrar. |
| FR-010, FR-013 (vencimiento, gracia) | **Eliminados**: una compra única no vence. |
| FR-011 (no perder datos al vencer) | **Eliminado por innecesario**: nada condiciona el acceso a los datos. |
| FR-012 (el resumen no depende de la suscripción) | **Absorbido por FR-002**, que lo extiende a toda la app. |
| FR-014, FR-015 (restaurar) | **Eliminados**: no aplica a un consumible repetible (ver research.md D8). |
| FR-016 (privacidad del pago) | **Conservado** como FR-009. |

---

## Contexto y alcance

La app es y seguirá siendo gratuita y completa: quien la instala tiene acceso
a todo, sin límite de tiempo, de cantidad ni de funcionalidad. Esta
especificación agrega **una sola cosa**: un lugar tranquilo, dentro de
Ajustes, donde quien quiera apoyar el proyecto pueda dejar una propina por
única vez a través de Google Play.

**Tres límites que definen el alcance:**

- **No desbloquea nada.** Apoyar no cambia ni una pantalla, ni un cálculo, ni
  un límite. La app se comporta exactamente igual antes y después. Esto no es
  un efecto secundario: es el requisito central (FR-002), y lo que separa una
  propina de una compra.
- **Nunca interrumpe.** El apoyo se ofrece en un solo lugar al que el usuario
  entra por su cuenta. No hay avisos, ni recordatorios, ni pantallas
  intersticiales, ni insistencia tras rechazarlo.
- **No cambia la privacidad de la app.** Sigue valiendo la enmienda v2.0.0 sin
  ampliarla: lo único que cruza la red es el identificador del producto y el
  token de compra que gestiona la propia biblioteca de Google Play.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Usar la app completa sin pagar nunca (Priority: P1)

Un usuario instala la app y usa todo lo que tiene —presupuesto, resumen,
gastos, deudas en cuotas, ahorro, categorías, tarjetas, respaldo y la captura
de consumos— sin pagar, sin registrarse y sin encontrarse ningún aviso de
pago, por mucho tiempo que pase y por muchos datos que cargue.

**Why this priority**: es la promesa del producto tras esta revisión. Si algo
quedara bloqueado, esta especificación estaría incumplida, no incompleta.

**Independent Test**: se prueba recorriendo todos los destinos de la app sin
haber apoyado nunca y verificando que ninguno muestra un aviso de pago ni
sustituye su contenido.

**Acceptance Scenarios**:

1. **Given** un usuario que nunca apoyó, **When** abre Deudas o Ahorro, **Then** ve sus deudas y sus aportes, no un aviso de pago.
2. **Given** ese mismo usuario, **When** activa la captura de consumos, **Then** el flujo de activación arranca sin pedirle ninguna compra.
3. **Given** ese mismo usuario, **When** registra una gran cantidad de obligaciones, gastos o meses, **Then** no encuentra ningún límite de cantidad ni de tiempo.
4. **Given** ese mismo usuario, **When** recorre la app entera, **Then** el único lugar donde se menciona apoyar económicamente es Ajustes, y solo si entra ahí.

---

### User Story 2 - Dejar una propina (Priority: P2)

Un usuario al que la app le resultó útil entra a Ajustes, encuentra la opción
de apoyar el proyecto, elige uno de los montos disponibles y lo paga por
Google Play. La app le agradece y nada más cambia.

**Why this priority**: es el único camino de ingreso, pero es secundario
frente a US1: una app que no se puede usar gratis no tiene a quién pedirle una
propina.

**Independent Test**: se prueba entrando a la pantalla de apoyo, verificando
que muestra los montos con el precio que informa Google Play, completando una
compra de prueba, y comprobando que la app agradece y que ninguna pantalla
cambió de comportamiento.

**Acceptance Scenarios**:

1. **Given** la pantalla de apoyo, **When** el usuario la abre, **Then** ve qué es la propina, que no desbloquea nada, y los montos disponibles con su precio tal como lo informa Google Play.
2. **Given** un monto elegido, **When** el usuario completa el pago, **Then** la app se lo agradece de forma clara.
3. **Given** una propina ya dejada, **When** el usuario vuelve a la pantalla de apoyo, **Then** puede dejar otra: apoyar no es un acto único.
4. **Given** el flujo de pago abierto, **When** el usuario lo cancela, **Then** no se le cobra nada y la app no muestra ningún error ni reproche.
5. **Given** una compra que Google rechaza, **When** el usuario vuelve a la app, **Then** ve el motivo y puede reintentar, sin que nada más haya cambiado.

---

### User Story 3 - Que apoyar no se vuelva un problema (Priority: P3)

El usuario intenta apoyar sin conexión, o cierra la app en medio del pago, o
Google tarda en confirmar. En ninguno de esos casos queda un cobro sin
reconocer ni la app queda en un estado raro.

**Why this priority**: no agrega valor visible, pero evita el peor resultado
posible de esta feature: que alguien pague y no pase nada.

**Independent Test**: se prueba intentando apoyar sin conexión, y
completando una compra que quede pendiente de confirmación, verificando que la
app la reconoce la próxima vez que se abre la pantalla de apoyo.

**Acceptance Scenarios**:

1. **Given** un dispositivo sin conexión, **When** el usuario abre la pantalla de apoyo, **Then** la app dice que no pudo consultar los montos y ofrece reintentar, sin inventar ningún precio.
2. **Given** una compra que quedó sin confirmar, **When** el usuario vuelve a abrir la pantalla de apoyo, **Then** la app la reconoce y la da por completada, sin cobrar de nuevo.
3. **Given** un dispositivo sin Google Play disponible, **When** el usuario abre Ajustes, **Then** la app no se rompe: la sección de apoyo explica que no está disponible, y el resto de Ajustes funciona normal.

---

### Edge Cases

- **Google Play no está instalado o no responde** (emulador sin servicios de Google, dispositivo sin la tienda): la sección de apoyo lo dice y no ofrece montos. Ninguna otra parte de la app se ve afectada.
- **El usuario apoya dos veces seguidas**: se le cobra dos veces, porque eso es lo que pidió. No hay tope ni advertencia de "ya apoyaste": sería tratar un regalo como una compra duplicada.
- **La confirmación de Google tarda o llega con la app cerrada**: la próxima vez que se abre la pantalla de apoyo, la compra pendiente se reconoce y se acusa recibo, para que Google no la reembolse sola a los tres días.
- **El usuario pide un reembolso a Google**: no hay nada que revertir en la app, porque apoyar no concedió nada.
- **Un respaldo restaurado trae datos de una versión con suscripción**: se migra como cualquier respaldo viejo y el rastro de suscripción se descarta, porque ya no significa nada (ver research.md D9).
- **El usuario nunca entra a Ajustes**: no se entera de que existe la opción de apoyar, y eso es aceptable: es el precio de no interrumpir nunca (FR-006).

## Requirements *(mandatory)*

### Functional Requirements

**La app es gratis y completa**

- **FR-001**: El sistema MUST permitir el uso completo e ilimitado —en tiempo, en cantidad y en funcionalidad— de toda la app sin ningún pago: ninguna pantalla, acción ni dato MUST quedar condicionado a haber apoyado.
- **FR-002**: Ninguna cifra financiera ni ningún comportamiento de la app MUST cambiar según si el usuario apoyó o no.

**Apoyar**

- **FR-003**: El sistema MUST ofrecer dejar una propina por única vez mediante el mecanismo de compras de Google Play, con varios montos a elección del usuario.
- **FR-004**: El sistema MUST mostrar el precio de cada monto tal como lo informa Google Play, antes de iniciar ninguna compra, y MUST NOT mostrar un precio inventado, estimado ni guardado de una consulta anterior.
- **FR-005**: La pantalla de apoyo MUST decir explícitamente que apoyar no desbloquea ninguna funcionalidad.
- **FR-006**: El ofrecimiento de apoyo MUST vivir únicamente en Ajustes, al que el usuario entra por su cuenta; el sistema MUST NOT mostrar avisos, recordatorios ni interrupciones de apoyo en ninguna otra parte de la app.
- **FR-007**: El sistema MUST permitir apoyar más de una vez, sin tope ni advertencia.
- **FR-008**: Cancelar una compra en curso MUST NOT tener ningún efecto ni producir ningún mensaje de error: es un flujo esperado, no un fallo.

**Que nadie pague en vano**

- **FR-009**: La compra MUST NOT transmitir ningún dato financiero del usuario (sueldo, gastos, deudas, ahorro); solo interactúa con el mecanismo de compras de Google para conocer el identificador del producto y el estado de la compra.
- **FR-010**: El sistema MUST acusar recibo de toda compra completada, incluidas las que quedaron pendientes de una sesión anterior, para que Google no la reembolse por falta de confirmación.
- **FR-011**: Cuando no se puedan consultar los montos (sin conexión, sin Google Play, o la tienda no responde), el sistema MUST decirlo con un motivo entendible y MUST ofrecer reintentar.
- **FR-012**: El sistema MUST agradecer de forma visible una compra completada: quien pagó tiene que saber que llegó.

### Key Entities

- **Monto de apoyo**: uno de los importes que se pueden dejar como propina. Su precio y su descripción los informa Google Play en el momento; la app solo conoce su identificador y el orden en que se muestran. No se persiste nada de él.

*No hay ninguna entidad persistida en esta especificación.* Una propina no
deja estado en la app: se paga, se agradece y se acabó. El historial de
compras vive en Google Play, que es de quien es.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario que nunca apoyó accede al 100% de las pantallas y acciones de la app, sin excepción.
- **SC-002**: Ninguna pantalla fuera de Ajustes menciona pagar, apoyar o suscribirse, verificable recorriendo todos los destinos de la app.
- **SC-003**: Completar una propina no produce ningún cambio observable en el comportamiento de la app, verificable comparando cualquier pantalla antes y después.
- **SC-004**: Ninguna compra completada queda sin acusar recibo, en el 100% de los casos de prueba, incluidas las interrumpidas por cerrar la app.
- **SC-005**: Sin conexión, la pantalla de apoyo nunca muestra un precio: muestra el motivo y la opción de reintentar.

## Assumptions

- **Compras únicas repetibles, no suscripción**: el producto de Google Play es un consumible, para que una misma persona pueda apoyar cuantas veces quiera. No hay nada que restaurar, porque no hay nada que se conceda (research.md D8).
- **Los montos exactos se definen en Google Play Console**, no en esta spec ni en el código: la app pide los identificadores y muestra lo que la tienda responda.
- **La app no lleva registro de quién apoyó ni cuánto**: no se persiste nada. Si alguna vez hiciera falta (por ejemplo para no volver a ofrecerlo), sería un cambio de alcance nuevo, con su propia justificación frente al Principio V.
- **El ingreso esperado es bajo y no condiciona ninguna decisión de producto**: esta feature existe para que apoyar sea posible, no para financiar el proyecto.
- **Google Play es el único medio de pago**: enlaces a plataformas externas de donación quedan fuera de alcance; la política de Google Play sobre pagos alternativos dentro de una app es restrictiva y ningún requisito vigente lo pide.
