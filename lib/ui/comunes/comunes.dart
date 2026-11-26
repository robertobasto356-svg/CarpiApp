import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/supa.dart';
import '../../core/tema.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../modelos/modelos.dart';
import '../carpintero/pedidos_carpintero.dart' show PedidoDetalleCarpintero;
import '../cliente/pedidos_cliente.dart' show PedidoClientePantalla;
import 'widgets.dart';

// =====================================================================
// Fotos: cámara o galería (comprimidas para no gastar datos ni Storage)
// =====================================================================
Future<Uint8List?> tomarFoto(BuildContext c, {ImageSource? fuente}) async {
  final origen =
      fuente ??
      await showModalBottomSheet<ImageSource>(
        context: c,
        builder: (d) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(d, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(d, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
  if (origen == null) return null;
  try {
    final f = await ImagePicker().pickImage(source: origen, imageQuality: 72, maxWidth: 1600, maxHeight: 1600);
    return f == null ? null : await f.readAsBytes();
  } catch (e) {
    if (c.mounted) avisar(c, 'No se pudo abrir la cámara: ${mensajeError(e)}', error: true);
    return null;
  }
}

Future<XFile?> tomarArchivoFoto(BuildContext c, ImageSource origen) async {
  try {
    return await ImagePicker().pickImage(source: origen, imageQuality: 72, maxWidth: 1600, maxHeight: 1600);
  } catch (e) {
    if (c.mounted) avisar(c, 'No se pudo abrir la cámara: ${mensajeError(e)}', error: true);
    return null;
  }
}

// =====================================================================
// Campana de notificaciones (tiempo real)
// =====================================================================
class Campana extends StatefulWidget {
  const Campana({super.key});

  @override
  State<Campana> createState() => _CampanaState();
}

class _CampanaState extends State<Campana> {
  int _sinLeer = 0;
  RealtimeChannel? _canal;

  @override
  void initState() {
    super.initState();
    _contar();
    _canal = Api.escucharNotificaciones((n) {
      if (!mounted) return;
      setState(() => _sinLeer++);
      avisar(context, n.titulo);
    });
  }

  Future<void> _contar() async {
    try {
      final n = await Api.notificacionesSinLeer();
      if (mounted) setState(() => _sinLeer = n);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_canal != null) supa.removeChannel(_canal!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BotonCirculo(
    Icons.notifications_none,
    () async {
      await ir(context, const NotificacionesPantalla());
      _contar();
    },
    ayuda: 'Notificaciones',
    insignia: _sinLeer,
  );
}

class NotificacionesPantalla extends StatelessWidget {
  const NotificacionesPantalla({super.key});

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Avisos',
    titulo: 'Notificaciones',
    cuerpo: Cargador<List<Notificacion>>(
      cargar: () async {
        final l = await Api.notificaciones();
        await Api.marcarNotificacionesLeidas();
        return l;
      },
      construir: (c, lista, recargar) => lista.isEmpty
          ? const Vacio(
              Icons.notifications_none,
              'Sin notificaciones',
              detalle: 'Aquí verás los cambios de tus pedidos, cotizaciones y mensajes.',
            )
          : RefreshIndicator.adaptive(
              onRefresh: recargar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final n = lista[i];
                  final cs = Theme.of(c).colorScheme;
                  return Tarjeta(
                    color: n.leida ? null : cs.primaryContainer.withValues(alpha: .5),
                    alTocar: () => _abrir(c, n),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(n.icono, color: cs.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (n.cuerpo.isNotEmpty) Text(n.cuerpo, style: TextStyle(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 4),
                              Text(fechaHora(n.fecha), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (n.pedidoId != null || n.tipo == 'mensaje')
                          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      ],
                    ),
                  );
                },
              ),
            ),
    ),
  );

  /// Abre lo que originó el aviso: el pedido o la bandeja de mensajes.
  static void _abrir(BuildContext c, Notificacion n) {
    if (n.tipo == 'mensaje') {
      ir(c, const ConversacionesPantalla());
    } else if (n.pedidoId != null) {
      ir(c, sesion.esCarpintero ? PedidoDetalleCarpintero(n.pedidoId!) : PedidoClientePantalla(n.pedidoId!));
    }
  }
}

// =====================================================================
// Conversaciones
// =====================================================================
class ConversacionesPantalla extends StatelessWidget {
  /// Elemento fijo arriba (el asistente IA para el cliente).
  final Widget? fijo;
  final bool atras;
  const ConversacionesPantalla({this.fijo, this.atras = true, super.key});

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: sesion.esCarpintero ? 'Clientes' : 'Cliente',
    titulo: 'Mensajes',
    subtitulo: sesion.esCarpintero ? 'Conversaciones con tus clientes' : 'Habla con tus carpinteros y con el asistente',
    atras: atras,
    cuerpo: Cargador<List<Conversacion>>(
      cargar: Api.conversaciones,
      construir: (c, lista, recargar) => RefreshIndicator.adaptive(
        onRefresh: recargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            ?fijo,
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Vacio(
                  Icons.chat_bubble_outline,
                  'Aún no hay conversaciones',
                  detalle: sesion.esCarpintero
                      ? 'Escribe a un cliente desde su ficha o desde un pedido.'
                      : 'Escribe a una carpintería desde el catálogo o desde tu pedido.',
                ),
              ),
            for (final conv in lista)
              Tarjeta(
                alTocar: () async {
                  await ir(
                    c,
                    ChatPantalla(
                      carpinteriaId: conv.carpinteriaId,
                      clientePerfilId: conv.clientePerfilId,
                      titulo: conv.titulo,
                    ),
                  );
                  recargar();
                },
                child: Row(
                  children: [
                    Avatar(conv.titulo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(conv.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(conv.ultimo, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          mismoDia(conv.fecha, DateTime.now()) ? hora(conv.fecha) : fechaCorta(conv.fecha),
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (conv.sinLeer > 0) ...[
                          const SizedBox(height: 4),
                          Badge(label: Text('${conv.sinLeer}'), backgroundColor: Theme.of(c).colorScheme.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// =====================================================================
// Chat en tiempo real
// =====================================================================
class ChatPantalla extends StatefulWidget {
  final String carpinteriaId;
  final String clientePerfilId;
  final String titulo;
  const ChatPantalla({required this.carpinteriaId, required this.clientePerfilId, required this.titulo, super.key});

  @override
  State<ChatPantalla> createState() => _ChatPantallaState();
}

class _ChatPantallaState extends State<ChatPantalla> {
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  final List<Mensaje> _mensajes = [];
  RealtimeChannel? _canal;
  bool _cargando = true;
  bool _enviando = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    _canal = Api.escucharMensajes(widget.carpinteriaId, widget.clientePerfilId, (m) {
      if (!mounted || _mensajes.any((x) => x.id == m.id)) return;
      setState(() => _mensajes.add(m));
      _bajar();
      if (m.autorId != miId) Api.marcarLeidos(widget.carpinteriaId, widget.clientePerfilId);
    });
  }

  Future<void> _cargar() async {
    try {
      final l = await Api.mensajes(widget.carpinteriaId, widget.clientePerfilId);
      if (!mounted) return;
      setState(() {
        _mensajes
          ..clear()
          ..addAll(l);
        _cargando = false;
        _error = null;
      });
      _bajar();
      await Api.marcarLeidos(widget.carpinteriaId, widget.clientePerfilId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _cargando = false;
        });
      }
    }
  }

  void _bajar() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _enviar({Uint8List? foto}) async {
    final t = _texto.text.trim();
    if (t.isEmpty && foto == null) return;
    setState(() => _enviando = true);
    try {
      await Api.enviarMensaje(
        carpinteriaId: widget.carpinteriaId,
        clientePerfilId: widget.clientePerfilId,
        texto: t,
        foto: foto,
      );
      _texto.clear();
      await _cargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    if (_canal != null) supa.removeChannel(_canal!);
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Marca('Mensajes', atras: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Avatar(widget.titulo, radio: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _cargando
                  ? const Cargando()
                  : _error != null
                  ? ErrorCarga(_error!, _cargar)
                  : _mensajes.isEmpty
                  ? const Vacio(
                      Icons.chat_bubble_outline,
                      'Escribe el primer mensaje',
                      detalle: 'Pueden compartir fotos del avance o del espacio.',
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) {
                        final m = _mensajes[i];
                        final mio = m.autorId == miId;
                        return Align(
                          alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .76),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: mio ? cs.primary : Colors.white,
                              border: mio ? null : Border.all(color: cs.outline),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mio ? 16 : 4),
                                bottomRight: Radius.circular(mio ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (m.fotoPath != null)
                                  GestureDetector(
                                    onTap: () => verImagen(context, 'mensajes', m.fotoPath!),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 220,
                                        height: 160,
                                        child: ImagenStorage('mensajes', m.fotoPath!),
                                      ),
                                    ),
                                  ),
                                if (m.texto.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(top: m.fotoPath != null ? 6 : 0),
                                    child: Text(
                                      m.texto,
                                      style: TextStyle(color: mio ? Colors.white : cs.onSurface, fontSize: 15),
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  hora(m.fecha),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: mio ? Colors.white.withValues(alpha: .8) : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_a_photo_outlined, color: cs.primary),
                      onPressed: _enviando
                          ? null
                          : () async {
                              final f = await tomarFoto(context);
                              if (f != null) await _enviar(foto: f);
                            },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _texto,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje…',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: cs.primary,
                      child: _enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send, color: Colors.white, size: 18),
                              onPressed: () => _enviar(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Perfil (ambos roles)
// =====================================================================
class PerfilPantalla extends StatelessWidget {
  final bool atras;
  const PerfilPantalla({this.atras = false, super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final p = sesion.perfil;
        if (p == null) return const Cargando();
        final k = sesion.carpinteria;
        final cs = Theme.of(context).colorScheme;

        Widget fila(IconData i, String t, VoidCallback f, {String? detalle, Color? color}) => Tarjeta(
          alTocar: f,
          relleno: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(i, color: color ?? cs.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t,
                      style: TextStyle(fontWeight: FontWeight.w600, color: color),
                    ),
                    if (detalle != null && detalle.isNotEmpty)
                      Text(detalle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        );

        return PantallaBase(
          seccion: p.esCarpintero ? 'Carpintero' : 'Cliente',
          titulo: 'Mi perfil',
          atras: atras,
          cuerpo: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Center(
                child: Column(
                  children: [
                    Avatar(
                      p.nombre,
                      radio: 42,
                      url: p.avatarPath == null ? null : Api.urlPublica('avatares', p.avatarPath!),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final f = await tomarFoto(context);
                        if (f == null || !context.mounted) return;
                        await conCarga(context, () async {
                          final ruta = '${p.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          await supa.storage
                              .from('avatares')
                              .uploadBinary(
                                ruta,
                                f,
                                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
                              );
                          await sesion.guardarPerfil({'avatar_path': ruta});
                        }, exito: 'Foto actualizada');
                      },
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Cambiar foto'),
                    ),
                    Text(p.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(
                      p.esCarpintero ? 'Carpintero · ${k?.nombre ?? ''}' : 'Cliente',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      supa.auth.currentUser?.email ?? '',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              fila(Icons.person_outline, 'Editar perfil', () => _editarPerfil(context, p), detalle: p.telefono),
              if (p.esCarpintero && k != null) ...[
                fila(
                  Icons.storefront_outlined,
                  'Mi carpintería',
                  () => _editarCarpinteria(context, k),
                  detalle: k.nombre,
                ),
                fila(
                  Icons.receipt_long_outlined,
                  'Datos fiscales',
                  () => _editarUno(context, 'RFC', 'rfc', p.rfc),
                  detalle: p.rfc.isEmpty ? 'Sin RFC' : p.rfc,
                ),
              ] else ...[
                fila(
                  Icons.location_on_outlined,
                  'Mi dirección',
                  () => _editarUno(context, 'Dirección de entrega', 'direccion', p.direccion),
                  detalle: p.direccion.isEmpty ? 'Agrega tu dirección' : p.direccion,
                ),
                fila(
                  Icons.credit_card_outlined,
                  'Método de pago preferido',
                  () => _metodoPago(context, p.metodoPago),
                  detalle: p.metodoPago.isEmpty ? 'Efectivo, transferencia…' : p.metodoPago,
                ),
              ],
              Tarjeta(
                relleno: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: SwitchListTile.adaptive(
                  value: p.notificaciones,
                  secondary: Icon(Icons.notifications_none, color: cs.primary),
                  title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Avisos de pedidos, citas, cotizaciones y mensajes',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  onChanged: (v) => conCarga(context, () => sesion.guardarPerfil({'notificaciones': v})),
                ),
              ),
              fila(Icons.help_outline, 'Ayuda y soporte', () => _soporte(context)),
              fila(Icons.logout, 'Cerrar sesión', () async {
                if (await confirmar(context, 'Cerrar sesión', '¿Quieres salir de tu cuenta?', si: 'Salir')) {
                  await sesion.salir();
                }
              }, color: Colores.error),
              const SizedBox(height: 12),
              Center(
                child: Text('CarpiApp 1.0 · Equipo 6', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editarPerfil(BuildContext c, Perfil p) async {
    final nombre = TextEditingController(text: p.nombre);
    final tel = TextEditingController(text: p.telefono);
    final dir = TextEditingController(text: p.direccion);
    final ok = await _hoja(c, 'Editar perfil', [
      Campo('Nombre', nombre, mayusculas: TextCapitalization.words),
      Campo('Teléfono', tel, teclado: TextInputType.phone),
      Campo('Dirección', dir),
    ]);
    if (ok != true || !c.mounted) return;
    if (nombre.text.trim().isEmpty) {
      avisar(c, 'El nombre no puede quedar vacío.', error: true);
      return;
    }
    await conCarga(
      c,
      () => sesion.guardarPerfil({
        'nombre': nombre.text.trim(),
        'telefono': tel.text.trim(),
        'direccion': dir.text.trim(),
      }),
      exito: 'Perfil actualizado',
    );
  }

  Future<void> _editarCarpinteria(BuildContext c, Carpinteria k) async {
    final nombre = TextEditingController(text: k.nombre);
    final desc = TextEditingController(text: k.descripcion);
    final tel = TextEditingController(text: k.telefono);
    final correo = TextEditingController(text: k.correo);
    final dir = TextEditingController(text: k.direccion);
    final ok = await _hoja(c, 'Mi carpintería', [
      Campo('Nombre de la carpintería', nombre, mayusculas: TextCapitalization.words),
      Campo('Descripción', desc, lineas: 3, pista: 'Especialidades, años de experiencia…'),
      Campo('Teléfono', tel, teclado: TextInputType.phone),
      Campo('Correo de contacto', correo, teclado: TextInputType.emailAddress, mayusculas: TextCapitalization.none),
      Campo('Dirección del taller', dir),
    ]);
    if (ok != true || !c.mounted) return;
    await conCarga(
      c,
      () => sesion.guardarCarpinteria({
        'nombre': nombre.text.trim().isEmpty ? k.nombre : nombre.text.trim(),
        'descripcion': desc.text.trim(),
        'telefono': tel.text.trim(),
        'correo': correo.text.trim(),
        'direccion': dir.text.trim(),
      }),
      exito: 'Datos de la carpintería guardados',
    );
  }

  Future<void> _editarUno(BuildContext c, String etiqueta, String columna, String valor) async {
    final ctl = TextEditingController(text: valor);
    final ok = await _hoja(c, etiqueta, [Campo(etiqueta, ctl, mayusculas: TextCapitalization.characters)]);
    if (ok == true && c.mounted) {
      await conCarga(c, () => sesion.guardarPerfil({columna: ctl.text.trim()}), exito: 'Guardado');
    }
  }

  Future<void> _metodoPago(BuildContext c, String actual) async {
    const opciones = ['Efectivo', 'Transferencia', 'Tarjeta', 'Depósito'];
    final r = await showModalBottomSheet<String>(
      context: c,
      builder: (d) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Método de pago preferido', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            for (final o in opciones)
              ListTile(
                title: Text(o),
                trailing: o == actual ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(d, o),
              ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'El pago se acuerda directamente con el carpintero; CarpiApp no cobra ni guarda tarjetas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
    if (r != null && c.mounted) await conCarga(c, () => sesion.guardarPerfil({'metodo_pago': r}));
  }

  void _soporte(BuildContext c) => showAdaptiveDialog<void>(
    context: c,
    builder: (d) => AlertDialog.adaptive(
      title: const Text('Ayuda y soporte'),
      content: const Text(
        '¿Tienes dudas? Escríbenos y te respondemos lo antes posible.\n\n'
        'También puedes preguntarle al asistente de CarpiApp sobre maderas, acabados y cómo usar la app.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(d);
            abrirEnlace(c, Uri(scheme: 'mailto', path: Config.correoSoporte, query: 'subject=Ayuda CarpiApp'));
          },
          child: const Text('Escribir correo'),
        ),
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cerrar')),
      ],
    ),
  );
}

/// Hoja inferior con un formulario simple. Devuelve true si se guarda.
Future<bool?> _hoja(BuildContext c, String titulo, List<Widget> campos) => hojaFormulario(c, titulo, campos);

Future<bool?> hojaFormulario(BuildContext c, String titulo, List<Widget> campos, {String guardar = 'Guardar'}) =>
    showModalBottomSheet<bool>(
      context: c,
      isScrollControlled: true,
      builder: (d) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(d).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...campos,
              const SizedBox(height: 8),
              BotonPrincipal(guardar, () => Navigator.pop(d, true)),
            ],
          ),
        ),
      ),
    );
