import 'package:flutter/material.dart';
import 'state.dart';
import 'widgets.dart';
import 'client.dart';

void _go(BuildContext c, Widget w) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));

// ======================= INICIO =======================
class CHome extends StatelessWidget {
  const CHome({super.key});

  @override
  Widget build(BuildContext context) => Obs((c) {
        final now = DateTime.now();
        final active = app.orders.where((j) => j.status != JobStatus.entregado).length;
        final pending = app.jobs.where((j) => j.status == JobStatus.solicitada).length;
        final today = app.visits.where((v) => sameDay(v.date, now)).length;

        Widget stat(String n, String l) => Expanded(
              child: Box(
                child: Column(children: [
                  Text(n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
            );

        return Scaffold(
          appBar: AppBar(
              title: const Text('CARPIAPP',
                  style: TextStyle(color: brown, fontWeight: FontWeight.w800))),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Greeting('Hola, ${firstName(app.me!.name)} ☀️', '¡Qué bueno verte hoy!', brown),
            MenuGrid([
              MenuTile(Icons.inventory_2_outlined, 'Pedidos', () => _go(c, const OrdersScreen()), brown),
              MenuTile(Icons.request_quote_outlined, 'Cotizaciones', () => _go(c, const QuotesScreen()), brown),
              MenuTile(Icons.people_outline, 'Clientes', () => _go(c, const ClientsScreen()), brown),
              MenuTile(Icons.handyman_outlined, 'Proyectos', () => _go(c, const ProjectsScreen()), brown),
              MenuTile(Icons.inventory_outlined, 'Inventario',
                  () => _go(c, const InventoryScreen(title: 'Inventario')), brown),
              MenuTile(Icons.layers_outlined, 'Materiales',
                  () => _go(c, const InventoryScreen(title: 'Materiales', tab: 0)), brown),
              MenuTile(Icons.event_outlined, 'Programar\nvisitas', () => _go(c, const VisitsScreen()), brown),
              MenuTile(Icons.build_outlined, 'Herramientas',
                  () => _go(c, const InventoryScreen(title: 'Herramientas', tab: 1)), brown),
              MenuTile(Icons.bar_chart, 'Reportes', () => _go(c, const ReportsScreen()), brown),
            ]),
            const SizedBox(height: 16),
            const Text('Resumen de hoy', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              stat('$active', 'Pedidos'),
              const SizedBox(width: 8),
              stat('$pending', 'Cotizaciones'),
              const SizedBox(width: 8),
              stat('$today', 'Visitas'),
            ]),
          ]),
        );
      });
}

// ======================= HOJA DE DETALLE =======================
void jobSheet(BuildContext context, Job j) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Obs((c) {
      final inOrders = j.status == JobStatus.enProceso ||
          j.status == JobStatus.porEntregar ||
          j.status == JobStatus.entregado;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${j.code} · ${j.title}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Tag(j.status.label, j.status.color),
            ]),
            const SizedBox(height: 12),
            ...detailLines(j),
            const SizedBox(height: 12),
            if (!inOrders)
              Btn(j.price == null ? 'Enviar cotización' : 'Actualizar precio', () async {
                final r = await askFields(c, 'Precio de la cotización', ['Precio'],
                    initial: [j.price?.round().toString() ?? ''], numeric: {0}, ok: 'Enviar');
                if (r != null && toNum(r[0]) > 0) {
                  j.price = toNum(r[0]);
                  j.status = JobStatus.cotizada;
                  app.update();
                }
              }, color: brown),
            if (inOrders) ...[
              const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing: 8, children: [
                for (final s in [JobStatus.enProceso, JobStatus.porEntregar, JobStatus.entregado])
                  ChoiceChip(
                    label: Text(s.label),
                    selected: j.status == s,
                    onSelected: (_) {
                      j.status = s;
                      if (s == JobStatus.entregado) j.progress = 100;
                      app.update();
                    },
                  ),
              ]),
              if (j.status != JobStatus.entregado) ...[
                const SizedBox(height: 8),
                Text('Avance: ${j.progress.round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: j.progress,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: green,
                  label: '${j.progress.round()}%',
                  onChanged: (v) {
                    j.progress = v;
                    app.update();
                  },
                ),
              ],
              if (j.price != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar en el catálogo de clientes'),
                  value: j.inCatalog,
                  onChanged: (v) {
                    j.inCatalog = v;
                    app.update();
                  },
                ),
            ],
          ]),
        ),
      );
    }),
  );
}

// ======================= PEDIDOS =======================
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersState();
}

class _OrdersState extends State<OrdersScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Obs((c) {
        var list = app.orders;
        if (tab == 1) list = list.where((j) => j.status != JobStatus.entregado).toList();
        if (tab == 2) list = list.where((j) => j.status == JobStatus.entregado).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Pedidos recibidos')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Tabs(const ['Todos', 'En proceso', 'Entregados'], tab, (v) => setState(() => tab = v)),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const Empty(Icons.inventory_2_outlined, 'Aún no tienes pedidos')
                    : ListView(children: [for (final j in list) JobCard(j, onTap: () => jobSheet(c, j))]),
              ),
              Btn('Nueva cotización', () => _go(c, const NewQuoteScreen()), color: brown),
            ]),
          ),
        );
      });
}

// ======================= COTIZACIONES =======================
class QuotesScreen extends StatelessWidget {
  const QuotesScreen({super.key});
  @override
  Widget build(BuildContext context) => Obs((c) {
        final list = app.quotes;
        return Scaffold(
          appBar: AppBar(title: const Text('Cotizaciones')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Expanded(
                child: list.isEmpty
                    ? const Empty(Icons.request_quote_outlined, 'Aún no hay cotizaciones')
                    : ListView(children: [for (final j in list) JobCard(j, onTap: () => jobSheet(c, j))]),
              ),
              Btn('Nueva cotización', () => _go(c, const NewQuoteScreen()), color: brown),
            ]),
          ),
        );
      });
}

class NewQuoteScreen extends StatefulWidget {
  const NewQuoteScreen({super.key});
  @override
  State<NewQuoteScreen> createState() => _NewQuoteState();
}

class _NewQuoteState extends State<NewQuoteScreen> {
  static const labels = ['Mueble', 'Medidas', 'Material', 'Presupuesto'];
  int step = 0;
  String type = '', material = materials.first;
  final client = TextEditingController(),
      w = TextEditingController(),
      h = TextEditingController(),
      d = TextEditingController(),
      color = TextEditingController(),
      price = TextEditingController(),
      desc = TextEditingController();

  void next() {
    if (step == 0 && type.isEmpty) return snack(context, 'Elige un tipo de mueble');
    if (step == 1 && client.text.trim().isEmpty) {
      return snack(context, 'Escribe el nombre del cliente');
    }
    if (step == 3) {
      final p = toNum(price.text);
      if (p <= 0) return snack(context, 'Escribe el precio');
      final name = client.text.trim();
      final reg = app.clientByName(name);
      app.addJob(Job(
        id: app.nextId(),
        title: type,
        type: type,
        clientEmail: reg?.email ?? '',
        clientName: reg?.name ?? name,
        material: material,
        color: color.text.trim(),
        desc: desc.text.trim(),
        w: w.text.trim(),
        h: h.text.trim(),
        d: d.text.trim(),
        price: p,
        status: JobStatus.cotizada,
      ));
      snack(context, 'Cotización enviada');
      Navigator.pop(context);
      return;
    }
    setState(() => step++);
  }

  Widget body() {
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tipo de mueble', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              for (final t in furnitureTypes)
                InkWell(
                  onTap: () => setState(() => type = t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: type == t ? green.withAlpha(30) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: type == t ? green : Colors.transparent, width: 1.5),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(typeIcon(t), color: type == t ? green : brown),
                      const SizedBox(height: 4),
                      Text(t, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
            ],
          ),
        ]);
      case 1:
        return Column(children: [
          Field('Nombre del cliente', client),
          Row(children: [
            Expanded(child: Field('Ancho (cm)', w, type: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: Field('Alto (cm)', h, type: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: Field('Profundidad', d, type: TextInputType.number)),
          ]),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Material', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: material,
            decoration: const InputDecoration(filled: true, fillColor: Colors.white, isDense: true, border: InputBorder.none),
            items: [for (final m in materials) DropdownMenuItem(value: m, child: Text(m))],
            onChanged: (v) => setState(() => material = v ?? material),
          ),
          const SizedBox(height: 12),
          Field('Color', color),
        ]);
      default:
        return Column(children: [
          Field('Precio de la cotización', price, type: TextInputType.number),
          Field('Descripción (opcional)', desc, lines: 3),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nueva cotización')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Column(children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i <= step ? green : Colors.black12,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: TextStyle(fontSize: 10, color: i == step ? green : Colors.grey)),
                ]),
              ),
          ]),
          const SizedBox(height: 20),
          body(),
          const SizedBox(height: 20),
          Btn(step == 3 ? 'Enviar cotización' : 'Siguiente', next, color: green),
          if (step > 0) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: () => setState(() => step--), child: const Text('Atrás')),
          ],
        ]),
      );
}

// ======================= CLIENTES =======================
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsState();
}

class _ClientsState extends State<ClientsScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) => Obs((c) {
        final list = app.clients
            .where((u) => u.name.toLowerCase().contains(q) || u.email.contains(q))
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Clientes')),
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
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const Empty(Icons.people_outline, 'Aún no hay clientes registrados')
                    : ListView(children: [
                        for (final u in list)
                          Box(
                            onTap: () => _go(c, ClientDetail(u)),
                            child: Row(children: [
                              CircleAvatar(backgroundColor: sand, child: Text(u.name[0].toUpperCase(), style: const TextStyle(color: brown))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(u.email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text('${app.jobsOf(u.email).length} proyectos',
                                      style: const TextStyle(fontSize: 11, color: green)),
                                ]),
                              ),
                            ]),
                          ),
                      ]),
              ),
            ]),
          ),
        );
      });
}

class ClientDetail extends StatelessWidget {
  final AppUser user;
  const ClientDetail(this.user, {super.key});
  @override
  Widget build(BuildContext context) => Obs((c) {
        final jobs = app.jobsOf(user.email);
        return Scaffold(
          appBar: AppBar(title: Text(user.name)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.email),
                if (user.phone.isNotEmpty) Text('Tel: ${user.phone}'),
                if (user.address.isNotEmpty) Text('Dirección: ${user.address}'),
              ]),
            ),
            Btn('Enviar mensaje',
                () => _go(c, ChatScreen(clientEmail: user.email, title: user.name)), color: brown),
            const SizedBox(height: 16),
            const Text('Proyectos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (jobs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Empty(Icons.handyman_outlined, 'Este cliente aún no tiene proyectos'),
              ),
            for (final j in jobs) JobCard(j, showClient: false, onTap: () => jobSheet(c, j)),
          ]),
        );
      });
}

// ======================= PROYECTOS =======================
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsState();
}

class _ProjectsState extends State<ProjectsScreen> {
  int tab = 0;

  Future<void> _create(BuildContext c) async {
    final r = await askFields(
        c, 'Nuevo proyecto', ['Mueble (ej. Closet)', 'Nombre del cliente', 'Precio'],
        numeric: {2}, ok: 'Crear');
    if (r == null || r[0].isEmpty || r[1].isEmpty) return;
    final reg = app.clientByName(r[1]);
    app.addJob(Job(
      id: app.nextId(),
      title: r[0],
      type: furnitureTypes.firstWhere((t) => t.toLowerCase() == r[0].toLowerCase(), orElse: () => 'Otro'),
      clientEmail: reg?.email ?? '',
      clientName: reg?.name ?? r[1],
      price: toNum(r[2]) > 0 ? toNum(r[2]) : null,
      status: JobStatus.enProceso,
    ));
  }

  @override
  Widget build(BuildContext context) => Obs((c) {
        var list = app.orders;
        if (tab == 1) list = list.where((j) => j.status != JobStatus.entregado).toList();
        if (tab == 2) list = list.where((j) => j.status == JobStatus.entregado).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Mis proyectos')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Tabs(const ['Todos', 'En proceso', 'Terminados'], tab, (v) => setState(() => tab = v)),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const Empty(Icons.handyman_outlined, 'Aún no tienes proyectos')
                    : ListView(children: [
                        for (final j in list) JobCard(j, progress: true, onTap: () => jobSheet(c, j))
                      ]),
              ),
              Btn('Nuevo proyecto', () => _create(c), color: brown),
            ]),
          ),
        );
      });
}

// ======================= INVENTARIO / MATERIALES / HERRAMIENTAS =======================
class InventoryScreen extends StatefulWidget {
  final String title;
  final int? tab; // null = muestra pestañas Materiales/Herramientas
  const InventoryScreen({required this.title, this.tab, super.key});
  @override
  State<InventoryScreen> createState() => _InventoryState();
}

class _InventoryState extends State<InventoryScreen> {
  late int t = widget.tab ?? 0;

  @override
  Widget build(BuildContext context) => Obs((c) {
        final tools = t == 1;
        final list = app.items.where((i) => i.isTool == tools).toList();
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              if (widget.tab == null) ...[
                Tabs(const ['Materiales', 'Herramientas'], t, (v) => setState(() => t = v)),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: list.isEmpty
                    ? Empty(Icons.inventory_outlined,
                        tools ? 'Aún no has agregado herramientas' : 'Aún no has agregado materiales')
                    : ListView(children: [
                        for (final i in list)
                          Box(
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${i.qty} ${tools ? 'pzas' : 'piezas'}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ]),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: i.qty > 0
                                    ? () {
                                        i.qty--;
                                        app.update();
                                      }
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  i.qty++;
                                  app.update();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  app.items.remove(i);
                                  app.update();
                                },
                              ),
                            ]),
                          ),
                      ]),
              ),
              Btn(tools ? 'Agregar herramienta' : 'Agregar material', () async {
                final r = await askFields(c, tools ? 'Nueva herramienta' : 'Nuevo material',
                    ['Nombre', 'Cantidad'], numeric: {1}, ok: 'Agregar');
                if (r != null && r[0].isNotEmpty) {
                  app.items.add(Item(r[0], toNum(r[1]).round(), tools));
                  app.update();
                }
              }, color: brown),
            ]),
          ),
        );
      });
}

// ======================= VISITAS =======================
class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});
  @override
  State<VisitsScreen> createState() => _VisitsState();
}

class _VisitsState extends State<VisitsScreen> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime sel = DateTime.now();

  Widget calendar() {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = (first.weekday + 6) % 7; // lunes = 0
    final cells = <Widget>[for (var i = 0; i < offset; i++) const SizedBox()];
    for (var n = 1; n <= days; n++) {
      final date = DateTime(month.year, month.month, n);
      final selected = sameDay(date, sel);
      final has = app.visits.any((v) => sameDay(v.date, date));
      cells.add(GestureDetector(
        onTap: () => setState(() => sel = date),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: selected ? green : null, shape: BoxShape.circle),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$n',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: sameDay(date, DateTime.now()) ? FontWeight.w800 : FontWeight.normal,
                  )),
              if (has)
                Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Colors.white : brown)),
            ]),
          ),
        ),
      ));
    }
    return GridView.count(
        crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: cells);
  }

  Future<void> _add(BuildContext c) async {
    final r = await askFields(c, 'Programar visita', ['Cliente', 'Motivo (ej. Toma de medidas)'], ok: 'Siguiente');
    if (r == null || r[0].isEmpty || !c.mounted) return;
    final t = await showTimePicker(context: c, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t == null) return;
    app.visits.add(Visit(r[0], r[1], sel, t));
    app.update();
  }

  @override
  Widget build(BuildContext context) => Obs((c) {
        final list = app.visits.where((v) => sameDay(v.date, sel)).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
        return Scaffold(
          appBar: AppBar(title: const Text('Mis visitas')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Box(
              child: Column(children: [
                Row(children: [
                  IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(() => month = DateTime(month.year, month.month - 1))),
                  Expanded(
                      child: Text(monthName(month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() => month = DateTime(month.year, month.month + 1))),
                ]),
                Row(children: [
                  for (final d in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                    Expanded(
                        child: Center(
                            child: Text(d, style: const TextStyle(fontSize: 11, color: Colors.grey)))),
                ]),
                calendar(),
              ]),
            ),
            const SizedBox(height: 8),
            Text(fmtDate(sel), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Empty(Icons.event_outlined, 'Sin visitas este día')),
            for (final v in list)
              Box(
                child: Row(children: [
                  const Icon(Icons.location_on_outlined, color: Colors.red),
                  const SizedBox(width: 10),
                  Text(v.time.format(c), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.client, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (v.note.isNotEmpty)
                        Text(v.note, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      app.visits.remove(v);
                      app.update();
                    },
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            Btn('Programar visita', () => _add(c), color: brown),
          ]),
        );
      });
}

// ======================= REPORTES Y FINANZAS =======================
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends State<ReportsScreen> {
  int p = 0; // 0 mes, 1 año, 2 todo

  bool inP(DateTime d) {
    final n = DateTime.now();
    if (p == 0) return d.year == n.year && d.month == n.month;
    if (p == 1) return d.year == n.year;
    return true;
  }

  @override
  Widget build(BuildContext context) => Obs((c) {
        final done = app.jobs.where((j) => j.status == JobStatus.entregado && inP(j.date)).toList();
        final income = done.fold<double>(0, (s, j) => s + (j.price ?? 0));
        final exp = app.expenses.where((e) => inP(e.date)).toList();
        final spent = exp.fold<double>(0, (s, e) => s + e.amount);
        final sent = app.jobs.where((j) => j.price != null && inP(j.date)).length;
        final running = app.jobs
            .where((j) => (j.status == JobStatus.enProceso || j.status == JobStatus.porEntregar) && inP(j.date))
            .length;
        final visited = app.visits.where((v) => v.at.isBefore(DateTime.now()) && inP(v.date)).length;

        Widget card(String l, String v, Color col) => Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: col.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l, style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ]),
              ),
            );

        Widget line(IconData i, String l, int n) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(i, size: 18, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(child: Text(l, style: const TextStyle(fontSize: 13))),
                Text('$n', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            );

        return Scaffold(
          appBar: AppBar(title: const Text('Reportes y finanzas')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Periodo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              value: p,
              decoration: const InputDecoration(filled: true, fillColor: Colors.white, isDense: true, border: InputBorder.none),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Este mes')),
                DropdownMenuItem(value: 1, child: Text('Este año')),
                DropdownMenuItem(value: 2, child: Text('Todo')),
              ],
              onChanged: (v) => setState(() => p = v ?? 0),
            ),
            const SizedBox(height: 12),
            Row(children: [
              card('Ingresos', money(income), green),
              const SizedBox(width: 10),
              card('Gastos', money(spent), Colors.red),
            ]),
            Row(children: [card('Ganancia', money(income - spent), income - spent >= 0 ? green : Colors.red)]),
            Box(
              child: Column(children: [
                line(Icons.check_circle_outline, 'Pedidos completados', done.length),
                line(Icons.request_quote_outlined, 'Cotizaciones enviadas', sent),
                line(Icons.folder_open, 'Proyectos en proceso', running),
                line(Icons.location_on_outlined, 'Visitas realizadas', visited),
              ]),
            ),
            if (exp.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Gastos registrados', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final e in exp)
                Box(
                  child: Row(children: [
                    Expanded(child: Text(e.concept)),
                    Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        app.expenses.remove(e);
                        app.update();
                      },
                    ),
                  ]),
                ),
            ],
            const SizedBox(height: 8),
            Btn('Registrar gasto', () async {
              final r = await askFields(c, 'Registrar gasto', ['Concepto', 'Monto'], numeric: {1}, ok: 'Agregar');
              if (r != null && r[0].isNotEmpty && toNum(r[1]) > 0) {
                app.expenses.add(Expense(r[0], toNum(r[1]), DateTime.now()));
                app.update();
              }
            }, color: brown),
          ]),
        );
      });
}
