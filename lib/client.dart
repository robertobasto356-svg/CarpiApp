import 'package:flutter/material.dart';
import 'state.dart';
import 'widgets.dart';
import 'main.dart' show ProfileScreen;

void _go(BuildContext c, Widget w) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));

// ======================= INICIO =======================
class KHome extends StatelessWidget {
  const KHome({super.key});

  @override
  Widget build(BuildContext context) => Obs((c) => Scaffold(
        appBar: AppBar(
            title: const Text('CARPIAPP',
                style: TextStyle(color: green, fontWeight: FontWeight.w800))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Greeting('Hola, ${firstName(app.me!.name)} ☀️', '¡Encuentra el mueble perfecto!', green),
          MenuGrid([
            MenuTile(Icons.request_quote_outlined, 'Solicitar\ncotización', () => _go(c, const RequestScreen()), green),
            MenuTile(Icons.grid_view_outlined, 'Catálogo', () => _go(c, const CatalogScreen()), green),
            MenuTile(Icons.inventory_2_outlined, 'Mis pedidos', () => _go(c, const MyOrdersScreen()), green),
            MenuTile(Icons.favorite_border, 'Mis favoritos', () => _go(c, const FavsScreen()), green),
            MenuTile(Icons.chat_bubble_outline, 'Mensajes',
                () => _go(c, ChatScreen(clientEmail: app.me!.email, title: 'Mensajes')), green),
            MenuTile(Icons.person_outline, 'Mis datos', () => _go(c, const ProfileScreen()), green),
          ]),
          const SizedBox(height: 16),
          const Text('Inspiración para tu hogar', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _go(c, const CatalogScreen()),
            child: Container(
              height: 140,
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [brown, Color(0xFFB07A4F)]),
              ),
              child: const Text('Diseños únicos para cada espacio',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ));
}

// ======================= CATÁLOGO =======================
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends State<CatalogScreen> {
  String q = '';
  int cat = 0;

  void detail(BuildContext c, Job j) => showDialog(
        context: c,
        builder: (d) => AlertDialog(
          title: Text(j.title),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Desde ${money(j.price!)}', style: const TextStyle(color: green, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Tipo: ${j.type}'),
            if (j.material.isNotEmpty) Text('Material: ${j.material}'),
            if (j.desc.isNotEmpty) Text(j.desc),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cerrar')),
            TextButton(
              onPressed: () {
                Navigator.pop(d);
                _go(c, RequestScreen(type: j.type));
              },
              child: const Text('Solicitar cotización'),
            ),
          ],
        ),
      );

  Widget card(BuildContext c, Job j) {
    final fav = app.myFavs.contains(j.id);
    return GestureDetector(
      onTap: () => detail(c, j),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: sand, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: Icon(typeIcon(j.type), size: 48, color: brown),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  onTap: () {
                    fav ? app.myFavs.remove(j.id) : app.myFavs.add(j.id);
                    app.update();
                  },
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(fav ? Icons.favorite : Icons.favorite_border,
                        size: 16, color: fav ? Colors.red : Colors.grey),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              Text('Desde ${money(j.price!)}',
                  style: const TextStyle(fontSize: 11, color: green, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Obs((c) {
        final cats = ['Todos', ...furnitureTypes];
        final list = app.catalog
            .where((j) => (cat == 0 || j.type == cats[cat]) && j.title.toLowerCase().contains(q))
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Catálogo de muebles')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                onChanged: (v) => setState(() => q = v.toLowerCase().trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Tabs(cats, cat, (v) => setState(() => cat = v)),
              const SizedBox(height: 10),
              Expanded(
                child: list.isEmpty
                    ? const Empty(Icons.grid_view_outlined, 'Aún no hay muebles en el catálogo')
                    : GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: .9,
                        children: [for (final j in list) card(c, j)],
                      ),
              ),
            ]),
          ),
        );
      });
}

// ======================= SOLICITAR COTIZACIÓN =======================
class RequestScreen extends StatefulWidget {
  final String type;
  const RequestScreen({this.type = '', super.key});
  @override
  State<RequestScreen> createState() => _RequestState();
}

class _RequestState extends State<RequestScreen> {
  late String type = widget.type.isEmpty ? furnitureTypes.first : widget.type;
  String material = materials.first;
  int images = 0;
  final w = TextEditingController(),
      h = TextEditingController(),
      d = TextEditingController(),
      color = TextEditingController(),
      desc = TextEditingController();

  Widget drop(String label, String value, List<String> opts, ValueChanged<String> on) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(filled: true, fillColor: Colors.white, isDense: true, border: InputBorder.none),
            items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (v) => on(v ?? value),
          ),
        ]),
      );

  void send() {
    final me = app.me!;
    app.addJob(Job(
      id: app.nextId(),
      title: type,
      type: type,
      clientEmail: me.email,
      clientName: me.name,
      material: material,
      color: color.text.trim(),
      desc: desc.text.trim(),
      w: w.text.trim(),
      h: h.text.trim(),
      d: d.text.trim(),
      images: images,
    ));
    snack(context, 'Solicitud enviada. El carpintero te responderá con el precio.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Solicitar cotización')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          drop('Tipo de mueble', type, furnitureTypes, (v) => setState(() => type = v)),
          const Text('Medidas (cm)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Field('Ancho', w, type: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: Field('Alto', h, type: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: Field('Profundidad', d, type: TextInputType.number)),
          ]),
          drop('Material preferido', material, materials, (v) => setState(() => material = v)),
          Field('Color', color),
          Field('Descripción (opcional)', desc, lines: 3),
          const Text('Agregar imágenes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < images; i++)
              InkWell(
                onTap: () => setState(() => images--),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: sand, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.image_outlined, color: brown),
                ),
              ),
            if (images < 5)
              InkWell(
                onTap: () => setState(() => images++),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: sand, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: brown),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          Btn('Enviar solicitud', send),
        ]),
      );
}

// ======================= MIS PEDIDOS =======================
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersState();
}

class _MyOrdersState extends State<MyOrdersScreen> {
  int tab = 0;

  void sheet(BuildContext context, Job j) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Obs((c) => Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text('${j.code} · ${j.title}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  Tag(j.status.label, j.status.color),
                ]),
                const SizedBox(height: 12),
                ...detailLines(j),
                if (j.status == JobStatus.enProceso || j.status == JobStatus.porEntregar) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: j.progress / 100, color: green, backgroundColor: Colors.black12),
                  const SizedBox(height: 4),
                  Text('Avance: ${j.progress.round()}%', style: const TextStyle(fontSize: 12)),
                ],
                const SizedBox(height: 16),
                if (j.status == JobStatus.cotizada)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          j.status = JobStatus.rechazada;
                          app.update();
                          Navigator.pop(c);
                        },
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Btn('Aceptar cotización', () {
                        j.status = JobStatus.enProceso;
                        app.update();
                        Navigator.pop(c);
                      }),
                    ),
                  ]),
                if (j.status == JobStatus.entregado && j.rating == null)
                  Btn('Calificar experiencia', () {
                    Navigator.pop(c);
                    _go(context, RatingScreen(j));
                  }),
              ]),
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) => Obs((c) {
        var list = app.jobsOf(app.me!.email);
        if (tab == 1) list = list.where((j) => j.status == JobStatus.entregado).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Mis pedidos')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Tabs(const ['Todos', 'Completados'], tab, (v) => setState(() => tab = v)),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const Empty(Icons.inventory_2_outlined, 'Aún no tienes pedidos')
                    : ListView(children: [
                        for (final j in list) JobCard(j, showClient: false, onTap: () => sheet(c, j))
                      ]),
              ),
              Btn('Solicitar cotización', () => _go(c, const RequestScreen())),
            ]),
          ),
        );
      });
}

class RatingScreen extends StatefulWidget {
  final Job job;
  const RatingScreen(this.job, {super.key});
  @override
  State<RatingScreen> createState() => _RatingState();
}

class _RatingState extends State<RatingScreen> {
  int stars = 5;
  final opinion = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('¿Cómo fue tu experiencia?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 40,
                onPressed: () => setState(() => stars = i),
                icon: Icon(i <= stars ? Icons.star : Icons.star_border, color: Colors.amber),
              ),
          ]),
          const SizedBox(height: 16),
          Field('Tu opinión', opinion, lines: 3),
          const SizedBox(height: 8),
          Btn('Enviar', () {
            widget.job.rating = stars;
            widget.job.opinion = opinion.text.trim();
            app.update();
            snack(context, '¡Gracias por tu opinión!');
            Navigator.pop(context);
          }),
        ]),
      );
}

// ======================= FAVORITOS =======================
class FavsScreen extends StatelessWidget {
  const FavsScreen({super.key});
  @override
  Widget build(BuildContext context) => Obs((c) {
        final list = app.catalog.where((j) => app.myFavs.contains(j.id)).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Mis favoritos')),
          body: list.isEmpty
              ? const Empty(Icons.favorite_border, 'Aún no tienes favoritos.\nToca el corazón en el catálogo.')
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final j in list)
                    Box(
                      onTap: () => _go(c, RequestScreen(type: j.type)),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: sand, borderRadius: BorderRadius.circular(8)),
                          child: Icon(typeIcon(j.type), color: brown),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(j.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Desde ${money(j.price!)}', style: const TextStyle(color: green, fontSize: 12)),
                          ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () {
                            app.myFavs.remove(j.id);
                            app.update();
                          },
                        ),
                      ]),
                    ),
                ]),
        );
      });
}

// ======================= MENSAJES (ambos modos) =======================
class ClientChatTab extends StatelessWidget {
  const ClientChatTab({super.key});
  @override
  Widget build(BuildContext context) =>
      Obs((_) => ChatScreen(clientEmail: app.me!.email, title: 'Mensajes'));
}

class ChatScreen extends StatefulWidget {
  final String clientEmail, title;
  const ChatScreen({required this.clientEmail, this.title = 'Mensajes', super.key});
  @override
  State<ChatScreen> createState() => _ChatState();
}

class _ChatState extends State<ChatScreen> {
  final ctrl = TextEditingController();

  void send() {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    app.msgs.add(Msg(widget.clientEmail, app.me!.role, t, DateTime.now()));
    ctrl.clear();
    app.update();
  }

  @override
  Widget build(BuildContext context) => Obs((c) {
        final mine = app.me!.role;
        final list = app.thread(widget.clientEmail).reversed.toList();
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Column(children: [
            Expanded(
              child: list.isEmpty
                  ? const Empty(Icons.chat_bubble_outline, 'Aún no hay mensajes.\nEscribe el primero.')
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final me = m.from == mine;
                        return Align(
                          alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * .75),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: me ? const Color(0xFFFFF3C4) : const Color(0xFFDCE9FB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(m.text),
                              const SizedBox(height: 2),
                              Text(TimeOfDay.fromDateTime(m.time).format(c),
                                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onSubmitted: (_) => send(),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: green,
                    child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: send),
                  ),
                ]),
              ),
            ),
          ]),
        );
      });
}
