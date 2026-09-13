# Research: Suscripción premium

Decisiones técnicas, en el mismo formato que `001-gestion-sueldo-ahorro/research.md`.

**Revisada el 2026-09-12**: la spec pasó de suscripción a propina voluntaria.
D1 y D5 siguen vigentes; D2, D3, D4 y D6 quedaron superadas por D7, D8 y D9,
al final de este archivo. Se conservan porque explican el diseño anterior.

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

## D2 — Dónde vive la lógica de "¿está vigente el acceso premium?" *(superada por D7)*

**Decisión**: es un getter sobre el modelo `EstadoSuscripcion` (`lib/dominio/modelos/estado_suscripcion.dart`), no una función en `dominio/calculos/`.

**Por qué**: las funciones de `calculos/` existen para combinar varias entradas (una deuda y un mes de referencia, una lista de obligaciones y transacciones). Acá no hay nada que combinar: la vigencia depende únicamente del campo `situacion` que ya trae el propio estado, calculado en el momento en que se refrescó contra Google Play. Un getter puro (`estaVigente => situacion == prueba || activa || enGracia`) es la pieza mínima que exige el Principio III sin inventar un archivo de cálculo que no combina nada — mismo criterio que `Deuda.estaGuardada` o `EstadoDeuda.estaSaldada` en la spec 001.

**Alternativas consideradas**: una función `calcularVigencia(estado, {hoy})` que comparara `vigenteHasta` contra la fecha actual. Rechazada: la fecha de vencimiento la determina Google, no una resta de fechas local: dos relojes potencialmente desincronizados (el del teléfono y el de Google) no deben decidir algo tan sensible como el acceso pago. Es preferible confiar en la `situacion` que Google ya evaluó la última vez que se pudo consultar, y no reevaluarla con la fecha del dispositivo.

---

## D3 — Persistencia del estado: una fila caché, versionada igual que el resto del esquema *(superada por D8 y D9)*

**Decisión**: una tabla nueva `suscripcion_premium`, fila única (`id = 1`), con `situacion`, `plan`, `vigente_hasta` y `ultima_verificacion`. Se agrega en una migración incremental nueva (`Esquema.version` pasa de 1 a 2), sin tocar las tablas existentes.

**Por qué**: es el mismo patrón que `configuracion` (fila única, `id = 1`) — un solo estado global de la app, no algo por mes ni por entidad. Vive en el mismo SQLite local que todo lo demás, así que sigue siendo cierto que "nada sale del dispositivo" salvo la propia llamada de compra/restauración a Google (Principio I enmendado). `ultima_verificacion` no se usa para invalidar el caché automáticamente (ver D2): existe solo para que la UI pueda mostrar, si hace falta, hace cuánto no se confirma el estado contra Google.

**Alternativas consideradas**: `shared_preferences` o un archivo aparte. Rechazadas: la constitución ya fija SQLite como la persistencia del proyecto (Restricciones Técnicas), y separar este único dato a otro mecanismo de almacenamiento sumaría una dependencia y una ruta de migración distinta sin ningún beneficio.

---

## D4 — Cuándo se refresca el estado contra Google Play *(superada por D8: ya no hay estado que refrescar)*

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

## D6 — El resumen del mes no depende de la suscripción *(generalizada por D7: ahora nada de la app depende de un pago)*

**Decisión**: el resumen sigue mostrando el presupuesto completo del mes —cuotas de deuda incluidas— y su desglose por categoría, esté vigente la suscripción o no. La suscripción **no entra en ningún cálculo financiero** ni oculta ninguna cifra. Lo que se bloquea es *gestionar* deudas y ahorro (crearlas, editarlas, aportar), no verlas contadas en el mes.

**Por qué**: una cifra financiera que cambia según el estado de pago de la app deja de ser confiable, y la confianza en el número es todo lo que esta app vende. La cuota de una deuda se debe igual haya o no suscripción: descontarla del comprometido dejaría el disponible del mes **inflado**, y el usuario tomaría decisiones de gasto contra un número que no es el suyo. Eso es peor que el problema que la omisión pretendía resolver.

Además, el resumen es una pantalla gratis (FR-004): meter la vigencia de la suscripción dentro de `EstadoMes` acoplaría el cálculo del presupuesto —el corazón de la spec 001— a una feature de monetización, justo lo que la arquitectura en capas evita.

**Consecuencia sobre la spec**: FR-012 estaba escrito asumiendo que el resumen "se vería afectado" por una suscripción no activa y que por lo tanto haría falta explicar la ausencia. Al implementar US4 se verificó que **nada en el resumen consulta la suscripción**: ni `lib/ui/estado/estado_mes.dart` ni `lib/ui/pantallas/resumen_mes/pantalla_resumen.dart` la mencionan, y la tarjeta de sugerencia de ahorro es informativa, sin acción que lleve a una pantalla bloqueada. FR-012 se reescribió como **garantía** (el resumen no se degrada) en vez de como aviso, y T033/T034 pasaron de "mostrar un aviso" a "fijar con una prueba que nadie meta esa dependencia más adelante". Revisado 2026-08-31.

**Alternativas consideradas**: omitir las cuotas del comprometido mientras la suscripción no esté vigente y explicarlo con un aviso al estilo de `AvisoMesCerrado`. Rechazada por lo anterior: comunica bien, pero para eso primero rompe la cifra. También se consideró marcar la sugerencia de ahorro como premium y convertirla en entrada al paywall; rechazada por YAGNI, porque no es un callejón sin salida —no es tocable— y el consejo que da es cierto y gratis de dar.

---

# Revisión 2026-09-12 — de suscripción a propina

Las decisiones D1 y D5 siguen vigentes tal como están escritas. **D2, D3, D4 y
D6 quedan superadas** por las tres que siguen: describen un estado de
suscripción que ya no existe. Se conservan sin borrar porque explican por qué
el diseño anterior era como era, y una de ellas (D6) contiene el argumento que
esta revisión termina de generalizar.

---

## D7 — Propina voluntaria en vez de suscripción con funciones bloqueadas

**Decisión**: la app se reparte completa y gratis. El único camino de ingreso
es una propina por única vez que el usuario deja si quiere, desde Ajustes, y
que **no desbloquea absolutamente nada**.

**Por qué**: el modelo anterior cobraba por funcionalidad que no tiene costo
marginal —Deudas y Ahorro corren enteras en el teléfono, sin servidor— a
cambio de una fricción muy concreta: dos de cinco pestañas cerradas en la
primera pantalla que ve alguien que instala la app. Con el público real del
proyecto ese bloqueo no produce ingreso y sí produce abandono. La propina
conserva la posibilidad de ingreso sin ninguna fricción, y elimina de paso
toda una categoría de código de riesgo: la que decide si el usuario tiene
derecho a ver sus propios datos.

**Consecuencia sobre el resto del proyecto**: desaparece T035 de esta spec (la
guarda de suscripción en el callback headless de la spec 002), que era una de
las dependencias cruzadas que mantenían trabadas a la vez a la 002 y a la 004.
También queda sin objeto el paso 8 de T042 de la spec 005 ("que el premium no
se herede del archivo restaurado"), que esperaba una suscripción real para
poder verificarse.

**Alternativas consideradas**:
- **Publicidad (AdMob o similar)**: rechazada. Transmite identificador de
  dispositivo y construye perfil de usuario, lo que no es una excepción
  acotada al Principio I sino su derogación; y en una app de finanzas
  personales destruye justo el atributo que la distingue. El ingreso esperado
  para un público chico e hispanohablante tampoco lo justifica.
- **App de pago en la tienda**: rechazada por decisión explícita del dueño del
  producto ("no quiero cobrar por usar el apk").
- **Cobrar solo lo que tenga costo marginal real** (por ejemplo, una
  interpretación por servicio externo como la que evalúa la spec 006):
  **no rechazada, pospuesta**. Es compatible con la propina y convive con
  ella, pero hoy no existe ninguna función con costo por uso que cobrar, así
  que especificarlo ahora sería violar el Principio V.

---

## D8 — Consumible repetible, sin estado local ni restauración

**Decisión**: el producto de Google Play es un **consumible** (compra única
repetible), no una suscripción ni un no-consumible. La app **no persiste
nada** sobre las propinas: ni si hubo, ni cuántas, ni cuándo. No existe una
acción de "restaurar compras".

**Por qué**: restaurar compras es una exigencia de la política de Google Play
para lo que *concede algo* — una suscripción o un desbloqueo permanente. Una
propina no concede nada, así que no hay nada que restaurar en un dispositivo
nuevo: el usuario no perdió ningún derecho al reinstalar. Y persistir "ya
apoyó" solo tendría sentido para dejar de ofrecerlo o para cambiar el mensaje,
dos comportamientos que ningún requisito pide (Principio V) y que además
contradicen FR-007, que permite apoyar cuantas veces se quiera.

Lo que **sí** sobrevive del diseño anterior es acusar recibo de la compra: una
compra sin confirmar la reembolsa Google sola a los tres días. Como una
propina interrumpida puede quedar pendiente entre sesiones, el repositorio
completa las compras pendientes al consultar los montos (FR-010), no solo al
terminar una compra recién hecha.

**Alternativas consideradas**:
- **No-consumible de una sola vez** ("apoyá el proyecto", comprable una única
  vez): más simple de configurar, pero convierte la propina en una compra con
  inventario, obliga a implementar restauración por política de la tienda y
  choca con FR-007. Rechazada.
- **Guardar la fecha de la última propina** para agradecer distinto a quien ya
  apoyó: rechazada por YAGNI y porque reintroduce estado —y una tabla— para un
  matiz cosmético.

---

## D9 — La tabla `suscripcion_premium` se elimina en una migración v4 → v5

**Decisión**: subir `Esquema.version` de 4 a 5, y que el paso v4 → v5 haga
`DROP TABLE IF EXISTS suscripcion_premium`. La tabla sale también de
`Esquema.creacion`, así que una instalación nueva nunca la crea; su DDL se
conserva solo como paso de la migración v3 → v4, igual que ya se hace con la
tabla `ingreso` de la spec 001 (D-C2 de la spec 003).

**Por qué**: es la única tabla del proyecto que **no contiene datos del
usuario** — era una caché de lo que respondía Google Play. La regla de D10
("ninguna migración destruye información del usuario") se sigue cumpliendo al
pie de la letra, porque acá no hay información del usuario que destruir.
Dejarla como tabla muerta sería peor: código y esquema que nadie lee, que el
respaldo tiene que seguir vaciando y que el próximo que llegue tendría que
investigar para descubrir que no significa nada.

**Efecto colateral buscado sobre el respaldo (spec 005)**: la lista
`_tablasQueNoViajan` pierde `suscripcion_premium` y queda solo con
`notificacion_diagnostico`, y desaparece el descarte de la suscripción
heredada al restaurar. Un respaldo hecho con la v4 que se restaure sobre la v5
pasa por esta migración y pierde la tabla ahí, que es exactamente el
comportamiento que antes se programaba a mano: el archivo deja de poder
conceder un acceso que ya no existe porque el acceso ya no existe.

**Alternativas consideradas**:
- **Dejar la tabla sin usar**, sin migración: evita tocar el esquema, pero
  deja esquema muerto, mantiene el vaciado en el respaldo y obliga a explicar
  para siempre por qué está ahí. Rechazada.
- **Reutilizar la tabla para guardar las propinas**: rechazada por D8 (no hay
  nada que guardar) y porque reutilizar una tabla para algo distinto de lo que
  su nombre dice es la clase de deuda que este proyecto evita por escrito.
