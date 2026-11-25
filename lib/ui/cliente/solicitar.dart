import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../modelos/modelos.dart';
import '../comunes/sensores.dart';
import '../comunes/widgets.dart';
import 'pedidos_cliente.dart';

/// Solicitud de cotización del cliente (mockup nuevo: sin medidas y con cita).
class SolicitarPantalla extends StatefulWidget {
  final Carpinteria? carpinteria;
  final ItemCatalogo? catalogo;
  final String? tipoInicial;
  final String? materialInicial;
  final String? descripcionInicial;
  final List<FotoPendiente> fotosIniciales;

  const SolicitarPantalla({
    this.carpinteria,
    this.catalogo,
    this.tipoInicial,
    this.materialInicial,
    this.descripcionInicial,
    this.fotosIniciales = const [],
    super.key,
  });

  @override
  State<SolicitarPantalla> createState() => _SolicitarPantallaState();
}

class _SolicitarPantallaState extends State<SolicitarPantalla> {
  List<Carpinteria> _talleres = [];
  Carpinteria? _taller;
  String? _tipo;
  String? _material;
  late final _desc = TextEditingController(text: widget.descripcionInicial ?? widget.catalogo?.descripcion ?? '');
  late final _direccion = TextEditingController(text: sesion.perfil?.direccion ?? '');
  late final List<FotoPendiente> _fotos = List.of(widget.fotosIniciales);
  DateTime? _cita;
  bool _enviando = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _taller = widget.carpinteria;
    final t = widget.tipoInicial ?? widget.catalogo?.tipoMueble;
    _tipo = t == null ? null : (tiposMueble.contains(t) ? t : 'Otro');
    final m = widget.materialInicial ?? widget.catalogo?.material;
    if (m != null && m.isNotEmpty) _material = m;
    _cargarTalleres();
  }

  Future<void> _cargarTalleres() async {
    try {
      final l = await Api.carpinterias();
      if (!mounted) return;
      setState(() {
        _talleres = l;
        if (_taller != null) _taller = l.where((k) => k.id == _taller!.id).firstOrNull ?? _taller;
        if (_taller == null && l.length == 1) _taller = l.first;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        avisar(context, mensajeError(e), error: true);
      }
    }
  }

  int get _paso {
    if (_tipo == null || _taller == null) return 0;
    if (_material == null) return 1;
    return 2;
  }

  Future<void> _enviar() async {
    if (_taller == null || _tipo == null) {
      avisar(context, 'Elige la carpintería y el tipo de mueble.', error: true);
      return;
    }
    if (_cita == null) {
      final seguir = await confirmar(context, 'Sin fecha de cita',
          'Puedes enviar la solicitud sin proponer fecha; el carpintero te contactará para agendar la visita.',
          si: 'Enviar así');
      if (!seguir) return;
    }
    setState(() => _enviando = true);
    try {
      final id = await Api.crearSolicitud(
        carpinteriaId: _taller!.id,
        tipoMueble: _tipo!,
        titulo: widget.catalogo?.titulo ?? _tipo!,
        materialAcabado: (_material == null || _material == 'Aún no lo sé') ? '' : _material!,
        descripcion: _desc.text.trim(),
        fechaCita: _cita,
        direccion: _direccion.text.trim(),
        catalogoId: widget.catalogo?.id,
      );
      if (_direccion.text.trim().isNotEmpty && (sesion.perfil?.direccion ?? '').isEmpty) {
        await sesion.guardarPerfil({'direccion': _direccion.text.trim()});
      }
      if (_fotos.isNotEmpty) {
        final p = await Api.pedido(id);
        for (final f in _fotos) {
          await Api.subirFoto(pedido: p, bytes: f.bytes, descripcion: f.descripcion, descripcionIa: f.descripcionIa);
        }
      }
      if (!mounted) return;
      await showAdaptiveDialog<void>(
        context: context,
        builder: (d) => AlertDialog.adaptive(
          title: const Text('¡Solicitud enviada!'),
          content: Text('${_taller!.nombre} recibió tu solicitud. '
              '${_cita == null ? 'Te contactará para agendar la cita.' : 'Confirmará tu cita del ${fechaHora(_cita!)}.'} '
              'Después de medir, te enviará la cotización en PDF.'),
          actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Ver mi pedido'))],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PedidoClientePantalla(id)));
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PantallaBase(
      seccion: 'Cliente',
      titulo: 'Solicitar cotización',
      subtitulo: 'Cuéntanos qué mueble necesitas',
      cuerpo: _cargando
          ? const Cargando()
          : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Tarjeta(
                relleno: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                child: Pasos(const ['Proyecto', 'Material', 'Cita'], _paso, numerados: false),
              ),
              if (widget.catalogo != null)
                Aviso('Basado en el trabajo "${widget.catalogo!.titulo}" del catálogo.', icono: Icons.photo_library_outlined),
              Seleccion<Carpinteria>(
                etiqueta: 'Carpintería',
                valor: _taller,
                opciones: _talleres,
                texto: (k) => k.calificacion == null ? k.nombre : '${k.nombre} · ★ ${k.calificacion!.toStringAsFixed(1)}',
                pista: _talleres.isEmpty ? 'Aún no hay carpinterías registradas' : 'Elegir carpintería',
                alCambiar: (v) => setState(() => _taller = v),
              ),
              Seleccion<String>(
                etiqueta: 'Tipo de mueble',
                valor: _tipo,
                opciones: tiposMueble,
                texto: (x) => x,
                pista: 'Elegir tipo de mueble',
                alCambiar: (v) => setState(() => _tipo = v),
              ),
              Seleccion<String>(
                etiqueta: 'Material y acabado',
                valor: _material == null ? null : (materialesAcabados.contains(_material) ? _material : null),
                opciones: [
                  ...materialesAcabados,
                ],
                texto: (x) => x,
                pista: _material != null && !materialesAcabados.contains(_material) ? _material! : 'Seleccionar material y acabado',
                alCambiar: (v) => setState(() => _material = v),
              ),
              Campo('Descripción del proyecto', _desc,
                  lineas: 4, pista: 'Describe el diseño, uso y detalles que tienes en mente…'),
              const Etiqueta('Fotos de referencia'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in _fotos)
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(f.bytes, width: 86, height: 86, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _fotos.remove(f)),
                        child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                      ),
                    ),
                  ]),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final f = await ir<FotoPendiente>(context, const CamaraCliente());
                    if (f != null) setState(() => _fotos.add(f));
                  },
                  child: Container(
                    width: _fotos.isEmpty ? double.infinity : 86,
                    height: _fotos.isEmpty ? 56 : 86,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline, width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: Text(_fotos.isEmpty ? '+ Agregar fotos' : '+',
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: _fotos.isEmpty ? 15 : 26)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              CampoToque(
                etiqueta: 'Fecha y hora de cita',
                texto: _cita == null ? 'Elegir fecha y horario' : fechaHora(_cita!),
                vacio: _cita == null,
                alTocar: () async {
                  final f = await elegirFechaHora(context, inicial: _cita);
                  if (f == null) return;
                  if (f.isBefore(DateTime.now())) {
                    if (context.mounted) avisar(context, 'Elige una fecha futura.', error: true);
                    return;
                  }
                  setState(() => _cita = f);
                },
              ),
              Campo('Dirección para la cita', _direccion, pista: 'Calle, número, colonia'),
              const Aviso('Las medidas las tomará el carpintero durante la cita.', icono: Icons.info, fondo: Colores.ia, colorTexto: Colores.iaTexto),
            ]),
      pie: BotonPrincipal('Enviar solicitud', _cargando ? null : _enviar, cargando: _enviando),
    );
  }
}
