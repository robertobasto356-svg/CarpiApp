import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/ui.dart';
import '../../datos/sesion.dart';
import '../../ia/carpi_ia.dart';
import '../../modelos/modelos.dart';
import '../carpintero/taller.dart' show TarjetaProveedor;
import '../cliente/solicitar.dart';
import 'sensores.dart';
import 'widgets.dart';

class _Burbuja {
  final bool deIA;
  final String texto;
  final RespuestaIA? respuesta;
  final DateTime hora = DateTime.now();
  _Burbuja(this.deIA, this.texto, [this.respuesta]);
}

/// Chat con CarpiIA (carpintero) o con el Asistente CarpiApp (cliente).
class AsistentePantalla extends StatefulWidget {
  final Pedido? pedido;
  const AsistentePantalla({this.pedido, super.key});

  @override
  State<AsistentePantalla> createState() => _AsistentePantallaState();
}

class _AsistentePantallaState extends State<AsistentePantalla> {
  late final CarpiIA _ia = CarpiIA(rol: sesion.esCarpintero ? 'carpintero' : 'cliente', pedido: widget.pedido);
  final _burbujas = <_Burbuja>[];
  final _texto = TextEditingController();
  final _scroll = ScrollController();
  final _fotos = <FotoPendiente>[];
  bool _pensando = false;

  bool get _cliente => !sesion.esCarpintero;

  @override
  void initState() {
    super.initState();
    final b = _ia.bienvenida();
    _burbujas.add(_Burbuja(true, b.texto, b));
  }

  @override
  void dispose() {
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _enviar(String texto) async {
    final t = texto.trim();
    if (t.isEmpty || _pensando) return;
    if (t == 'Adjuntar una foto') {
      await _adjuntarFoto();
      return;
    }
    if (t == 'Revisar este pedido') {
      return _enviar('Revisa qué le falta a este pedido');
    }
    setState(() {
      _burbujas.add(_Burbuja(false, t));
      _pensando = true;
    });
    _texto.clear();
    _bajar();
    try {
      final r = await _ia.responder(t);
      if (!mounted) return;
      setState(() => _burbujas.add(_Burbuja(true, r.texto, r)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _burbujas.add(_Burbuja(true, 'No pude consultar la guía en este momento (${mensajeError(e)}). Intenta de nuevo.')));
    } finally {
      if (mounted) setState(() => _pensando = false);
      _bajar();
    }
  }

  Future<void> _adjuntarFoto() async {
    final f = await ir<FotoPendiente>(context, const CamaraCliente());
    if (f == null || !mounted) return;
    setState(() {
      _fotos.add(f);
      _burbujas.add(_Burbuja(false, '📷 Foto de referencia adjunta'));
      _burbujas.add(_Burbuja(
        true,
        'Guardé tu foto (${_fotos.length} en total). ${f.descripcion.isEmpty ? '' : 'Descripción: “${f.descripcion}”. '}'
        'Se enviará con tu solicitud; el carpintero la usará como referencia visual, no para calcular medidas.',
        RespuestaIA('', sugerencias: const ['Preparar mi pedido']),
      ));
    });
    _bajar();
  }

  void _bajar() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ultima = _burbujas.lastWhere((b) => b.deIA).respuesta;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Marca(_cliente ? 'Mensajes' : 'CarpiIA', atras: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              const CircleAvatar(backgroundColor: Colores.ia, child: Text('✦', style: TextStyle(color: Colores.iaTexto, fontSize: 18))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_cliente ? 'Asistente CarpiApp' : 'CarpiIA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(
                    widget.pedido == null ? 'Información general · Mérida' : 'Pedido ${widget.pedido!.folio} · ${widget.pedido!.titulo}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
            ]),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _burbujas.length + (_pensando ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _burbujas.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(padding: EdgeInsets.all(8), child: Text('Escribiendo…')),
                  );
                }
                final b = _burbujas[i];
                return b.deIA ? _burbujaIA(b, cs) : _burbujaUsuario(b, cs);
              },
            ),
          ),
          if (ultima != null && ultima.sugerencias.isNotEmpty && !_pensando)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in ultima.sugerencias)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: ActionChip(
                        label: Text(s),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: cs.outline),
                        onPressed: () => _enviar(s),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _cliente
                  ? 'La IA no genera diseños ni confirma materiales, medidas, precios o fechas.'
                  : 'CarpiIA es un apoyo: tú revisas y decides qué aplicar.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                if (_cliente)
                  IconButton(icon: Icon(Icons.add_a_photo_outlined, color: cs.primary), onPressed: _adjuntarFoto),
                Expanded(
                  child: TextField(
                    controller: _texto,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _enviar,
                    decoration: InputDecoration(
                      hintText: _cliente ? 'Pregunta o cuéntame tu idea…' : 'Pregunta a CarpiIA…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: cs.outline)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: cs.primary,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: () => _enviar(_texto.text)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _burbujaUsuario(_Burbuja b, ColorScheme cs) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(b.texto, style: const TextStyle(color: Colors.white, fontSize: 15)),
            Text(hora(b.hora), style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 10)),
          ]),
        ),
      );

  Widget _burbujaIA(_Burbuja b, ColorScheme cs) {
    final r = b.respuesta;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .86),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (b.texto.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colores.ia,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_cliente ? '✦ ASISTENTE IA' : '✦ CARPIIA',
                    style: const TextStyle(color: Colores.iaTexto, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 4),
                _TextoMarcado(b.texto),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(hora(b.hora), style: TextStyle(color: Colores.iaTexto.withValues(alpha: .7), fontSize: 10)),
                ),
              ]),
            ),
          if (r != null && r.fichas.isNotEmpty && r.fichas.first.categoria != 'app')
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline)),
              child: Row(children: [
                Icon(Icons.menu_book_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Guía local de maderas y acabados', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('Características generales · cuidados para la región', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    Text('La existencia se verifica con cada proveedor.', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                ),
              ]),
            ),
          if (r != null)
            for (final p in r.proveedores)
              Padding(padding: const EdgeInsets.only(top: 6), child: TarjetaProveedor(p)),
          if (r?.pie != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(r!.pie!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
          if (r?.borrador != null) _tarjetaBorrador(r!.borrador!, cs),
        ]),
      ),
    );
  }

  Widget _tarjetaBorrador(BorradorSolicitud b, ColorScheme cs) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary, width: 1.4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Borrador de solicitud', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${b.resumen}${_fotos.isEmpty ? '' : ' · Fotos de referencia: ${_fotos.length}'}'),
          if (b.descripcion.isNotEmpty) Text(b.descripcion, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Puedes editarlo antes de enviarlo al carpintero.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          BotonPrincipal('Revisar y enviar al carpintero', () {
            ir(
              context,
              SolicitarPantalla(
                tipoInicial: b.tipo,
                materialInicial: b.material,
                descripcionInicial: b.descripcionCompleta,
                fotosIniciales: List.of(_fotos),
              ),
            );
          }, icono: Icons.send_outlined),
        ]),
      );
}

/// Texto con **negritas** simples.
class _TextoMarcado extends StatelessWidget {
  final String texto;
  const _TextoMarcado(this.texto);

  @override
  Widget build(BuildContext context) {
    final partes = texto.split('**');
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Color(0xFF1E3B2E), fontSize: 14.5, height: 1.38),
        children: [
          for (var i = 0; i < partes.length; i++)
            TextSpan(text: partes[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null),
        ],
      ),
    );
  }
}
