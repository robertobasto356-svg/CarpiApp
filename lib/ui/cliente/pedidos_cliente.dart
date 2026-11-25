import 'package:printing/printing.dart';

import '../../core/formato.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../modelos/modelos.dart';
import '../carpintero/pedidos_carpintero.dart' show TarjetaPedido, TarjetaCita;
import '../comunes/comunes.dart';
import '../comunes/sensores.dart';
import '../comunes/widgets.dart';
import 'solicitar.dart';

class MisPedidosPantalla extends StatefulWidget {
  final bool atras;
  const MisPedidosPantalla({this.atras = true, super.key});

  @override
  State<MisPedidosPantalla> createState() => _MisPedidosPantallaState();
}

class _MisPedidosPantallaState extends State<MisPedidosPantalla> {
  int _tab = 0;
  final _clave = GlobalKey<CargadorState<List<Pedido>>>();

  @override
  Widget build(BuildContext context) => PantallaBase(
        seccion: 'Cliente',
        titulo: 'Mis pedidos',
        subtitulo: 'Solicitudes, cotizaciones y seguimiento',
        atras: widget.atras,
        acciones: [
          BotonCirculo(Icons.add, () async {
            await ir(context, const SolicitarPantalla());
            _clave.currentState?.recargar();
          }, ayuda: 'Solicitar cotización'),
        ],
        cuerpo: Column(children: [
          Pildoras(const ['Todos', 'En curso', 'Completados'], _tab, (i) => setState(() => _tab = i)),
          const SizedBox(height: 10),
          Expanded(
            child: Cargador<List<Pedido>>(
              key: _clave,
              cargar: Api.pedidosCliente,
              construir: (c, lista, recargar) {
                final l = switch (_tab) {
                  1 => lista.where((p) => !EstadoPedido.cerrados.contains(p.estado)).toList(),
                  2 => lista.where((p) => EstadoPedido.cerrados.contains(p.estado)).toList(),
                  _ => lista,
                };
                return RefreshIndicator.adaptive(
                  onRefresh: recargar,
                  child: l.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 40),
                          Vacio(Icons.receipt_long_outlined, 'Aún no tienes pedidos',
                              detalle: 'Solicita una cotización y da seguimiento aquí.',
                              accion: SizedBox(
                                  width: 240,
                                  child: BotonPrincipal('Solicitar cotización', () async {
                                    await ir(c, const SolicitarPantalla());
                                    recargar();
                                  }))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: l.length,
                          itemBuilder: (_, i) => Stack(children: [
                            TarjetaPedido(l[i], mostrarCliente: false, alTocar: () async {
                              await ir(c, PedidoClientePantalla(l[i].id));
                              recargar();
                            }),
                            if (l[i].estado == 'cotizado')
                              const Positioned(
                                right: 12,
                                top: 12,
                                child: Badge(label: Text('Responder'), backgroundColor: Color(0xFF2F6FDB)),
                              ),
                          ]),
                        ),
                );
              },
            ),
          ),
        ]),
      );
}

class _DatosPedido {
  final Pedido pedido;
  final List<Cita> citas;
  final Cotizacion? cotizacion;
  final List<Foto> fotos;
  final List<Avance> avances;
  final Map<String, dynamic>? calificacion;
  _DatosPedido(this.pedido, this.citas, this.cotizacion, this.fotos, this.avances, this.calificacion);
}

class PedidoClientePantalla extends StatefulWidget {
  final int pedidoId;
  const PedidoClientePantalla(this.pedidoId, {super.key});

  @override
  State<PedidoClientePantalla> createState() => _PedidoClientePantallaState();
}

class _PedidoClientePantallaState extends State<PedidoClientePantalla> {
  final _clave = GlobalKey<CargadorState<_DatosPedido>>();

  Future<_DatosPedido> _cargar() async {
    final r = await Future.wait([
      Api.pedido(widget.pedidoId),
      Api.citasPedido(widget.pedidoId),
      Api.cotizacionDePedido(widget.pedidoId),
      Api.fotos(widget.pedidoId),
      Api.avances(widget.pedidoId),
      Api.calificacionDe(widget.pedidoId),
    ]);
    return _DatosPedido(r[0] as Pedido, r[1] as List<Cita>, r[2] as Cotizacion?, r[3] as List<Foto>, r[4] as List<Avance>,
        r[5] as Map<String, dynamic>?);
  }

  void _recargar() => _clave.currentState?.recargar();

  @override
  Widget build(BuildContext context) => PantallaBase(
        seccion: 'Mis pedidos',
        cuerpo: Cargador<_DatosPedido>(
          key: _clave,
          cargar: _cargar,
          construir: (c, d, recargar) => RefreshIndicator.adaptive(
            onRefresh: recargar,
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: _contenido(c, d)),
          ),
        ),
      );

  List<Widget> _contenido(BuildContext c, _DatosPedido d) {
    final p = d.pedido;
    final k = p.carpinteria;
    final cs = Theme.of(c).colorScheme;
    final cot = d.cotizacion;
    return [
      Text(p.folio, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
      Text(p.titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      Text(k?.nombre ?? '', style: TextStyle(color: cs.onSurfaceVariant)),
      const SizedBox(height: 8),
      ChipEstado.pedido(p.estado),
      const SizedBox(height: 14),
      Tarjeta(relleno: const EdgeInsets.fromLTRB(6, 14, 6, 10), child: Pasos(pasosPedido, p.est.paso, numerados: false)),
      if (EstadoPedido.fabricacion.contains(p.estado)) ...[
        const Seccion('Avance de tu mueble'),
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Progreso(p.progreso),
            if (p.fechaEntrega != null) ...[
              const SizedBox(height: 8),
              Text('Entrega estimada: ${fechaLarga(p.fechaEntrega!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      ],
      if (p.estado == 'entregado' && d.calificacion == null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BotonPrincipal('Calificar experiencia', () async {
            await ir(c, CalificarPantalla(p));
            _recargar();
          }, icono: Icons.star_outline_rounded),
        ),
      if (d.calificacion != null)
        Tarjeta(
          child: Row(children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= (d.calificacion!['estrellas'] as int) ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFE0A100)),
            const SizedBox(width: 8),
            const Expanded(child: Text('¡Gracias por tu opinión!')),
          ]),
        ),

      // Cotización recibida
      if (cot != null) ...[
        const Seccion('Cotización recibida'),
        _cotizacion(c, cot, p),
      ] else if (!EstadoPedido.cerrados.contains(p.estado))
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Aviso('Después de la cita, el carpintero registrará las medidas y te enviará la cotización en PDF.',
              icono: Icons.hourglass_top_rounded),
        ),

      // Cita
      const Seccion('Cita para medir'),
      if (d.citas.isEmpty) const Tarjeta(child: Text('El carpintero te contactará para agendar la visita.')),
      for (final cita in d.citas)
        TarjetaCita(cita,
            acciones: cita.estado == 'propuesta'
                ? const Padding(padding: EdgeInsets.only(top: 8), child: Text('Esperando confirmación del carpintero.'))
                : null),

      // Proyecto
      const Seccion('Tu solicitud'),
      Tarjeta(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Dato('Mueble', p.tipoMueble),
          Dato('Material', p.materialAcabado.isEmpty ? 'A definir con el carpintero' : p.materialAcabado),
          if (p.descripcion.isNotEmpty) Dato('Detalles', p.descripcion),
          if (p.tieneMedidas) Dato('Medidas', p.medidasTexto),
        ]),
      ),

      // Fotos
      Seccion('Fotos',
          accion: EstadoPedido.cerrados.contains(p.estado)
              ? null
              : TextButton.icon(
                  onPressed: () async {
                    await ir(c, CamaraCliente(pedido: p));
                    _recargar();
                  },
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Agregar')),
      ),
      if (d.fotos.isEmpty) const Tarjeta(child: Text('Sin fotos.')),
      if (d.fotos.isNotEmpty)
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.fotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => verImagen(c, 'fotos', d.fotos[i].path, pie: d.fotos[i].descripcion),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 110, height: 110, child: ImagenStorage('fotos', d.fotos[i].path)),
              ),
            ),
          ),
        ),

      // Acciones
      const Seccion('Contacto'),
      Row(children: [
        Expanded(
          child: BotonSecundario('Mensaje', () {
            ir(c, ChatPantalla(carpinteriaId: p.carpinteriaId, clientePerfilId: sesion.perfil!.id, titulo: k?.nombre ?? 'Carpintería'));
          }, icono: Icons.chat_bubble_outline),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BotonSecundario('Ver en AR', () => ir(c, VistaArPantalla(tipoMueble: p.tipoMueble, pedido: p)),
              icono: Icons.view_in_ar_outlined),
        ),
      ]),

      // Historial
      const Seccion('Seguimiento'),
      for (final a in d.avances)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.circle, size: 10, color: EstadoPedido.de(a.estado).color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.nota.isEmpty ? EstadoPedido.de(a.estado).etiqueta : a.nota, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(fechaHora(a.fecha), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
    ];
  }

  Widget _cotizacion(BuildContext c, Cotizacion cot, Pedido p) {
    final cs = Theme.of(c).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('PDF · ${cot.folio}${cot.enviadaAt == null ? '' : ' · ${fechaCorta(cot.enviadaAt!).toUpperCase()}'}',
          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Align(alignment: Alignment.centerLeft, child: ChipEstado(cot.estado == 'enviada' ? 'Recibida en PDF' : cot.estadoTexto, cot.estadoColor)),
      const SizedBox(height: 10),
      Tarjeta(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Dato('Proyecto', [p.tipoMueble, p.materialAcabado].where((s) => s.isNotEmpty).join(' · ')),
          const Etiqueta('Medidas tomadas en la cita'),
          Text(p.medidasTexto, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Registradas por el carpintero', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
      ),
      ResumenCostos(cot.costoMateriales, cot.manoObra, cot.costosAdicionales),
      if (cot.notas.isNotEmpty) Tarjeta(child: Dato('Notas', cot.notas)),
      if (cot.pdfPath != null) ...[
        Tarjeta(
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFD22B2B).withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
              child: const Text('PDF', style: TextStyle(color: Color(0xFFD22B2B), fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cotizacion-${cot.folio}.pdf', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Cotización final · enviada por tu carpintero', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        BotonSecundario('Ver cotización PDF', () async {
          final url = await Api.urlFirmada('cotizaciones', cot.pdfPath!);
          if (c.mounted) await abrirEnlace(c, Uri.parse(url));
        }, icono: Icons.visibility_outlined),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: BotonSecundario('Descargar PDF', () async {
              final ok = await conCarga(c, () async {
                final bytes = await Api.descargar('cotizaciones', cot.pdfPath!);
                await Printing.sharePdf(bytes: bytes, filename: 'Cotizacion-${cot.folio}.pdf');
              });
              if (!ok) return;
            }, icono: Icons.download_outlined),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BotonSecundario('Imprimir PDF', () async {
              final bytes = await Api.descargar('cotizaciones', cot.pdfPath!);
              await Printing.layoutPdf(name: 'Cotizacion-${cot.folio}', onLayout: (_) async => bytes);
            }, icono: Icons.print_outlined),
          ),
        ]),
      ],
      if (cot.estado == 'enviada') ...[
        const SizedBox(height: 14),
        BotonPrincipal('Aceptar cotización', () => _responder(c, cot, 'aceptada'), icono: Icons.check_circle_outline),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: BotonSecundario('Pedir ajustes', () => _responder(c, cot, 'ajustes'), icono: Icons.tune)),
          const SizedBox(width: 8),
          Expanded(child: BotonSecundario('Rechazar', () => _responder(c, cot, 'rechazada'), color: const Color(0xFFD22B2B))),
        ]),
      ],
      if (cot.estado == 'ajustes')
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Aviso('Pediste ajustes. El carpintero te enviará una cotización actualizada.', icono: Icons.hourglass_top_rounded),
        ),
    ]);
  }

  Future<void> _responder(BuildContext c, Cotizacion cot, String respuesta) async {
    var comentario = '';
    if (respuesta == 'aceptada') {
      if (!await confirmar(c, 'Aceptar cotización',
          'Aceptas la cotización ${cot.folio} por ${dinero(cot.total)}. El carpintero iniciará la fabricación y acordará contigo el anticipo y la forma de pago.',
          si: 'Aceptar')) {
        return;
      }
    } else {
      final ctl = TextEditingController();
      if (!c.mounted) return;
      final ok = await hojaFormulario(
        c,
        respuesta == 'ajustes' ? '¿Qué te gustaría ajustar?' : '¿Por qué la rechazas?',
        [Campo(respuesta == 'ajustes' ? 'Comentario para el carpintero' : 'Motivo (opcional)', ctl, lineas: 4)],
        guardar: respuesta == 'ajustes' ? 'Pedir ajustes' : 'Rechazar cotización',
      );
      if (ok != true) return;
      comentario = ctl.text.trim();
      if (respuesta == 'ajustes' && comentario.isEmpty) {
        if (c.mounted) avisar(c, 'Escribe qué quieres ajustar.', error: true);
        return;
      }
    }
    if (!c.mounted) return;
    await conCarga(c, () => Api.responderCotizacion(cot.id, respuesta, comentario),
        exito: switch (respuesta) {
          'aceptada' => '¡Cotización aceptada! Tu carpintero comenzará la fabricación.',
          'ajustes' => 'Se enviaron tus comentarios al carpintero.',
          _ => 'Cotización rechazada.',
        });
    _recargar();
  }
}

class CalificarPantalla extends StatefulWidget {
  final Pedido pedido;
  const CalificarPantalla(this.pedido, {super.key});

  @override
  State<CalificarPantalla> createState() => _CalificarPantallaState();
}

class _CalificarPantallaState extends State<CalificarPantalla> {
  int _estrellas = 5;
  final _opinion = TextEditingController();
  bool _enviando = false;

  @override
  Widget build(BuildContext context) => PantallaBase(
        seccion: 'Cliente',
        titulo: 'Calificar trabajo',
        subtitulo: '${widget.pedido.titulo} · ${widget.pedido.carpinteria?.nombre ?? ''}',
        cuerpo: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          const SizedBox(height: 12),
          const Center(child: Text('¿Cómo fue tu experiencia?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 44,
                onPressed: () => setState(() => _estrellas = i),
                icon: Icon(i <= _estrellas ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFE0A100)),
              ),
          ]),
          Center(
            child: Text(const ['', 'Muy mala', 'Mala', 'Regular', 'Buena', 'Excelente'][_estrellas],
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          Campo('Tu opinión', _opinion, lineas: 4, pista: 'Calidad, puntualidad, trato, limpieza en la instalación…'),
        ]),
        pie: BotonPrincipal('Enviar', () async {
          setState(() => _enviando = true);
          try {
            await Api.calificar(widget.pedido.id, _estrellas, _opinion.text.trim());
            if (!context.mounted) return;
            avisar(context, '¡Gracias por tu opinión!');
            Navigator.pop(context);
          } catch (e) {
            if (context.mounted) avisar(context, mensajeError(e), error: true);
          } finally {
            if (mounted) setState(() => _enviando = false);
          }
        }, cargando: _enviando),
      );
}
