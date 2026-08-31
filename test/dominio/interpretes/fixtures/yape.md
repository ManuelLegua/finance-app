# Fixtures — Yape

Notificaciones reales capturadas de la app Yape (billetera), tal como aparecen en la barra de notificaciones de Android — **no** el correo del banco, que usa otra plantilla (T034, research.md D-N9).

`packageName`: pendiente de confirmar (T041).

---

## Ejemplo 1 — Dinero entrante (pago recibido)

**Capturado**: 2026-08-30, 18:57 (dom, 30 de ago)

**Título**: `Confirmación de Pago`

**Cuerpo**:
```
Yape! Manuel Alexander Legua Mendoza te envió un pago por S/ 3.40
```

**Dirección esperada**: entrante (`NoEsConsumo`, FR-012) — no debe generar un `ConsumoPendiente`.

**Monto en el texto**: S/ 3.40

**Quién envía**: Manuel Alexander Legua Mendoza (persona, no comercio — coherente con que Yape es P2P).

**Nota**: el título real (`Confirmación de Pago`) y el cuerpo (`te envió un pago por`) **difieren** del patrón de referencia registrado en research.md D-N11 (`"[Nombre] te yapeó S/ [monto]"`), que era una suposición sin captura real todavía. Palabra clave de entrada presente en el cuerpo real: **"te envió"** — confirma esa entrada de la lista de D-N11; **"te yapeó"** queda sin confirmar hasta ver un ejemplo real que la use. El título por sí solo ("Confirmación de Pago") es ambiguo — podría leerse como saliente si el parser mirara solo el título; el cuerpo es el que desambigua. **Implicación para el parser (T037–T039): no basta con mirar el título, hay que priorizar las palabras clave del cuerpo.**

---

<!--
Siguiente: agregar acá un consumo saliente real de Yape (pagar en una tienda con
el QR de Yape), y si aparece, un rechazo/extorno. Cuando haya al menos un
consumo saliente de este origen, más ejemplos de otros 2 orígenes variados
(banco tradicional + emisor de tarjeta, según D-N9), T034 se da por cumplida.
-->
