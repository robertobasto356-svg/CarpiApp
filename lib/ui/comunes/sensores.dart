import 'dart:async';
import 'dart:io' show HttpClient;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../ia/descripcion_foto.dart';
import '../../modelos/modelos.dart';
import 'comunes.dart';
import 'widgets.dart';

/// Foto pendiente de subir (cuando el pedido aún no existe).
class FotoPendiente {
  final Uint8List bytes;
  String descripcion;
  final String descripcionIa;
  FotoPendiente(this.bytes, {this.descripcion = '', this.descripcionIa = ''});
}

// =====================================================================
// Nivel digital (acelerómetro)
// =====================================================================
class NivelPantalla extends StatefulWidget {
  const NivelPantalla({super.key});

  @override
  State<NivelPantalla> createState() => _NivelPantallaState();
}

class _NivelPantallaState extends State<NivelPantalla> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double _x = 0, _y = 0, _z = 9.8;
  double _offX = 0, _offY = 0, _offPlomo = 0;
  int _modo = 0; // 0 superficie · 1 plomo (muro, marco, puerta)
  bool _sinSensor = false;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      (e) {
        if (!mounted) return;
        // Filtro paso bajo para estabilizar la burbuja.
        const a = .15;
        setState(() {
          _x = _x + a * (e.x - _x);
          _y = _y + a * (e.y - _y);
          _z = _z + a * (e.z - _z);
        });
      },
      onError: (_) => setState(() => _sinSensor = true),
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  double get _angX => math.atan2(_x, math.sqrt(_y * _y + _z * _z)) * 180 / math.pi - _offX;
  double get _angY => math.atan2(_y, math.sqrt(_x * _x + _z * _z)) * 180 / math.pi - _offY;
  double get _plomo => math.atan2(_x, _y) * 180 / math.pi - _offPlomo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final angulo = _modo == 0 ? math.sqrt(_angX * _angX + _angY * _angY) : _plomo.abs();
    final nivelado = angulo < .5;
    final color = nivelado ? Colores.exito : (angulo < 2 ? const Color(0xFFC77700) : Colores.error);
    return PantallaBase(
      seccion: 'Sensores',
      titulo: 'Nivel digital',
      subtitulo: 'Usa el acelerómetro del celular para revisar nivel y plomo',
      cuerpo: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Pildoras(const ['Superficie (piso, cubierta)', 'Plomo (muro, marco)'], _modo, (i) => setState(() => _modo = i)),
        const SizedBox(height: 16),
        if (_sinSensor)
          const Aviso.alerta('Este dispositivo no tiene acelerómetro disponible.')
        else ...[
          Center(
            child: _modo == 0
                ? _burbujaCircular(cs, color)
                : _burbujaLineal(cs, color),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('${angulo.toStringAsFixed(1)}°',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: color)),
          ),
          Center(
            child: Text(
              nivelado ? (_modo == 0 ? 'Nivelado' : 'A plomo') : 'Inclinado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          if (_modo == 0)
            Center(
              child: Text('Inclinación X ${_angX.toStringAsFixed(1)}° · Y ${_angY.toStringAsFixed(1)}°',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          const SizedBox(height: 20),
          Aviso(
            _modo == 0
                ? 'Coloca el celular boca arriba sobre la superficie. Útil para revisar pisos y cubiertas antes de instalar.'
                : 'Apoya el canto largo del celular contra el muro o marco en posición vertical.',
            icono: Icons.lightbulb_outline,
          ),
          Row(children: [
            Expanded(
              child: BotonSecundario('Calibrar en cero', () {
                setState(() {
                  if (_modo == 0) {
                    _offX = _angX + _offX;
                    _offY = _angY + _offY;
                  } else {
                    _offPlomo = _plomo + _offPlomo;
                  }
                });
                avisar(context, 'Calibrado: la posición actual es el nuevo cero.');
              }, icono: Icons.center_focus_strong_outlined),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BotonSecundario('Restablecer', () => setState(() => _offX = _offY = _offPlomo = 0), icono: Icons.restart_alt),
            ),
          ]),
          const SizedBox(height: 10),
          Text('Precisión aproximada de ±0.5° según el sensor del teléfono. Para trabajos finos, verifica con nivel de burbuja.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ]),
    );
  }

  Widget _burbujaCircular(ColorScheme cs, Color color) {
    const tam = 240.0;
    final dx = (-_angX / 10).clamp(-1.0, 1.0) * (tam / 2 - 24);
    final dy = (_angY / 10).clamp(-1.0, 1.0) * (tam / 2 - 24);
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primaryContainer.withValues(alpha: .5),
        border: Border.all(color: cs.outline, width: 2),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary, width: 2))),
        Container(width: 1, height: tam, color: cs.outline),
        Container(width: tam, height: 1, color: cs.outline),
        Transform.translate(
          offset: Offset(dx, dy),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .85)),
          ),
        ),
      ]),
    );
  }

  Widget _burbujaLineal(ColorScheme cs, Color color) {
    const ancho = 280.0;
    final dx = (_plomo / 10).clamp(-1.0, 1.0) * (ancho / 2 - 26);
    return Container(
      width: ancho,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        color: cs.primaryContainer.withValues(alpha: .5),
        border: Border.all(color: cs.outline, width: 2),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Container(width: 60, height: 70, decoration: BoxDecoration(border: Border.symmetric(vertical: BorderSide(color: cs.primary, width: 2)))),
        Transform.translate(
          offset: Offset(dx, 0),
          child: Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .85))),
        ),
      ]),
    );
  }
}

// =====================================================================
// Vista en realidad aumentada (modelo 3D de referencia)
// =====================================================================
class VistaArPantalla extends StatefulWidget {
  final String tipoMueble;
  final Pedido? pedido;
  const VistaArPantalla({required this.tipoMueble, this.pedido, super.key});

  @override
  State<VistaArPantalla> createState() => _VistaArPantallaState();
}

class _VistaArPantallaState extends State<VistaArPantalla> {
  late String _tipo = widget.tipoMueble;
  static const _opciones = ['Clóset', 'Cocina', 'Mesa de comedor', 'Escritorio', 'Librero', 'Cama', 'Puerta', 'Mueble de TV'];

  /// ¿Los modelos están publicados en Supabase Storage (bucket `modelos`)?
  /// Si no, la vista 3D usa los archivos incluidos en la app.
  static bool? _remotoDisponible;

  @override
  void initState() {
    super.initState();
    if (_remotoDisponible == null) _verificarRemoto();
  }

  Future<void> _verificarRemoto() async {
    var ok = false;
    final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await cliente.headUrl(Uri.parse(Config.modelo('closet.glb')));
      final res = await req.close();
      ok = res.statusCode == 200;
    } catch (_) {
      ok = false;
    } finally {
      cliente.close(force: true);
    }
    _remotoDisponible = ok;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final modelo = modeloMueble(_tipo);
    final p = widget.pedido;
    if (_remotoDisponible == null) {
      return const PantallaBase(seccion: 'Realidad aumentada', titulo: 'Vista en el espacio', cuerpo: Cargando());
    }
    final remoto = _remotoDisponible!;
    return PantallaBase(
      seccion: p == null ? 'Realidad aumentada' : 'Pedido · ${p.cliente?.nombre ?? p.carpinteria?.nombre ?? ''}',
      titulo: 'Vista en el espacio',
      subtitulo: 'Referencia visual del mueble para revisar con el cliente.',
      cuerpo: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
        SizedBox(
          height: 360,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              ModelViewer(
                key: ValueKey('$modelo-$remoto'),
                src: remoto ? Config.modelo('$modelo.glb') : 'assets/modelos/$modelo.glb',
                iosSrc: remoto ? Config.modelo('$modelo.usdz') : null,
                alt: 'Modelo de referencia · $_tipo',
                ar: true,
                arModes: const ['scene-viewer', 'webxr', 'quick-look'],
                arPlacement: ArPlacement.floor,
                arScale: ArScale.fixed,
                autoRotate: true,
                cameraControls: true,
                backgroundColor: const Color(0xFFEFE7DE),
                shadowIntensity: 1,
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF6FD39A)),
                    SizedBox(width: 6),
                    Text('Toca el ícono AR para verlo en tu espacio', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text('Modelo de referencia · $_tipo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final o in _opciones)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(o), selected: o == _tipo, onSelected: (_) => setState(() => _tipo = o)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        const Aviso.alerta(
          'Vista aproximada para conversar con el cliente. No representa medidas exactas ni sustituye la revisión del espacio por el carpintero.',
          icono: Icons.info_outline,
        ),
        Text('En Android se abre con Scene Viewer (Google) y en iPhone con AR Quick Look. Requiere un equipo compatible con realidad aumentada.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]),
      pie: p != null && sesion.esCarpintero
          ? BotonPrincipal('Guardar vista en el pedido', () async {
              await conCarga(context, () => Api.agregarNota(p, 'Se revisó con el cliente la vista en realidad aumentada (modelo de referencia: $_tipo).'),
                  exito: 'Se registró en el historial del pedido');
            }, icono: Icons.bookmark_add_outlined)
          : null,
    );
  }
}

// =====================================================================
// Captura de referencia del carpintero (foto + apoyo de IA)
// =====================================================================
class CapturaReferencia extends StatefulWidget {
  final Pedido pedido;
  const CapturaReferencia({required this.pedido, super.key});

  @override
  State<CapturaReferencia> createState() => _CapturaReferenciaState();
}

class _CapturaReferenciaState extends State<CapturaReferencia> {
  Uint8List? _foto;
  String _ia = '';
  final _texto = TextEditingController();
  bool _analizando = false;
  bool _guardando = false;

  Future<void> _tomar(ImageSource origen) async {
    final f = await tomarArchivoFoto(context, origen);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _foto = bytes;
      _analizando = true;
      _ia = '';
    });
    final d = await DescripcionFoto.describir(f.path);
    if (!mounted) return;
    setState(() {
      _ia = d;
      _analizando = false;
      if (_texto.text.isEmpty) _texto.text = d;
    });
  }

  Future<void> _guardar() async {
    if (_foto == null) return;
    setState(() => _guardando = true);
    try {
      await Api.subirFoto(
        pedido: widget.pedido,
        bytes: _foto!,
        descripcion: _texto.text.trim(),
        descripcionIa: _ia,
        tipo: 'referencia',
      );
      if (mounted) {
        avisar(context, 'Referencia guardada en el pedido');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final cs = Theme.of(context).colorScheme;
    return PantallaBase(
      seccion: 'Pedido · Referencia',
      titulo: 'Foto del proyecto',
      cuerpo: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
        Tarjeta(
          child: Row(children: [
            CircleAvatar(radius: 14, backgroundColor: cs.primaryContainer, child: Icon(Icons.circle, size: 10, color: cs.primary)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.cliente?.nombre ?? ''} · ${p.titulo}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${p.est.etiqueta} · Pedido ${p.folio}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        _Visor(foto: _foto, texto: 'Encuadra el mueble completo'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: BotonPrincipal('Tomar foto', () => _tomar(ImageSource.camera), icono: Icons.photo_camera_outlined)),
          const SizedBox(width: 10),
          Expanded(child: BotonSecundario('Elegir foto', () => _tomar(ImageSource.gallery), icono: Icons.photo_library_outlined)),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colores.ia, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✦ APOYO DE IA', style: TextStyle(color: Colores.iaTexto, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 6),
            const Text(
              'La IA describe elementos visibles y organiza la información de la solicitud. No indica cómo fabricar ni elige materiales por el carpintero.',
              style: TextStyle(color: Colores.iaTexto),
            ),
            const SizedBox(height: 6),
            Text('Si preguntan por maderas, consulta fichas locales verificadas de Mérida y alrededores.',
                style: TextStyle(color: Colores.iaTexto.withValues(alpha: .75), fontSize: 12.5)),
            if (_analizando) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (_foto != null && !_analizando) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _texto,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: _ia.isEmpty ? 'No se reconocieron objetos. Describe la referencia…' : null,
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        Text('Revisa el texto generado antes de guardarlo.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]),
      pie: BotonPrincipal('Guardar referencia', _foto == null ? null : _guardar, cargando: _guardando),
    );
  }
}

class _Visor extends StatelessWidget {
  final Uint8List? foto;
  final String texto;
  const _Visor({required this.foto, required this.texto});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: const Color(0xFF353A34)),
            if (foto != null) Image.memory(foto!, fit: BoxFit.cover),
            if (foto == null)
              const Center(child: Icon(Icons.center_focus_weak, color: Colors.white54, size: 64)),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ]),
        ),
      );
}

// =====================================================================
// Cámara del cliente: agregar referencia y revisar la descripción de IA
// =====================================================================
class CamaraCliente extends StatefulWidget {
  /// Si se indica, la foto se sube directamente a ese pedido.
  final Pedido? pedido;
  const CamaraCliente({this.pedido, super.key});

  @override
  State<CamaraCliente> createState() => _CamaraClienteState();
}

class _CamaraClienteState extends State<CamaraCliente> {
  Uint8List? _foto;
  String _ia = '';
  final _texto = TextEditingController();
  bool _analizando = false;
  bool _guardando = false;

  Future<void> _tomar(ImageSource origen) async {
    final f = await tomarArchivoFoto(context, origen);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _foto = bytes;
      _analizando = true;
    });
    final d = await DescripcionFoto.describir(f.path);
    if (!mounted) return;
    setState(() {
      _ia = d;
      _texto.text = d;
      _analizando = false;
    });
  }

  Future<void> _adjuntar() async {
    final fp = FotoPendiente(_foto!, descripcion: _texto.text.trim(), descripcionIa: _ia);
    if (widget.pedido == null) {
      Navigator.pop(context, fp);
      return;
    }
    setState(() => _guardando = true);
    try {
      await Api.subirFoto(pedido: widget.pedido!, bytes: fp.bytes, descripcion: fp.descripcion, descripcionIa: fp.descripcionIa);
      if (mounted) {
        avisar(context, 'Foto adjuntada al pedido');
        Navigator.pop(context, fp);
      }
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final revisando = _foto != null;
    return PantallaBase(
      seccion: 'Nuevo pedido',
      titulo: revisando ? 'Revisa tu foto' : 'Agrega una referencia',
      subtitulo: revisando
          ? 'Puedes editar la descripción antes de continuar.'
          : 'Toma una foto del espacio o elige una imagen',
      cuerpo: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
        _Visor(foto: _foto, texto: 'Encuadra el espacio o el mueble'),
        const SizedBox(height: 12),
        if (!revisando) ...[
          Text('La foto es una referencia visual; no se utilizará para calcular medidas.',
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: BotonSecundario('Galería', () => _tomar(ImageSource.gallery), icono: Icons.photo_library_outlined)),
            const SizedBox(width: 10),
            Expanded(child: BotonPrincipal('Capturar', () => _tomar(ImageSource.camera), icono: Icons.photo_camera_outlined)),
          ]),
          const SizedBox(height: 12),
          Text('Puedes adjuntar varias fotos y añadir una descripción.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colores.ia, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✦ DESCRIPCIÓN SUGERIDA POR IA',
                  style: TextStyle(color: Colores.iaTexto, fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 8),
              if (_analizando)
                const LinearProgressIndicator()
              else
                TextField(
                  controller: _texto,
                  maxLines: 5,
                  minLines: 2,
                  decoration: const InputDecoration(hintText: 'Toca para editar o añade detalles propios…'),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: BotonSecundario('Volver a tomar', () => setState(() => _foto = null), icono: Icons.refresh)),
            const SizedBox(width: 10),
            Expanded(child: BotonPrincipal('Adjuntar al pedido', _analizando ? null : _adjuntar, cargando: _guardando)),
          ]),
          const SizedBox(height: 10),
          Text(
              'La descripción es orientativa. El carpintero revisará contigo los detalles del proyecto; no se generan propuestas de diseño.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

