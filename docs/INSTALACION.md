# Instalación y despliegue de CarpiApp

Todo el proyecto funciona con herramientas y planes gratuitos.

## 1. Entorno de desarrollo (Windows)

| Herramienta | Versión | Dónde |
|---|---|---|
| Flutter | 3.50 estable (Dart 3.14) | https://github.com/flutter/flutter |
| JDK | 17 (Temurin) | https://adoptium.net |
| Android SDK | plataforma 36, build-tools 36, NDK 28.2 | herramientas de línea de comandos de Android |

En la PC del equipo todo está en `E:\dev` (el disco C: casi no tiene espacio). Para usarlo en una terminal de PowerShell:

```powershell
. E:\dev\carpiapp-env.ps1
```

El script define `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_USER_HOME`, `PUB_CACHE`, `GRADLE_USER_HOME` y los temporales (`TEMP`/`TMP`) en E:, y agrega Flutter al `PATH` solo para esa terminal.

> **Memoria:** Gradle está limitado a 3 GB en `android/gradle.properties`. Con 16 GB de RAM, no compiles Android y web al mismo tiempo. Si el disco C: se llena, Windows no puede ampliar el archivo de paginación y la compilación se cae con "insufficient memory".

Comprobar:

```powershell
flutter doctor
```

## 2. Supabase

Proyecto: **CARPIAPP** (`koeahqzwxzikzzouoqti`), plan gratuito.

1. **Base de datos:** las migraciones de `supabase/migrations/` ya están aplicadas. Para un proyecto nuevo, ejecútalas en orden en el SQL Editor.
2. **Redirect URLs** (Authentication → URL Configuration): agrega `io.carpiapp://login-callback`. Sin esto, los enlaces de confirmación de correo y de recuperación de contraseña no regresan a la app.
3. **Confirmación de correo:** el correo gratuito de Supabase envía pocos correos por hora. Para presentaciones con muchas cuentas de prueba, desactiva *Confirm email* (Authentication → Providers → Email) o conecta un SMTP gratuito (por ejemplo Brevo o Resend).
4. **Modelos 3D para realidad aumentada:** sube los 16 archivos de `assets/modelos/` (`.glb` y `.usdz`) al bucket público `modelos` (Storage → modelos → Upload). La vista 3D funciona sin este paso, pero la realidad aumentada en iPhone necesita los `.usdz` publicados.
5. **Protección de contraseñas filtradas** (Authentication → Attack Protection): recomendable activarla si el plan lo permite.

La llave publicable está en `lib/core/config.dart`. Es segura dentro de la app porque la seguridad la aplican las políticas RLS. Nunca pongas la llave `service_role` en la app.

## 3. Ejecutar en un teléfono Android

1. En el teléfono: Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación" → activa **Depuración USB**.
2. Conecta el teléfono por USB y acepta la huella de la PC.
3. Ejecuta:

```powershell
flutter run
```

### Instalar sin cable (desde GitHub)

Cada versión publicada (etiqueta `v1.0.0`, `v1.0.1`…) aparece en **GitHub → Releases** con el archivo `CarpiApp-v1.0.0.apk`. Desde el teléfono, abre la página de Releases del repositorio, descarga el `.apk` y ábrelo. Android pedirá permitir "instalar apps desconocidas" para el navegador. Para actualizar, instala la versión nueva encima: no se pierden datos, porque todo vive en Supabase.

Para publicar una versión (sube antes el número `version:` de `pubspec.yaml`, por ejemplo `1.0.1+2`):

```powershell
git tag v1.0.0; git push origin v1.0.0
```

#### Llave de firma (una sola vez)

Para que cada versión nueva se instale **encima** de la anterior, todas deben firmarse con la misma llave. Se crea una vez y se guarda como secreto en GitHub (nunca en el repositorio):

```powershell
keytool -genkeypair -v -keystore carpiapp.jks -alias carpiapp -keyalg RSA -keysize 2048 -validity 10000
```

En **GitHub → Settings → Secrets and variables → Actions** agrega:

| Secreto | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | El archivo en base64: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("carpiapp.jks"))` |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del almacén |
| `ANDROID_KEY_ALIAS` | `carpiapp` |
| `ANDROID_KEY_PASSWORD` | Contraseña de la llave |

Guarda `carpiapp.jks` y sus contraseñas en un lugar seguro: si se pierden, la siguiente versión obligará a desinstalar la app (los datos no se pierden, viven en Supabase). Para firmar en la PC, crea `android/key.properties` (ignorado por git) con `storeFile`, `storePassword`, `keyAlias` y `keyPassword`. Sin llave, la app se firma con la de depuración.

### Compilar en la PC

Para generar un APK instalable:

```powershell
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`. Cópialo al teléfono y ábrelo; Android pedirá permitir "instalar apps desconocidas".

## 4. iPhone sin pagar la cuenta de desarrollador

Compilar para iOS requiere una Mac. Usamos la Mac gratuita de **GitHub Actions** (el repositorio es público):

1. En GitHub: pestaña **Actions** → *Compilar CarpiApp* → **Run workflow**. También se ejecuta solo con cada push a `main`.
2. Al terminar, descarga el artifact **CarpiApp-ios** (contiene `CarpiApp-sin-firmar.ipa`).
3. En Windows instala **Sideloadly** (gratis) e iTunes de la web de Apple.
4. Conecta el iPhone, arrastra el `.ipa` a Sideloadly, escribe tu Apple ID y pulsa *Start*.
5. En el iPhone: Ajustes → General → VPN y gestión de dispositivos → confía en tu Apple ID.

Con un Apple ID gratuito la app dura **7 días**. Después se reinstala igual, sin perder datos, porque todo vive en Supabase. Las notificaciones push de iOS requieren la cuenta de pago; CarpiApp usa notificaciones dentro de la app en tiempo real.

Con acceso a una Mac con Xcode, también se puede usar `flutter run` con el iPhone conectado.

## 5. Pruebas

```powershell
flutter analyze
flutter test
```

GitHub Actions corre ambas antes de compilar.

## 6. Regenerar los modelos 3D

```powershell
python tools/generar_modelos.py assets/modelos
```

## 7. Regenerar los íconos de la app

Los íconos de Android (incluido el adaptativo) y de iPhone salen del emblema de `assets/logo.png`:

```powershell
python tools/generar_iconos.py
```
