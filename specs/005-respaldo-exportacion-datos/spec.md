# Feature Specification: Respaldo y exportación de datos

**Feature Branch**: `005-respaldo-exportacion-datos`

**Created**: 2026-09-07

**Status**: Draft

**Input**: User description: "Respaldo y exportación de datos: la app finance-app es local y sin conexión (Principio IV de la constitución — nada sale del dispositivo salvo lo que el propio usuario decida exportar explícitamente), y hoy no existe ninguna forma de respaldar ni exportar lo que hay en el SQLite local (presupuesto, gastos, deudas, ahorro, cobros de ingreso). Con un solo usuario probando en su propio teléfono es asumible, pero antes de repartir la app a otros probadores hace falta poder sacar una copia de los datos (por ejemplo a un archivo que el usuario mismo comparta o guarde donde quiera) y poder restaurarla, para no perder todo si se reinstala la app o se cambia de teléfono."

**Depende de**: [001-gestion-sueldo-ahorro](../001-gestion-sueldo-ahorro/spec.md), [002-captura-notificaciones-bancarias](../002-captura-notificaciones-bancarias/spec.md) y [003-cobros-parciales-ingreso](../003-cobros-parciales-ingreso/spec.md) — esta especificación no cambia lo que esas funcionalidades hacen, solo agrega una forma de sacar y volver a cargar todo lo que guardan.

**Requiere**: la enmienda ya aprobada al Principio I de la constitución del proyecto (v3.0.0, 2026-09-07), que habilita el respaldo y la exportación a pedido del usuario. Se aprobó con la misma lógica que la excepción de Google Play Billing de v2.0.0: la salida de datos existe, pero **nunca es automática ni silenciosa** — ocurre solo cuando el usuario la pide, con datos suyos, y es él quien decide adónde van. Sin una acción explícita suya, la app se comporta igual que antes de esta funcionalidad.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Exportar un respaldo completo (Priority: P1)

El usuario, desde Ajustes, pide exportar sus datos y la app genera un único
archivo con todo lo que tiene cargado. El usuario decide qué hacer con ese
archivo: guardarlo en el propio teléfono, o compartirlo por el medio que
elija (correo, un servicio de almacenamiento, etc.) usando el mecanismo
nativo del sistema para compartir archivos.

**Why this priority**: sin esto no existe ningún respaldo posible; es el
requisito mínimo para que reinstalar la app o cambiar de teléfono no
signifique perder todo. Tiene valor por sí solo aunque todavía no exista
forma de restaurar: ya es una copia de seguridad fuera del dispositivo.

**Independent Test**: se prueba exportando con datos ya cargados y
comprobando que el archivo generado contiene esos mismos datos.

**Acceptance Scenarios**:

1. **Given** datos cargados (presupuesto, gastos, deudas, ahorro, cobros de
   ingreso), **When** el usuario pide exportar desde Ajustes, **Then** la app
   genera un archivo con todo eso y le deja elegir dónde guardarlo o con quién
   compartirlo.
2. **Given** que la exportación terminó, **When** el usuario vuelve a
   Ajustes, **Then** tiene la certeza de que el archivo se generó
   correctamente, sin quedar en duda.
3. **Given** un problema al generar el archivo (por ejemplo, sin espacio en
   el dispositivo), **When** ocurre, **Then** la app lo informa con
   claridad y no deja ningún archivo a medio escribir.
4. **Given** una instalación recién hecha, sin ningún dato cargado todavía,
   **When** el usuario pide exportar, **Then** la app genera igual un
   archivo válido, sin fallar por falta de datos.

---

### User Story 2 - Restaurar desde un respaldo (Priority: P2)

El usuario, típicamente después de reinstalar la app o de cambiar de
teléfono, elige un archivo de respaldo generado antes por esta misma
funcionalidad, y la app reemplaza lo que tenga cargado por el contenido de
ese archivo.

**Why this priority**: completa el propósito de US1 — un respaldo que no se
puede restaurar no evita perder nada. Depende de que exista la exportación,
por eso va después.

**Independent Test**: se prueba exportando un respaldo, vaciando o
reinstalando la app, y comprobando que restaurar ese archivo devuelve
exactamente los mismos datos que había antes de exportar.

**Acceptance Scenarios**:

1. **Given** una instalación nueva sin datos, **When** el usuario restaura
   un archivo de respaldo válido, **Then** ve exactamente los mismos datos
   que tenía cuando lo exportó.
2. **Given** un archivo generado por una versión anterior de la app,
   **When** el usuario lo restaura en una versión más nueva, **Then** la
   restauración funciona igual, aplicando las mismas actualizaciones de
   datos que ya se aplican al actualizar la app sin restaurar nada.

---

### User Story 3 - No perder datos actuales por restaurar por error (Priority: P3)

El dispositivo ya tiene datos cargados (no es una instalación nueva) y el
usuario, por error o a propósito, intenta restaurar un archivo de respaldo.
Como la restauración reemplaza todo lo actual, el sistema se lo advierte con
todas las letras y le exige confirmar antes de tocar cualquier dato.

**Why this priority**: es una salvaguarda sobre US2, no una funcionalidad
aparte; sin ella, una restauración accidental podría borrar datos más
nuevos que los del archivo.

**Independent Test**: se prueba con datos ya cargados, iniciando una
restauración y comprobando que la app exige una confirmación explícita antes
de reemplazar nada, y que cancelar deja todo intacto.

**Acceptance Scenarios**:

1. **Given** datos ya cargados en el dispositivo, **When** el usuario elige
   restaurar un archivo, **Then** la app le advierte que esto va a
   reemplazar todo lo que tiene ahora, y pide una confirmación aparte antes
   de tocar cualquier dato.
2. **Given** esa advertencia, **When** el usuario cancela, **Then** ningún
   dato cambia.
3. **Given** un archivo que no es un respaldo válido de esta app (corrupto,
   de otra app, o de una versión más nueva de la que no se puede garantizar
   compatibilidad), **When** el usuario intenta restaurarlo, **Then** la app
   lo rechaza con un mensaje claro y ningún dato existente queda modificado.

---

### Edge Cases

- Restaurar un archivo de una versión de la app más vieja que la instalada:
  se actualiza con las mismas migraciones que ya existen, no hay un camino
  aparte para datos restaurados (ver FR-010).
- Restaurar un archivo de una versión más nueva que la app instalada: se
  rechaza con un mensaje claro, porque no se puede garantizar qué campos
  nuevos existen en ese archivo.
- El usuario sale de la app a mitad de una restauración: los datos previos
  no deben quedar en un estado parcialmente reemplazado (todo o nada).
- Espacio insuficiente en el dispositivo al momento de exportar.
- El usuario intenta restaurar el mismo archivo dos veces seguidas: el
  resultado es el mismo que restaurarlo una vez (idempotente).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST ofrecer, desde un lugar fijo de la app
  (Ajustes), una acción explícita para exportar todos los datos del usuario
  a un único archivo.
- **FR-002**: La exportación MUST incluir todo lo que el usuario cargó:
  presupuesto y obligaciones, gastos reales, tarjetas, deudas y sus cuotas,
  ahorro y metas, cobros de ingreso, y las asociaciones comercio-categoría
  aprendidas por la captura de notificaciones.
- **FR-003**: La exportación MUST excluir el estado de la suscripción
  premium (spec 004): ese estado solo se restaura contra Google Play
  ("Restaurar suscripción"), nunca desde un archivo local, para que un
  archivo de respaldo no pueda usarse para falsificar acceso pagado.
- **FR-004**: El sistema MUST dejar que el usuario decida qué hacer con el
  archivo exportado (guardarlo en el dispositivo o compartirlo por el medio
  que elija), sin subirlo a ningún servidor propio de la app.
- **FR-005**: El sistema MUST confirmar con claridad cuándo la exportación
  terminó con éxito, y MUST informar con claridad cualquier fallo, sin dejar
  un archivo a medio escribir.
- **FR-006**: El sistema MUST ofrecer, desde el mismo lugar fijo, una acción
  explícita para restaurar datos desde un archivo de respaldo generado por
  esta misma funcionalidad.
- **FR-007**: Si el dispositivo ya tiene datos cargados, el sistema MUST
  advertir explícitamente, antes de restaurar, que la restauración reemplaza
  todo lo actual, y MUST exigir una confirmación aparte antes de tocar
  cualquier dato.
- **FR-008**: El sistema MUST reemplazar todos los datos existentes con los
  del archivo restaurado (restauración completa) — no ofrece una
  restauración parcial ni combina ambas copias.
- **FR-009**: El sistema MUST rechazar un archivo que no sea un respaldo
  válido de esta app (corrupto, de otra app, o de una versión más nueva de
  la que no se puede garantizar compatibilidad) con un mensaje claro, sin
  modificar ningún dato existente en el intento.
- **FR-010**: Un archivo de respaldo generado por una versión anterior de la
  app MUST poder restaurarse en una versión más nueva, aplicando las mismas
  actualizaciones de datos que ya existen para actualizar una instalación.
- **FR-011**: Exportar y restaurar MUST estar disponible sin necesidad de la
  suscripción premium (spec 004): es una garantía sobre los datos del
  usuario, no una función avanzada.
- **FR-012**: El sistema MUST permitir exportar aunque no haya ningún dato
  cargado todavía (instalación recién hecha), generando un archivo válido
  igual.

### Key Entities

- **Archivo de respaldo**: una copia completa y autocontenida de los datos
  financieros del usuario en un momento dado. Es un único archivo que el
  usuario controla por completo — dónde se guarda, con quién se comparte —
  y que esta misma app sabe leer para restaurar. No incluye el estado de la
  suscripción premium.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un usuario que reinstala la app o cambia de teléfono recupera
  el 100% de sus datos financieros restaurando su último respaldo, sin
  volver a cargar nada a mano.
- **SC-002**: Exportar un respaldo toma menos de 15 segundos desde que el
  usuario lo pide hasta que tiene el archivo listo para guardar o compartir
  (mismo estándar de rapidez que registrar un gasto, SC-002 de la spec 001).
- **SC-003**: Ningún intento de restaurar un archivo inválido o
  incompatible deja los datos existentes del dispositivo en un estado peor
  que antes del intento.
- **SC-004**: El estado de la suscripción premium nunca cambia como
  resultado de exportar o restaurar un respaldo.

## Assumptions

- Exportar y restaurar son acciones manuales que el usuario dispara desde
  Ajustes. Esta funcionalidad NO incluye respaldos automáticos ni
  programados, ni recordatorios periódicos de hacer un respaldo: nadie lo
  pidió, y agregarlo hoy sería especular (Principio V, YAGNI).
- Restaurar reemplaza todo, no combina dos copias: es la opción más simple y
  predecible para un solo usuario, y evita la complejidad de resolver
  conflictos entre dos versiones de un mismo mes (Principio V, YAGNI).
- La funcionalidad es gratuita para todos los usuarios, con o sin
  suscripción premium: es una garantía sobre la propiedad de los datos,
  coherente con que la spec 004 (FR-011) ya promete que esos mismos datos
  nunca se pierden por dejar de pagar.
- El archivo de respaldo no está pensado para abrirse o analizarse fuera de
  la app (no es un export a planilla de cálculo para revisar gastos en otra
  herramienta): es exclusivamente un mecanismo de ida y vuelta con esta
  misma app. Un export legible para análisis externo, si hiciera falta,
  sería una funcionalidad aparte.
- El contenido del archivo exportado no se cifra ni se protege con una
  contraseña propia de la app: la responsabilidad de dónde y con quién se
  comparte ese archivo es del usuario, igual que con cualquier documento
  personal que decida exportar. Ningún escenario actual pide cifrado.
- Restaurar un archivo de una versión más nueva que la app instalada no se
  admite: no hay forma de garantizar qué campos nuevos existen en ese
  archivo sin arriesgar datos corruptos o mal interpretados.
