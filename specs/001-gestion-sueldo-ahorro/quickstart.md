# Quickstart — Validar la feature 001

**Feature**: 001-gestion-sueldo-ahorro | **Fecha**: 2026-08-26

Guía para levantar el proyecto y comprobar que la funcionalidad hace lo que dice la spec. No contiene código de implementación: eso pertenece a `tasks.md` y a la fase de implementación.

---

## Requisitos previos

- Flutter 3.47.1 stable, ya instalado en `C:\Users\manue\dev\flutter` (Dart 3.13.1).
- El SDK **no está en el `PATH`** de la terminal. Para la sesión actual, en PowerShell:

  ```powershell
  $env:PATH = "C:\Users\manue\dev\flutter\bin;$env:PATH"
  flutter --version
  ```

  Para dejarlo permanente conviene agregarlo al `PATH` del usuario desde la configuración de Windows. Las órdenes de esta guía asumen que `flutter` ya resuelve.

- Un dispositivo Android o un emulador para las pruebas manuales. `flutter devices` debe listar al menos uno. Las pruebas automáticas **no** lo necesitan: corren en Windows.

---

## Puesta en marcha

```powershell
flutter pub get
flutter analyze          # debe salir sin issues
flutter test             # toda la suite
flutter run              # app en el dispositivo seleccionado
```

---

## Validación automática

La suite es la primera línea de verificación y cubre los criterios de exactitud (SC-007) sin abrir la app.

```powershell
flutter test test/dominio          # reglas financieras puras (Principio III)
flutter test test/datos            # repositorios contra SQLite real (sqflite_common_ffi)
flutter test test/ui               # reglas de presentación
flutter test test/pureza_test.dart # guarda: lib/dominio no importa flutter ni sqflite
```

| Qué se comprueba | Dónde | Requisito |
|---|---|---|
| Totales, déficit, saldo exactamente cero | `test/dominio/resumen_mes_test.dart` | FR-025 – FR-030, SC-007 |
| Cuotas vigentes, saldo pendiente, mes de término, saldado anticipado | `test/dominio/deudas_test.dart` | FR-015 – FR-024 |
| Sugerencia, meta del mes, progreso y acumulado de ahorro | `test/dominio/ahorro_test.dart` | FR-031 – FR-043, FR-053, FR-054 |
| Subtotales por categoría que suman el total sin descuadre | `test/dominio/desglose_test.dart` | FR-046 |
| Formato `S/ 1,234.56` y montos de siete cifras | `test/dominio/dinero_test.dart` | FR-048, FR-049 |
| Persistencia y migración sin pérdida de datos | `test/datos/base_datos_test.dart` | FR-050, constitución |
| Cierre de meses y ventana de gracia | `test/dominio/cierre_mes_test.dart` | FR-052, FR-055 – FR-058 |

---

## Validación manual por historia de usuario

Cada bloque es independiente y arranca desde la app recién instalada, salvo que se indique lo contrario.

### HU1 — Registrar ingreso y presupuesto (P1)

1. Registrar un ingreso de `S/ 3,000.00` para el mes en curso.
2. Añadir cuatro obligaciones: alquiler `S/ 900.00` (fija, departamento), luz `S/ 120.00` (fija, servicios), pasajes `S/ 200.00` (variable), comida `S/ 600.00` (variable).
3. Cerrar la app por completo y volver a abrirla.
4. Editar el alquiler a `S/ 950.00` y eliminar la obligación de luz.
5. Intentar guardar una obligación con monto vacío y otra con `-50`.

**Esperado**: todo persiste tras reabrir (SC-011); los totales se recalculan al instante tras editar y eliminar; los dos montos inválidos se rechazan con un motivo legible en español y ninguno queda guardado (FR-005).

### HU2 — Resumen del mes y déficit (P1)

1. Con el estado de la HU1, abrir el resumen.
2. Subir las obligaciones hasta superar el ingreso (por ejemplo, comida a `S/ 1,900.00`).
3. Ajustar las obligaciones para que el comprometido iguale exactamente el ingreso.
4. Abrir un mes sin ingreso registrado.

**Esperado**: (1) ingreso `S/ 3,000.00`, comprometido y disponible proyectado coherentes al centavo con la cuenta a mano; (2) la app declara el déficit con texto e ícono —no solo con color— e indica el faltante exacto (FR-028, FR-029); (3) disponible `S/ 0.00` **sin** declarar déficit (FR-030); (4) la app pide registrar el ingreso en vez de mostrar ceros (HU2 esc. 4).

### HU3 — Gastos reales contra presupuesto (P1)

1. Con comida presupuestada en `S/ 600.00`, registrar un gasto de `S/ 45.00` en comida.
2. Con pasajes en `S/ 200.00` y `S/ 190.00` ya gastados, registrar `S/ 25.00` más.
3. Registrar un gasto en una categoría sin presupuesto.
4. Registrar gastos con fechas distintas y abrir el listado del mes.
5. Editar un gasto y eliminar otro.
6. Registrar un gasto con fecha del mes anterior.

**Esperado**: (1) comida muestra `S/ 45.00` de `S/ 600.00` y `S/ 555.00` restantes; (2) la app señala el sobregiro de `S/ 15.00` sin bloquear el registro (FR-014); (3) el gasto se contabiliza y se marca como no presupuestado (FR-012); (4) listado ordenado de la fecha más reciente a la más antigua (FR-013); (5) los acumulados se recalculan; (6) el gasto aparece en el mes de su fecha, no en el mes abierto (FR-008).

### HU4 — Deudas en cuotas (P2)

1. Registrar una tarjeta de crédito (nombre, entidad de la lista, tipo crédito) y una tarjeta de débito. Luego una deuda de 12 cuotas de `S/ 150.00` con inicio en el mes en curso.
2. Registrar una segunda deuda de `S/ 80.00` en la misma tarjeta.
3. Registrar una tercera deuda con inicio dentro de tres meses.
4. Abrir el presupuesto del mes y desplegar el compromiso de la tarjeta.
5. Navegar al mes siguiente y a un mes posterior a la última cuota de la primera deuda.
6. Corregir el número de cuotas de una deuda ya registrada.
7. Marcar una deuda como saldada anticipadamente.

**Esperado**: la tarjeta de débito **no** aparece al crear la deuda (FR-061); la categoría tarjeta de crédito muestra `S/ 230.00` desglosable en sus dos deudas (FR-017); la deuda futura no aporta al mes actual pero sí al total adeudado (FR-020); tras la última cuota la deuda desaparece del presupuesto y queda saldada (FR-019); la corrección recalcula los meses afectados y el saldo pendiente sin tocar los gastos reales ya registrados (FR-023); la deuda saldada anticipadamente deja de aportar cuotas y su saldo pasa a `S/ 0.00` (FR-021). La vista de deudas muestra total adeudado, compromiso mensual agregado y mes en que quedará libre de deudas (FR-022, SC-006).

### HU5 — Ahorro (P2)

1. Elegir la regla "porcentaje del ingreso" al 20% con ingreso `S/ 3,000.00`.
2. Subir los compromisos a `S/ 2,700.00` y volver a mirar la sugerencia.
3. Cambiar a la regla "lo que sobre".
4. Fijar una meta de `S/ 500.00` para el mes en curso, luego cambiarla a `S/ 1,500.00` con disponible `S/ 1,200.00`.
5. Registrar un aporte de `S/ 300.00` y después otro de `S/ 250.00`.
6. Entrar en déficit y mirar la sugerencia.
7. Consultar el historial y el acumulado.
8. Avanzar al mes siguiente y abrir la sección de ahorro sin fijar meta todavía.
9. Volver a un mes pasado que tuvo una meta distinta de la actual.

**Esperado**: (1) sugiere `S/ 600.00`; (2) advierte que el 20% excede el disponible de `S/ 300.00` y ofrece ese disponible como alcanzable (FR-034); (3) sugiere el disponible completo; (4) `S/ 500.00` alcanzable con margen `S/ 700.00`, `S/ 1,500.00` no alcanzable indicando el recorte de `S/ 300.00` (FR-036); (5) ahorro del mes `S/ 550.00`, señalando que superó la meta en `S/ 50.00` (FR-040); (6) la sugerencia se suprime y la app remite a revisar compromisos (FR-037); (7) el acumulado histórico es consultable en una interacción y los meses sin aportes figuran con `S/ 0.00` (FR-041, FR-043, SC-010); (8) la app propone la meta del mes anterior y **no** la deja fijada hasta confirmarla (FR-053); (9) ese mes se evalúa contra la meta que tenía entonces, no contra la vigente hoy (FR-054).

### HU6 — Desglose por categoría (P3)

1. Con gastos repartidos en cuatro categorías, abrir el desglose.
2. Sumar a mano los subtotales de gasto y compararlos con el total real del mes.

**Esperado**: una fila por categoría con presupuestado, gastado, diferencia y peso porcentual sobre el ingreso, ordenadas de mayor a menor gasto; las categorías sin presupuesto ni gasto no aparecen (FR-047); las sobregiradas se distinguen sin depender solo del color (FR-029); los subtotales suman exactamente el total (FR-046, SC-007).

---

### Cierre de meses (transversal)

1. Con `diasGraciaCierre` en 5 y estando dentro de los primeros cinco días del mes, registrar un gasto con fecha del mes anterior.
2. Intentar editar ese mismo gasto recién registrado.
3. Poner `diasGraciaCierre` en 0 y volver a intentar registrar en el mes anterior.
4. Abrir un mes de hace tres meses e intentar cualquier cambio.
5. Con un mes cerrado a la vista, corregir el número de cuotas de una deuda que lo afecta.

**Esperado**: (1) se admite y la app avisa de que quedará inmutable (FR-055); (2) no hay acción de editar ni eliminar (FR-056); (3) se rechaza con el motivo explícito; (4) el mes se muestra de solo lectura con el aviso correspondiente, legible sin color (FR-052, FR-058); (5) **sí** se permite, y las cuotas de ese mes cerrado se recalculan — es la única corrección admitida sobre un mes cerrado (FR-057).

---

## Comprobaciones transversales

| Comprobación | Cómo | Requisito |
|---|---|---|
| Funciona sin internet | Activar modo avión y usar la app completa | SC-012, Principio I |
| Primer uso en menos de 3 minutos | Con un probador que no haya visto la app, cronometrar el registro del ingreso y cinco obligaciones, sin darle instrucciones | SC-003 |
| Los datos sobreviven al reinicio | Reiniciar el dispositivo y reabrir | SC-011, FR-050 |
| Montos de siete cifras | Registrar `S/ 9,999,999.99` y revisar que no desborde la interfaz | Edge case "montos grandes" |
| Mes nuevo en menos de 30 s | Avanzar al mes siguiente y confirmar la precarga de fijas | SC-004, FR-006 |
| Registrar un gasto en menos de 15 s | Cronometrar desde la app abierta | SC-002 |
| Sin salida de datos | `flutter pub deps` y revisar que ninguna dependencia sea de red o telemetría | Principio I |

---

## Referencias

- Contratos: [contracts/calculos-dominio.md](./contracts/calculos-dominio.md), [contracts/repositorios.md](./contracts/repositorios.md)
- Modelo de datos y esquema SQL: [data-model.md](./data-model.md)
- Decisiones técnicas: [research.md](./research.md)
