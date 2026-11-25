import '../../core/formato.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../modelos/modelos.dart';
import '../comunes/comunes.dart';
import '../comunes/widgets.dart';
import 'pedidos_carpintero.dart';

/// Alta o edición de un cliente. Devuelve el cliente guardado.
Future<Cliente?> formularioCliente(BuildContext c, [Cliente? existente]) async {
  final nombre = TextEditingController(text: existente?.nombre ?? '');
  final tel = TextEditingController(text: existente?.telefono ?? '');
  final correo = TextEditingController(text: existente?.correo ?? '');
  final dir = TextEditingController(text: existente?.direccion ?? '');
  final notas = TextEditingController(text: existente?.notas ?? '');
  final ok = await hojaFormulario(c, existente == null ? 'Nuevo cliente' : 'Editar cliente', [
    Campo('Nombre completo', nombre, mayusculas: TextCapitalization.words),
    Campo('Teléfono', tel, teclado: TextInputType.phone),
    Campo('Correo', correo, teclado: TextInputType.emailAddress, mayusculas: TextCapitalization.none),
    Campo('Dirección', dir),
    Campo('Notas', notas, lineas: 3, pista: 'Preferencias, referencias de la casa…'),
  ]);
  if (ok != true || !c.mounted) return null;
  if (nombre.text.trim().isEmpty) {
    avisar(c, 'Escribe el nombre del cliente.', error: true);
    return null;
  }
  Cliente? guardado;
  await conCarga(c, () async {
    guardado = await Api.guardarCliente(existente?.id, {
      'nombre': nombre.text.trim(),
      'telefono': tel.text.trim(),
      'correo': correo.text.trim(),
      'direccion': dir.text.trim(),
      'notas': notas.text.trim(),
    });
  }, exito: 'Cliente guardado');
  return guardado;
}

class ClientesPantalla extends StatefulWidget {
  final bool atras;
  const ClientesPantalla({this.atras = true, super.key});

  @override
  State<ClientesPantalla> createState() => _ClientesPantallaState();
}

class _ClientesPantallaState extends State<ClientesPantalla> {
  String _q = '';
  final _clave = GlobalKey<CargadorState<List<Cliente>>>();

  @override
  Widget build(BuildContext context) => PantallaBase(
        seccion: 'Clientes',
        titulo: 'Clientes',
        subtitulo: 'Contactos y proyectos de tu carpintería',
        atras: widget.atras,
        acciones: [
          BotonCirculo(Icons.chat_bubble_outline, () => ir(context, const ConversacionesPantalla()), ayuda: 'Mensajes'),
          const SizedBox(width: 8),
          BotonCirculo(Icons.person_add_alt, () async {
            await formularioCliente(context);
            _clave.currentState?.recargar();
          }, ayuda: 'Nuevo cliente'),
        ],
        cuerpo: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Buscador('Buscar cliente', (q) => setState(() => _q = q)),
          ),
          Expanded(
            child: Cargador<List<Cliente>>(
              key: _clave,
              cargar: Api.clientes,
              construir: (c, lista, recargar) {
                final l = _q.isEmpty
                    ? lista
                    : lista
                        .where((x) =>
                            x.nombre.toLowerCase().contains(_q) ||
                            x.telefono.contains(_q) ||
                            x.correo.toLowerCase().contains(_q))
                        .toList();
                if (l.isEmpty) {
                  return Vacio(Icons.people_outline, lista.isEmpty ? 'Aún no tienes clientes' : 'Sin resultados',
                      detalle: lista.isEmpty
                          ? 'Los clientes que te pidan cotización por la app aparecerán aquí. También puedes agregarlos tú.'
                          : null);
                }
                final cs = Theme.of(c).colorScheme;
                return RefreshIndicator.adaptive(
                  onRefresh: recargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: l.length,
                    itemBuilder: (_, i) {
                      final x = l[i];
                      return Tarjeta(
                        alTocar: () async {
                          await ir(c, ClienteDetalle(x));
                          recargar();
                        },
                        child: Row(children: [
                          Avatar(x.nombre),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(x.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(x.telefono.isNotEmpty ? x.telefono : (x.correo.isNotEmpty ? x.correo : 'Sin contacto'),
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${x.pedidos} ${x.pedidos == 1 ? 'pedido' : 'pedidos'}',
                                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            if (x.tieneCuenta)
                              Text('En la app', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          ]),
                        ]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

class ClienteDetalle extends StatefulWidget {
  final Cliente cliente;
  const ClienteDetalle(this.cliente, {super.key});

  @override
  State<ClienteDetalle> createState() => _ClienteDetalleState();
}

class _ClienteDetalleState extends State<ClienteDetalle> {
  late Cliente _c = widget.cliente;
  final _clave = GlobalKey<CargadorState<List<Pedido>>>();

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return PantallaBase(
      seccion: 'Clientes',
      acciones: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'editar') {
              final r = await formularioCliente(context, c);
              if (r != null) setState(() => _c = r);
            } else if (v == 'borrar') {
              if (await confirmar(context, 'Eliminar cliente',
                      'Se eliminará ${c.nombre} junto con sus pedidos. Esta acción no se puede deshacer.',
                      si: 'Eliminar', peligro: true) &&
                  context.mounted) {
                final ok = await conCarga(context, () => Api.borrarCliente(c.id), exito: 'Cliente eliminado');
                if (ok && context.mounted) Navigator.pop(context);
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(value: 'borrar', child: Text('Eliminar')),
          ],
        ),
      ],
      cuerpo: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Center(child: Avatar(c.nombre, radio: 36)),
        const SizedBox(height: 8),
        Center(child: Text(c.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        if (c.tieneCuenta) const Center(child: Text('Usa CarpiApp')),
        const SizedBox(height: 12),
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (c.telefono.isNotEmpty) Dato('Teléfono', c.telefono, alTocar: () => llamar(context, c.telefono)),
            if (c.correo.isNotEmpty)
              Dato('Correo', c.correo, alTocar: () => abrirEnlace(context, Uri(scheme: 'mailto', path: c.correo))),
            if (c.direccion.isNotEmpty) Dato('Dirección', c.direccion, alTocar: () => comoLlegar(context, c.direccion)),
            if (c.notas.isNotEmpty) Dato('Notas', c.notas),
            if (c.telefono.isEmpty && c.correo.isEmpty && c.direccion.isEmpty) const Text('Sin datos de contacto.'),
          ]),
        ),
        Row(children: [
          if (c.tieneCuenta)
            Expanded(
              child: BotonSecundario('Mensaje', () {
                ir(context, ChatPantalla(carpinteriaId: c.carpinteriaId, clientePerfilId: c.perfilId!, titulo: c.nombre));
              }, icono: Icons.chat_bubble_outline),
            ),
          if (c.tieneCuenta && c.telefono.isNotEmpty) const SizedBox(width: 8),
          if (c.telefono.isNotEmpty)
            Expanded(child: BotonSecundario('WhatsApp', () => whatsapp(context, c.telefono), icono: Icons.phone_outlined)),
        ]),
        Seccion('Proyectos',
            accion: TextButton.icon(
              onPressed: () async {
                final id = await nuevoPedido(context, cliente: c);
                if (id != null && context.mounted) await ir(context, PedidoDetalleCarpintero(id));
                _clave.currentState?.recargar();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo'),
            )),
        Cargador<List<Pedido>>(
          key: _clave,
          cargar: () => Api.pedidosDeCliente(c.id),
          construir: (ctx, l, recargar) => Column(children: [
            if (l.isEmpty) const Tarjeta(child: Text('Este cliente aún no tiene proyectos.')),
            for (final p in l)
              TarjetaPedido(p, mostrarCliente: false, alTocar: () async {
                await ir(ctx, PedidoDetalleCarpintero(p.id));
                recargar();
              }),
            if (l.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                    'Cliente desde ${fechaCorta(l.map((p) => p.creado).reduce((a, b) => a.isBefore(b) ? a : b))}',
                    style: const TextStyle(fontSize: 12)),
              ),
          ]),
        ),
      ]),
    );
  }
}
