/// Los cuerpos de correo tal como los capturó la app, para las pruebas del
/// parser genérico (T038/T038a).
///
/// **Extraídos de [notificacion-gmail-capturada.md](./notificacion-gmail-capturada.md),
/// no escritos a mano.** D-N9 prohíbe construir el parser contra texto
/// inventado, y esa prohibición no sirve de nada si el texto se re-teclea al
/// pasarlo a Dart: estas constantes se generaron leyendo los bloques del
/// fixture, que a su vez los volcó el propio teléfono.
///
/// Si hace falta cambiarlos, se cambia el `.md` —que es la fuente— y se
/// vuelven a extraer. Editar este archivo a mano rompe esa cadena.
library;

/// G2 — Sip, operación saliente (yapeo enviado, S/ 20.00).
///
/// Un envío de dinero, que desde D-N15 es un consumo igual que una compra.
const String cuerpoG2SipSaliente = 'Realizaste una operación\n\nHola Manuel Alexander\nPor tu seguridad, te enviamos\nlos datos de tu operación.\nOperación realizada: Enviar a celular\nMonto\nS/ 20.00\nEnviado a\nManuel Alexander Legua Mendoza\n*** ***992\nDestino\nYape\nFecha y Hora\n13/09/2026 - 00:29';

const String tituloG2Sip = 'Operaciones Sip';

/// G3 — BCP, operación entrante (yapeo recibido, S/ 20.00).
///
/// FR-012 y FR-013 mandan ignorarlo.
const String cuerpoG3BcpEntrante = 'Constancia de recepción de Yapeo a celular BCP - Servicio de Notificaciones BCP\n\nHola Manuel Alexander,\nRecibiste un yapeo de S/ 20.00 de Manuel Alexander Legua Mendoza.\nMonto\nMonto recibido\nS/ 20.00\nDatos de la operación\nOperación realizada\nYapeo a celular\nFecha y hora\n13 de septiembre de 2026 - 12:29 AM\nEnviado por\nManuel Alexander Legua Mendoza\n¿No reconoces esta operación?\nComunícate inmediatamente con nosotros al\n(01)​ 311​-9898 anexo *911 para ayudarte a verificarla.\n¡Seguimos transformando tus planes en realidad!\nJuntos somos más seguros\nEl BCP nunca te solicitará datos confidenciales por correo, tales como tu clave secreta de cajero de 4 dígitos, clave de internet de 6 dígitos, número de t';

const String tituloG3Bcp = 'BCP Notificaciones';

/// G4 — BCP, consumo con Tarjeta de Crédito **en dólares** (`\$ 23.60`).
///
/// Los 1024 caracteres exactos que dejó pasar Android, pie del correo
/// incluido — y el pie es parte del caso de prueba, no ruido: contiene
/// "compras", "rechazada" y "tarjeta de débito o crédito", que envenenan la
/// clasificación de D-N11 si el parser lo lee.
const String cuerpoG4BcpConsumoDolares = 'Realizaste un consumo con tu Tarjeta de Crédito BCP - Servicio de Notificaciones BCP\n \nHola Manuel Alexander,\nRealizaste un consumo de \$ 23.60 con tu Tarjeta de Crédito BCP en ANTHROPIC* CLAUDE SUB.\nPor tu seguridad, te enviamos los datos de tu operación.\nMonto\nTotal del consumo\n\$ 23.60\nDatos de la operación\nOperación realizada\nConsumo Tarjeta de Crédito\nFecha y hora\n13 de setiembre de 2026 - 10:54 AM\nNúmero de Tarjeta de Crédito\n************6140\nEmpresa\nANTHROPIC* CLAUDE SUB\nNúmero de operación\n0000510200\n¿Problemas con tus compras?\nSi tu compra fue rechazada, cancelada o duplicada, el tiempo estimado de devolución será de 3 a 7 días.\n¿No reconoces esta operación?\nComunícate inmediatamente con nosotros al\n(01)​ 311​-9898 anexo *911 para ayudarte a verificarla.\n¡Seguimos mejorando para ti!\nJuntos somos más seguros\nEl BCP nunca te solicitará datos confidenciales por correo, tales como tu clave secreta de cajero de 4 dígitos, clave de internet de 6 dígitos, número de tu tarjeta de débito o crédito, fecha de ven';

const String tituloG4Bcp = 'BCP Notificaciones';

/// G5 — Sip, consumo con Tarjeta de Crédito **en soles** (`S/. 37.70`).
///
/// El camino feliz. Tres cosas que no aparecen en ningún correo del BCP: el
/// sol se escribe `S/.` con punto, la etiqueta del comercio es
/// `Establecimiento:` con dos puntos, y **el pie no empieza con `¿`** — la
/// regla de recorte que sirve para el BCP no sirve acá.
const String cuerpoG5SipConsumoSoles = 'Sip, realizaste un consumo con tu Tarjeta de Crédito Sip\nHola, MANUEL.\nHas realizado una transacción \ncon tu Tarjeta de Crédito Sip.\nTarjeta Titular:\nXXXXXXXXXXXX2145\nEstablecimiento:\nIKF 982 PV VENTANILLA\nMonto:\nS/. 37.70\nFecha de operación:\n13/09/2026 a las 21:09\nSi no reconoces la operación, comunícate de inmediato al (01) 619-3100.\nPara tu seguridad: \nSip jamás solicitará el número, fecha de \nvencimiento, CVV o claves de tu tarjeta, ni \npedirá que la entregues mediante visitas.\nEste correo electrónico fue enviado por: InFinance XP S.A.\nAvenida Aviación 2405 Piso 9, Lima, Lima, San Borja Peru \nPrivacy Policy \nUpdate Profile Manage Subscriptions Unsubscribe';

/// G6 — Sip, segundo consumo en soles (`S/. 15.90`), cuatro minutos después.
///
/// Mismo formato y misma tarjeta que G5: sirve de par para la deduplicación.
const String cuerpoG6SipConsumoSoles = 'Sip, realizaste un consumo con tu Tarjeta de Crédito Sip\nHola, MANUEL.\nHas realizado una transacción \ncon tu Tarjeta de Crédito Sip.\nTarjeta Titular:\nXXXXXXXXXXXX2145\nEstablecimiento:\n231 PVEA VENTANILLA\nMonto:\nS/. 15.90\nFecha de operación:\n13/09/2026 a las 21:14\nSi no reconoces la operación, comunícate de inmediato al (01) 619-3100.\nPara tu seguridad: \nSip jamás solicitará el número, fecha de \nvencimiento, CVV o claves de tu tarjeta, ni \npedirá que la entregues mediante visitas.\nEste correo electrónico fue enviado por: InFinance XP S.A.\nAvenida Aviación 2405 Piso 9, Lima, Lima, San Borja Peru \nPrivacy Policy \nUpdate Profile Manage Subscriptions Unsubscribe';

/// El remitente de un consumo con tarjeta de Sip son **tres caracteres**, y no
/// el `Operaciones Sip` con que firma un envío de dinero. Un mismo emisor usa
/// más de un nombre según el tipo de correo.
const String tituloG5G6Sip = 'Sip';

/// G7 — Yape, aviso de operación **sin monto**.
///
/// Confirma un yapeo —beneficiario, fecha, número de operación— pero no dice
/// de cuánto. Lo guardó la propia app en su diagnóstico durante la primera
/// prueba que funcionó de punta a punta, y es el caso que motivó D-N16: sin
/// monto no hay nada que registrar, y llamarlo "formato no reconocido" era
/// mentira además de ruido.
const String cuerpoG7YapeAvisoSinMonto = 'Por tu seguridad, te notificaremos por cada yapeo que realices\nYapero\nMANUEL ALEXANDER LEGUA M.\nTu número de celular\nXXXXXXXXX992\nFecha y Hora de la operación\n13 septiembre 2026 - 11:00 p. m.\nCelular del Beneficiario\nXXXXXXXXX992\nNombre del Beneficiario\nMANUEL ALEXANDER LEGUA M.\nNº de operación\n7108364';

const String tituloG7Yape = 'YAPE Notificaciones';
