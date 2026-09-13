# Quickstart: Apoyo voluntario (propina)

**Revisado 2026-09-12.** El recorrido anterior validaba comprar una
suscripción, ver Deudas desbloquearse y restaurarla en otro dispositivo. Nada
de eso existe ya: no hay nada que desbloquear ni que restaurar.

---

## Lo que la suite automatizada sí cubre

```powershell
$env:PATH = "C:\Users\manue\dev\flutter\bin;$env:PATH"
flutter test test/ui/todo_gratis_test.dart        # ningún destino está bloqueado
flutter test test/ui/pantalla_propina_test.dart   # montos, error sin conexión, cancelar
flutter test test/datos/migracion_005_test.dart   # la tabla se va sin perder datos
flutter analyze
```

La garantía central de esta feature —que **ningún** destino esté condicionado a
un pago— está fijada por `todo_gratis_test.dart`, no por este recorrido: es una
propiedad que una prueba puede verificar mejor que un par de ojos.

## Lo que solo se puede validar a mano

El flujo de compra real no se puede automatizar (research.md D5). Necesita la
app publicada en la pista de pruebas internas de Google Play Console y una
cuenta con licencia de prueba.

### Antes de empezar

1. Los tres productos **consumibles** creados y activos en Play Console:
   `propina_cafe`, `propina_menu`, `propina_generosa` (T068). Consumibles, no
   suscripciones: de eso depende poder apoyar más de una vez.
2. El APK subido a la pista de pruebas internas, con el mismo
   `applicationId` (`io.github.manuellegua.finanzas`) y firmado con la misma
   clave que se subirá después.
3. La cuenta de Google del dispositivo dada de alta como probador de licencias,
   para que las compras no cobren de verdad.

### Recorrido

1. **Nada está bloqueado.** Recorrer los cinco destinos de la barra inferior y
   todos los del menú lateral. Ninguno debe pedir pagar ni sustituir su
   contenido. En particular: Deudas y Ahorro muestran sus datos, y "Captura"
   arranca el flujo del permiso sin pedir nada antes. **Si algo pide pagar, la
   revisión está incumplida, no incompleta.**
2. **El apoyo se encuentra, pero no se cruza.** Ajustes es el único lugar donde
   aparece. Verificar que no hay ningún banner, diálogo ni distintivo de apoyo
   en ninguna otra pantalla (FR-006, SC-002).
3. **Los precios son los de la tienda.** Abrir "Apoyar esta app": los tres
   montos con el precio que devuelve Google Play, y el texto que dice que no
   desbloquea nada. Ningún precio escrito a mano en la app (FR-004, FR-005).
4. **Cancelar no duele.** Elegir un monto, abrir el diálogo de Google y
   cerrarlo. No debe aparecer ningún error ni reproche, y no debe cobrarse
   nada (FR-008).
5. **Apoyar funciona.** Completar una compra. La app tiene que agradecer de
   forma visible (FR-012).
6. **Nada cambió.** Volver a recorrer Deudas, Ahorro, Resumen y Ajustes: todo
   igual que en el paso 1. Este paso es el que verifica SC-003 y es el más
   fácil de saltearse por obvio.
7. **Se puede apoyar de nuevo.** Volver a la pantalla y completar una segunda
   compra del mismo monto. Si Google la rechaza por "ya lo tenés", el producto
   quedó creado como no consumible en Play Console: corregirlo ahí (FR-007).
8. **Sin conexión se dice, no se inventa.** Poner el dispositivo en modo avión
   y abrir la pantalla de apoyo: tiene que explicar que no pudo consultar los
   montos y ofrecer reintentar, sin mostrar ningún precio (FR-011, SC-005).
9. **Una compra interrumpida no se pierde.** Iniciar una compra y cerrar la app
   antes de que Google confirme. Volver a abrir la pantalla de apoyo: la compra
   pendiente tiene que quedar acusada, sin cobrar de nuevo (FR-010, SC-004).
   Este es el paso que evita el peor resultado posible de esta feature —que
   alguien pague y Google le devuelva la plata a los tres días por falta de
   confirmación.

### Sin Google Play

En un emulador sin servicios de Google, el paso 3 debe mostrar que el apoyo no
está disponible **sin romper Ajustes**: el resto de la pantalla (días de
gracia, respaldo) tiene que seguir funcionando. Es el caso más probable en
desarrollo diario y conviene verificarlo antes que ningún otro.
