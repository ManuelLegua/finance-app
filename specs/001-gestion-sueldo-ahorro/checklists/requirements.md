# Specification Quality Checklist: Gestión de sueldo, gasto real, deudas y ahorro

**Purpose**: Validar la completitud y calidad de la especificación antes de pasar a la planificación
**Created**: 2026-08-26
**Last Updated**: 2026-08-26 (revisión 2)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sin detalles de implementación (lenguajes, frameworks, APIs)
- [x] Centrada en el valor para el usuario y la necesidad de negocio
- [x] Redactada para lectores no técnicos
- [x] Todas las secciones obligatorias completadas

## Requirement Completeness

- [x] No quedan marcadores [NEEDS CLARIFICATION]
- [x] Los requisitos son verificables y no ambiguos
- [x] Los criterios de éxito son medibles
- [x] Los criterios de éxito son agnósticos de la tecnología
- [x] Todos los escenarios de aceptación están definidos
- [x] Los casos límite están identificados
- [x] El alcance está delimitado explícitamente
- [x] Los supuestos y dependencias están documentados

## Feature Readiness

- [x] Cada requisito funcional se apoya en al menos una historia de usuario
- [x] Las historias están priorizadas y son independientemente verificables
- [x] Las historias P1 (1, 2 y 3) constituyen un MVP con valor
- [x] La especificación no contradice la constitución del proyecto

## Decisiones resueltas en la revisión 2

Tres preguntas de alcance que estaban abiertas y el usuario resolvió:

1. **Presupuesto y gasto real conviven en paralelo** — la app proyecta el ahorro a
   inicio de mes y lo contrasta con lo efectivamente gastado. No se eligió uno de
   los dos modelos: se muestran ambos (FR-025 a FR-027).
2. **Las cuotas se registran tal como las informa el banco** — la app no modela
   TEA ni amortización, para no discrepar en centavos con el estado de cuenta
   real (FR-024).
3. **El ahorro se registra manualmente** — se lleva lo efectivamente apartado, no
   una suposición de lo que sobró (FR-038 a FR-043).

## Riesgo abierto

**Sostenibilidad del registro manual de gastos.** La historia 3 depende de que el
usuario anote cada gasto conforme ocurre. Es el punto donde más apps de finanzas
personales fracasan: el registro se abandona a las dos semanas y los datos dejan
de reflejar la realidad.

Mitigación en la especificación: SC-002 fija un objetivo de menos de quince
segundos por registro, lo que condiciona el diseño de esa pantalla.

Mitigación pendiente de decisión: la captura automática de consumos a partir de
las notificaciones del banco, evaluada como posible especificación 002 y sujeta a
restricciones de plataforma (viable en Android, no en iOS).

## Alcance explícitamente excluido

Conviene tenerlo a la vista para no reabrirlo durante la implementación:

- Multiusuario, autenticación, sincronización entre dispositivos
- Multimoneda y conversión
- Integración bancaria y captura automática de movimientos (ver 002)
- Ingresos extraordinarios, gratificaciones, devoluciones
- Línea de crédito, pago mínimo, intereses por revolver
- Cuotas de monto variable o escalonado
- Retiros, rendimientos o múltiples cuentas de ahorro
- Respaldo, exportación y restauración de datos
