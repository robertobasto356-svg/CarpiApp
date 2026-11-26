import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../ia/carpi_ia.dart';
import '../../modelos/modelos.dart';
import '../comunes/asistente.dart';
import '../comunes/comunes.dart';
import '../comunes/sensores.dart';
import '../comunes/widgets.dart';
import 'clientes_carpintero.dart';
import 'cotizaciones.dart';
import 'taller.dart';

// =====================================================================
// Tarjetas reutilizables
// =====================================================================
class TarjetaPedido extends StatelessWidget {
  final Pedido p;
  final VoidCallback alTocar;
  final bool mostrarCliente;
  final bool mostrarProgreso;
  const TarjetaPedido(
    this.p, {
    required this.alTocar,
    this.mostrarCliente = true,
    this.mostrarProgreso = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tarjeta(
      alTocar: alTocar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(iconoMueble(p.tipoMueble), color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.folio} · ${p.titulo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      mostrarCliente
                          ? '${p.cliente?.nombre ?? 'Cliente'} · ${fechaCorta(p.creado)}'
                          : sesion.esCarpintero
                          ? 'Solicitado el ${fechaCorta(p.creado)}'
                          : '${p.carpinteria?.nombre ?? ''} · ${fechaCorta(p.creado)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChipEstado.pedido(p.estado),
              const Spacer(),
              if (p.fechaEntrega != null)
                Text(
                  'Entrega: ${fechaCorta(p.fechaEntrega!)}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
            ],
          ),
          if (mostrarProgreso || EstadoPedido.enProceso.contains(p.estado)) ...[
            const SizedBox(height: 10),
            Progreso(p.progreso),
          ],
        ],
      ),
    );
  }
}

class TarjetaCita extends StatelessWidget {
  final Cita c;
  final VoidCallback? alTocar;
  final Widget? acciones;
  const TarjetaCita(this.c, {this.alTocar, this.acciones, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final propuesta = c.estado == 'propuesta';
    return Tarjeta(
      alTocar: alTocar,
      color: propuesta ? cs.primaryContainer.withValues(alpha: .55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text(
                      '${c.fechaHora.day}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    Text(
                      mesAnio(c.fechaHora).substring(0, 3).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${hora(c.fechaHora)} · ${c.motivo}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      [c.clienteNombre, c.pedidoTitulo].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                    ),
                    if (c.direccion.isNotEmpty)
                      Text(c.direccion, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              ),
              ChipEstado(
                c.estadoTexto.split(' ').first,
                propuesta ? const Color(0xFFC77700) : (c.estado == 'cancelada' ? Colors.grey : cs.primary),
              ),
            ],
          ),
          ?acciones,
        ],
      ),
    );
  }
}

// =====================================================================
// Lista de pedidos
// =====================================================================
class PedidosCarpintero extends StatefulWidget {
  final bool atras;
  const PedidosCarpintero({this.atras = true, super.key});

  @override
  State<PedidosCarpintero> createState() => _PedidosCarpinteroState();
}

class _PedidosCarpinteroState extends State<PedidosCarpintero> {
  int _tab = 0;
  String _q = '';
  final _clave = GlobalKey<CargadorState<List<Pedido>>>();
  static const _tabs = ['Todos', 'Nuevos', 'En proceso', 'Entregados'];

  List<Pedido> _filtrar(List<Pedido> l) {
    var r = switch (_tab) {
      1 => l.where((p) => EstadoPedido.nuevos.contains(p.estado) || p.estado == 'cotizado').toList(),
      2 => l.where((p) => EstadoPedido.enProceso.contains(p.estado)).toList(),
      3 => l.where((p) => p.estado == 'entregado').toList(),
      _ => l,
    };
    if (_q.isNotEmpty) {
      r = r
          .where(
            (p) =>
                p.titulo.toLowerCase().contains(_q) ||
                (p.cliente?.nombre.toLowerCase().contains(_q) ?? false) ||
                p.folio.toLowerCase().contains(_q),
          )
          .toList();
    }
    return r;
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Pedidos',
    titulo: 'Pedidos recibidos',
    subtitulo: 'Solicitudes, cotizaciones y trabajos',
    atras: widget.atras,
    acciones: [
      BotonCirculo(Icons.add, () async {
        final id = await nuevoPedido(context);
        if (id != null && context.mounted) {
          await ir(context, PedidoDetalleCarpintero(id));
        }
        _clave.currentState?.recargar();
      }, ayuda: 'Nuevo pedido'),
    ],
    cuerpo: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Buscador('Buscar pedido o cliente', (q) => setState(() => _q = q)),
        ),
        Pildoras(_tabs, _tab, (i) => setState(() => _tab = i)),
        const SizedBox(height: 10),
        Expanded(
          child: Cargador<List<Pedido>>(
            key: _clave,
            cargar: () => Api.pedidosCarpinteria(),
            construir: (c, lista, recargar) {
              final l = _filtrar(lista);
              return RefreshIndicator.adaptive(
                onRefresh: recargar,
                child: l.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 60),
                          Vacio(
                            Icons.inventory_2_outlined,
                            'No hay pedidos aquí',
                            detalle: 'Las solicitudes de tus clientes aparecerán en "Nuevos".',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: l.length,
                        itemBuilder: (_, i) => TarjetaPedido(
                          l[i],
                          alTocar: () async {
                            await ir(c, PedidoDetalleCarpintero(l[i].id));
                            recargar();
                          },
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// Pedido capturado por el carpintero (cliente por teléfono o en persona).
Future<int?> nuevoPedido(BuildContext c, {Cliente? cliente}) async {
  final clientes = await Api.clientes();
  if (!c.mounted) return null;
  Cliente? elegido = cliente;
  var tipo = tiposMueble.first;
  final titulo = TextEditingController();
  final material = TextEditingController();
  final desc = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: c,
    isScrollControlled: true,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(d).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nuevo pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Seleccion<Cliente>(
                etiqueta: 'Cliente',
                valor: elegido == null ? null : clientes.where((x) => x.id == elegido!.id).firstOrNull,
                opciones: clientes,
                texto: (x) => x.nombre,
                pista: clientes.isEmpty ? 'Primero agrega un cliente' : 'Elegir cliente',
                alCambiar: (v) => set(() => elegido = v),
              ),
              TextButton.icon(
                onPressed: () async {
                  final nuevo = await formularioCliente(d);
                  if (nuevo != null) {
                    clientes.add(nuevo);
                    set(() => elegido = nuevo);
                  }
                },
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Agregar cliente nuevo'),
              ),
              Seleccion<String>(
                etiqueta: 'Tipo de mueble',
                valor: tipo,
                opciones: tiposMueble,
                texto: (x) => x,
                alCambiar: (v) => set(() => tipo = v ?? tipo),
              ),
              Campo('Nombre del proyecto', titulo, pista: 'Ej. Clóset recámara principal'),
              Campo('Material y acabado', material, pista: 'Ej. Melamina blanca'),
              Campo('Descripción', desc, lineas: 3),
              BotonPrincipal('Crear pedido', () {
                if (elegido == null) {
                  avisar(d, 'Elige o agrega un cliente.', error: true);
                  return;
                }
                Navigator.pop(d, true);
              }),
            ],
          ),
        ),
      ),
    ),
  );
  if (ok != true || elegido == null || !c.mounted) return null;
  int? id;
  await conCarga(c, () async {
    id = await Api.crearPedido(
      clienteId: elegido!.id,
      titulo: titulo.text.trim().isEmpty ? tipo : titulo.text.trim(),
      tipoMueble: tipo,
      materialAcabado: material.text.trim(),
      descripcion: desc.text.trim(),
    );
  });
  return id;
}

// =====================================================================
// Detalle del pedido (carpintero)
// =====================================================================
class _Detalle {
  final Pedido pedido;
  final List<Cita> citas;
  final Cotizacion? cotizacion;
  final List<Foto> fotos;
  final List<Avance> avances;
  _Detalle(this.pedido, this.citas, this.cotizacion, this.fotos, this.avances);
}

class PedidoDetalleCarpintero extends StatefulWidget {
  final int pedidoId;
  const PedidoDetalleCarpintero(this.pedidoId, {super.key});

  @override
  State<PedidoDetalleCarpintero> createState() => _PedidoDetalleCarpinteroState();
}

class _PedidoDetalleCarpinteroState extends State<PedidoDetalleCarpintero> {
  final _clave = GlobalKey<CargadorState<_Detalle>>();

  Future<_Detalle> _cargar() async {
    final r = await Future.wait([
      Api.pedido(widget.pedidoId),
      Api.citasPedido(widget.pedidoId),
      Api.cotizacionDePedido(widget.pedidoId),
      Api.fotos(widget.pedidoId),
      Api.avances(widget.pedidoId),
    ]);
    return _Detalle(r[0] as Pedido, r[1] as List<Cita>, r[2] as Cotizacion?, r[3] as List<Foto>, r[4] as List<Avance>);
  }

  void _recargar() => _clave.currentState?.recargar();

  Future<void> _abrir(Widget w) async {
    await ir(context, w);
    _recargar();
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Pedido',
    cuerpo: Cargador<_Detalle>(
      key: _clave,
      cargar: _cargar,
      construir: (c, d, recargar) => RefreshIndicator.adaptive(
        onRefresh: recargar,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: _contenido(c, d)),
      ),
    ),
  );

  List<Widget> _contenido(BuildContext c, _Detalle d) {
    final p = d.pedido;
    final cs = Theme.of(c).colorScheme;
    final cli = p.cliente;
    final enFabricacion = EstadoPedido.fabricacion.contains(p.estado);
    return [
      Text(
        p.folio,
        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
      ),
      Text(p.titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Row(
        children: [
          ChipEstado.pedido(p.estado),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (v) => _menu(v, p),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar datos del proyecto')),
              const PopupMenuItem(value: 'nota', child: Text('Agregar nota al historial')),
              if (!EstadoPedido.cerrados.contains(p.estado))
                const PopupMenuItem(value: 'cancelar', child: Text('Cancelar pedido')),
              if (p.estado == 'entregado')
                const PopupMenuItem(value: 'catalogo', child: Text('Publicar en mi catálogo')),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      Pasos(pasosPedido, p.est.paso, numerados: false),

      // Cliente
      const Seccion('Cliente'),
      Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(cli?.nombre ?? '?'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cli?.nombre ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(
                        cli?.tieneCuenta == true ? 'Usa CarpiApp' : 'Sin cuenta en la app',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (cli != null && cli.telefono.isNotEmpty)
              Dato('Teléfono', cli.telefono, alTocar: () => llamar(c, cli.telefono)),
            if (cli != null && cli.direccion.isNotEmpty)
              Dato('Dirección', cli.direccion, alTocar: () => comoLlegar(c, cli.direccion)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (cli?.tieneCuenta == true)
                  ActionChip(
                    avatar: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Mensaje'),
                    onPressed: () => ir(
                      c,
                      ChatPantalla(carpinteriaId: p.carpinteriaId, clientePerfilId: cli!.perfilId!, titulo: cli.nombre),
                    ),
                  ),
                if (cli != null && cli.telefono.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('WhatsApp'),
                    onPressed: () => whatsapp(
                      c,
                      cli.telefono,
                      'Hola ${primerNombre(cli.nombre)}, te escribo de tu pedido ${p.folio}.',
                    ),
                  ),
                if (cli != null)
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Ficha'),
                    onPressed: () => _abrir(ClienteDetalle(cli)),
                  ),
              ],
            ),
          ],
        ),
      ),

      // Proyecto
      const Seccion('Proyecto'),
      Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Dato('Mueble', p.tipoMueble),
            Dato('Material', p.materialAcabado.isEmpty ? 'Por definir' : p.materialAcabado),
            if (p.descripcion.isNotEmpty) Dato('Detalles', p.descripcion),
            Dato('Solicitado', fechaLarga(p.creado)),
          ],
        ),
      ),

      // Fotos
      Seccion(
        'Fotos de referencia',
        accion: TextButton.icon(
          onPressed: () => _abrir(CapturaReferencia(pedido: p)),
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: const Text('Agregar'),
        ),
      ),
      if (d.fotos.isEmpty)
        const Tarjeta(child: Text('Sin fotos todavía. Puedes tomar una referencia del espacio o del mueble.'))
      else
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.fotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = d.fotos[i];
              return GestureDetector(
                onTap: () => verImagen(
                  c,
                  'fotos',
                  f.path,
                  pie: [f.descripcion, f.descripcionIa].where((s) => s.isNotEmpty).join('\n\n'),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 120, height: 120, child: ImagenStorage('fotos', f.path)),
                ),
              );
            },
          ),
        ),

      // Citas
      Seccion(
        'Cita para medir',
        accion: TextButton.icon(
          onPressed: () async {
            final f = await elegirFechaHora(c);
            if (f == null || !c.mounted) return;
            await conCarga(c, () async {
              await Api.crearCita(
                clienteId: p.clienteId,
                pedidoId: p.id,
                fechaHora: f,
                motivo: 'Toma de medidas',
                direccion: cli?.direccion ?? '',
              );
              if (p.estado == 'solicitado') await Api.actualizarPedido(p.id, {'estado': 'cita_agendada'});
            }, exito: 'Cita agendada');
            _recargar();
          },
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('Agendar'),
        ),
      ),
      if (d.citas.isEmpty) const Tarjeta(child: Text('Aún no hay cita. Agenda una visita para tomar las medidas.')),
      for (final cita in d.citas) TarjetaCita(cita, acciones: _accionesCita(c, cita, p)),

      // Medidas
      Seccion(
        'Medidas tomadas en la cita',
        accion: TextButton(onPressed: () => _medidas(p), child: Text(p.tieneMedidas ? 'Editar' : 'Registrar')),
      ),
      Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.medidasTexto, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (p.medidasNotas.isNotEmpty) ...[const SizedBox(height: 4), Text(p.medidasNotas)],
            if (p.medidasRegistradasAt != null)
              Text(
                'Registradas el ${fechaCorta(p.medidasRegistradasAt!)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 8),
            Text(
              'Consejo: mide en varios puntos y usa la medida menor.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ir(c, const NivelPantalla()),
                icon: const Icon(Icons.straighten, size: 18),
                label: const Text('Abrir nivel digital'),
              ),
            ),
          ],
        ),
      ),

      // Cotización
      const Seccion('Cotización'),
      _bloqueCotizacion(c, d),

      // Fabricación
      if (enFabricacion) ...[const Seccion('Avance de fabricación'), _BloqueAvance(pedido: p, alGuardar: _recargar)],

      // Herramientas
      const Seccion('Herramientas'),
      Row(
        children: [
          Expanded(
            child: BotonSecundario('Revisar con CarpiIA', () => _revisar(c, d), icono: Icons.auto_awesome_outlined),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BotonSecundario(
              'Vista AR',
              () => _abrir(VistaArPantalla(tipoMueble: p.tipoMueble, pedido: p)),
              icono: Icons.view_in_ar_outlined,
            ),
          ),
        ],
      ),

      // Historial
      const Seccion('Historial'),
      for (final a in d.avances)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.circle, size: 10, color: EstadoPedido.de(a.estado).color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nota.isEmpty ? EstadoPedido.de(a.estado).etiqueta : a.nota,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${fechaHora(a.fecha)} · ${a.progreso}%',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget? _accionesCita(BuildContext c, Cita cita, Pedido p) {
    if (cita.estado == 'cancelada' || cita.estado == 'realizada') return null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        children: [
          if (cita.estado == 'propuesta')
            FilledButton.tonal(
              onPressed: () async {
                await conCarga(
                  c,
                  () => Api.actualizarCita(cita.id, {'estado': 'confirmada'}),
                  exito: 'Cita confirmada',
                );
                _recargar();
              },
              child: const Text('Confirmar'),
            ),
          if (cita.estado == 'confirmada')
            FilledButton.tonal(
              onPressed: () async {
                await conCarga(c, () => Api.actualizarCita(cita.id, {'estado': 'realizada'}));
                _recargar();
                _medidas(p);
              },
              child: const Text('Realizada · medir'),
            ),
          TextButton(
            onPressed: () async {
              final f = await elegirFechaHora(c, inicial: cita.fechaHora);
              if (f == null || !c.mounted) return;
              await conCarga(
                c,
                () => Api.actualizarCita(cita.id, {'fecha_hora': f.toUtc().toIso8601String(), 'estado': 'confirmada'}),
                exito: 'Cita reprogramada',
              );
              _recargar();
            },
            child: const Text('Reprogramar'),
          ),
          TextButton(
            onPressed: () async {
              if (!await confirmar(c, 'Cancelar cita', '¿Cancelar esta cita?', si: 'Cancelar cita', peligro: true)) {
                return;
              }
              if (!c.mounted) return;
              await conCarga(c, () => Api.actualizarCita(cita.id, {'estado': 'cancelada'}));
              _recargar();
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _bloqueCotizacion(BuildContext c, _Detalle d) {
    final p = d.pedido;
    final cot = d.cotizacion;
    final cs = Theme.of(c).colorScheme;
    if (cot == null) {
      return Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p.tieneMedidas
                  ? 'Ya tienes las medidas. Arma la cotización con materiales, mano de obra y costos adicionales.'
                  : 'Registra primero las medidas en la cita; también puedes empezar la cotización y completarlas después.',
            ),
            const SizedBox(height: 12),
            BotonPrincipal(
              'Crear cotización',
              () => _abrir(EditorCotizacion(pedido: p)),
              icono: Icons.request_quote_outlined,
            ),
          ],
        ),
      );
    }
    return Tarjeta(
      alTocar: () => _abrir(CotizacionLista(cot.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(cot.folio, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              ChipEstado(cot.estadoTexto, cot.estadoColor),
              const Spacer(),
              Text(
                dinero(cot.total),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary),
              ),
            ],
          ),
          if (cot.estado == 'ajustes' && cot.comentarioCliente.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Aviso.alerta('“${cot.comentarioCliente}”', titulo: 'EL CLIENTE PIDE AJUSTES'),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (cot.estado == 'borrador' || cot.estado == 'ajustes')
                Expanded(
                  child: BotonSecundario(
                    'Editar',
                    () => _abrir(EditorCotizacion(pedido: p, cotizacion: cot)),
                    icono: Icons.edit_outlined,
                  ),
                ),
              if (cot.estado == 'borrador' || cot.estado == 'ajustes') const SizedBox(width: 8),
              Expanded(
                child: BotonSecundario(
                  'Ver PDF y enviar',
                  () => _abrir(CotizacionLista(cot.id)),
                  icono: Icons.picture_as_pdf_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _medidas(Pedido p) async {
    final alto = TextEditingController(text: p.alto == null ? '' : numeroCorto(p.alto));
    final ancho = TextEditingController(text: p.ancho == null ? '' : numeroCorto(p.ancho));
    final fondo = TextEditingController(text: p.fondo == null ? '' : numeroCorto(p.fondo));
    final notas = TextEditingController(text: p.medidasNotas);
    const num = TextInputType.numberWithOptions(decimal: true);
    final ok = await hojaFormulario(context, 'Medidas del espacio', [
      const Aviso(
        'Mide en varios puntos: los muros rara vez son rectos. Registra la medida menor.',
        icono: Icons.lightbulb_outline,
      ),
      Row(
        children: [
          Expanded(child: Campo('Alto (cm)', alto, teclado: num)),
          const SizedBox(width: 8),
          Expanded(child: Campo('Ancho (cm)', ancho, teclado: num)),
          const SizedBox(width: 8),
          Expanded(child: Campo('Fondo (cm)', fondo, teclado: num)),
        ],
      ),
      Campo('Notas de la visita', notas, lineas: 3, pista: 'Contactos, desniveles, ventanas, tuberías…'),
    ]);
    if (ok != true || !mounted) return;
    final a = aNumero(alto.text), w = aNumero(ancho.text), f = aNumero(fondo.text);
    if ([a, w, f].any((v) => v != null && v <= 0)) {
      avisar(context, 'Las medidas deben ser mayores a cero.', error: true);
      return;
    }
    await conCarga(context, () async {
      await Api.actualizarPedido(p.id, {
        'alto_cm': a,
        'ancho_cm': w,
        'fondo_cm': f,
        'medidas_notas': notas.text.trim(),
        'medidas_registradas_at': DateTime.now().toUtc().toIso8601String(),
        if (['solicitado', 'cita_agendada'].contains(p.estado)) 'estado': 'en_cotizacion',
      });
    }, exito: 'Medidas guardadas');
    _recargar();
  }

  Future<void> _revisar(BuildContext c, _Detalle d) async {
    final hallazgos = CarpiIA.revisarPedido(d.pedido, fotos: d.fotos.length, cotizacion: d.cotizacion, citas: d.citas);
    await showModalBottomSheet<void>(
      context: c,
      isScrollControlled: true,
      builder: (s) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        builder: (s, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colores.iaTexto),
                SizedBox(width: 8),
                Text('CarpiIA · revisión del pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            for (final h in hallazgos)
              Aviso(
                h.texto,
                icono: h.ok ? Icons.check_circle_outline : Icons.error_outline,
                fondo: h.ok ? Colores.ia : Colores.aviso,
                colorTexto: h.ok ? Colores.iaTexto : Colores.avisoTexto,
              ),
            const Text(
              'La revisión solo detecta datos faltantes; las decisiones de fabricación son tuyas.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            BotonSecundario('Preguntar a CarpiIA', () {
              Navigator.pop(s);
              ir(c, AsistentePantalla(pedido: d.pedido));
            }, icono: Icons.chat_outlined),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(String v, Pedido p) async {
    switch (v) {
      case 'editar':
        final titulo = TextEditingController(text: p.titulo);
        final material = TextEditingController(text: p.materialAcabado);
        final desc = TextEditingController(text: p.descripcion);
        final ok = await hojaFormulario(context, 'Datos del proyecto', [
          Campo('Nombre del proyecto', titulo),
          Campo('Material y acabado', material),
          Campo('Descripción', desc, lineas: 4),
        ]);
        if (ok == true && mounted) {
          await conCarga(
            context,
            () => Api.actualizarPedido(p.id, {
              'titulo': titulo.text.trim().isEmpty ? p.titulo : titulo.text.trim(),
              'material_acabado': material.text.trim(),
              'descripcion': desc.text.trim(),
            }),
          );
          _recargar();
        }
      case 'nota':
        final nota = TextEditingController();
        final ok = await hojaFormulario(context, 'Nota para el historial', [Campo('Nota', nota, lineas: 3)]);
        if (ok == true && nota.text.trim().isNotEmpty && mounted) {
          await conCarga(context, () => Api.agregarNota(p, nota.text.trim()));
          _recargar();
        }
      case 'cancelar':
        if (await confirmar(
              context,
              'Cancelar pedido',
              'El cliente verá el pedido como cancelado.',
              si: 'Cancelar pedido',
              peligro: true,
            ) &&
            mounted) {
          await conCarga(context, () => Api.actualizarPedido(p.id, {'estado': 'cancelado'}));
          _recargar();
        }
      case 'catalogo':
        await _abrir(EditorItemCatalogo(desdePedido: p));
    }
  }
}

/// Control de estado y avance durante la fabricación.
class _BloqueAvance extends StatefulWidget {
  final Pedido pedido;
  final VoidCallback alGuardar;
  const _BloqueAvance({required this.pedido, required this.alGuardar});

  @override
  State<_BloqueAvance> createState() => _BloqueAvanceState();
}

class _BloqueAvanceState extends State<_BloqueAvance> {
  late String _estado = widget.pedido.estado == 'aceptado' ? 'en_fabricacion' : widget.pedido.estado;
  late double _progreso = widget.pedido.progreso.toDouble();
  late DateTime? _entrega = widget.pedido.fechaEntrega;
  final _nota = TextEditingController();

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.estado == 'aceptado')
            const Aviso(
              'El cliente aceptó la cotización. Marca el inicio de la fabricación para que vea el avance.',
              icono: Icons.celebration_outlined,
            ),
          const Etiqueta('Estado'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final e in ['en_fabricacion', 'por_entregar', 'entregado'])
                ChoiceChip(
                  label: Text(EstadoPedido.de(e).etiqueta),
                  selected: _estado == e,
                  onSelected: (_) => setState(() {
                    _estado = e;
                    if (e == 'entregado') _progreso = 100;
                    if (e == 'por_entregar' && _progreso < 90) _progreso = 90;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Etiqueta('Avance: ${_progreso.round()}%'),
          Slider.adaptive(
            value: _progreso,
            max: 100,
            divisions: 20,
            label: '${_progreso.round()}%',
            onChanged: (v) => setState(() => _progreso = v),
          ),
          CampoToque(
            etiqueta: 'Fecha de entrega estimada',
            texto: _entrega == null ? 'Elegir fecha' : fechaLarga(_entrega!),
            vacio: _entrega == null,
            icono: Icons.calendar_today_outlined,
            alTocar: () async {
              final f = await elegirFechaHora(context, inicial: _entrega, soloFecha: true);
              if (f != null) setState(() => _entrega = f);
            },
          ),
          Campo('Nota para el cliente (opcional)', _nota, pista: 'Ej. Ya cortamos las piezas', lineas: 2),
          BotonPrincipal('Guardar avance', () async {
            final ok = await conCarga(
              context,
              () => Api.registrarAvance(
                p.id,
                estado: _estado,
                progreso: _progreso.round(),
                entrega: _entrega,
                nota: _nota.text,
              ),
              exito: 'Avance actualizado; el cliente recibirá un aviso.',
            );
            if (ok) {
              _nota.clear();
              if (context.mounted) FocusScope.of(context).unfocus();
              widget.alGuardar();
            }
          }, icono: Icons.save_outlined),
        ],
      ),
    );
  }
}
