# Arquitectura de CarpiApp

```
 Teléfono (Flutter: Android / iOS)                     Supabase (plan gratuito)
 ┌───────────────────────────────────────┐            ┌──────────────────────────────────┐
 │ UI carpintero · UI cliente            │  HTTPS     │ Auth (correo + contraseña)       │
 │ Sesión (perfil, carpintería)          │──────────▶ │ PostgreSQL 17 + RLS              │
 │ Api (consultas PostgREST / RPC)       │            │   funciones RPC del cliente      │
 │ CarpiIA (reglas + búsqueda)           │◀────────── │   búsqueda en español (FTS)      │
 │ ML Kit (descripción de fotos)         │  Realtime  │ Realtime (mensajes, avisos)      │
 │ PDF de cotización                     │            │ Storage (fotos, PDF, modelos 3D) │
 │ Sensores: cámara, acelerómetro, AR    │            └──────────────────────────────────┘
 └───────────────────────────────────────┘
```

No hay servidor propio: la app habla directo con Supabase y **toda la seguridad la aplica la base de datos** con políticas RLS. Por eso la llave de la app puede ser pública.

## Tecnologías

| Área | Tecnología | Uso |
|---|---|---|
| App móvil | Flutter 3.50 · Dart 3.14 | Una sola base de código para Android e iOS |
| Interfaz | Material 3 con controles adaptativos | Colores y estructura de los mockups nuevos del Figma |
| Base de datos | PostgreSQL 17 (Supabase) | Usuarios, carpinterías, pedidos, cotizaciones… |
| Autenticación | Supabase Auth | Registro, inicio de sesión, recuperar contraseña (enlace profundo) |
| Archivos | Supabase Storage | Fotos de referencia, PDF de cotizaciones, catálogo, avatares, modelos 3D |
| Tiempo real | Supabase Realtime | Chat, notificaciones y cambios de pedidos |
| IA | CarpiIA (propia) + ML Kit Image Labeling | Asistente en español y descripción de fotos en el teléfono |
| PDF | paquetes `pdf` y `printing` | Cotización para descargar, compartir e imprimir |
| Sensores | `image_picker`, `sensors_plus`, `model_viewer_plus` | Cámara, nivel digital, realidad aumentada |
| CI | GitHub Actions | Pruebas, APK e IPA sin firmar |
| Diseño | Figma | Mockups y documentación del proyecto |

> La tabla original del Figma mencionaba .NET MAUI, ASP.NET Core, Entity Framework y JWT. El proyecto real se construyó en **Flutter + Supabase**: Supabase ya incluye API, autenticación con JWT y almacenamiento, sin mantener un servidor propio.

## Base de datos

Las migraciones están en `supabase/migrations/`:

| Archivo | Contenido |
|---|---|
| `…200000_esquema_carpiapp.sql` | Tablas, funciones, triggers, RLS, permisos y tiempo real |
| `…201000_almacenamiento.sql` | Buckets y políticas de Storage |
| `…202000_datos_iniciales.sql` | Proveedores de Mérida y base de conocimiento de CarpiIA |
| `…203000_ajustes_seguridad.sql` | Ajustes tras la revisión de seguridad |
| `…204000_notificaciones_sin_duplicar.sql` | Un solo aviso por cada respuesta o envío de cotización |

### Tablas

| Tabla | Para qué |
|---|---|
| `perfiles` | Usuario, rol (`carpintero` / `cliente`) y datos de contacto |
| `carpinterias` | Taller de cada carpintero (se crea solo al registrarse) |
| `clientes` | Agenda de cada carpintería (con o sin cuenta en la app) |
| `pedidos` | Mueble solicitado: estado, avance, medidas tomadas en la cita |
| `citas` | Visitas para medir, revisar o instalar |
| `cotizaciones` + `cotizacion_partidas` | Materiales, mano de obra, costos adicionales; total calculado |
| `avances` | Historial automático de estados y avance |
| `fotos` | Referencias del cliente y del carpintero, con descripción de IA |
| `catalogo`, `favoritos` | Trabajos publicados y favoritos de los clientes |
| `proveedores` | Directorio general de Mérida + proveedores propios de cada taller |
| `inventario`, `gastos` | Control del taller y finanzas |
| `mensajes`, `notificaciones`, `calificaciones` | Comunicación y reputación |
| `conocimiento` | Fichas verificadas que consulta CarpiIA |

### Ciclo de un pedido

`solicitado → cita_agendada → en_cotizacion → cotizado → (ajustes_solicitados ↺) → aceptado → en_fabricacion → por_entregar → entregado`
(también `rechazado` y `cancelado`). Cada cambio crea un registro en `avances` y una notificación.

### Seguridad

- RLS activo en todas las tablas. Funciones auxiliares en el esquema `privado`, que la API no expone.
- **Aislamiento entre carpinterías:** un carpintero solo ve sus clientes, pedidos, inventario, gastos y reportes.
- **Cliente:** ve solo sus pedidos, citas, fotos y las cotizaciones ya enviadas (no los borradores). No puede cambiar su rol ni crear pedidos por fuera de la función `crear_solicitud`.
- Las acciones del cliente pasan por funciones RPC que validan identidad y transición: `crear_solicitud`, `responder_cotizacion` y `calificar_pedido`.
- Storage: las rutas `{carpintería}/{pedido}/…` se validan contra el pedido; los PDF solo los sube la carpintería.
- Probado con usuarios simulados (dos carpinteros y un cliente). Revisado con los *advisors* de Supabase.

## CarpiIA (inteligencia artificial propia y gratuita)

Los modelos de embeddings gratuitos de Supabase solo entienden inglés, así que CarpiIA usa una arquitectura pensada para español y sin costo:

1. **Reglas de intención** (`lib/ia/carpi_ia.dart`): saludo, límites, proveedores, cálculo de tableros, revisión de pedido y armado guiado de la solicitud.
2. **Búsqueda semántica ligera en español** (`buscar_conocimiento`): texto completo de PostgreSQL con diccionario español, sin acentos y con similitud por trigramas, sobre 44 fichas verificadas (maderas locales, tableros, acabados, herrajes, cuidados contra humedad y comején, proceso de la app).
3. **Límites del diseño:** al cliente nunca le confirma precios, medidas, materiales definitivos ni fechas, y no genera diseños. Al carpintero le da información de apoyo; él decide.
4. **Fotos:** ML Kit Image Labeling corre **en el teléfono** (gratis, sin internet) y genera una descripción editable ("La imagen muestra un clóset…"). La foto nunca se usa para calcular medidas.

## Sensores

| Sensor | Pantalla | Detalle |
|---|---|---|
| Cámara | Captura de referencia (carpintero), Agrega una referencia (cliente), chat | Fotos comprimidas antes de subirlas |
| Acelerómetro | Nivel digital | Modo superficie (burbuja 2D) y plomo (muro/marco); calibración |
| Realidad aumentada | Vista en el espacio | Modelos 3D de referencia; Scene Viewer en Android, AR Quick Look en iPhone |

Los modelos 3D (`assets/modelos/`) se generan con `tools/generar_modelos.py` con medidas reales en metros.

## Decisiones

- **Material de Flutter:** Flutter 3.47+ marca `flutter/material` como obsoleto en favor de `material_ui`. La app sigue en `flutter/material` (importado solo desde `lib/core/ui.dart`) porque los paquetes de terceros aún no migran y mezclar ambas copias rompe los temas. Migrar después implica cambiar dos líneas.
- **supabase_flutter 2.x:** la versión 3 salió en noviembre de 2026; la 2.x sigue recibiendo correcciones de seguridad y es la que soportan los demás paquetes.
- **Notificaciones:** dentro de la app y en tiempo real. Las push en iOS requieren la cuenta de Apple de pago.
