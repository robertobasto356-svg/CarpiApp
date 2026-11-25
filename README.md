# CarpiApp

**App de gestión y cotización para carpinterías.** Conecta a carpinteros y clientes: el cliente pide su mueble y agenda una cita, el carpintero toma las medidas, arma la cotización y la envía en PDF, y el cliente sigue la fabricación hasta la entrega.

Proyecto del **Equipo 6 · 4-A** — Desarrollo de aplicaciones móviles. Android y iPhone.

| | |
|---|---|
| App | Flutter 3.50 (Dart 3.14) · Android e iOS |
| Backend | Supabase: PostgreSQL 17, Auth, Storage, Realtime |
| IA | CarpiIA: búsqueda en español + reglas (propia, sin costo) · ML Kit en el teléfono |
| Sensores | Cámara · acelerómetro (nivel digital) · realidad aumentada (Scene Viewer / AR Quick Look) |
| Costo | $0: todo funciona con planes gratuitos |

## Qué hace

**Carpintero** (cada uno con su propia carpintería; sus datos solo los ve él)
- Panel con resumen del día, solicitudes por atender y próximas visitas.
- Pedidos: solicitudes, citas para medir, registro de medidas, avance de fabricación con historial.
- Cotizaciones en 4 pasos (Cliente · Proyecto · Costos · Resumen) con partidas de materiales, mano de obra y costos adicionales; **PDF** para descargar, enviar al cliente o imprimir.
- Clientes, proyectos, inventario de materiales y herramientas, **directorio de proveedores de Mérida**, visitas en calendario, reportes de ingresos/gastos, catálogo de trabajos.
- **CarpiIA**: dudas de materiales y acabados, proveedores, cálculo de tableros y revisión de datos faltantes de un pedido.
- Cámara con descripción automática de la foto, **nivel digital** y **vista en realidad aumentada**.

**Cliente**
- Catálogo de muebles y carpinterías con calificaciones y favoritos.
- Solicitud de cotización **sin medidas**: tipo de mueble, material, descripción, fotos y fecha de la cita.
- Recibe la cotización en PDF y la acepta, pide ajustes o la rechaza.
- Seguimiento del pedido, chat en tiempo real con fotos, notificaciones y calificación.
- **Asistente CarpiApp**: información de maderas y cuidados, y armado guiado de la solicitud (no diseña ni confirma precios, medidas o fechas).

## Estructura

```
lib/
  core/        configuración, tema (colores del Figma), formatos
  modelos/     modelos de datos y estados del pedido
  datos/       sesión (Auth) y acceso a Supabase
  ia/          CarpiIA y descripción de fotos (ML Kit)
  pdf/         PDF de la cotización
  ui/          auth · carpintero · cliente · comunes (chat, perfil, asistente, sensores)
supabase/migrations/   esquema, seguridad (RLS), almacenamiento y datos iniciales
tools/generar_modelos.py   modelos 3D de referencia (GLB + USDZ)
test/          pruebas de la lógica
.github/workflows/compilar.yml   compila APK e IPA gratis en GitHub Actions
```

## Empezar

```bash
flutter pub get
flutter run          # con un teléfono Android conectado (depuración USB)
flutter test         # pruebas
```

Guías completas:
- [docs/INSTALACION.md](docs/INSTALACION.md): entorno, Supabase, compilar e instalar en Android y iPhone sin costo.
- [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md): base de datos, seguridad, IA y sensores.
- [docs/MANUAL.md](docs/MANUAL.md): manual de uso para carpinteros y clientes.

## Equipo 6

Almeida Puga Jeanine Grissell · Dominguez Xicum Michelle Guadalupe · Basto Bojorquez Roberto Agustin · Diaz Dzib Keely Aisha
Mtra. Marlene Ruiz Barboza
