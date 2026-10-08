# Política de privacidad de MochiLog

## 1. Datos tratados

MochiLog procesa en el dispositivo los registros de análisis de iPhone, iPad y Apple Watch seleccionados por el usuario. Guarda registros de batería, modelo, fecha, capacidad, región del producto e identificadores para distinguir dispositivos físicos. Los registros originales pueden contener otros datos del dispositivo y de uso. Los ajustes y registros permanecen por regla general en el dispositivo y no se envían automáticamente al desarrollador.

## 2. Sincronización y transferencia opcionales

Con iCloud activado, los registros se sincronizan mediante la base de datos privada de iCloud del usuario entre dispositivos de la misma cuenta Apple. Pueden enviarse al Apple Watch enlazado o exportarse y compartirse por decisión del usuario. En la beta de transferencia para iOS/iPadOS 27 y macOS 27, un Mac enlazado recoge los registros cuando el móvil está desbloqueado, los guarda temporalmente y los transmite cifrados por la red local. Mac y móvil intercambian datos de enlace, estado y diagnósticos. Los registros no se envían a un servidor del desarrollador. La app Mac consulta GitHub para buscar actualizaciones; GitHub puede recibir datos de red como la dirección IP. La versión alfa complementaria para Windows 11 también envía los registros de un PC enlazado a MochiLog mediante transferencia cifrada.

Si se activa Batería en vivo, un ordenador vinculado obtiene ciclos de carga y capacidades actuales del servicio de diagnóstico del dispositivo y los envía cifrados a la app móvil. Estos valores solo se mantienen en memoria y no se guardan como historial, registros de batería, datos de iCloud ni registros de diagnóstico para soporte. La opción está desactivada por defecto. Es independiente de la recopilación y conservación de archivos Analytics diarios. Si se usa una VPN configurada por el usuario, como Tailscale, también se aplican sus condiciones y tratamiento de datos.

## 3. Soporte

Al enviar un correo de soporte, el desarrollador recibe el apodo, correo, mensaje y adjuntos. El soporte de transferencia Mac adjunta, al enviarse, versiones del sistema y la app, modelo, estado de transferencia, identificadores, errores y eventos de diagnóstico recientes. Estos pueden incluir nombres o rutas de archivos. Revise el mensaje antes de enviarlo. Los proveedores de correo procesan el mensaje. Conservamos la información mientras sea necesaria para atender la solicitud y los registros pertinentes; atendemos solicitudes de eliminación salvo obligación legal de conservación.

## 4. Almacenamiento y eliminación

Los registros locales pueden borrarse con los controles de la app. Desactivar iCloud no borra automáticamente datos ya almacenados allí o en otros dispositivos. Los registros pendientes y datos de enlace del Mac se guardan en Application Support y pueden permanecer tras eliminar solo la app. Contacte con soporte para ayuda con su eliminación. Las copias de seguridad y reinstalaciones afectan a la recuperación. Por defecto, las apps de Mac y Windows eliminan el registro original cuando la app móvil confirma su recepción. Si se activa la conservación, los registros confirmados se guardan hasta 500 MB y un mes de forma predeterminada (ambos límites ajustables) y pueden exportarse, reenviarse manualmente o eliminarse. Los registros pendientes no se incluyen en la limpieza automática ni en la eliminación manual.

## 5. Servicios externos y cambios

MochiLog no usa SDK de publicidad, seguimiento ni análisis de uso de terceros. Las propinas opcionales en App Store usan Apple StoreKit. Cloudflare distribuye el sitio web y puede tratar datos de red como la IP. Los cambios de esta política se publicarán en el sitio y la app con fecha de actualización.

## 6. Contacto

Consultas y solicitudes de eliminación de correos de soporte: support@mochilog.ryuya-dev.net.

Revised: 2026-10-07

La vista completa puede tratar metadatos de fabricación, identificadores de batería e indicadores de estado en memoria. Muestra los nombres y valores originales sin deducir unidades. No se guardan ni se adjuntan a los registros de soporte y se transfieren cifrados mediante el enlace existente.


El uso compartido de registros del PC transmite cifrados los registros de otro dispositivo solo si ambos están enlazados al mismo ordenador, tienen la sincronización con iCloud activada y se confirma la misma cuenta de Apple. Se compara un hash del ID de usuario de CloudKit específico de la app; no se envían el Apple ID, correo ni ID original al ordenador. El hash es un identificador para comparar cuentas, no una garantía de anonimato. El permiso se mantiene temporalmente en la memoria del ordenador y se revoca al desactivar la sincronización o cambiar de cuenta. Sin conexión, el permiso anterior puede durar hasta 15 minutos. Se conserva la identidad de origen. No se envían registros a un servidor del desarrollador.
