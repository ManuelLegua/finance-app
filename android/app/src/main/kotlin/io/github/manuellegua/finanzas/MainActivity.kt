package io.github.manuellegua.finanzas

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import im.zoe.labs.flutter_notification_listener.FlutterNotificationListenerPlugin
import im.zoe.labs.flutter_notification_listener.NotificationsHandlerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * El único código nativo propio del proyecto. Existe por dos razones, y las
 * dos son defectos del plugin de escucha que solo se pueden tapar desde acá:
 * **que activar y desactivar la captura muchas veces siga funcionando**, y
 * **que abrir la app no deje la captura muerta** (ver
 * [desalojarMotorDeLaInterfaz], T068).
 *
 * ## Por qué activar y desactivar rompía la escucha
 *
 * `flutter_notification_listener` apaga el servicio deshabilitando su
 * componente de sistema. Android entonces suelta la vinculación del listener
 * y **no la recupera al rehabilitarlo**: queda el componente habilitado, el
 * permiso concedido y el servicio corriendo en primer plano, pero sin recibir
 * ni una notificación, y sin ningún síntoma. Verificado en dispositivo el
 * 2026-09-13 (D-N13.2, T064a).
 *
 * El par que Android sí diseñó para "dejar de escuchar un rato y después
 * volver" es [NotificationListenerService.requestUnbind] y
 * [NotificationListenerService.requestRebind], y ninguno de los dos toca el
 * componente. `requestUnbind` es un método de instancia, así que hay que
 * llamarlo sobre el servicio vivo — el plugin publica el suyo como estática
 * pública, que es lo que hace innecesario forkearlo.
 *
 * **`requestRebind` por sí solo no alcanza**, y se probó: falla para listeners
 * que no fueron desvinculados con `requestUnbind`. Los dos van juntos o no van.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        desalojarMotorDeLaInterfaz()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { llamada, respuesta ->
                when (llamada.method) {
                    METODO_DESVINCULAR -> respuesta.success(desvincularEscucha())
                    METODO_REVINCULAR -> respuesta.success(revincularEscucha())
                    METODO_EXENTA -> respuesta.success(exentaDeOptimizacion())
                    METODO_AJUSTES_BATERIA -> {
                        abrirAjustesDeBateria()
                        respuesta.success(null)
                    }
                    else -> respuesta.notImplemented()
                }
            }
    }

    /**
     * Saca el motor de Flutter **de esta pantalla** de la ranura de caché que
     * el servicio de escucha usa para el suyo.
     *
     * Sin esto, abrir la app deja la captura muerta mientras ese proceso viva
     * (T068). El plugin guarda en [FlutterEngineCache], bajo **una sola
     * clave**, el motor al que se engancha — y se engancha a todos, incluido
     * el de la interfaz. Cuando después el servicio pide el suyo,
     * `getFlutterEngine` encuentra la ranura ocupada, devuelve el motor de la
     * interfaz y **se saltea el `executeDartCallback`**, que vive solo en la
     * rama del *miss* y es lo único que enciende el isolate de fondo. El
     * servicio queda hablándole a un canal donde nadie registró handler, y
     * cada notificación se pierde sin excepción ni log.
     *
     * Desalojando el motor acá, el servicio siempre cae en la rama del *miss*:
     * crea **su** motor y corre el callback ahí, que es el camino headless que
     * prometen D-N1 y FR-011 — la captura sigue viva con la app cerrada.
     *
     * **No le quita el motor a un servicio que ya esté andando.** El servicio
     * se guarda su `mBackgroundChannel` directo y no lo relee de la caché;
     * verificado en dispositivo el 2026-09-16 (prueba 5 de T068: abrir la app
     * después de un arranque por servicio no rompe la captura).
     *
     * La ranura de la interfaz no le hace falta a nadie más: el único que lee
     * esa clave es el plugin, y solo para esto.
     */
    private fun desalojarMotorDeLaInterfaz() {
        FlutterEngineCache.getInstance()
            .remove(FlutterNotificationListenerPlugin.FLUTTER_ENGINE_CACHE_KEY)
    }

    /**
     * Suelta la escucha sin tocar el componente, y con ella se va el servicio
     * y su notificación persistente.
     *
     * Devuelve `false` si no había servicio vivo al que pedírselo — que no es
     * un error: significa que ya estaba apagado.
     */
    private fun desvincularEscucha(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false

        val servicio = NotificationsHandlerService.instance ?: return false
        servicio.requestUnbind()
        return true
    }

    /**
     * Vuelve a pedir la escucha. Solo es válido si antes se soltó con
     * [desvincularEscucha]; por eso los dos métodos existen juntos.
     */
    private fun revincularEscucha(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false

        NotificationListenerService.requestRebind(
            ComponentName(this, SERVICIO_DE_ESCUCHA),
        )
        return true
    }

    /**
     * Si Android tiene a la app exenta de la optimización de batería.
     *
     * **Consultarlo no exige ningún permiso**; pedirlo con un diálogo directo
     * sí exigiría `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, que Play limita a
     * casos de uso acotados. Por eso la app consulta acá y manda a los ajustes
     * en [abrirAjustesDeBateria]: mismo resultado, un toque más, y nada que
     * justificar en la ficha.
     */
    private fun exentaDeOptimizacion(): Boolean {
        val energia = getSystemService(PowerManager::class.java) ?: return false
        return energia.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Abre la lista del sistema donde el usuario saca a una app de la
     * optimización de batería.
     *
     * Es `IGNORE_BATTERY_OPTIMIZATION_SETTINGS` —la lista— y no
     * `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` —el diálogo directo—, porque la
     * segunda exige el permiso restringido y esta no exige ninguno.
     */
    private fun abrirAjustesDeBateria() {
        startActivity(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
        )
    }

    private companion object {
        const val CANAL = "io.github.manuellegua.finanzas/captura"
        const val METODO_DESVINCULAR = "desvincularEscucha"
        const val METODO_REVINCULAR = "revincularEscucha"
        const val METODO_EXENTA = "exentaDeOptimizacionDeBateria"
        const val METODO_AJUSTES_BATERIA = "abrirAjustesDeOptimizacionDeBateria"

        /**
         * El nombre que declara el manifiesto. Va como cadena y no como clase
         * porque es el componente registrado, no el objeto: si el plugin lo
         * renombrara, esto deja de revincular en silencio y solo lo detecta el
         * recorrido en dispositivo, nunca la suite.
         */
        const val SERVICIO_DE_ESCUCHA =
            "im.zoe.labs.flutter_notification_listener.NotificationsHandlerService"
    }
}
