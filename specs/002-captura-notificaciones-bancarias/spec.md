# Feature Specification: Captura automática de consumos desde notificaciones bancarias

**Feature Branch**: `002-captura-notificaciones-bancarias`

**Created**: 2026-08-26

**Status**: Draft

**Depends on**: [001-gestion-sueldo-ahorro](../001-gestion-sueldo-ahorro/spec.md) — define las transacciones, las categorías y las deudas en cuotas sobre las que esta funcionalidad opera.

**Input**: User description: "Captura automática de consumos desde las notificaciones del banco en Android. La app lee las notificaciones de cualquier banco o billetera digital peruana reconocida — no un puñado fijo de bancos, sino cualquiera que el usuario tenga o llegue a tener —, extrae monto, comercio y fecha, y propone una transacción precargada que el usuario confirma o corrige de un toque, nunca la registra en silencio. Solo captura consumos (dinero que sale); nunca dinero recibido. Aprende la categoría por comercio. Todo el procesamiento ocurre en el dispositivo. Es exclusiva de Android."

**Revisión** *(2026-08-30)*: el alcance de orígenes pasó de una lista fija de cuatro bancos a un reconocimiento genérico. Ver FR-008 a FR-011 y la sección "Sobre el reconocimiento" en Assumptions — es el cambio que más afecta el diseño técnico y anula la premisa original de "un intérprete por banco".

## Contexto y alcance

La especificación 001 depende de que el usuario anote cada gasto a mano. Ese es
el punto donde las apps de finanzas personales se abandonan: el registro se
sostiene dos semanas y luego los datos dejan de reflejar la realidad.

Esta funcionalidad reduce ese esfuerzo aprovechando que los bancos ya notifican
cada consumo. La app lee esas notificaciones en el propio dispositivo, extrae los
datos y deja la transacción lista para que el usuario solo confirme.

**Tres límites que definen el alcance:**

- **Nunca registra en silencio.** Toda transacción capturada pasa por una
  confirmación del usuario. Un error de lectura no debe poder corromper los datos
  sin que el usuario lo vea.
- **Solo Android.** iOS no ofrece ninguna forma de leer las notificaciones de
  otras apps; no es un permiso que pueda solicitarse. En iOS el registro sigue
  siendo íntegramente manual, y esta funcionalidad no existe.
- **Nada sale del dispositivo.** El texto de las notificaciones y los datos
  extraídos se procesan y almacenan localmente, en coherencia con el Principio I
  de la constitución del proyecto.

La captura complementa el registro manual, no lo reemplaza: el efectivo y
cualquier consumo que no genere notificación se siguen anotando a mano.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Activar la captura y entender qué implica (Priority: P1)

El usuario abre la app por primera vez y encuentra la opción de capturar sus
consumos automáticamente. La app le explica qué va a leer, qué no, y que nada
sale de su teléfono. Al aceptar, lo lleva a la pantalla de Android donde se
concede el permiso. De vuelta en la app, ve confirmado que la captura está
activa y de qué apps.

**Why this priority**: sin el permiso concedido nada de lo demás ocurre. Y
porque el permiso de acceso a notificaciones es amplio: el usuario debe entender
qué está autorizando antes de concederlo.

**Independent Test**: se prueba recorriendo la activación en un dispositivo
limpio y verificando que el estado mostrado coincide con el permiso real del
sistema, incluido el caso de que el usuario lo deniegue o lo revoque después.

**Acceptance Scenarios**:

1. **Given** la app recién instalada, **When** el usuario abre la sección de captura automática, **Then** ve una explicación de qué notificaciones se leerán, con qué fin, y la afirmación de que ningún dato sale del dispositivo.
2. **Given** la explicación en pantalla, **When** el usuario acepta activar, **Then** la app lo dirige a la pantalla de permisos de Android correspondiente.
3. **Given** el permiso concedido, **When** el usuario vuelve a la app, **Then** ve la captura marcada como activa y la lista de apps de las que capturará.
4. **Given** el permiso denegado, **When** el usuario vuelve a la app, **Then** ve la captura marcada como inactiva, con el registro manual disponible y sin mensajes de error alarmantes.
5. **Given** la captura activa, **When** el usuario revoca el permiso desde los ajustes de Android, **Then** la app detecta el cambio y avisa que la captura dejó de funcionar.
6. **Given** la captura activa, **When** el usuario decide desactivarla desde la app, **Then** deja de procesar notificaciones y las transacciones ya confirmadas permanecen intactas.

---

### User Story 2 - Confirmar un consumo capturado (Priority: P1)

El usuario paga el almuerzo con su tarjeta. Segundos después su banco le
notifica el consumo. La app lo detecta y lo deja esperando en una bandeja de
pendientes. Cuando el usuario abre la app, ve el consumo con monto, comercio y
fecha ya llenos, y una categoría propuesta. Confirma de un toque y el gasto
queda registrado en su mes.

**Why this priority**: es el núcleo de la funcionalidad y lo que entrega el
valor. Junto con la historia 1 constituye el MVP de esta especificación.

**Independent Test**: se prueba simulando notificaciones de cada banco soportado
y verificando que el pendiente generado contiene los datos correctos y que al
confirmarlo aparece como transacción del mes correspondiente.

**Acceptance Scenarios**:

1. **Given** la captura activa, **When** llega una notificación de consumo de S/ 45.00 en un comercio, **Then** aparece un pendiente con monto S/ 45.00, el nombre del comercio y la fecha del consumo.
2. **Given** un pendiente en la bandeja, **When** el usuario lo confirma, **Then** se registra como transacción del mes correspondiente a su fecha y desaparece de pendientes.
3. **Given** un pendiente con el comercio mal interpretado, **When** el usuario corrige la descripción, el monto o la categoría antes de confirmar, **Then** se registra con los valores corregidos.
4. **Given** un pendiente que el usuario no reconoce o no quiere registrar, **When** lo descarta, **Then** desaparece de la bandeja sin crear transacción.
5. **Given** varios pendientes acumulados, **When** el usuario abre la bandeja, **Then** los ve ordenados del más reciente al más antiguo, con el total que suman.
6. **Given** un pendiente generado hace tres días, **When** el usuario lo confirma hoy, **Then** la transacción conserva la fecha del consumo, no la de la confirmación.
7. **Given** la app cerrada, **When** llega una notificación de consumo, **Then** el pendiente se genera igual y está disponible al abrir la app.
8. **Given** pendientes sin confirmar, **When** pasa el tiempo, **Then** no caducan ni se eliminan solos.

---

### User Story 3 - Que la app aprenda mis categorías (Priority: P2)

La primera vez que el usuario confirma un consumo de un supermercado, elige la
categoría comida. La próxima vez que compre en ese mismo comercio, la app ya
propone comida. Con el uso, la mayoría de los pendientes llegan con la categoría
correcta y confirmarlos es un solo toque.

**Why this priority**: es lo que hace que confirmar sea realmente de un toque en
vez de un toque más elegir categoría. Depende de que la captura ya funcione.

**Independent Test**: se prueba confirmando un consumo de un comercio con una
categoría dada, y verificando que un consumo posterior del mismo comercio llega
con esa categoría propuesta; y que cambiarla actualiza la asociación.

**Acceptance Scenarios**:

1. **Given** un comercio nunca antes categorizado, **When** el usuario confirma un consumo suyo eligiendo una categoría, **Then** la app guarda esa asociación comercio-categoría.
2. **Given** una asociación guardada, **When** llega un consumo del mismo comercio, **Then** el pendiente propone esa categoría.
3. **Given** una asociación guardada, **When** el usuario confirma un consumo de ese comercio con una categoría distinta, **Then** la asociación se actualiza a la nueva categoría.
4. **Given** un comercio desconocido, **When** llega su consumo, **Then** el pendiente aparece sin categoría propuesta y la app pide elegirla antes de permitir confirmar.
5. **Given** asociaciones acumuladas, **When** el usuario las consulta, **Then** puede ver la lista de comercios con su categoría y corregir o eliminar cualquiera.

---

### User Story 4 - Distinguir consumos en cuotas (Priority: P3)

El usuario compra un electrodoméstico en 6 cuotas con su tarjeta. El banco le
notifica el monto total de la compra. Si eso se registrara como un gasto único
del mes, distorsionaría por completo su presupuesto: en realidad pagará una
fracción cada mes durante seis meses.

**Why this priority**: sin esto, una sola compra grande en cuotas arruina las
cifras del mes. Pero ocurre pocas veces al año, y el usuario puede corregirlo a
mano mientras tanto.

**Independent Test**: se prueba con un pendiente de monto alto, indicando que fue
en cuotas, y verificando que en lugar de una transacción se crea una deuda en
cuotas conforme a la especificación 001.

**Acceptance Scenarios**:

1. **Given** un pendiente de consumo con tarjeta de crédito, **When** el usuario lo abre, **Then** puede indicar que la compra fue en cuotas.
2. **Given** un pendiente marcado como compra en cuotas, **When** el usuario indica el número de cuotas y la cuota mensual, **Then** se registra como deuda en cuotas según la especificación 001, y no como transacción del mes.
3. **Given** una compra en cuotas registrada así, **When** el usuario consulta el presupuesto del mes, **Then** ve solo la cuota mensual comprometida, no el monto total de la compra.
4. **Given** un pendiente de consumo con tarjeta, **When** el usuario no indica nada sobre cuotas, **Then** se registra como transacción normal por el monto notificado.

---

### Edge Cases

**Permisos y disponibilidad**

- **Permiso revocado por el sistema o el usuario**: la app detecta el estado real y avisa que la captura está inactiva, sin perder los pendientes ya generados.
- **Servicio de escucha detenido por el sistema operativo**: al reanudarse, la captura vuelve a funcionar sin intervención del usuario. Los consumos ocurridos mientras estuvo detenido no se recuperan.
- **Dispositivo iOS**: la funcionalidad no se ofrece ni se muestra; la app no exhibe opciones inactivas ni mensajes sobre una capacidad que esa plataforma no tendrá.
- **Notificaciones desactivadas en la app del banco**: no llega nada que leer. La app no puede distinguir esto de "no hubo consumos", por lo que el usuario debe saber que la captura depende de las notificaciones del banco.

**Interpretación de notificaciones**

- **App no reconocida en absoluto** (no está en la lista de orígenes reconocidos): la notificación ni se procesa ni se guarda en ningún lado — distinto del caso siguiente, donde la app sí es un banco/billetera conocido pero el texto puntual no se pudo leer.
- **Formato no reconocido de un origen sí conocido**: no se genera ningún pendiente. El texto se conserva localmente en un registro de diagnóstico que el usuario puede revisar y borrar, para poder ajustar el reconocimiento genérico después.
- **Cambio de formato de un banco**: esos consumos puntuales dejan de reconocerse y pasan al registro de diagnóstico; al ser un reconocimiento genérico y no un intérprete propio de ese banco, es menos frágil ante este cambio que si dependiera de un patrón exclusivo suyo, pero no es inmune. La app no debe fallar ni generar pendientes con datos erróneos.
- **Notificación que no es un consumo** (promociones, avisos de saldo, inicio de sesión, recordatorios de pago): se ignora sin generar pendiente.
- **Notificación duplicada o reeditada**: el mismo consumo notificado más de una vez genera un solo pendiente.
- **Dos consumos idénticos y legítimos** (mismo monto, mismo comercio, en minutos): se conservan ambos como pendientes distintos; la app no los descarta como duplicados sin evidencia.
- **Consumo rechazado o extornado**: no genera pendiente de gasto.
- **Yape o Plin recibido** (dinero entrante): no genera pendiente, porque la especificación 001 no modela ingresos como transacciones.
- **Monto ilegible o ausente en el texto**: no se genera pendiente; pasa al registro de diagnóstico.
- **Consumo en moneda extranjera**: no se genera pendiente, porque la app opera únicamente en soles. Pasa al registro de diagnóstico.

**Datos y ciclo de vida**

- **Consumo a fin de mes confirmado en el mes siguiente**: la transacción se asigna al mes de la fecha del consumo.
- **Pendientes acumulados sin confirmar**: no caducan. Si superan una cantidad razonable, la app lo señala para que el usuario no los pierda de vista.
- **Desactivar la captura**: deja de procesar notificaciones nuevas; las transacciones ya confirmadas y las asociaciones aprendidas se conservan.
- **Comercio con nombre inconsistente entre notificaciones** (mayúsculas, sufijos de sucursal): se reconoce como el mismo comercio para efectos de la categoría aprendida.

## Requirements *(mandatory)*

### Functional Requirements

**Activación y permisos**

- **FR-001**: El sistema MUST explicar, antes de solicitar el permiso, qué notificaciones leerá, con qué finalidad, y que ningún dato sale del dispositivo.
- **FR-002**: El sistema MUST dirigir al usuario a la pantalla de concesión de permiso del sistema operativo.
- **FR-003**: El sistema MUST mostrar el estado real de la captura (activa o inactiva) conforme al permiso vigente, no según lo que el usuario haya aceptado antes.
- **FR-004**: El sistema MUST detectar la revocación del permiso y avisar que la captura dejó de funcionar.
- **FR-005**: El sistema MUST permitir desactivar la captura desde la app, conservando transacciones confirmadas y categorías aprendidas.
- **FR-006**: El sistema MUST seguir permitiendo el registro manual de transacciones con la captura inactiva o denegada.
- **FR-007**: En plataformas que no permiten leer notificaciones de otras apps, el sistema MUST omitir por completo esta funcionalidad de la interfaz.

**Captura e interpretación**

- **FR-008**: El sistema MUST reconocer notificaciones de consumo de cualquier banco o billetera digital peruana en una lista de orígenes reconocidos, mediante un reconocimiento genérico de patrones — no un intérprete escrito a mano por cada banco.
- **FR-008a**: Agregar un banco o billetera nuevo a la lista de orígenes reconocidos MUST NOT requerir escribir lógica de interpretación nueva: alcanza con identificar la app (FR-010) para que el reconocimiento genérico ya vigente empiece a aplicarle.
- **FR-008b**: El sistema MUST distinguir un consumo (dinero que sale) de un movimiento entrante (dinero que se recibe) por el contenido de la notificación, sin asumirlo por la app de origen — la misma app de billetera notifica ambos casos de forma parecida.
- **FR-009**: El sistema MUST extraer de cada notificación reconocida el monto, el comercio y la fecha del consumo.
- **FR-010**: El sistema MUST registrar de qué app u origen proviene cada consumo capturado.
- **FR-011**: El sistema MUST capturar consumos aunque la app esté cerrada o en segundo plano.
- **FR-012**: El sistema MUST ignorar las notificaciones que no correspondan a un consumo.
- **FR-013**: El sistema MUST ignorar las notificaciones de dinero recibido (FR-008b), consumo rechazado y consumo extornado.
- **FR-014**: El sistema MUST ignorar los consumos en moneda distinta al sol.
- **FR-015**: El sistema MUST evitar generar más de un pendiente para una misma notificación repetida o reeditada.
- **FR-016**: El sistema MUST conservar como pendientes distintos dos consumos legítimos de igual monto y comercio.
- **FR-017**: Cuando no logre interpretar una notificación de un origen soportado, el sistema MUST NOT generar un pendiente con datos parciales o inventados.
- **FR-018**: El sistema MUST conservar localmente las notificaciones no interpretadas en un registro de diagnóstico consultable y borrable por el usuario.
- **FR-019**: Todo el procesamiento y almacenamiento MUST ocurrir en el dispositivo, sin transmitir el contenido de las notificaciones ni los datos extraídos fuera de él.

**Confirmación**

- **FR-020**: El sistema MUST NOT registrar ninguna transacción capturada sin confirmación explícita del usuario.
- **FR-021**: El sistema MUST presentar los consumos capturados en una bandeja de pendientes, ordenados del más reciente al más antiguo.
- **FR-022**: El sistema MUST mostrar el número de pendientes sin confirmar y el monto que suman.
- **FR-023**: El sistema MUST permitir confirmar un pendiente en una sola acción cuando tenga categoría propuesta.
- **FR-024**: El sistema MUST permitir corregir monto, descripción, fecha y categoría antes de confirmar.
- **FR-025**: El sistema MUST permitir descartar un pendiente sin crear transacción.
- **FR-026**: Al confirmar, el sistema MUST crear la transacción con la fecha del consumo, no la de la confirmación.
- **FR-027**: El sistema MUST conservar los pendientes sin confirmar indefinidamente, sin caducidad.
- **FR-028**: El sistema MUST señalar cuando la cantidad de pendientes sin confirmar sea inusualmente alta.

**Categorización aprendida**

- **FR-029**: Al confirmar un consumo, el sistema MUST guardar la asociación entre el comercio y la categoría elegida.
- **FR-030**: El sistema MUST proponer la categoría asociada cuando llegue un consumo de un comercio ya conocido.
- **FR-031**: El sistema MUST actualizar la asociación cuando el usuario confirme ese comercio con otra categoría.
- **FR-032**: El sistema MUST reconocer como el mismo comercio las variantes de nombre que difieran solo en mayúsculas, espacios o sufijos de sucursal.
- **FR-033**: El sistema MUST exigir que el usuario elija categoría antes de confirmar un consumo de comercio desconocido.
- **FR-034**: El sistema MUST permitir consultar, corregir y eliminar las asociaciones comercio-categoría aprendidas.

**Compras en cuotas**

- **FR-035**: El sistema MUST permitir marcar un pendiente de tarjeta de crédito como compra en cuotas.
- **FR-036**: Al marcarlo como compra en cuotas, el sistema MUST registrarlo como deuda en cuotas conforme a la especificación 001, en lugar de como transacción del mes.
- **FR-037**: El sistema MUST tratar como transacción normal todo pendiente que el usuario no marque como compra en cuotas.

### Key Entities

- **Origen de captura**: app bancaria o billetera identificada como reconocida (por su paquete de Android). No tiene lógica propia de interpretación — todas comparten el mismo reconocimiento genérico (FR-008). La lista de orígenes reconocidos es ampliable sin escribir código de interpretación nuevo (FR-008a).
- **Consumo pendiente**: consumo detectado y aún no confirmado. Contiene monto, comercio, fecha, origen y categoría propuesta. Al confirmarse se convierte en una transacción de la especificación 001; al descartarse desaparece sin dejar registro contable.
- **Asociación comercio-categoría**: vínculo aprendido entre el nombre de un comercio y la categoría que el usuario le asignó. Se crea y actualiza con cada confirmación.
- **Registro de diagnóstico**: notificaciones de un origen soportado que no se pudieron interpretar, conservadas localmente para revisar por qué falló el reconocimiento. Consultable y borrable por el usuario.
- **Estado de la captura**: si la captura está activa, qué orígenes cubre y si el permiso del sistema sigue vigente.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ningún consumo se registra como transacción sin que el usuario lo confirme, en el 100% de los casos.
- **SC-002**: Confirmar un consumo con categoría propuesta toma una sola acción y menos de cinco segundos.
- **SC-003**: Tras un mes de uso, al menos el 80% de los consumos capturados llegan con la categoría correcta ya propuesta.
- **SC-004**: Los consumos con tarjeta y billetera de los orígenes soportados llegan a la bandeja sin que el usuario teclee monto ni comercio.
- **SC-005**: Una misma notificación nunca produce dos pendientes, en el 100% de los casos de prueba.
- **SC-006**: Ninguna notificación mal interpretada produce un pendiente con datos incorrectos: o se interpreta bien, o pasa a diagnóstico.
- **SC-007**: El contenido de las notificaciones nunca abandona el dispositivo, verificable observando que la app funciona sin conexión y no realiza envíos.
- **SC-008**: El usuario entiende qué está autorizando antes de conceder el permiso, sin consultar documentación externa.
- **SC-009**: El tiempo dedicado a registrar gastos se reduce de forma apreciable frente al registro íntegramente manual de la especificación 001.
- **SC-010**: Un consumo capturado con la app cerrada está disponible al abrirla, en el 100% de los casos.
- **SC-011**: Agregar un banco o billetera nuevo a la lista de orígenes reconocidos no exige escribir ni desplegar código de interpretación nuevo, solo identificar la app.

## Assumptions

**Sobre la plataforma**

- **Exclusivo de Android**: iOS no ofrece ninguna API para leer notificaciones de otras aplicaciones. No es una limitación que pueda sortearse con un permiso o una autorización especial; en iOS esta funcionalidad simplemente no existirá.
- **Distribución en Play Store, viable con precauciones** *(revisado 2026-08-29)*: la suposición original era no publicar en tiendas por el riesgo de que Google rechazara el permiso de notificaciones en una app de finanzas. Investigando la política vigente, esa suposición era demasiado pesimista: hay apps de seguimiento de gastos publicadas y activas en Play Store que leen notificaciones bancarias para capturar transacciones (Expenzo, FinArt), con el mismo procesamiento local que exige esta especificación. El permiso de acceso a notificaciones (`NotificationListenerService`) no está entre los que exigen el Formulario de Declaración de Permisos con video de Google — ese trámite aplica sobre todo a SMS, registro de llamadas y accesibilidad — aunque Google Play Protect sí vigila su uso por riesgo de fraude financiero. Publicar exige cumplir sin excepción FR-001, FR-019 y FR-020 (explicar antes de pedir el permiso, nunca transmitir el contenido fuera del dispositivo, nunca registrar en silencio) y contar con una política de privacidad pública, que Google exige para publicar cualquier app.
- **El usuario mantiene activas las notificaciones de sus bancos**: si las silencia en el sistema, no hay nada que capturar y la app no puede advertirlo.

**Sobre el reconocimiento** *(revisado 2026-08-30 — reemplaza la premisa original de "un intérprete por banco")*

- **Un reconocimiento genérico, compartido por todos los orígenes**: en vez de un intérprete de texto por banco, un único mecanismo reconoce patrones comunes a cualquier notificación de consumo (un monto en soles, palabras que indican que el dinero salió y no entró) y una lista de apps reconocidas que acota a cuáles notificaciones prestarle atención. Agregar un banco nuevo a esa lista no exige escribir ni probar un intérprete nuevo.
- **Se valida contra notificaciones reales de varios bancos, no de todos**: el reconocimiento genérico igual se construye y ajusta observando notificaciones reales — no hay documentación pública del formato de ningún banco —, pero alcanza con una muestra representativa de distintos bancos y billeteras para validar que el patrón generaliza, no con una muestra de cada uno.
- **Precisión más pareja, no perfecta por banco**: un intérprete a medida por banco reconoce mejor los casos particulares de ese banco; el reconocimiento genérico prioriza cubrir bancos nuevos sin trabajo adicional, a cambio de fallar con más frecuencia en textos atípicos de cualquiera de ellos — esos casos van al registro de diagnóstico, nunca se inventan (FR-017).
- **Cobertura parcial por diseño**: solo se capturan consumos que generan notificación **de un origen reconocido**. El efectivo, las domiciliaciones y cualquier gasto que el banco no avise — o de una app que todavía no está en la lista de orígenes reconocidos — se siguen registrando a mano. La captura reduce el registro manual, no lo elimina.
- **El comercio es el que informa el banco**: se usa el nombre tal como aparece en la notificación, que puede ser un identificador poco legible. El usuario puede corregirlo al confirmar.

**Sobre el alcance**

- **Solo gastos**: los ingresos recibidos por Yape o Plin no generan pendientes, porque la especificación 001 no modela ingresos como transacciones.
- **Solo soles**: los consumos en otra moneda no se capturan, en coherencia con la moneda única de la especificación 001.
- **Sin conciliación con el estado de cuenta**: la app no compara lo capturado contra el estado de cuenta del banco ni detecta consumos que se hayan perdido.
- **Sin recuperación retroactiva**: las notificaciones anteriores a la activación del permiso, o llegadas mientras el servicio estuvo detenido, no se recuperan.
- **La confirmación es obligatoria y no configurable**: no se ofrece un modo de registro automático sin confirmación. Es una decisión de diseño derivada del riesgo de corromper datos financieros con un error de interpretación, no una limitación técnica.
