# Data Model: Suscripción premium

## 1. Enums

### `PlanSuscripcion`

| Valor | Slug | Etiqueta |
|---|---|---|
| `mensual` | `mensual` | Mensual |
| `anual` | `anual` | Anual |

### `SituacionSuscripcion`

| Valor | Slug | Etiqueta | ¿Acceso premium? |
|---|---|---|---|
| `nunca` | `nunca` | Nunca suscripto | No |
| `enPrueba` | `en_prueba` | En prueba gratis | Sí |
| `activa` | `activa` | Activa | Sí |
| `enGracia` | `en_gracia` | Pago pendiente (en gracia) | Sí |
| `vencida` | `vencida` | Vencida | No |
| `cancelada` | `cancelada` | Cancelada | No |

`enGracia` concede acceso porque es Google Play, no la app, quien decide cuánto
dura ese margen tras un cobro fallido (FR-013): la app solo refleja el estado
que le informa.

## 2. Entidades

### `EstadoSuscripcion`

Estado cacheado localmente de la suscripción. Fila única, análoga a
`Configuracion` (spec 001).

| Campo | Tipo | Reglas |
|---|---|---|
| `situacion` | `SituacionSuscripcion` | Nunca ausente; arranca en `nunca`. |
| `plan` | `PlanSuscripcion?` | `null` solo cuando `situacion == nunca`. |
| `vigenteHasta` | `DateTime?` | Fecha hasta la que cubre el período actual. `null` cuando `situacion == nunca` o `cancelada` sin período restante. Informativo: no se usa para calcular vigencia (ver `research.md` D2). |
| `ultimaVerificacion` | `DateTime` | Cuándo se confirmó este estado contra Google Play por última vez. Arranca en la fecha de instalación si nunca se pudo verificar. |

**Derivado**:

| Campo | Fórmula |
|---|---|
| `estaVigente` | `situacion` es `enPrueba`, `activa` o `enGracia`. |

### `OfertaSuscripcion`

No persistida: se consulta en vivo a Google Play para mostrar el paywall
(FR-005). Si no hay conexión, el paywall lo indica y ofrece reintentar; no se
inventan precios.

| Campo | Tipo | Reglas |
|---|---|---|
| `plan` | `PlanSuscripcion` | |
| `precioFormateado` | `String` | Ya viene localizado y formateado por Google Play (ej. `"S/ 19.90 al mes"`); la app no hace aritmética sobre este valor (Principio II no aplica: no es un monto que la app calcule o guarde). |
| `duracionPruebaDias` | `int` | Días de prueba gratis de esa oferta (FR-006a). |

## 3. Puerto de datos

### `RepositorioSuscripcion` (interfaz en `dominio/repositorios/`)

```dart
Future<EstadoSuscripcion>        estadoCacheado();
Future<EstadoSuscripcion>        refrescar();
Future<List<OfertaSuscripcion>>  ofertasDisponibles();
Future<EstadoSuscripcion>        comprar(PlanSuscripcion plan);
Future<EstadoSuscripcion>        restaurar();
```

Ver el contrato completo, con las garantías de cada método, en
[contracts/repositorio-suscripcion.md](./contracts/repositorio-suscripcion.md).

## 4. Esquema SQL (incremento de versión)

```sql
-- Esquema.version pasa de 3 a 4 (la base ya iba por v3: spec 002 la subió
-- a 2, spec 003 a 3). Migración v3 → v4, no destructiva.
CREATE TABLE suscripcion_premium (
  id                    INTEGER PRIMARY KEY CHECK (id = 1),
  situacion             TEXT    NOT NULL
                          CHECK (situacion IN ('nunca','en_prueba','activa',
                                                'en_gracia','vencida','cancelada')),
  plan                  TEXT    CHECK (plan IN ('mensual','anual')),
  vigente_hasta         TEXT,               -- 'YYYY-MM-DD', nullable
  ultima_verificacion   TEXT    NOT NULL     -- 'YYYY-MM-DD'
);
```

**Convenciones**: mismo criterio que el resto del esquema — `CHECK` como
última línea de defensa, no como validación de cara al usuario; una sola fila
(`id = 1`) igual que `configuracion`; fechas en texto ISO, igual que
`transaccion.fecha` y `aporte_ahorro.fecha`.

## 5. Trazabilidad requisito → modelo

| Requisito | Modelo/campo |
|---|---|
| FR-001, FR-002, FR-003 (bloquear sin suscripción activa) | `EstadoSuscripcion.estaVigente` |
| FR-005, FR-006, FR-006a (paywall con plan, precio y prueba) | `OfertaSuscripcion` |
| FR-007, FR-008 (desbloqueo inmediato / compra cancelada sin efecto) | `RepositorioSuscripcion.comprar` |
| FR-009 (mostrar estado vigente) | `EstadoSuscripcion.situacion`, `.plan`, `.vigenteHasta` |
| FR-010, FR-011, FR-013 (vencimiento sin pérdida de datos, período de gracia) | `SituacionSuscripcion` (`enGracia`, `vencida`, `cancelada`) — no toca ninguna tabla de Deudas/Ahorro/notificaciones |
| FR-014, FR-015 (restaurar) | `RepositorioSuscripcion.restaurar` |
| FR-016 (sin datos financieros en la verificación) | El modelo no incluye ningún campo de `Dinero`, `Deuda`, `AporteAhorro` ni similar |
