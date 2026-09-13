# Ficha de Google Play Store

Borrador de todo lo que Play Console pide por escrito. **Nada de esto es
código**: es el papeleo que decide si la app se aprueba o se rechaza, y se
versiona junto al código para que cuando la app cambie, la ficha cambie en el
mismo commit.

**Antes de subir nada**: cerrar T067 de la spec 002 (borrar el instrumento de
volcado), o la app contradice su propia política de privacidad. Ver CLAUDE.md.

---

## 1. Ficha principal

**Nombre de la app** (máx. 30 caracteres):

```
Finanzas: sueldo y gastos
```

*25 caracteres.* "Finanzas" a secas es demasiado genérico para que alguien la
encuentre, y probablemente esté tomado. El agregado dice en dos palabras a qué
público apunta: alguien con un sueldo, no un inversor.

**Descripción corta** (máx. 80 caracteres):

```
Administrá tu sueldo mensual en soles. Sin cuentas, sin internet, sin anuncios.
```

*78 caracteres.* Lo que la distingue no es una funcionalidad, es lo que no
tiene.

**Descripción completa** (máx. 4000 caracteres):

```
Finanzas te ayuda a repartir tu sueldo mensual y saber, de un vistazo, cuánto
te queda de verdad.

Está pensada para una sola cosa: administrar un sueldo en soles peruanos. No
es una app de inversiones ni un libro contable. Si cobrás una vez al mes —o en
quincena y fin de mes— y querés saber cuánto podés gastar sin quedarte corto,
es para vos.

QUÉ HACE

• Presupuesto mensual. Registrá tu ingreso, repartilo entre tus obligaciones
  fijas y variables, y mirá cuánto queda disponible.
• Cobros parciales. Si cobrás en partes, cargá cada una por separado: quincena,
  fin de mes, lo que sea.
• Gastos reales. Anotar un gasto toma segundos. La app te marca cuándo te
  pasaste del presupuesto de una categoría.
• Deudas en cuotas. Cargá una compra en cuotas una vez y la app calcula sola
  cuánto compromete cada mes, hasta que se termine.
• Ahorro. Ponete una meta mensual y seguí tus aportes.
• Desglose por categoría. Ves en qué se te va la plata, con el detalle de qué
  deuda aporta a cada monto.
• Respaldo. Sacá una copia de todos tus datos cuando quieras y volvé a
  cargarla al cambiar de teléfono.

QUÉ NO HACE, A PROPÓSITO

• No pide cuenta ni registro. No sabemos quién sos.
• No tiene publicidad.
• No tiene analítica ni telemetría.
• No manda tus datos a ningún servidor, porque no hay ningún servidor.

Tus datos viven en tu teléfono y ahí se quedan. Desinstalás la app y no queda
copia de nada en ningún lado, porque nunca existió.

ES GRATIS Y COMPLETA

Todo lo que ves está disponible sin pagar, sin límite de tiempo y sin límite
de cantidad. No hay funciones bloqueadas ni versión "pro". Si te resulta útil
y querés apoyar el proyecto, hay una propina voluntaria en Ajustes — que no
desbloquea nada, porque ya lo tenés todo.

PENSADA PARA PERÚ

Montos en soles, con el formato de acá. Los cálculos se hacen con centavos
enteros, no con decimales aproximados: el total que ves es el total exacto,
sin errores de redondeo.

CAPTURA DE CONSUMOS (OPCIONAL)

Si se lo permitís, la app puede leer las notificaciones de tus bancos y
billeteras para detectar consumos y ahorrarte cargarlos a mano. Todo el
procesamiento ocurre dentro de tu teléfono y nada se transmite. Nunca registra
un gasto sola: cada consumo detectado espera a que vos lo confirmes. Podés no
darle ese permiso y usar la app completa igual.
```

**Categoría**: Finanzas
**Etiquetas**: presupuesto, gastos, ahorro, finanzas personales
**Público objetivo**: mayores de 18 (contenido financiero, sin restricción real)
**Contiene anuncios**: No
**Compras dentro de la app**: Sí (propina voluntaria)

---

## 2. Formulario de Seguridad de los datos

Es el que más suspensiones provoca, porque se responde de memoria y sin mirar
el código. Acá está respondido contra lo que la app hace de verdad.

**¿La app recopila o comparte alguno de los tipos de datos requeridos?**
→ **No.**

Justificación por si Play repregunta: los datos financieros que el usuario
carga se guardan en el almacenamiento privado de la app, en su dispositivo. No
se transmiten a ningún servidor —no existe ninguno del desarrollador— ni a
terceros. Según la definición de Google, "recopilar" es transmitir datos fuera
del dispositivo; nada de lo que el usuario carga sale de ahí.

**¿Los datos se cifran en tránsito?**
→ No aplica: no hay datos en tránsito.

**¿El usuario puede pedir que se borren sus datos?**
→ Sí: desinstalando la app. No hay copia en ningún otro lado.

**Sobre la compra dentro de la app**: la procesa Google Play. El desarrollador
no recibe datos de pago ni de facturación; solo el identificador del producto y
el estado de la compra, que gestiona la propia biblioteca de Google Play
Billing.

**Sobre el respaldo**: el archivo lo genera la app y se lo entrega al usuario
por la hoja de compartir del sistema. La app no elige destino ni lo sube a
ningún lado. Es una acción manual del usuario sobre sus propios datos, no una
recopilación del desarrollador.

---

## 3. Declaración del acceso a notificaciones

Play pide justificar el uso de `NotificationListenerService`, y lo mira con
lupa en apps de finanzas por riesgo de fraude. Texto propuesto:

```
La app usa el acceso a notificaciones exclusivamente para detectar consumos
con tarjeta del propio usuario y ofrecerle registrarlos en su presupuesto, y
así ahorrarle cargarlos a mano.

Es una función opcional: la app es completamente utilizable sin conceder este
permiso, registrando los gastos manualmente. El usuario ve una explicación de
qué se va a leer y qué se hace con eso ANTES de que se le pida el permiso, y
puede revocarlo en cualquier momento.

Solo se procesan las notificaciones de una lista cerrada de bancos y
billeteras, visible dentro de la app. De cada una se extrae únicamente el
monto, el comercio y la fecha del consumo. No se leen notificaciones de
mensajería, redes sociales ni ninguna otra aplicación.

Todo el procesamiento ocurre en el dispositivo. El contenido de las
notificaciones no se transmite a ningún servidor, ni del desarrollador ni de
terceros, y no se comparte con nadie. La app no tiene servidores.

La app nunca registra un gasto por su cuenta: cada consumo detectado queda en
una bandeja de pendientes hasta que el usuario lo confirma explícitamente.
```

---

## 4. Lo que falta y solo se puede hacer con el dispositivo

- **Capturas de pantalla**: mínimo 2, hasta 8, en formato teléfono. Las que
  valen la pena: Resumen con el disponible del mes, Presupuesto con las
  obligaciones cargadas, Gastos, Deudas con una compra en cuotas, y el
  desglose por categoría. Con datos de ejemplo realistas, no vacíos.
- **Ícono**: 512 × 512 px, PNG de 32 bits.
- **Gráfico destacado**: 1024 × 500 px.
- **Cuestionario de clasificación de contenido**: lo responde el desarrollador
  en Play Console; para esta app no hay contenido sensible de ninguna
  categoría.
