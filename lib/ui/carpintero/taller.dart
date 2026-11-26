import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/formato.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../modelos/modelos.dart';
import '../comunes/comunes.dart';
import '../comunes/widgets.dart';
import 'pedidos_carpintero.dart';

// =====================================================================
// Proyectos (pedidos en fabricación) con indicadores de avance
// =====================================================================
class ProyectosPantalla extends StatefulWidget {
  const ProyectosPantalla({super.key});

  @override
  State<ProyectosPantalla> createState() => _ProyectosPantallaState();
}

class _ProyectosPantallaState extends State<ProyectosPantalla> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Proyectos',
    titulo: 'Mis proyectos',
    subtitulo: 'Muebles aceptados, en fabricación y terminados',
    cuerpo: Column(
      children: [
        Pildoras(const ['Todos', 'En proceso', 'Terminados'], _tab, (i) => setState(() => _tab = i)),
        const SizedBox(height: 10),
        Expanded(
          child: Cargador<List<Pedido>>(
            cargar: () => Api.pedidosCarpinteria(estados: EstadoPedido.fabricacion),
            construir: (c, lista, recargar) {
              final l = switch (_tab) {
                1 => lista.where((p) => p.estado != 'entregado').toList(),
                2 => lista.where((p) => p.estado == 'entregado').toList(),
                _ => lista,
              };
              if (l.isEmpty) {
                return const Vacio(
                  Icons.design_services_outlined,
                  'Sin proyectos aquí',
                  detalle: 'Cuando un cliente acepte una cotización, el proyecto aparecerá en esta lista.',
                );
              }
              return RefreshIndicator.adaptive(
                onRefresh: recargar,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: l.length,
                  itemBuilder: (_, i) => TarjetaPedido(
                    l[i],
                    mostrarProgreso: true,
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

// =====================================================================
// Inventario: materiales y herramientas
// =====================================================================
class InventarioPantalla extends StatefulWidget {
  final int tab;
  const InventarioPantalla({this.tab = 0, super.key});

  @override
  State<InventarioPantalla> createState() => _InventarioPantallaState();
}

class _InventarioPantallaState extends State<InventarioPantalla> {
  late int _tab = widget.tab;
  final _clave = GlobalKey<CargadorState<List<ItemInventario>>>();
  String get _tipo => _tab == 0 ? 'material' : 'herramienta';

  Future<void> _editar([ItemInventario? it]) async {
    final nombre = TextEditingController(text: it?.nombre ?? '');
    final categoria = TextEditingController(text: it?.categoria ?? '');
    final unidad = TextEditingController(text: it?.unidad ?? (_tab == 0 ? 'hoja' : 'pza'));
    final cantidad = TextEditingController(text: it == null ? '' : numeroCorto(it.cantidad));
    final costo = TextEditingController(text: it == null ? '' : it.costoUnitario.toStringAsFixed(2));
    final minimo = TextEditingController(text: it == null ? '' : numeroCorto(it.stockMinimo));
    const n = TextInputType.numberWithOptions(decimal: true);
    final ok = await hojaFormulario(
      context,
      it == null ? (_tab == 0 ? 'Nuevo material' : 'Nueva herramienta') : 'Editar',
      [
        Campo('Nombre', nombre, pista: _tab == 0 ? 'Ej. Melamina blanca 16 mm' : 'Ej. Taladro atornillador'),
        Campo('Categoría', categoria, pista: _tab == 0 ? 'Tableros, herrajes, acabados…' : 'Eléctrica, manual…'),
        Row(
          children: [
            Expanded(child: Campo('Cantidad', cantidad, teclado: n)),
            const SizedBox(width: 8),
            Expanded(child: Campo('Unidad', unidad)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Campo('Costo unitario', costo, teclado: n, prefijo: const Icon(Icons.attach_money)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Campo('Avisar con', minimo, teclado: n, pista: 'Mínimo'),
            ),
          ],
        ),
      ],
    );
    if (ok != true || !mounted) return;
    if (nombre.text.trim().isEmpty) {
      avisar(context, 'Escribe el nombre.', error: true);
      return;
    }
    await conCarga(
      context,
      () => Api.guardarInventario(it?.id, {
        'tipo': _tipo,
        'nombre': nombre.text.trim(),
        'categoria': categoria.text.trim(),
        'unidad': unidad.text.trim().isEmpty ? 'pza' : unidad.text.trim(),
        'cantidad': math.max(0, aNumero(cantidad.text) ?? 0),
        'costo_unitario': math.max(0, aNumero(costo.text) ?? 0),
        'stock_minimo': math.max(0, aNumero(minimo.text) ?? 0),
      }),
    );
    _clave.currentState?.recargar();
  }

  Future<void> _ajustar(ItemInventario it, double delta) async {
    final nueva = math.max(0.0, it.cantidad + delta);
    try {
      await Api.guardarInventario(it.id, {'cantidad': nueva});
      _clave.currentState?.recargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Inventario',
    titulo: 'Inventario',
    subtitulo: 'Lo que tienes en el taller',
    acciones: [BotonCirculo(Icons.add, _editar, ayuda: 'Agregar')],
    cuerpo: Column(
      children: [
        Pildoras(const ['Materiales', 'Herramientas'], _tab, (i) {
          setState(() => _tab = i);
          _clave.currentState?.recargar();
        }),
        const SizedBox(height: 10),
        Expanded(
          child: Cargador<List<ItemInventario>>(
            key: _clave,
            cargar: () => Api.inventario(_tipo),
            construir: (c, l, recargar) {
              final cs = Theme.of(c).colorScheme;
              final bajos = l.where((x) => x.bajo).length;
              final valor = l.fold<double>(0, (s, x) => s + x.cantidad * x.costoUnitario);
              return RefreshIndicator.adaptive(
                onRefresh: recargar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (l.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${contar(l.length, 'registro')} · valor aproximado ${dinero(valor)}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    if (bajos > 0)
                      Aviso.alerta('$bajos ${bajos == 1 ? 'artículo está' : 'artículos están'} por agotarse.'),
                    if (l.isEmpty)
                      Vacio(
                        Icons.inventory_outlined,
                        _tab == 0 ? 'Sin materiales registrados' : 'Sin herramientas registradas',
                        accion: SizedBox(width: 200, child: BotonSecundario('Agregar', _editar, icono: Icons.add)),
                      ),
                    for (final it in l)
                      Tarjeta(
                        alTocar: () => _editar(it),
                        relleno: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    [
                                      cantidadCon(it.cantidad, it.unidad),
                                      if (it.costoUnitario > 0) '${dinero(it.costoUnitario)}/${it.unidad}',
                                      if (it.categoria.isNotEmpty) it.categoria,
                                    ].join(' · '),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: it.bajo ? const Color(0xFFC77700) : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: it.cantidad > 0 ? () => _ajustar(it, -1) : null,
                            ),
                            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _ajustar(it, 1)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFD22B2B)),
                              onPressed: () async {
                                if (await confirmar(
                                      c,
                                      'Eliminar',
                                      '¿Eliminar ${it.nombre}?',
                                      si: 'Eliminar',
                                      peligro: true,
                                    ) &&
                                    c.mounted) {
                                  await conCarga(c, () => Api.borrarInventario(it.id));
                                  recargar();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    BotonSecundario(
                      _tab == 0 ? 'Ver proveedores de materiales' : 'Ver proveedores de herramientas',
                      () => ir(c, ProveedoresPantalla(tipo: _tab == 0 ? 'materiales' : 'herramientas')),
                      icono: Icons.storefront_outlined,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

// =====================================================================
// Proveedores (mockups nuevos: Materiales | Herramientas)
// =====================================================================
class ProveedoresPantalla extends StatefulWidget {
  final String tipo;
  const ProveedoresPantalla({required this.tipo, super.key});

  @override
  State<ProveedoresPantalla> createState() => _ProveedoresPantallaState();
}

class _ProveedoresPantallaState extends State<ProveedoresPantalla> {
  late int _tab = widget.tipo == 'materiales' ? 0 : 1;
  String _q = '';
  final _clave = GlobalKey<CargadorState<List<Proveedor>>>();
  String get _tipo => _tab == 0 ? 'materiales' : 'herramientas';

  Future<void> _editar([Proveedor? p]) async {
    final nombre = TextEditingController(text: p?.nombre ?? '');
    final desc = TextEditingController(text: p?.descripcion ?? '');
    final tel = TextEditingController(text: p?.telefono ?? '');
    final wa = TextEditingController(text: p?.whatsapp ?? '');
    final web = TextEditingController(text: p?.sitioWeb ?? '');
    final dir = TextEditingController(text: p?.direccion ?? '');
    final horario = TextEditingController(text: p?.horario ?? '');
    final ok = await hojaFormulario(context, p == null ? 'Nuevo proveedor' : 'Editar proveedor', [
      Campo('Nombre', nombre, mayusculas: TextCapitalization.words),
      Campo('Qué ofrece', desc, lineas: 2),
      Row(
        children: [
          Expanded(child: Campo('Teléfono', tel, teclado: TextInputType.phone)),
          const SizedBox(width: 8),
          Expanded(child: Campo('WhatsApp', wa, teclado: TextInputType.phone)),
        ],
      ),
      Campo('Sitio web', web, teclado: TextInputType.url, mayusculas: TextCapitalization.none),
      Campo('Dirección', dir),
      Campo('Horario', horario, pista: 'Lun–vie 8:00–18:00'),
    ]);
    if (ok != true || !mounted) return;
    if (nombre.text.trim().isEmpty) {
      avisar(context, 'Escribe el nombre del proveedor.', error: true);
      return;
    }
    await conCarga(
      context,
      () => Api.guardarProveedor(p?.id, {
        'tipo': _tipo,
        'nombre': nombre.text.trim(),
        'descripcion': desc.text.trim(),
        'telefono': tel.text.trim(),
        'whatsapp': wa.text.trim(),
        'sitio_web': web.text.trim(),
        'direccion': dir.text.trim(),
        'horario': horario.text.trim(),
      }),
      exito: 'Proveedor guardado',
    );
    _clave.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Inventario',
    titulo: _tab == 0 ? 'Materiales' : 'Herramientas',
    subtitulo: _tab == 0 ? 'Proveedores para tus proyectos' : 'Proveedores para tu taller',
    acciones: [BotonCirculo(Icons.add, _editar, ayuda: 'Agregar proveedor')],
    cuerpo: Column(
      children: [
        Pildoras(const ['Materiales', 'Herramientas'], _tab, (i) {
          setState(() => _tab = i);
          _clave.currentState?.recargar();
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Buscador('Buscar proveedor', (q) => setState(() => _q = q)),
        ),
        Expanded(
          child: Cargador<List<Proveedor>>(
            key: _clave,
            cargar: () => Api.proveedores(_tipo),
            construir: (c, lista, recargar) {
              final l = _q.isEmpty
                  ? lista
                  : lista
                        .where((p) => '${p.nombre} ${p.descripcion} ${p.direccion}'.toLowerCase().contains(_q))
                        .toList();
              if (l.isEmpty) return const Vacio(Icons.storefront_outlined, 'Sin proveedores');
              return RefreshIndicator.adaptive(
                onRefresh: recargar,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: l.length,
                  itemBuilder: (_, i) => TarjetaProveedor(
                    l[i],
                    alEditar: l[i].esPropio ? () => _editar(l[i]) : null,
                    alBorrar: l[i].esPropio
                        ? () async {
                            if (await confirmar(
                                  c,
                                  'Eliminar proveedor',
                                  '¿Eliminar ${l[i].nombre}?',
                                  si: 'Eliminar',
                                  peligro: true,
                                ) &&
                                c.mounted) {
                              await conCarga(c, () => Api.borrarProveedor(l[i].id));
                              recargar();
                            }
                          }
                        : null,
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

class TarjetaProveedor extends StatelessWidget {
  final Proveedor p;
  final VoidCallback? alEditar;
  final VoidCallback? alBorrar;
  const TarjetaProveedor(this.p, {this.alEditar, this.alBorrar, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  p.tipo == 'materiales' ? Icons.forest_outlined : Icons.handyman_outlined,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text(p.descripcion, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              ),
              if (alEditar != null)
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'e' ? alEditar!() : alBorrar?.call(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'e', child: Text('Editar')),
                    PopupMenuItem(value: 'b', child: Text('Eliminar')),
                  ],
                ),
            ],
          ),
          const Divider(height: 20),
          if (p.telefono.isNotEmpty) Dato('Teléfono', p.telefono, alTocar: () => llamar(context, p.telefono)),
          if (p.whatsapp.isNotEmpty) Dato('WhatsApp', p.whatsapp, alTocar: () => whatsapp(context, p.whatsapp)),
          if (p.correo.isNotEmpty)
            Dato(
              'Correo',
              p.correo,
              alTocar: () => abrirEnlace(context, Uri(scheme: 'mailto', path: p.correo)),
            ),
          if (p.sitioWeb.isNotEmpty) Dato('Sitio web', p.sitioWeb, alTocar: () => abrirWeb(context, p.sitioWeb)),
          if (p.direccion.isNotEmpty) Dato('Dirección', p.direccion),
          if (p.horario.isNotEmpty) Dato('Horario', p.horario),
          if (p.direccion.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => comoLlegar(context, p.direccion), child: const Text('Cómo llegar ›')),
            ),
          if (!p.esPropio)
            Text(
              'Directorio CarpiApp · confirma existencias y precios con el proveedor',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// Visitas (calendario)
// =====================================================================
class VisitasPantalla extends StatefulWidget {
  const VisitasPantalla({super.key});

  @override
  State<VisitasPantalla> createState() => _VisitasPantallaState();
}

class _VisitasPantallaState extends State<VisitasPantalla> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _dia = DateTime.now();
  final _clave = GlobalKey<CargadorState<List<Cita>>>();

  Future<List<Cita>> _cargar() =>
      Api.citasCarpinteria(_mes.subtract(const Duration(days: 7)), DateTime(_mes.year, _mes.month + 1, 8));

  void _cambiarMes(int d) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + d));
    _clave.currentState?.recargar();
  }

  Future<void> _nueva() async {
    final clientes = await Api.clientes();
    if (!mounted) return;
    Cliente? cliente;
    final motivo = TextEditingController(text: 'Toma de medidas');
    final dir = TextEditingController();
    var fecha = DateTime(_dia.year, _dia.month, _dia.day, 10);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(d).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Programar visita', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Seleccion<Cliente>(
                  etiqueta: 'Cliente',
                  valor: cliente,
                  opciones: clientes,
                  texto: (x) => x.nombre,
                  pista: 'Opcional',
                  alCambiar: (v) => set(() {
                    cliente = v;
                    if (dir.text.isEmpty && v != null) dir.text = v.direccion;
                  }),
                ),
                Campo('Motivo', motivo),
                CampoToque(
                  etiqueta: 'Fecha y hora',
                  texto: fechaHora(fecha),
                  icono: Icons.schedule,
                  alTocar: () async {
                    final f = await elegirFechaHora(d, inicial: fecha);
                    if (f != null) set(() => fecha = f);
                  },
                ),
                Campo('Dirección', dir),
                BotonPrincipal('Guardar visita', () => Navigator.pop(d, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await conCarga(
      context,
      () => Api.crearCita(
        clienteId: cliente?.id,
        fechaHora: fecha,
        motivo: motivo.text.trim(),
        direccion: dir.text.trim(),
      ),
      exito: 'Visita programada',
    );
    setState(() => _dia = fecha);
    _clave.currentState?.recargar();
  }

  Widget _calendario(List<Cita> citas) {
    final cs = Theme.of(context).colorScheme;
    final primero = DateTime(_mes.year, _mes.month, 1);
    final dias = DateTime(_mes.year, _mes.month + 1, 0).day;
    final offset = (primero.weekday + 6) % 7;
    final hoy = DateTime.now();
    return Tarjeta(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _cambiarMes(-1)),
              Expanded(
                child: Text(
                  mesAnio(_mes),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _cambiarMes(1)),
            ],
          ),
          Row(
            children: [
              for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(d, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < offset; i++) const SizedBox(),
              for (var n = 1; n <= dias; n++)
                Builder(
                  builder: (_) {
                    final fecha = DateTime(_mes.year, _mes.month, n);
                    final sel = mismoDia(fecha, _dia);
                    final delDia = citas.where((c) => mismoDia(c.fechaHora, fecha) && c.estado != 'cancelada');
                    final propuesta = delDia.any((c) => c.estado == 'propuesta');
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _dia = fecha),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: sel ? cs.primary : null, shape: BoxShape.circle),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$n',
                              style: TextStyle(
                                color: sel ? Colors.white : cs.onSurface,
                                fontWeight: mismoDia(fecha, hoy) ? FontWeight.w900 : FontWeight.w500,
                              ),
                            ),
                            if (delDia.isNotEmpty)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: sel ? Colors.white : (propuesta ? const Color(0xFFC77700) : cs.primary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Visitas',
    titulo: 'Mis visitas',
    subtitulo: 'Citas para medir, revisar e instalar',
    acciones: [BotonCirculo(Icons.add, _nueva, ayuda: 'Programar visita')],
    cuerpo: Cargador<List<Cita>>(
      key: _clave,
      cargar: _cargar,
      construir: (c, citas, recargar) {
        final delDia = citas.where((x) => mismoDia(x.fechaHora, _dia)).toList();
        final propuestas = citas.where((x) => x.estado == 'propuesta').toList();
        return RefreshIndicator.adaptive(
          onRefresh: recargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _calendario(citas),
              if (propuestas.isNotEmpty)
                Aviso.alerta(
                  '${propuestas.length} ${propuestas.length == 1 ? 'cita propuesta' : 'citas propuestas'} por clientes. Confírmalas desde el pedido.',
                  icono: Icons.event_available_outlined,
                ),
              Seccion(diaLargo(_dia)),
              if (delDia.isEmpty) const Tarjeta(child: Text('Sin visitas este día.')),
              for (final cita in delDia)
                TarjetaCita(
                  cita,
                  alTocar: cita.pedidoId == null
                      ? null
                      : () async {
                          await ir(c, PedidoDetalleCarpintero(cita.pedidoId!));
                          recargar();
                        },
                  acciones: Wrap(
                    spacing: 8,
                    children: [
                      if (cita.direccion.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => comoLlegar(c, cita.direccion),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Cómo llegar'),
                        ),
                      if (cita.estado == 'confirmada' || cita.estado == 'propuesta')
                        TextButton(
                          onPressed: () async {
                            await conCarga(c, () => Api.actualizarCita(cita.id, {'estado': 'realizada'}));
                            recargar();
                          },
                          child: const Text('Marcar realizada'),
                        ),
                      if (cita.pedidoId == null)
                        TextButton(
                          onPressed: () async {
                            if (await confirmar(
                                  c,
                                  'Eliminar visita',
                                  '¿Eliminar esta visita?',
                                  si: 'Eliminar',
                                  peligro: true,
                                ) &&
                                c.mounted) {
                              await conCarga(c, () => Api.borrarCita(cita.id));
                              recargar();
                            }
                          },
                          child: const Text('Eliminar'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

// =====================================================================
// Reportes y finanzas
// =====================================================================
class _Reporte {
  final double ingresos;
  final double porCobrar;
  final double gastos;
  final int completados;
  final int enviadas;
  final int enProceso;
  final int visitas;
  final List<Gasto> listaGastos;
  final Map<DateTime, (double, double)> porMes;
  _Reporte(
    this.ingresos,
    this.porCobrar,
    this.gastos,
    this.completados,
    this.enviadas,
    this.enProceso,
    this.visitas,
    this.listaGastos,
    this.porMes,
  );
}

class ReportesPantalla extends StatefulWidget {
  const ReportesPantalla({super.key});

  @override
  State<ReportesPantalla> createState() => _ReportesPantallaState();
}

class _ReportesPantallaState extends State<ReportesPantalla> {
  int _periodo = 0; // 0 mes · 1 año · 2 todo
  final _clave = GlobalKey<CargadorState<_Reporte>>();

  DateTime? get _desde {
    final n = DateTime.now();
    return switch (_periodo) {
      0 => DateTime(n.year, n.month),
      1 => DateTime(n.year),
      _ => null,
    };
  }

  Future<_Reporte> _cargar() async {
    final desde = _desde;
    bool enPeriodo(DateTime d) => desde == null || !d.isBefore(desde);
    final cots = await Api.cotizacionesCarpinteria();
    final pedidos = await Api.pedidosCarpinteria();
    final n = DateTime.now();
    final seisMeses = DateTime(n.year, n.month - 5);
    final gastos = await Api.gastos(desde == null ? null : (desde.isBefore(seisMeses) ? desde : seisMeses));
    final citas = await Api.citasCarpinteria(desde ?? DateTime(2020), n);

    double ingresos = 0, porCobrar = 0;
    final porMes = <DateTime, (double, double)>{for (var i = 5; i >= 0; i--) DateTime(n.year, n.month - i): (0.0, 0.0)};
    for (final q in cots.where((q) => q.estado == 'aceptada')) {
      final p = q.pedido;
      if (p == null) continue;
      if (p.estado == 'entregado') {
        final cuando = p.actualizado;
        if (enPeriodo(cuando)) ingresos += q.total;
        final m = DateTime(cuando.year, cuando.month);
        if (porMes.containsKey(m)) porMes[m] = (porMes[m]!.$1 + q.total, porMes[m]!.$2);
      } else if (p.estado != 'cancelado') {
        porCobrar += q.total;
      }
    }
    for (final g in gastos) {
      final m = DateTime(g.fecha.year, g.fecha.month);
      if (porMes.containsKey(m)) porMes[m] = (porMes[m]!.$1, porMes[m]!.$2 + g.monto);
    }
    final gastosPeriodo = gastos.where((g) => enPeriodo(g.fecha)).toList();
    return _Reporte(
      ingresos,
      porCobrar,
      gastosPeriodo.fold(0, (s, g) => s + g.monto),
      pedidos.where((p) => p.estado == 'entregado' && enPeriodo(p.actualizado)).length,
      cots.where((q) => q.enviadaAt != null && enPeriodo(q.enviadaAt!)).length,
      pedidos.where((p) => EstadoPedido.enProceso.contains(p.estado)).length,
      citas.where((c) => c.estado == 'realizada').length,
      gastosPeriodo,
      porMes,
    );
  }

  Future<void> _nuevoGasto() async {
    final concepto = TextEditingController();
    final monto = TextEditingController();
    var categoria = 'Materiales';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(d).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Registrar gasto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Campo('Concepto', concepto, pista: 'Ej. Compra de MDF'),
              Seleccion<String>(
                etiqueta: 'Categoría',
                valor: categoria,
                opciones: const ['Materiales', 'Herramientas', 'Transporte', 'Renta y servicios', 'Sueldos', 'Otro'],
                texto: (x) => x,
                alCambiar: (v) => set(() => categoria = v ?? categoria),
              ),
              Campo(
                'Monto',
                monto,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                prefijo: const Icon(Icons.attach_money),
              ),
              BotonPrincipal('Agregar', () => Navigator.pop(d, true)),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final m = aNumero(monto.text) ?? 0;
    if (concepto.text.trim().isEmpty || m <= 0) {
      avisar(context, 'Escribe el concepto y un monto mayor a cero.', error: true);
      return;
    }
    await conCarga(context, () => Api.agregarGasto(concepto.text.trim(), categoria, m, DateTime.now()));
    _clave.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Reportes',
    titulo: 'Reportes y finanzas',
    subtitulo: 'Solo tú ves esta información',
    acciones: [BotonCirculo(Icons.add, _nuevoGasto, ayuda: 'Registrar gasto')],
    cuerpo: Column(
      children: [
        Pildoras(const ['Este mes', 'Este año', 'Todo'], _periodo, (i) {
          setState(() => _periodo = i);
          _clave.currentState?.recargar();
        }),
        const SizedBox(height: 10),
        Expanded(
          child: Cargador<_Reporte>(
            key: _clave,
            cargar: _cargar,
            construir: (c, r, recargar) {
              final cs = Theme.of(c).colorScheme;
              Widget kpi(String t, double v, Color col) => Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: col.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t,
                        style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(dineroCorto(v), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              );
              Widget linea(IconData i, String t, int n) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(i, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t)),
                    Text('$n', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              );
              final ganancia = r.ingresos - r.gastos;
              final maximo = r.porMes.values.fold<double>(1, (m, v) => math.max(m, math.max(v.$1, v.$2)));
              return RefreshIndicator.adaptive(
                onRefresh: recargar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Row(
                      children: [
                        kpi('Ingresos', r.ingresos, const Color(0xFF2E7D4F)),
                        const SizedBox(width: 10),
                        kpi('Gastos', r.gastos, const Color(0xFFD22B2B)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        kpi('Ganancia', ganancia, ganancia >= 0 ? const Color(0xFF2E7D4F) : const Color(0xFFD22B2B)),
                        const SizedBox(width: 10),
                        kpi('Por cobrar', r.porCobrar, const Color(0xFF2F6FDB)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ingresos = cotizaciones aceptadas de pedidos entregados. Por cobrar = aceptadas aún en proceso.',
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                    const Seccion('Últimos 6 meses'),
                    Tarjeta(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 140,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final e in r.porMes.entries)
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            _barra(e.value.$1 / maximo, const Color(0xFF2E7D4F)),
                                            const SizedBox(width: 3),
                                            _barra(e.value.$2 / maximo, const Color(0xFFD22B2B)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(mesAnio(e.key).substring(0, 3), style: const TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.square, size: 12, color: Color(0xFF2E7D4F)),
                              Text(' Ingresos   '),
                              Icon(Icons.square, size: 12, color: Color(0xFFD22B2B)),
                              Text(' Gastos'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Seccion('Actividad'),
                    Tarjeta(
                      child: Column(
                        children: [
                          linea(Icons.check_circle_outline, 'Pedidos completados', r.completados),
                          linea(Icons.request_quote_outlined, 'Cotizaciones enviadas', r.enviadas),
                          linea(Icons.design_services_outlined, 'Proyectos en proceso', r.enProceso),
                          linea(Icons.location_on_outlined, 'Visitas realizadas', r.visitas),
                        ],
                      ),
                    ),
                    Seccion(
                      'Gastos registrados',
                      accion: TextButton.icon(
                        onPressed: _nuevoGasto,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar'),
                      ),
                    ),
                    if (r.listaGastos.isEmpty) const Tarjeta(child: Text('Sin gastos en este periodo.')),
                    for (final g in r.listaGastos)
                      Tarjeta(
                        relleno: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.concepto, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${g.categoria} · ${fechaCorta(g.fecha)}',
                                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Text(dinero(g.monto), style: const TextStyle(fontWeight: FontWeight.w700)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                if (await confirmar(
                                      c,
                                      'Eliminar gasto',
                                      '¿Eliminar "${g.concepto}"?',
                                      si: 'Eliminar',
                                      peligro: true,
                                    ) &&
                                    c.mounted) {
                                  await conCarga(c, () => Api.borrarGasto(g.id));
                                  recargar();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _barra(double v, Color c) => Container(
    width: 12,
    height: math.max(3, 110 * v.clamp(0, 1)),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
  );
}

// =====================================================================
// Catálogo de la carpintería
// =====================================================================
class CatalogoCarpintero extends StatefulWidget {
  const CatalogoCarpintero({super.key});

  @override
  State<CatalogoCarpintero> createState() => _CatalogoCarpinteroState();
}

class _CatalogoCarpinteroState extends State<CatalogoCarpintero> {
  final _clave = GlobalKey<CargadorState<List<ItemCatalogo>>>();

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Catálogo',
    titulo: 'Mi catálogo',
    subtitulo: 'Trabajos que ven los clientes para inspirarse y cotizar',
    acciones: [
      BotonCirculo(Icons.add, () async {
        await ir(context, const EditorItemCatalogo());
        _clave.currentState?.recargar();
      }, ayuda: 'Agregar trabajo'),
    ],
    cuerpo: Cargador<List<ItemCatalogo>>(
      key: _clave,
      cargar: () => Api.catalogo(carpinteriaId: sesionCarpinteriaId(), soloPublicados: false),
      construir: (c, l, recargar) => l.isEmpty
          ? Vacio(
              Icons.photo_library_outlined,
              'Tu catálogo está vacío',
              detalle: 'Sube fotos de tus mejores trabajos con un precio de referencia.',
              accion: SizedBox(
                width: 220,
                child: BotonSecundario('Agregar trabajo', () async {
                  await ir(c, const EditorItemCatalogo());
                  recargar();
                }, icono: Icons.add),
              ),
            )
          : RefreshIndicator.adaptive(
              onRefresh: recargar,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .78,
                ),
                itemCount: l.length,
                itemBuilder: (_, i) => TarjetaCatalogo(
                  l[i],
                  alTocar: () async {
                    await ir(c, EditorItemCatalogo(item: l[i]));
                    recargar();
                  },
                ),
              ),
            ),
    ),
  );
}

String sesionCarpinteriaId() => Api.miCarpinteriaId;

class TarjetaCatalogo extends StatelessWidget {
  final ItemCatalogo item;
  final VoidCallback alTocar;
  final Widget? esquina;
  final bool mostrarTaller;
  const TarjetaCatalogo(this.item, {required this.alTocar, this.esquina, this.mostrarTaller = false, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imagenPath == null
                      ? Container(
                          color: cs.primaryContainer,
                          child: Icon(iconoMueble(item.tipoMueble), size: 48, color: cs.primary),
                        )
                      : ImagenStorage('catalogo', item.imagenPath!, publica: true),
                  if (!item.publicado) Positioned(left: 8, top: 8, child: ChipEstado('Oculto', Colors.grey.shade700)),
                  if (esquina != null) Positioned(right: 6, top: 6, child: esquina!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (mostrarTaller && item.carpinteriaNombre.isNotEmpty)
                    Text(
                      item.carpinteriaNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                  Text(
                    item.precioDesde == null ? 'Precio a cotizar' : 'Desde ${dineroCorto(item.precioDesde)}',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditorItemCatalogo extends StatefulWidget {
  final ItemCatalogo? item;
  final Pedido? desdePedido;
  const EditorItemCatalogo({this.item, this.desdePedido, super.key});

  @override
  State<EditorItemCatalogo> createState() => _EditorItemCatalogoState();
}

class _EditorItemCatalogoState extends State<EditorItemCatalogo> {
  late final _titulo = TextEditingController(text: widget.item?.titulo ?? widget.desdePedido?.titulo ?? '');
  late final _material = TextEditingController(
    text: widget.item?.material ?? widget.desdePedido?.materialAcabado ?? '',
  );
  late final _desc = TextEditingController(text: widget.item?.descripcion ?? widget.desdePedido?.descripcion ?? '');
  late final _precio = TextEditingController(
    text: widget.item?.precioDesde == null ? '' : widget.item!.precioDesde!.toStringAsFixed(0),
  );
  late String _tipo = widget.item?.tipoMueble ?? widget.desdePedido?.tipoMueble ?? tiposMueble.first;
  late bool _publicado = widget.item?.publicado ?? true;
  Uint8List? _foto;
  bool _guardando = false;
  late final String _inicial;

  String _firma() => [_titulo.text, _material.text, _desc.text, _precio.text, _tipo, _publicado].join('§');

  @override
  void initState() {
    super.initState();
    _inicial = _firma();
  }

  @override
  void dispose() {
    for (final c in [_titulo, _material, _desc, _precio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_titulo.text.trim().isEmpty) {
      avisar(context, 'Escribe el nombre del trabajo.', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      var ruta = widget.item?.imagenPath;
      if (_foto != null) ruta = await Api.subirImagenCatalogo(_foto!);
      await Api.guardarItemCatalogo(widget.item, {
        'titulo': _titulo.text.trim(),
        'tipo_mueble': _tipo,
        'material': _material.text.trim(),
        'descripcion': _desc.text.trim(),
        'precio_desde': aNumero(_precio.text),
        'imagen_path': ruta,
        'publicado': _publicado,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SinPerderCambios(
      hayCambios: () => _foto != null || _firma() != _inicial,
      child: PantallaBase(
        seccion: 'Catálogo',
        titulo: widget.item == null ? 'Nuevo trabajo' : 'Editar trabajo',
        acciones: [
          if (widget.item != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmar(
                      context,
                      'Eliminar',
                      '¿Quitar este trabajo del catálogo?',
                      si: 'Eliminar',
                      peligro: true,
                    ) &&
                    context.mounted) {
                  final ok = await conCarga(context, () => Api.borrarItemCatalogo(widget.item!));
                  if (ok && context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
        cuerpo: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            GestureDetector(
              onTap: () async {
                final f = await tomarFoto(context);
                if (f != null) setState(() => _foto = f);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _foto != null
                      ? Image.memory(_foto!, fit: BoxFit.cover)
                      : widget.item?.imagenPath != null
                      ? ImagenStorage('catalogo', widget.item!.imagenPath!, publica: true)
                      : Container(
                          color: cs.primaryContainer,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: cs.primary, size: 40),
                              const SizedBox(height: 6),
                              Text(
                                'Agregar foto',
                                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Campo('Nombre del trabajo', _titulo, pista: 'Ej. Clóset de cedro con puertas corredizas'),
            Seleccion<String>(
              etiqueta: 'Tipo de mueble',
              valor: tiposMueble.contains(_tipo) ? _tipo : 'Otro',
              opciones: tiposMueble,
              texto: (x) => x,
              alCambiar: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            Campo('Material y acabado', _material),
            Campo('Descripción', _desc, lineas: 3),
            Campo(
              'Precio de referencia (desde)',
              _precio,
              teclado: TextInputType.number,
              prefijo: const Icon(Icons.attach_money),
              pista: 'Opcional',
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _publicado,
              title: const Text('Visible para los clientes'),
              onChanged: (v) => setState(() => _publicado = v),
            ),
          ],
        ),
        pie: BotonPrincipal('Guardar', _guardar, cargando: _guardando),
      ),
    );
  }
}
