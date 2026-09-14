# Contrato — Parser genérico de notificaciones (`lib/dominio/interpretes/`)

**Feature**: 002-captura-notificaciones-bancarias

**Revisión 2026-08-30**: reemplaza el contrato original de "un `InterpreteNotificacion` por banco". Ahora hay un único parser genérico que interpreta el texto de cualquier origen reconocido (D-N2). Ver research.md D-N2, D-N10, D-N11.

Puro Dart: sin `package:flutter/`, sin el plugin de notificaciones, sin `sqflite`, sin `DateTime.now()` interno — la fecha de recepción entra como parámetro, igual que en `cierre_mes.dart` de 001. `test/pureza_test.dart` cubre también esta carpeta.

## Contrato

```dart
sealed class ResultadoInterpretacion {}

final class ConsumoExtraido extends ResultadoInterpretacion {
  final Dinero monto;
  final String comercio;
  final DateTime fecha;       // fecha del consumo, no de recepción
}

final class NoEsConsumo extends ResultadoInterpretacion {}          // dinero entrante, promoción, etc. — FR-012, FR-013

final class NoInterpretable extends ResultadoInterpretacion {
  final MotivoDiagnostico motivo;
}

/// Único parser, compartido por todos los orígenes de `origenesReconocidos`
/// (D-N10). No recibe el origen como parámetro porque no lo necesita: el
/// texto es lo único de lo que depende (D-N2) — es justamente lo que permite
/// que un banco nuevo no exija código nuevo.
ResultadoInterpretacion interpretar({
  required String titulo,
  required String contenido,
  required DateTime recibidaEn,
});
```

| Garantía | Requisito |
|---|---|
| Nunca devuelve `ConsumoExtraido` con datos parciales o inventados | FR-017 |
| El monto se compone con aritmética entera, nunca `double.parse` | D-N3, Principio II |
| Clasifica la notificación como saliente o entrante por palabras clave en el texto (D-N11), nunca asumiéndolo por la app de origen | FR-008b |
| Dinero entrante, consumo rechazado o extornado, y avisos que no son consumo son `NoEsConsumo` | FR-012, FR-013 |
| Un texto que no menciona **ninguna cifra de dinero** es `NoEsConsumo`, no `NoInterpretable`: sin monto no hubo movimiento, y el diagnóstico es para lo que falló, no para lo que no era | D-N16 |
| Sin palabras clave de ninguna lista, o con señales de ambas direcciones a la vez, **pero con una cifra presente**, es `NoInterpretable(formatoNoReconocido)` — nunca se adivina la dirección | D-N11, D-N16 |
| Moneda distinta al sol es `NoInterpretable(monedaExtranjera)`, no un consumo en soles | FR-014 |
| Un texto de formato desconocido, de cualquier origen, es `NoInterpretable(formatoNoReconocido)`, nunca lanza ni produce un `ConsumoExtraido` a medias | FR-017 |

## `normalizarComercio`

```dart
String normalizarComercio(String comercioCrudo);
```

| Garantía | Requisito |
|---|---|
| Determinística: la misma entrada produce siempre la misma salida | D-N7 |
| Variantes de mayúsculas, espacios y sufijos de sucursal normalizan igual | FR-032 |

## `origenesReconocidos` (`lib/shared/constantes/`)

```dart
const List<OrigenReconocido> origenesReconocidos = [ /* paquete + nombre, D-N10 */ ];
```

Filtra **antes** de llegar al parser: el servicio de escucha (`datos/notificaciones/servicio_escucha.dart`) descarta de entrada cualquier notificación cuyo paquete no esté en esta lista (FR-008a, edge case "app no reconocida en absoluto"). El parser de arriba nunca ve, y por lo tanto nunca puede fallar sobre, una notificación de una app no reconocida.

## Nota de proceso (D-N9)

El parser genérico no empieza a escribirse sin una muestra real de notificaciones de **varios orígenes distintos** (se recomienda al menos 3, de tipos distintos: banco tradicional, billetera, emisor de tarjeta), documentada en `test/dominio/interpretes/fixtures/`. A diferencia del contrato original, **no hace falta una muestra de cada banco de `origenesReconocidos`** antes de que el parser funcione para todos ellos — esa es la ventaja de este diseño sobre el anterior.
