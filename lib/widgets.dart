import 'package:flutter/material.dart';
import 'state.dart';

const brown = Color(0xFF6B2E10);
const green = Color(0xFF0B6B4A);
const bg = Color(0xFFF2F2F7);
const sand = Color(0xFFEFE3D8);

const furnitureTypes = ['Closet', 'Cocina', 'Escritorio', 'Mesa', 'Librero', 'Otro'];
const materials = ['Pino', 'Cedro', 'Caoba', 'Roble', 'MDF', 'Melamina', 'Triplay', 'Otro'];

const _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];
const _short = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String monthName(DateTime d) => '${_months[d.month - 1]} ${d.year}';
String fmtDate(DateTime d) => '${d.day} ${_short[d.month - 1]} ${d.year}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String firstName(String n) => n.trim().split(' ').first;
double toNum(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

String money(double v) {
  if (v < 0) return '-${money(-v)}';
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '\$$b';
}

IconData typeIcon(String t) {
  switch (t) {
    case 'Closet':
      return Icons.checkroom_outlined;
    case 'Cocina':
      return Icons.kitchen_outlined;
    case 'Escritorio':
      return Icons.desk_outlined;
    case 'Mesa':
      return Icons.table_restaurant_outlined;
    case 'Librero':
      return Icons.menu_book_outlined;
    default:
      return Icons.chair_outlined;
  }
}

/// Reconstruye su contenido cada vez que cambia el estado global.
class Obs extends StatelessWidget {
  final Widget Function(BuildContext) b;
  const Obs(this.b, {super.key});
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: app, builder: (c, _) => b(c));
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({this.size = 96, super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/logo.png',
        width: size,
        fit: BoxFit.contain,
        // Si el archivo no se encuentra, muestra un ícono en su lugar.
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: size / 2,
          backgroundColor: brown,
          child: Icon(Icons.carpenter, size: size * .55, color: Colors.white),
        ),
      );
}

class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const Btn(this.label, this.onTap, {this.color = green, super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController c;
  final bool obscure;
  final TextInputType? type;
  final int lines;
  const Field(this.label, this.c, {this.obscure = false, this.type, this.lines = 1, super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            obscureText: obscure,
            keyboardType: type,
            maxLines: lines,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ]),
      );
}

class Box extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets pad;
  final Color color;
  const Box(
      {required this.child,
      this.onTap,
      this.pad = const EdgeInsets.all(12),
      this.color = Colors.white,
      super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(padding: pad, child: child),
          ),
        ),
      );
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration:
            BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const Empty(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
}

class Tabs extends StatelessWidget {
  final List<String> labels;
  final int sel;
  final ValueChanged<int> onSel;
  const Tabs(this.labels, this.sel, this.onSel, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(labels[i]),
            selected: sel == i,
            selectedColor: green.withAlpha(50),
            onSelected: (_) => onSel(i),
          ),
        ),
      );
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const MenuTile(this.icon, this.label, this.onTap, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );
}

class MenuGrid extends StatelessWidget {
  final List<Widget> children;
  const MenuGrid(this.children, {super.key});
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: children,
      );
}

class Greeting extends StatelessWidget {
  final String title, sub;
  final Color color;
  const Greeting(this.title, this.sub, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final bool progress, showClient;
  const JobCard(this.job,
      {required this.onTap, this.progress = false, this.showClient = true, super.key});
  @override
  Widget build(BuildContext context) => Box(
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: sand, borderRadius: BorderRadius.circular(8)),
            child: Icon(typeIcon(job.type), color: brown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(job.code, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                Tag(job.status.label, job.status.color),
              ]),
              Text(job.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                showClient ? '${job.clientName} · ${fmtDate(job.date)}' : fmtDate(job.date),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (progress)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(
                      child: LinearProgressIndicator(
                          value: job.progress / 100, color: green, backgroundColor: Colors.black12),
                    ),
                    const SizedBox(width: 8),
                    Text('${job.progress.round()}%', style: const TextStyle(fontSize: 11)),
                  ]),
                ),
            ]),
          ),
        ]),
      );
}

List<Widget> detailLines(Job j) {
  Widget l(String a, String b) => b.isEmpty
      ? const SizedBox()
      : Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$a: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: b),
          ])),
        );
  return [
    l('Cliente', j.clientName),
    l('Mueble', j.type),
    l('Medidas (cm)',
        [j.w, j.h, j.d].every((e) => e.isEmpty) ? '' : '${j.w} × ${j.h} × ${j.d}'),
    l('Material', j.material),
    l('Color', j.color),
    l('Descripción', j.desc),
    l('Imágenes', j.images > 0 ? '${j.images}' : ''),
    l('Precio', j.price == null ? '' : money(j.price!)),
    l('Fecha', fmtDate(j.date)),
    l('Calificación',
        j.rating == null ? '' : '${'★' * j.rating!}${j.opinion.isEmpty ? '' : ' — ${j.opinion}'}'),
  ];
}

/// Diálogo sencillo con varios campos de texto. Devuelve null si se cancela.
Future<List<String>?> askFields(BuildContext context, String title, List<String> labels,
    {List<String>? initial, Set<int> numeric = const {}, String ok = 'Guardar'}) {
  final ctrls = [
    for (var i = 0; i < labels.length; i++)
      TextEditingController(text: initial != null ? initial[i] : '')
  ];
  return showDialog<List<String>>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: ctrls[i],
                keyboardType: numeric.contains(i) ? TextInputType.number : TextInputType.text,
                decoration: InputDecoration(labelText: labels[i]),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(d, [for (final t in ctrls) t.text.trim()]),
          child: Text(ok),
        ),
      ],
    ),
  );
}

void snack(BuildContext c, String t) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));
