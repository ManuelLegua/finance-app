# Research: Suscripción premium

Cinco decisiones técnicas, en el mismo formato que `001-gestion-sueldo-ahorro/research.md`.

---

## D1 — Paquete de facturación: `in_app_purchase` + `in_app_purchase_android`

**Decisión**: usar el paquete oficial de Flutter `in_app_purchase`, con su extensión `in_app_purchase_android` para las funciones específicas de Google Play Billing (planes base, ofertas de prueba, restaurar compras).

**Por qué**: es mantenido por el propio equipo de Flutter, envuelve la Billing Library de Google directamente (versión 8.0.0 en la release actual del paquete) y es la vía documentada por Flutter para compras dentro de la app. Reimplementarlo a mano exigiría hablar con la Billing Library nativa vía canales de plataforma (Kotlin) desde cero — semanas de trabajo para reproducir algo que ya existe y se mantiene activamente, sin ningún requisito que lo justifique (Restricciones Técnicas de la constitución: "cada paquete de terceros debe justificarse frente al costo de implementarlo a mano").

**Versiones instaladas (T001/T003, 2026-08-30)**: `in_app_purchase` **3.3.0** y `in_app_purchase_android` **0.5.3**, que declara `com.android.billingclient:billing:8.0.0` en su `android/build.gradle.kts` — confirma la versión de Billing Library que asumía esta decisión. Licencia verificada leyendo el `LICENSE` instalado en `.pub-cache`: BSD de tres cláusulas de The Flutter Authors, en ambos paquetes. `flutter pub add` arrastró además `in_app_purchase_platform_interface`, `in_app_purchase_storekit` (iOS, inerte acá) y `json_annotation`.

**Soporte de planes base y ofertas**: confirmado desde la versión 0.3.0 del paquete — `queryProductDetailsAsync` devuelve `subscriptionOfferDetails`, una lista con `basePlanId`, `offerToken` y `pricingPhases` por cada plan (mensual, anual) y su oferta de prueba. Es exactamente el modelo de "un producto, varios planes" que pide la spec (FR-006, FR-006a).

**Riesgo conocido**: hay reportes de un error `INVALID_OFFER_TOKEN` en flujos de compra/upgrade con algunas combinaciones de token. Se mitiga probando el flujo completo (comprar, restaurar, cambiar de plan) contra la pista de pruebas internas de Google Play antes de publicar — ver `quickstart.md`.

**Alternativas consideradas**:
- **RevenueCat (`purchases_flutter`)**: simplifica mucho la gestión de suscripciones, pero enruta la verificación de compra a través de los servidores de RevenueCat, no solo los de Google. La enmienda al Principio I autoriza explícitamente la conexión con los servidores de Google para la compra; sumar un tercero ahí es una salida de datos que la enmienda no cubre y que ningún requisito pide. Rechazada.
- **Canal de plataforma escrito a mano**: control total, pero reimplementa la Billing Library de Google sin ningún beneficio sobre el paquete oficial. Rechazada por Principio V (YAGNI).

---

## D2 — Dónde vive la lógica de "¿está vigente el acceso premium?"

**Decisión**: es un getter sobre el modelo `EstadoSuscripcion` (`lib/dominio/modelos/estado_suscripcion.dart`), no una función en `dominio/calculos/`.

**Por qué**: las funciones de `calculos/` existen para combinar varias entradas (una deuda y un mes de referencia, una lista de obligaciones y transacciones). Acá no hay nada que combinar: la vigencia depende únicamente del campo `situacion` que ya trae el propio estado, calculado en el momento en que se refrescó contra Google Play. Un getter puro (`estaVigente => situacion == prueba || activa || enGracia`) es la pieza mínima que exige el Principio III sin inventar un archivo de cálculo que no combina nada — mismo criterio que `Deuda.estaGuardada` o `EstadoDeuda.estaSaldada` en la spec 001.

**Alternativas consideradas**: una función `calcularVigencia(estado, {hoy})` que comparara `vigenteHasta` contra la fecha actual. Rechazada: la fecha de vencimiento la determina Google, no una resta de fechas local: dos relojes potencialmente desincronizados (el del teléfono y el de Google) no deben decidir algo tan sensible como el acceso pago. Es preferible confiar en la `situacion` que Google ya evaluó la última vez que se pudo consultar, y no reevaluarla con la fecha del dispositivo.

---

## D3 — Persistencia del estado: una fila caché, versionada igual que el resto del esquema

**Decisión**: una tabla nueva `suscripcion_premium`, fila única (`id = 1`), con `situacion`, `plan`, `vigente_hasta` y `ultima_verificacion`. Se agrega en una migración incremental nueva (`Esquema.version` pasa de 1 a 2), sin tocar las tablas existentes.

**Por qué**: es el mismo patrón que `configuracion` (fila única, `id = 1`) — un solo estado global de la app, no algo por mes ni por entidad. Vive en el mismo SQLite local que todo lo demás, así que sigue siendo cierto que "nada sale del dispositivo" salvo la propia llamada de compra/restauración a Google (Principio I enmendado). `ultima_verificacion` no se usa para invalidar el caché automáticamente (ver D2): existe solo para que la UI pueda mostrar, si hace falta, hace cuánto no se confirma el estado contra Google.

**Alternativas consideradas**: `shared_preferences` o un archivo aparte. Rechazadas: la constitución ya fija SQLite como la persistencia del proyecto (Restricciones Técnicas), y separar este único dato a otro mecanismo de almacenamiento sumaría una dependencia y una ruta de migración distinta sin ningún beneficio.

---

## D4 — Cuándo se refresca el estado contra Google Play

**Decisión**: al abrir la app, y cada vez que el usuario entra a una pantalla premium (Deudas, Ahorro, o el flujo de activar la captura de notificaciones) o al indicador de estado de la suscripción. El refresco es "mejor esfuerzo": si no hay conexión, se usa el último estado cacheado sin bloquear ni mostrar error (edge case ya definido en la spec).

**Por qué**: cubre el caso real (el usuario paga, cierra la app, la vuelve a abrir y ya está desbloqueado) sin necesitar un servicio en segundo plano corriendo todo el tiempo, que la spec no pide y que consumiría batería sin respaldo de ningún requisito (Principio V).

**Alternativas consideradas**: un `WorkManager`/tarea periódica en segundo plano para revalidar cada cierto tiempo sin que el usuario abra la app. Rechazada: añade una pieza de infraestructura nueva (servicio en segundo plano, permisos asociados) para un beneficio marginal — el peor caso sin esto es que un vencimiento tarde en reflejarse hasta la próxima vez que se abra una pantalla premium, que es aceptable y está cubierto por el edge case de "confía en el último estado conocido".

---

## D5 — Cómo se prueba esto sin poder simular compras reales en `flutter test`

**Decisión**: tres frentes, igual que el resto del proyecto:

1. **Dominio puro**: `EstadoSuscripcion.estaVigente` para cada `situacion` (prueba, activa, gracia → vigente; vencida, cancelada, nunca → no vigente). Sin SDK de por medio, se prueba como cualquier getter (Principio III).
2. **Repositorio con doble en memoria**: `RepositorioSuscripcionEnMemoria` en `test/dobles/`, igual que los demás repositorios, para las pruebas de `EstadoSuscripcion` (UI) y del paywall — no dependen de la Billing Library real.
3. **Validación manual contra Google Play de verdad**: el flujo de compra, restauración y cambio de plan no se puede probar con `flutter test` — se valida a mano contra la pista de pruebas internas de Google Play Console, con cuentas de prueba (licencias de prueba), documentado paso a paso en `quickstart.md`. Es la misma filosofía que el recorrido de prueba manual del `CLAUDE.md` para lo que la suite automatizada no puede cubrir (Principio IV, "que el usuario entienda su situación de un vistazo" también aplica al flujo de compra).

**Alternativas consideradas**: mockear el plugin `in_app_purchase` directamente en las pruebas de dominio/UI. Rechazada como mecanismo principal: el plugin expone tipos concretos difíciles de sustituir limpiamente sin acoplar las pruebas a su API interna; la interfaz `RepositorioSuscripcion` ya es el punto de sustitución correcto (mismo patrón que `RepositorioIngreso`, `RepositorioAhorro`, etc.), y detrás de ella sí puede haber un mock de bajo nivel si hiciera falta probar el adaptador concreto — pero eso queda fuera de lo que la suite automatizada necesita cubrir.

---

## D6 — El resumen del mes no depende de la suscripción

**Decisión**: el resumen sigue mostrando el presupuesto completo del mes —cuotas de deuda incluidas— y su desglose por categoría, esté vigente la suscripción o no. La suscripción **no entra en ningún cálculo financiero** ni oculta ninguna cifra. Lo que se bloquea es *gestionar* deudas y ahorro (crearlas, editarlas, aportar), no verlas contadas en el mes.

**Por qué**: una cifra financiera que cambia según el estado de pago de la app deja de ser confiable, y la confianza en el número es todo lo que esta app vende. La cuota de una deuda se debe igual haya o no suscripción: descontarla del comprometido dejaría el disponible del mes **inflado**, y el usuario tomaría decisiones de gasto contra un número que no es el suyo. Eso es peor que el problema que la omisión pretendía resolver.

Además, el resumen es una pantalla gratis (FR-004): meter la vigencia de la suscripción dentro de `EstadoMes` acoplaría el cálculo del presupuesto —el corazón de la spec 001— a una feature de monetización, justo lo que la arquitectura en capas evita.

**Consecuencia sobre la spec**: FR-012 estaba escrito asumiendo que el resumen "se vería afectado" por una suscripción no activa y que por lo tanto haría falta explicar la ausencia. Al implementar US4 se verificó que **nada en el resumen consulta la suscripción**: ni `lib/ui/estado/estado_mes.dart` ni `lib/ui/pantallas/resumen_mes/pantalla_resumen.dart` la mencionan, y la tarjeta de sugerencia de ahorro es informativa, sin acción que lleve a una pantalla bloqueada. FR-012 se reescribió como **garantía** (el resumen no se degrada) en vez de como aviso, y T033/T034 pasaron de "mostrar un aviso" a "fijar con una prueba que nadie meta esa dependencia más adelante". Revisado 2026-08-31.

**Alternativas consideradas**: omitir las cuotas del comprometido mientras la suscripción no esté vigente y explicarlo con un aviso al estilo de `AvisoMesCerrado`. Rechazada por lo anterior: comunica bien, pero para eso primero rompe la cifra. También se consideró marcar la sugerencia de ahorro como premium y convertirla en entrada al paywall; rechazada por YAGNI, porque no es un callejón sin salida —no es tocable— y el consejo que da es cierto y gratis de dar.
