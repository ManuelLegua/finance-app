# Finanzas Constitution

Aplicación de finanzas personales de uso individual para administrar un sueldo
mensual en soles peruanos (S/), repartirlo entre obligaciones recurrentes y
decidir cuánto ahorrar cada mes.

## Core Principles

### I. Datos locales y privados (enmendado en v2.0.0)

Toda la información financiera (sueldo, gastos, deudas, ahorro) vive
exclusivamente en el dispositivo y nunca se transmite a ningún servidor,
propio o de terceros. La app no requiere cuenta de usuario. Ninguna
dependencia puede introducir telemetría, analítica ni sincronización remota
de esos datos. Cualquier funcionalidad futura que implique salida de datos
del dispositivo exige una enmienda explícita a esta constitución.

**Excepción explícita y acotada**: la verificación de compras dentro de la
app (Google Play Billing) puede conectarse con los servidores de Google
exclusivamente para procesar o restaurar una compra. Esa conexión no
transmite ni puede transmitir ningún dato financiero del usuario: solo el
identificador del producto comprado y el estado de la licencia, que maneja la
propia biblioteca de Google Play Billing. Fuera de esa función puntual, la
app sigue funcionando 100% sin internet.

**Razón**: son datos de sueldo, deudas y gastos de una persona concreta; el
riesgo de una filtración supera cualquier beneficio de una funcionalidad en la
nube. La app admite ahora un modelo de monetización con funciones pagas, pero
el compromiso de privacidad sobre los datos financieros se mantiene intacto:
lo único que sale del dispositivo es la transacción de compra gestionada por
Google, nunca el contenido de la app.

### II. Exactitud monetaria (NO NEGOCIABLE)

Los montos se representan y almacenan como enteros de centavos, nunca como
`double` ni `float`. Todo cálculo de totales, saldos y porcentajes opera sobre
enteros; el redondeo ocurre únicamente en la capa de presentación, a dos
decimales. La moneda es siempre el sol peruano (S/).

**Razón**: la aritmética de punto flotante produce errores de centavos que
destruyen la confianza en una app cuyo único propósito es decir cuánto dinero
queda.

### III. Lógica financiera pura y probada

Los cálculos de saldo, déficit, ahorro sugerido y reparto por categoría residen
en funciones puras de Dart, sin dependencias de Flutter, UI ni almacenamiento.
Cada regla financiera tiene pruebas unitarias que cubren el caso normal, el
límite (saldo exactamente cero) y el adverso (déficit). Estas pruebas se
escriben antes que la implementación de la regla.

**Razón**: es el núcleo del producto y la parte donde un error silencioso hace
más daño; aislarla la vuelve verificable sin levantar la app.

### IV. Claridad sobre sofisticación

La interfaz prioriza que el usuario entienda su situación de un vistazo. El
déficit se comunica de forma inequívoca y no solo mediante color, para no
depender de la percepción cromática. Se prefiere una pantalla legible a una
funcionalidad extra. No se añaden gráficos, animaciones ni pantallas que no
respondan a un requisito de la especificación.

### V. Alcance individual, sin especulación

La app sirve a un solo usuario en un solo dispositivo. No se construye
multiusuario, multimoneda, roles, compartición ni sincronización mientras no
exista un requisito especificado que lo pida. Se aplica YAGNI: el código que no
respalda un requisito vigente no se escribe.

## Restricciones Técnicas

- **Stack**: Flutter (canal stable) y Dart, con Material Design.
- **Plataformas**: Android es la plataforma de desarrollo y prueba primaria.
  El código Dart se mantiene libre de dependencias específicas de plataforma
  para que iOS compile sin cambios cuando haya acceso a un entorno macOS.
- **Persistencia**: base de datos local en el dispositivo. El esquema se versiona
  y toda migración preserva los datos existentes del usuario.
- **Dependencias**: cada paquete de terceros debe justificarse frente al costo de
  implementarlo a mano. Se rechazan dependencias sin mantenimiento activo o que
  violen el Principio I.
- **Localización**: textos e interfaz en español; formato de montos y fechas
  según convención peruana.

## Flujo de Desarrollo

- El desarrollo es dirigido por especificación: ninguna funcionalidad se
  implementa antes de estar descrita en `specs/` y aprobada por el usuario.
- El orden es especificación → plan → tareas → implementación. Un cambio de
  alcance se refleja primero en la especificación, no directamente en el código.
- Las pruebas de la lógica financiera son un requisito de entrada, no un paso
  posterior opcional.
- Los commits agrupan cambios coherentes y referencian la tarea que atienden.

## Governance

Esta constitución prevalece sobre cualquier otra práctica del proyecto. Cuando
un plan o una implementación entren en conflicto con ella, se corrige el plan o
la implementación, no la constitución.

Toda enmienda requiere: (1) que el usuario la apruebe explícitamente, (2) que se
registre aquí con su justificación, y (3) que se incremente la versión según
versionado semántico — MAJOR al eliminar o redefinir un principio, MINOR al
añadir uno nuevo, PATCH para aclaraciones que no cambian el fondo.

Cualquier desviación de un principio debe justificarse por escrito en el plan de
la funcionalidad afectada, no resolverse en silencio durante la implementación.

**Version**: 2.0.0 | **Ratified**: 2026-08-26 | **Last Amended**: 2026-08-29
