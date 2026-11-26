import '../../core/formato.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../modelos/modelos.dart';
import '../comunes/asistente.dart';
import '../comunes/comunes.dart';
import '../comunes/sensores.dart';
import '../comunes/widgets.dart';
import 'clientes_carpintero.dart';
import 'cotizaciones.dart';
import 'pedidos_carpintero.dart';
import 'taller.dart';

/// Navegación principal del carpintero (mockups nuevos: Inicio · Pedidos · Clientes · Perfil).
class ShellCarpintero extends StatefulWidget {
  const ShellCarpintero({super.key});

  @override
  State<ShellCarpintero> createState() => _ShellCarpinteroState();
}

class _ShellCarpinteroState extends State<ShellCarpintero> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    if (sesion.carpinteria == null) {
      return Scaffold(
        body: Vacio(
          Icons.storefront_outlined,
          'No encontramos tu carpintería',
          detalle: 'Cierra sesión e inicia de nuevo. Si el problema sigue, escríbenos a soporte.',
          accion: SizedBox(width: 200, child: BotonSecundario('Cerrar sesión', sesion.salir)),
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: [
          InicioCarpintero(alCambiarPestana: (i) => setState(() => _i = i)),
          const PedidosCarpintero(atras: false),
          const ClientesPantalla(atras: false),
          const PerfilPantalla(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Pedidos',
          ),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _Resumen {
  final int activos;
  final int porCotizar;
  final int visitasHoy;
  final List<Cita> proximas;
  final List<Pedido> nuevos;
  _Resumen(this.activos, this.porCotizar, this.visitasHoy, this.proximas, this.nuevos);
}

class InicioCarpintero extends StatefulWidget {
  final ValueChanged<int> alCambiarPestana;
  const InicioCarpintero({required this.alCambiarPestana, super.key});

  @override
  State<InicioCarpintero> createState() => _InicioCarpinteroState();
}

class _InicioCarpinteroState extends State<InicioCarpintero> {
  final _clave = GlobalKey<CargadorState<_Resumen>>();

  Future<_Resumen> _cargar() async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final pedidos = await Api.pedidosCarpinteria();
    final citas = await Api.citasCarpinteria(inicio, inicio.add(const Duration(days: 8)));
    final activos = pedidos.where((p) => !EstadoPedido.cerrados.contains(p.estado)).length;
    final porCotizar = pedidos.where((p) => EstadoPedido.nuevos.contains(p.estado)).toList();
    final visitasHoy = citas.where((c) => mismoDia(c.fechaHora, hoy) && c.estado != 'cancelada').length;
    final proximas = citas.where((c) => c.estado == 'confirmada' || c.estado == 'propuesta').take(3).toList();
    return _Resumen(activos, porCotizar.length, visitasHoy, proximas, porCotizar.take(3).toList());
  }

  Future<void> _abrir(Widget w) async {
    await ir(context, w);
    _clave.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = sesion.perfil!;
    final cs = Theme.of(context).colorScheme;
    return PantallaBase(
      seccion: sesion.carpinteria!.nombre,
      atras: false,
      acciones: const [Campana()],
      cuerpo: Cargador<_Resumen>(
        key: _clave,
        cargar: _cargar,
        construir: (c, r, recargar) => RefreshIndicator.adaptive(
          onRefresh: recargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Saludo(p.nombre, '¡Qué bueno verte hoy!'),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  Mosaico(
                    Icons.assignment_outlined,
                    'Pedidos',
                    () => widget.alCambiarPestana(1),
                    insignia: r.porCotizar,
                  ),
                  Mosaico(Icons.request_quote_outlined, 'Cotizaciones', () => _abrir(const CotizacionesPantalla())),
                  Mosaico(Icons.people_outline, 'Clientes', () => widget.alCambiarPestana(2)),
                  Mosaico(Icons.design_services_outlined, 'Proyectos', () => _abrir(const ProyectosPantalla())),
                  Mosaico(Icons.inventory_outlined, 'Inventario', () => _abrir(const InventarioPantalla())),
                  Mosaico(
                    Icons.forest_outlined,
                    'Materiales',
                    () => _abrir(const ProveedoresPantalla(tipo: 'materiales')),
                  ),
                  Mosaico(Icons.event_outlined, 'Programar\nvisitas', () => _abrir(const VisitasPantalla())),
                  Mosaico(
                    Icons.handyman_outlined,
                    'Herramientas',
                    () => _abrir(const ProveedoresPantalla(tipo: 'herramientas')),
                  ),
                  Mosaico(Icons.insights_outlined, 'Reportes', () => _abrir(const ReportesPantalla())),
                  Mosaico(Icons.auto_awesome_outlined, 'CarpiIA', () => _abrir(const AsistentePantalla())),
                  Mosaico(Icons.chat_bubble_outline, 'Mensajes', () => _abrir(const ConversacionesPantalla())),
                  Mosaico(Icons.photo_library_outlined, 'Mi catálogo', () => _abrir(const CatalogoCarpintero())),
                ],
              ),
              const Seccion('Resumen de hoy'),
              Tarjeta(
                child: Row(
                  children: [
                    _dato('${r.activos}', 'Pedidos', cs),
                    _dato('${r.porCotizar}', 'Por cotizar', cs),
                    _dato('${r.visitasHoy}', 'Visitas hoy', cs),
                  ],
                ),
              ),
              if (r.nuevos.isNotEmpty) ...[
                const Seccion('Solicitudes por atender'),
                for (final ped in r.nuevos) TarjetaPedido(ped, alTocar: () => _abrir(PedidoDetalleCarpintero(ped.id))),
              ],
              Seccion(
                'Próximas visitas',
                accion: TextButton(onPressed: () => _abrir(const VisitasPantalla()), child: const Text('Ver agenda')),
              ),
              if (r.proximas.isEmpty)
                const Tarjeta(child: Text('No tienes visitas en los próximos días.'))
              else
                for (final cita in r.proximas) TarjetaCita(cita, alTocar: () => _abrir(const VisitasPantalla())),
              const SizedBox(height: 8),
              Tarjeta(
                alTocar: () => _abrir(const NivelPantalla()),
                color: cs.primaryContainer.withValues(alpha: .55),
                child: Row(
                  children: [
                    Icon(Icons.straighten, color: cs.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Nivel digital: revisa si muros y pisos están a plomo y nivel con los sensores del celular.',
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dato(String n, String t, ColorScheme cs) => Expanded(
    child: Column(
      children: [
        Text(
          n,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: cs.primary),
        ),
        Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
