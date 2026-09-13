# Specification Quality Checklist: Montos en moneda extranjera

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-13
**Feature**: [spec.md](../spec.md)

## Content Quality

- [X] No implementation details (languages, frameworks, APIs)
- [X] Focused on user value and business needs
- [X] Written for non-technical stakeholders
- [X] All mandatory sections completed

## Requirement Completeness

- [ ] No [NEEDS CLARIFICATION] markers remain
- [X] Requirements are testable and unambiguous
- [X] Success criteria are measurable
- [X] Success criteria are technology-agnostic (no implementation details)
- [X] All acceptance scenarios are defined
- [X] Edge cases are identified
- [X] Scope is clearly bounded
- [X] Dependencies and assumptions identified

## Feature Readiness

- [X] All functional requirements have clear acceptance criteria
- [X] User scenarios cover primary flows
- [X] Feature meets measurable outcomes defined in Success Criteria
- [X] No implementation details leak into specification

## Notes

Quedan **dos** marcadores `[NEEDS CLARIFICATION]`, los dos de alcance y los dos
esperando respuesta del usuario:

- **FR-029** — ¿las obligaciones recurrentes también aceptan moneda extranjera,
  o solo los gastos reales?
- **FR-030** — ¿el tipo de cambio se informa por movimiento, o hay uno por mes
  que sirve de valor por defecto?

Ambos están planteados como preguntas de sí o no, junto con los seis supuestos
reversibles de la sección *Assumptions*, en el análisis que acompaña a esta
especificación. Hasta que se respondan, la spec **no pasa a `/speckit-plan`**.

**Bloqueo adicional, anterior a las aclaraciones**: esta funcionalidad
contradice el texto vigente del Principio II de la constitución (*"La moneda es
siempre el sol peruano (S/)"*) y necesita una enmienda **v4.0.0** aprobada
explícitamente por el usuario y registrada en
`.specify/memory/constitution.md`. Sin esa aprobación la spec queda en Draft
aunque los dos marcadores se resuelvan.
