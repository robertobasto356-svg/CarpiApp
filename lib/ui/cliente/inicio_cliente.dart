import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../modelos/modelos.dart';
import '../comunes/asistente.dart';
import '../comunes/comunes.dart';
import '../comunes/sensores.dart';
import '../comunes/widgets.dart';
import '../carpintero/pedidos_carpintero.dart' show TarjetaPedido;
import 'explorar.dart';
import 'pedidos_cliente.dart';
import 'solicitar.dart';

/// Navegación del cliente (mockups nuevos: Inicio · Catálogo · Pedidos · Perfil).
class ShellCliente extends StatefulWidget {
  const ShellCliente({super.key});

  @override
  State<ShellCliente> createState() => _ShellClienteState();
}

class _ShellClienteState extends State<ShellCliente> {
  int _i = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: [
          InicioCliente(alCambiarPestana: (i) => setState(() => _i = i)),
          const ExplorarPantalla(atras: false),
          const MisPedidosPantalla(atras: false),
          const PerfilPantalla(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (i) => setState(() => _i = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Catálogo'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pedidos'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      );
}

class InicioCliente extends StatefulWidget {
  final ValueChanged<int> alCambiarPestana;
  const InicioCliente({required this.alCambiarPestana, super.key});

  @override
  State<InicioCliente> createState() => _InicioClienteState();
}

class _InicioClienteState extends State<InicioCliente> {
  final _clave = GlobalKey<CargadorState<(List<Pedido>, List<ItemCatalogo>)>>();

  Future<void> _abrir(Widget w) async {
    await ir(context, w);
    _clave.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    final p = sesion.perfil!;
    final cs = Theme.of(context).colorScheme;
    return PantallaBase(
      seccion: 'Cliente',
      atras: false,
      acciones: const [Campana()],
      cuerpo: Cargador<(List<Pedido>, List<ItemCatalogo>)>(
        key: _clave,
        cargar: () async => (await Api.pedidosCliente(), await Api.catalogo()),
        construir: (c, d, recargar) {
          final activos = d.$1.where((x) => !EstadoPedido.cerrados.contains(x.estado)).toList();
          final porResponder = d.$1.where((x) => x.estado == 'cotizado').length;
          final inspiracion = d.$2.where((x) => x.imagenPath != null).take(6).toList();
          return RefreshIndicator.adaptive(
            onRefresh: recargar,
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              Saludo(p.nombre, '¡Encuentra el mueble perfecto!'),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  Mosaico(Icons.request_quote_outlined, 'Solicitar\ncotización', () => _abrir(const SolicitarPantalla())),
                  Mosaico(Icons.auto_stories_outlined, 'Catálogo', () => widget.alCambiarPestana(1)),
                  Mosaico(Icons.receipt_long_outlined, 'Mis pedidos', () => widget.alCambiarPestana(2), insignia: porResponder),
                  Mosaico(Icons.favorite_border, 'Mis favoritos', () => _abrir(const FavoritosPantalla())),
                  Mosaico(Icons.chat_bubble_outline, 'Mensajes', () => _abrir(const MensajesCliente())),
                  Mosaico(Icons.person_outline, 'Mis datos', () => _abrir(const PerfilPantalla(atras: true))),
                ],
              ),
              const SizedBox(height: 12),
              Tarjeta(
                alTocar: () => _abrir(const AsistentePantalla()),
                color: const Color(0xFFE7F2E9),
                child: const Row(children: [
                  CircleAvatar(backgroundColor: Colors.white, child: Text('✦', style: TextStyle(color: Color(0xFF1F5A3F), fontSize: 18))),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Asistente CarpiApp', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1F5A3F))),
                      Text('Pregunta por maderas y acabados o prepara tu pedido conmigo.', style: TextStyle(color: Color(0xFF1F5A3F))),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: Color(0xFF1F5A3F)),
                ]),
              ),
              if (activos.isNotEmpty) ...[
                Seccion('Tus pedidos en curso', accion: TextButton(onPressed: () => widget.alCambiarPestana(2), child: const Text('Ver todos'))),
                for (final ped in activos.take(2))
                  TarjetaPedido(ped, mostrarCliente: false, alTocar: () => _abrir(PedidoClientePantalla(ped.id))),
              ],
              const Seccion('Inspiración para tu hogar'),
              if (inspiracion.isEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => widget.alCambiarPestana(1),
                  child: Container(
                    height: 150,
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(colors: [Color(0xFF5A3825), Color(0xFFC88A4B)]),
                    ),
                    child: const Text('Diseños únicos para cada espacio',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                )
              else
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: inspiracion.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final it = inspiracion[i];
                      return GestureDetector(
                        onTap: () => _abrir(DetalleCatalogo(it)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: 240,
                            child: Stack(fit: StackFit.expand, children: [
                              ImagenStorage('catalogo', it.imagenPath!, publica: true),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  color: const Color(0xCC5A3825),
                                  child: Text(it.titulo,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Tarjeta(
                alTocar: () => _abrir(const VistaArPantalla(tipoMueble: 'Clóset')),
                child: Row(children: [
                  Icon(Icons.view_in_ar_outlined, color: cs.primary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Mira un mueble de referencia en tu espacio con realidad aumentada.')),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Mensajes del cliente con el asistente fijo arriba (mockup IA).
class MensajesCliente extends StatelessWidget {
  const MensajesCliente({super.key});

  @override
  Widget build(BuildContext context) => ConversacionesPantalla(
        fijo: Tarjeta(
          alTocar: () => ir(context, const AsistentePantalla()),
          color: const Color(0xFFE7F2E9),
          child: const Row(children: [
            CircleAvatar(backgroundColor: Colors.white, child: Text('✦', style: TextStyle(color: Color(0xFF1F5A3F)))),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Asistente CarpiApp', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Asistente IA · Información general · Mérida', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ]),
        ),
      );
}
