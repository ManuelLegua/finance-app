# Specification Quality Checklist: Captura automática de consumos desde notificaciones bancarias

**Purpose**: Validar la completitud y calidad de la especificación antes de pasar a la planificación
**Created**: 2026-08-26
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
- [x] Las historias P1 (1 y 2) constituyen un MVP con valor
- [x] La especificación no contradice la constitución del proyecto
- [x] La dependencia de la especificación 001 está declarada

## Verificación contra la constitución

| Principio | Estado | Nota |
|---|---|---|
| I. Datos locales y privados | ✅ | FR-019 y SC-007 lo exigen explícitamente. La captura refuerza el principio: lee lo que ya está en el dispositivo, sin contactar al banco. |
| II. Exactitud monetaria | ✅ | Los montos capturados entran al mismo modelo de la 001. FR-017 impide crear pendientes con montos parciales o inferidos. |
| III. Lógica pura y probada | ✅ | La interpretación de notificaciones es transformación de texto a datos: comprobable con notificaciones de ejemplo, sin dispositivo. |
| IV. Claridad sobre sofisticación | ✅ | FR-020 antepone el control del usuario a la comodidad. Se rechazó el registro automático por este principio. |
| V. Alcance individual | ✅ | Sin cambios: sigue siendo un usuario, un dispositivo. |

## Decisiones resueltas antes de redactar

1. **Orígenes soportados** *(revisado 2026-08-30)*: cualquier banco o billetera peruana en una lista de orígenes reconocidos, sembrada con los 15 emisores de `EntidadesPeru` (001), que ya incluye Yape y Plin, ampliable sin escribir un intérprete nuevo por banco (FR-008, FR-008a). Reemplaza la decisión original de una lista fija de cuatro.
2. **Confirmación obligatoria**: se descartó el registro automático y el modo
   híbrido por confianza. Un error de interpretación no debe poder entrar a los
   datos sin que el usuario lo vea (FR-020, SC-001).
3. **Categorización aprendida**: la app recuerda la categoría por comercio a
   partir de las decisiones del usuario, sin reglas preescritas (FR-029 a FR-034).

## Riesgos abiertos

**El reconocimiento no se puede escribir a ciegas** *(revisado 2026-08-30)*. No
existe documentación pública del formato de las notificaciones de ningún banco.
Con el reconocimiento genérico esto pesa menos que con un intérprete por banco:
alcanza con observar notificaciones reales de una muestra representativa de
orígenes (no de los 16 sembrados uno por uno) para construir y validar el
parser compartido. La historia 2 no puede completarse sin esa muestra inicial,
pero cubrir un origen adicional después ya no depende de conseguir muestras
suyas. El registro de diagnóstico (FR-018) sigue siendo el mecanismo para
detectar y corregir los casos que el parser genérico no reconozca bien.

**Los formatos cambiarán.** Un cambio de redacción del banco rompe el
reconocimiento en silencio. Mitigación: FR-017 impide generar datos erróneos, y
FR-018 conserva lo no reconocido para diagnosticar. Queda fuera de alcance
detectar automáticamente que un origen dejó de reconocerse.

**Restricción de Google Play.** El supuesto de distribución personal sostiene la
viabilidad. Publicar en Play Store exigiría justificar el permiso de acceso a
notificaciones ante la revisión de Google, con aprobación incierta para una app
de finanzas. Si publicar pasa a ser un objetivo, esta especificación debe
revisarse.

## Alcance explícitamente excluido

- Registro automático sin confirmación del usuario
- Soporte en iOS (imposible por diseño de la plataforma)
- Captura de ingresos recibidos por Yape o Plin
- Consumos en moneda extranjera
- Conciliación contra el estado de cuenta del banco
- Recuperación de notificaciones anteriores a la activación
- Detección automática de que un banco cambió su formato
- Edición de la lista de orígenes reconocidos desde la propia UI (D-N10 la deja como posible mejora futura, no un requisito de esta revisión)
