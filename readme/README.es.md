<div align="center">

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Español** · [Português](README.pt-BR.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Русский](README.ru.md)

<img src="../Assets.xcassets/AppIcon.appiconset/256.png" alt="Logotipo de CiteBar" width="112" height="112">

# CiteBar

**Deja de recargar Google Scholar.**<br>
Para quienes revisan sus citas un poquito más de la cuenta.

[Descargar](https://github.com/hichipli/CiteBar/releases/latest) · [Sitio web](https://www.citebar.org/) · `brew install --cask hichipli/tap/citebar`

  [![Última versión](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![Licencia](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](../LICENSE)
  [![Descargas](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)

<img src="../website/assets/demo.gif" alt="Del panel de la barra de menús al estudio de Citation Record: se arrastra la máquina del tiempo hasta el día en que se alcanzaron las 1000 citas y luego se prueban los temas Gazette, Certificate y Night" width="420">

</div>

---

## ¿Por qué CiteBar?

Porque recargar tu perfil de Google Scholar cada 20 minutos no es investigar. CiteBar convierte el seguimiento de citas, que antes era una pestaña del navegador abierta por pura obsesión, en un discreto compañero de la barra de menús: lo consulta una vez al día, te avisa qué artículo acaba de recibir una cita y no te molesta el resto del tiempo.

Ideal para investigadores que siguen el impacto de sus artículos, doctorandos que celebran sus primeras citas, directores de laboratorio que siguen a todo su grupo y cualquiera que alguna vez se haya preguntado: «¿Habrá subido mi h-index?».

## Inicio rápido

**¿Solo quieres usar CiteBar?** Sáltate la parte técnica y empieza en más o menos un minuto.

1. **Descarga la última versión**
   - Ve a [GitHub Releases](https://github.com/hichipli/CiteBar/releases/latest).
   - Descarga el archivo `CiteBar-x.x.x-universal-[date].dmg`.
   - El DMG universal funciona tanto en Mac con Apple Silicon como con Intel.
   - ¿Prefieres Homebrew? `brew install --cask hichipli/tap/citebar` se encarga de los pasos 1 y 2 por ti.

2. **Instala CiteBar**
   - Abre el DMG.
   - Arrastra `CiteBar.app` a `Applications`.
   - Abre CiteBar desde `Applications`.

3. **Añade tu perfil**
   - La primera vez que lo abras, CiteBar mostrará Add Profiles. Pega el enlace de tu perfil de Google Scholar.
   - ¿Sigues a un laboratorio o a tus coautores? Pega todos sus enlaces de una vez, uno por línea, y agrúpalos.
   - La actualización diaria viene activada por defecto. Google Scholar se actualiza cada uno o dos días, así que con esto CiteBar se mantiene al día.

Puedes pegar el enlace completo del perfil o solo el ID, que es el valor de `user` en la URL:

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

Las versiones actuales están firmadas con un Apple Developer ID y notarizadas por Apple. Aun así, macOS puede mostrar la confirmación habitual que aparece la primera vez que abres una app descargada de internet.

Si actualizas desde `1.3.x` o `1.4.1`, instala manualmente el DMG más reciente una sola vez. A partir de ahí, las actualizaciones automáticas dentro de la app deberían funcionar con normalidad.

¿Problemas con la instalación? Consulta la [guía de instalación](../DISTRIBUTION.md) (en inglés).

## Funciones que importan

<img src="../website/assets/panel.png" alt="El panel de CiteBar: un perfil con 1284 citas, citas por año, un artículo recién citado, los dos artículos que subirían el h-index a 14, dos artículos vigilados y un grupo de laboratorio con sus citas combinadas" width="360">

**El recuento, con contexto**
- Tu número de citas vive en la barra de menús; haz clic para abrir el panel
- Citas por año, citas de este año, crecimiento en 30 días, h-index e i10-index
- Descubre qué artículo acaba de recibir una cita y haz clic para ver quién lo citó
- Cuando tu próximo h-index esté cerca, verás exactamente qué artículos necesitan citas y cuántas le faltan a cada uno
- Vigila artículos concretos: márcalos con una estrella en el Papers window para tenerlos siempre en el panel, con sus citas más recientes primero en las notificaciones
- Las etiquetas de las columnas y las ayudas al pasar el cursor explican cada número

**Grupos para laboratorios y colaboradores**
- Agrupa perfiles en un laboratorio, un equipo de coautores o una promoción, con citas combinadas y crecimiento en 30 días
- Pega de una vez una lista entera de enlaces de Scholar
- Copia los enlaces de un grupo para compartirlos con tus compañeros, que solo tienen que pegarlos en su propio CiteBar

**Notificaciones que vale la pena abrir**
- Las notificaciones indican qué artículos han ganado citas
- Los hitos, como llegar a 100 o 1000 citas o subir de h-index, tienen su propio aviso
- Nada de avisos de «no ha cambiado nada»

**Un historial de citas digno de compartir**
- Cuatro estilos de tarjeta: Record, Night, Gazette (una portada de periódico con un titular escrito a partir de tus cifras) y Certificate
- Elige qué muestra: citas por año, h-index, los artículos más citados o uno solo, el crecimiento entre 7 y 365 días, y una nota
- Comparte (AirDrop, Mensajes, Mail), copia o guarda con un solo clic, desde el panel o desde el menú ⋯ de cualquier perfil en Settings

<img src="../website/assets/card-record.png" alt="Tarjeta Record" width="180"> <img src="../website/assets/card-night.png" alt="Tarjeta Night" width="180"> <img src="../website/assets/card-gazette.png" alt="Tarjeta Gazette" width="180"> <img src="../website/assets/card-certificate.png" alt="Tarjeta Certificate" width="180">

**Una máquina del tiempo para tu historial**
- Arrastra a lo largo de una línea de tiempo hasta cualquier día y crea la tarjeta de ese día
- Los hitos de citas y las subidas de h-index aparecen marcados, para que puedas compartir un momento que se te pasó
- Funciona desde el primer día: los hitos anteriores a la instalación de CiteBar se fechan a partir de los recuentos anuales de Google Scholar y se marcan con ~, y cada día desde entonces queda registrado con exactitud

**Respetuoso y fiable**
- Una sola solicitud por perfil, con dos segundos de separación entre una y otra
- Los fallos de red se reintentan automáticamente; ante los límites de frecuencia de Google Scholar, la app espera de forma progresiva (de 15 minutos hasta 4 horas) y se reanuda sola
- Refresh Now funciona en cualquier momento
- Actualizaciones automáticas mediante Sparkle

**Privacidad ante todo**
- Todos los datos se quedan en tu Mac
- Sin telemetría
- Sin servidores ni cuentas de CiteBar

**Tus datos, contigo**
- Settings › Data muestra dónde se guardan los datos (`~/Library/Application Support/CiteBar/`) y cuánto espacio ocupa cada parte: el historial de citas, las listas de artículos y el historial de artículos
- Conserva el historial de citas para siempre (opción predeterminada) o durante 5, 2 o 1 año
- El historial de artículos, opcional, guarda el recuento de cada artículo cada vez que cambia, de modo que los días pasados de la máquina del tiempo también muestran los artículos
- Exporta todo (perfiles, grupos, ajustes e historial completo) a un único archivo e impórtalo en un Mac nuevo; la importación solo añade, nunca borra
- Copia de seguridad automática opcional tras cada actualización en iCloud Drive o en la carpeta que elijas, como Google Drive o Dropbox

**Experiencia nativa de macOS**
- Presencia ligera en la barra de menús, con modo claro y oscuro
- Settings nativos con las pestañas Profiles, General, Data y About
- Opción de abrirse al iniciar sesión
- Compatible con Apple Silicon e Intel

**Tan ligero que puedes dejarlo siempre abierto**
- Uso de CPU prácticamente nulo en reposo
- Actividad de red mínima, con intervalos que tú controlas
- Más detalles de implementación en las [notas técnicas](../TECHNICAL.md) (en inglés)

## Privacidad

CiteBar solo lee páginas de perfil de Google Scholar disponibles públicamente. Tus ajustes y tu historial de citas se quedan en tu Mac, guardados en `~/Library/Application Support/CiteBar/`.

La app usa intervalos de actualización prudentes, pausas entre solicitudes y esperas progresivas tras los errores, para consultar los recuentos de citas de forma responsable.

## Ayuda y documentación del proyecto

- Instalación o avisos de seguridad de macOS: [guía de instalación](../DISTRIBUTION.md)
- Compilar desde el código fuente: [guía de configuración](../SETUP.md)
- Errores y solicitudes de funciones: [GitHub Issues](https://github.com/hichipli/CiteBar/issues)
- Cambios del proyecto: [registro de cambios](../CHANGELOG.md)

Toda esta documentación está en inglés.

¿Tienes una idea, una propuesta de función a medio pensar o un flujo de trabajo que CiteBar todavía no resuelve del todo? Abre un issue; puedes escribirlo en español. No hace falta que llegues con una propuesta pulida ni con un pull request: los comentarios prácticos que surgen del trabajo de investigación real ya son valiosos por sí mismos.

## Desarrolladores y colaboradores

¿Quieres compilar desde el código fuente, contribuir código o entender cómo funciona CiteBar por dentro?

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build
make run
```

Documentación útil del proyecto (en inglés):

- [Guía de contribución](../CONTRIBUTING.md)
- [Notas técnicas](../TECHNICAL.md)
- [Guía de publicación de versiones](../RELEASING.md)
- [Gestión de versiones](../VERSION_MANAGEMENT.md)

## Licencia

CiteBar se distribuye bajo la [licencia MIT](../LICENSE).

## Comunidad

Gracias a todas las personas que ayudan a mejorar CiteBar.

<div>
  <a href="https://github.com/CassWang1"><img src="https://github.com/CassWang1.png?size=48" width="48" alt="CassWang1" /></a>
  <a href="https://github.com/lukestein"><img src="https://github.com/lukestein.png?size=48" width="48" alt="lukestein" /></a>
  <a href="https://github.com/DABH"><img src="https://github.com/DABH.png?size=48" width="48" alt="DABH" /></a>
  <a href="https://github.com/yizirui"><img src="https://github.com/yizirui.png?size=48" width="48" alt="yizirui" /></a>
</div>

---

<div align="center">

**Hecho con cariño para la comunidad académica**

[Descargar la última versión](https://github.com/hichipli/CiteBar/releases/latest) | [Informar de un problema](https://github.com/hichipli/CiteBar/issues) | [Contribuir](../CONTRIBUTING.md)

</div>
