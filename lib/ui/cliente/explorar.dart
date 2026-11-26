import '../../core/formato.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../datos/sesion.dart';
import '../../modelos/modelos.dart';
import '../carpintero/taller.dart' show TarjetaCatalogo;
import '../comunes/comunes.dart';
import '../comunes/sensores.dart';
import '../comunes/widgets.dart';
import 'solicitar.dart';

/// Catálogo de muebles y directorio de carpinterías.
class ExplorarPantalla extends StatefulWidget {
  final bool atras;
  const ExplorarPantalla({this.atras = true, super.key});

  @override
  State<ExplorarPantalla> createState() => _ExplorarPantallaState();
}

class _ExplorarPantallaState extends State<ExplorarPantalla> {
  int _vista = 0; // 0 muebles · 1 carpinterías
  String _q = '';
  String _categoria = 'Todos';
  Set<int> _favs = {};
  final _clave = GlobalKey<CargadorState<(List<ItemCatalogo>, List<Carpinteria>)>>();

  Future<(List<ItemCatalogo>, List<Carpinteria>)> _cargar() async {
    final r = await Future.wait([Api.catalogo(), Api.carpinterias(), Api.favoritos()]);
    _favs = r[2] as Set<int>;
    return (r[0] as List<ItemCatalogo>, r[1] as List<Carpinteria>);
  }

  Future<void> _fav(ItemCatalogo it) async {
    final marcar = !_favs.contains(it.id);
    setState(() => marcar ? _favs.add(it.id) : _favs.remove(it.id));
    try {
      await Api.cambiarFavorito(it.id, marcar);
    } catch (e) {
      if (!mounted) return;
      setState(() => marcar ? _favs.remove(it.id) : _favs.add(it.id));
      avisar(context, mensajeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Cliente',
    titulo: 'Catálogo de muebles',
    subtitulo: 'Inspírate en trabajos reales y pide tu cotización',
    atras: widget.atras,
    acciones: [BotonCirculo(Icons.favorite_border, () => ir(context, const FavoritosPantalla()), ayuda: 'Favoritos')],
    cuerpo: Column(
      children: [
        Pildoras(const ['Muebles', 'Carpinterías'], _vista, (i) => setState(() => _vista = i)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Buscador(_vista == 0 ? 'Buscar mueble' : 'Buscar carpintería', (q) => setState(() => _q = q)),
        ),
        if (_vista == 0)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final cat in ['Todos', ...tiposMueble])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: _categoria == cat,
                      onSelected: (_) => setState(() => _categoria = cat),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Cargador<(List<ItemCatalogo>, List<Carpinteria>)>(
            key: _clave,
            cargar: _cargar,
            construir: (c, d, recargar) => RefreshIndicator.adaptive(
              onRefresh: recargar,
              child: _vista == 0 ? _muebles(c, d.$1) : _carpinterias(c, d.$2),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _muebles(BuildContext c, List<ItemCatalogo> todos) {
    final l = todos
        .where((x) => _categoria == 'Todos' || x.tipoMueble == _categoria)
        .where((x) => _q.isEmpty || '${x.titulo} ${x.material} ${x.carpinteriaNombre}'.toLowerCase().contains(_q))
        .toList();
    if (l.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          Vacio(
            Icons.grid_view_outlined,
            todos.isEmpty ? 'El catálogo aún está vacío' : 'Sin resultados',
            detalle: 'Puedes pedir una cotización de cualquier mueble aunque no esté en el catálogo.',
            accion: SizedBox(
              width: 240,
              child: BotonPrincipal('Solicitar cotización', () => ir(c, const SolicitarPantalla())),
            ),
          ),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .74,
      ),
      itemCount: l.length,
      itemBuilder: (_, i) {
        final it = l[i];
        final fav = _favs.contains(it.id);
        return TarjetaCatalogo(
          it,
          mostrarTaller: true,
          alTocar: () async {
            await ir(c, DetalleCatalogo(it, favorito: fav));
            _clave.currentState?.recargar();
          },
          esquina: GestureDetector(
            onTap: () => _fav(it),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Icon(
                fav ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: fav ? const Color(0xFFD22B2B) : Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _carpinterias(BuildContext c, List<Carpinteria> todas) {
    final l = todas
        .where((k) => _q.isEmpty || '${k.nombre} ${k.descripcion} ${k.direccion}'.toLowerCase().contains(_q))
        .toList();
    if (l.isEmpty) {
      return ListView(children: const [SizedBox(height: 40), Vacio(Icons.storefront_outlined, 'Sin carpinterías')]);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: l.length,
      itemBuilder: (_, i) => TarjetaCarpinteria(l[i], alTocar: () => ir(c, PerfilCarpinteria(l[i]))),
    );
  }
}

class TarjetaCarpinteria extends StatelessWidget {
  final Carpinteria k;
  final VoidCallback alTocar;
  const TarjetaCarpinteria(this.k, {required this.alTocar, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tarjeta(
      alTocar: alTocar,
      child: Row(
        children: [
          Avatar(k.nombre, radio: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (k.descripcion.isNotEmpty)
                  Text(
                    k.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE0A100)),
                    Text(
                      k.calificacion == null ? ' Nueva' : ' ${k.calificacion!.toStringAsFixed(1)} (${k.resenas})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.location_on_outlined, size: 16, color: cs.onSurfaceVariant),
                    Text(k.ciudad, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class PerfilCarpinteria extends StatelessWidget {
  final Carpinteria k;
  const PerfilCarpinteria(this.k, {super.key});

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Carpintería',
    cuerpo: Cargador<(List<ItemCatalogo>, List<Map<String, dynamic>>)>(
      cargar: () async => (await Api.catalogo(carpinteriaId: k.id), await Api.calificacionesDe(k.id)),
      construir: (c, d, _) {
        final cs = Theme.of(c).colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                Avatar(k.nombre, radio: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE0A100)),
                          Text(
                            k.calificacion == null
                                ? ' Sin reseñas aún'
                                : ' ${k.calificacion!.toStringAsFixed(1)} · ${contar(k.resenas, 'reseña')}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (k.descripcion.isNotEmpty) Text(k.descripcion),
            const SizedBox(height: 8),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (k.telefono.isNotEmpty) Dato('Teléfono', k.telefono, alTocar: () => llamar(c, k.telefono)),
                  if (k.direccion.isNotEmpty) Dato('Dirección', k.direccion, alTocar: () => comoLlegar(c, k.direccion)),
                  Dato('Ciudad', k.ciudad),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: BotonSecundario('Mensaje', () {
                    ir(c, ChatPantalla(carpinteriaId: k.id, clientePerfilId: sesion.perfil!.id, titulo: k.nombre));
                  }, icono: Icons.chat_bubble_outline),
                ),
                const SizedBox(width: 10),
                Expanded(child: BotonPrincipal('Cotizar', () => ir(c, SolicitarPantalla(carpinteria: k)))),
              ],
            ),
            const Seccion('Trabajos'),
            if (d.$1.isEmpty) const Tarjeta(child: Text('Esta carpintería aún no publica trabajos.')),
            if (d.$1.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .78,
                ),
                itemCount: d.$1.length,
                itemBuilder: (_, i) => TarjetaCatalogo(d.$1[i], alTocar: () => ir(c, DetalleCatalogo(d.$1[i]))),
              ),
            const Seccion('Opiniones'),
            if (d.$2.isEmpty) const Tarjeta(child: Text('Aún no hay opiniones.')),
            for (final o in d.$2.take(10))
              Tarjeta(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= (o['estrellas'] as int) ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 18,
                            color: const Color(0xFFE0A100),
                          ),
                        const Spacer(),
                        Text(
                          fechaCorta(DateTime.parse(o['created_at'] as String).toLocal()),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if ((o['opinion'] as String).isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text(o['opinion'] as String)),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

class DetalleCatalogo extends StatefulWidget {
  final ItemCatalogo item;
  final bool favorito;
  const DetalleCatalogo(this.item, {this.favorito = false, super.key});

  @override
  State<DetalleCatalogo> createState() => _DetalleCatalogoState();
}

class _DetalleCatalogoState extends State<DetalleCatalogo> {
  late bool _fav = widget.favorito;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final cs = Theme.of(context).colorScheme;
    return PantallaBase(
      seccion: 'Catálogo',
      acciones: [
        BotonCirculo(_fav ? Icons.favorite : Icons.favorite_border, () async {
          setState(() => _fav = !_fav);
          try {
            await Api.cambiarFavorito(it.id, _fav);
          } catch (e) {
            if (context.mounted) avisar(context, mensajeError(e), error: true);
          }
        }, ayuda: 'Favorito'),
      ],
      cuerpo: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: it.imagenPath == null
                  ? Container(
                      color: cs.primaryContainer,
                      child: Icon(iconoMueble(it.tipoMueble), size: 80, color: cs.primary),
                    )
                  : GestureDetector(
                      onTap: () => verImagen(context, 'catalogo', it.imagenPath!, publica: true),
                      child: ImagenStorage('catalogo', it.imagenPath!, publica: true),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(it.titulo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(
            it.precioDesde == null ? 'Precio a cotizar' : 'Desde ${dinero(it.precioDesde)}',
            style: TextStyle(color: cs.primary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Dato('Tipo', it.tipoMueble),
                if (it.material.isNotEmpty) Dato('Material', it.material),
                Dato('Carpintería', it.carpinteriaNombre),
                if (it.descripcion.isNotEmpty) Dato('Detalles', it.descripcion),
              ],
            ),
          ),
          const Aviso(
            'El precio es de referencia. El precio final lo define el carpintero después de medir tu espacio.',
          ),
          BotonSecundario(
            'Verlo en mi espacio (AR)',
            () => ir(context, VistaArPantalla(tipoMueble: it.tipoMueble)),
            icono: Icons.view_in_ar_outlined,
          ),
        ],
      ),
      pie: BotonPrincipal('Solicitar cotización', () async {
        final talleres = await Api.carpinterias();
        if (!context.mounted) return;
        final k = talleres.where((x) => x.id == it.carpinteriaId).firstOrNull;
        ir(context, SolicitarPantalla(carpinteria: k, catalogo: it));
      }),
    );
  }
}

class FavoritosPantalla extends StatelessWidget {
  const FavoritosPantalla({super.key});

  @override
  Widget build(BuildContext context) => PantallaBase(
    seccion: 'Cliente',
    titulo: 'Mis favoritos',
    cuerpo: Cargador<List<ItemCatalogo>>(
      cargar: () async {
        final favs = await Api.favoritos();
        final todos = await Api.catalogo();
        return todos.where((x) => favs.contains(x.id)).toList();
      },
      construir: (c, l, recargar) => l.isEmpty
          ? const Vacio(
              Icons.favorite_border,
              'Aún no tienes favoritos',
              detalle: 'Toca el corazón en el catálogo para guardar ideas.',
            )
          : RefreshIndicator.adaptive(
              onRefresh: recargar,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .74,
                ),
                itemCount: l.length,
                itemBuilder: (_, i) => TarjetaCatalogo(
                  l[i],
                  mostrarTaller: true,
                  alTocar: () async {
                    await ir(c, DetalleCatalogo(l[i], favorito: true));
                    recargar();
                  },
                ),
              ),
            ),
    ),
  );
}
