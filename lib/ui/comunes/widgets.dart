import 'dart:async';

import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputFormatter;
import 'package:url_launcher/url_launcher.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/ui.dart';
import '../../datos/api.dart';
import '../../modelos/modelos.dart';

// =====================================================================
// Navegación y mensajes
// =====================================================================
Future<T?> ir<T>(BuildContext c, Widget pantalla) =>
    Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => pantalla));

void avisar(BuildContext c, String texto, {bool error = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), backgroundColor: error ? Colores.error : null));
}

Future<bool> confirmar(
  BuildContext c,
  String titulo,
  String mensaje, {
  String si = 'Aceptar',
  bool peligro = false,
}) async {
  final r = await showAdaptiveDialog<bool>(
    context: c,
    builder: (d) => AlertDialog.adaptive(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          style: peligro ? TextButton.styleFrom(foregroundColor: Colores.error) : null,
          child: Text(si),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Evita perder un formulario al tocar "atrás" (botón del sistema, gesto o flecha):
/// primero deja que [antes] lo maneje (p. ej. volver al paso anterior) y, si hay
/// cambios sin guardar, pide confirmación. `Navigator.pop` directo (al guardar) no se bloquea.
class SinPerderCambios extends StatelessWidget {
  final bool Function() hayCambios;
  final bool Function()? antes;
  final Widget child;
  const SinPerderCambios({required this.hayCambios, this.antes, required this.child, super.key});

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (yaSalio, resultado) async {
      if (yaSalio || (antes?.call() ?? false)) return;
      final nav = Navigator.of(context);
      if (!hayCambios() ||
          await confirmar(
            context,
            '¿Descartar cambios?',
            'Lo que capturaste todavía no se ha guardado.',
            si: 'Descartar',
            peligro: true,
          )) {
        nav.pop(resultado);
      }
    },
    child: child,
  );
}

/// Ejecuta una acción mostrando un indicador y avisando si falla.
Future<bool> conCarga(BuildContext c, Future<void> Function() accion, {String? exito}) async {
  showDialog<void>(
    context: c,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator.adaptive()),
  );
  try {
    await accion();
    if (c.mounted) Navigator.of(c, rootNavigator: true).pop();
    if (exito != null && c.mounted) avisar(c, exito);
    return true;
  } catch (e) {
    if (c.mounted) {
      Navigator.of(c, rootNavigator: true).pop();
      avisar(c, mensajeError(e), error: true);
    }
    return false;
  }
}

Future<void> abrirEnlace(BuildContext c, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && c.mounted) avisar(c, 'No se pudo abrir el enlace.', error: true);
  } catch (_) {
    if (c.mounted) avisar(c, 'No se pudo abrir el enlace.', error: true);
  }
}

Future<void> llamar(BuildContext c, String tel) =>
    abrirEnlace(c, Uri(scheme: 'tel', path: tel.replaceAll(RegExp(r'[^0-9+]'), '')));

Future<void> whatsapp(BuildContext c, String tel, [String texto = '']) {
  var n = tel.replaceAll(RegExp(r'[^0-9]'), '');
  if (n.length == 10) n = '52$n';
  return abrirEnlace(c, Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(texto)}'));
}

Future<void> comoLlegar(BuildContext c, String direccion, [String ciudad = 'Mérida, Yucatán']) => abrirEnlace(
  c,
  Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$direccion, $ciudad')}'),
);

Future<void> abrirWeb(BuildContext c, String sitio) =>
    abrirEnlace(c, Uri.parse(sitio.startsWith('http') ? sitio : 'https://$sitio'));

// =====================================================================
// Encabezados
// =====================================================================

/// "CARPIAPP / SECCIÓN" como en los mockups.
class Marca extends StatelessWidget {
  final String seccion;
  final List<Widget> acciones;
  final bool atras;
  const Marca(this.seccion, {this.acciones = const [], this.atras = false, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final puedeVolver = atras && Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          if (puedeVolver) ...[
            BotonCirculo(Icons.chevron_left, () => Navigator.of(context).maybePop()),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARPIAPP',
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: .3),
                ),
                Text(
                  seccion.toUpperCase(),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, letterSpacing: .6),
                ),
              ],
            ),
          ),
          ...acciones,
        ],
      ),
    );
  }
}

class BotonCirculo extends StatelessWidget {
  final IconData icono;
  final VoidCallback? alTocar;
  final String? ayuda;
  final int insignia;
  const BotonCirculo(this.icono, this.alTocar, {this.ayuda, this.insignia = 0, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final boton = Material(
      color: cs.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: alTocar,
        child: SizedBox(width: 40, height: 40, child: Icon(icono, color: cs.primary, size: 22)),
      ),
    );
    final conInsignia = insignia > 0
        ? Badge(label: Text('$insignia'), backgroundColor: Colores.error, child: boton)
        : boton;
    return ayuda == null ? conInsignia : Tooltip(message: ayuda!, child: conInsignia);
  }
}

class Titulo extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  const Titulo(this.titulo, {this.subtitulo, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(subtitulo!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

/// Pantalla con el encabezado de marca, título y cuerpo desplazable.
class PantallaBase extends StatelessWidget {
  final String seccion;
  final String? titulo;
  final String? subtitulo;
  final List<Widget> acciones;
  final Widget cuerpo;
  final Widget? pie;
  final bool atras;
  final Future<void> Function()? alRefrescar;

  const PantallaBase({
    required this.seccion,
    this.titulo,
    this.subtitulo,
    this.acciones = const [],
    required this.cuerpo,
    this.pie,
    this.atras = true,
    this.alRefrescar,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Marca(seccion, acciones: acciones, atras: atras),
            if (titulo != null) Titulo(titulo!, subtitulo: subtitulo),
            Expanded(
              child: alRefrescar == null ? cuerpo : RefreshIndicator.adaptive(onRefresh: alRefrescar!, child: cuerpo),
            ),
            if (pie != null)
              SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: pie),
              ),
          ],
        ),
      ),
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  const Etiqueta(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(
      texto.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class Seccion extends StatelessWidget {
  final String titulo;
  final Widget? accion;
  const Seccion(this.titulo, {this.accion, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        ?accion,
      ],
    ),
  );
}

// =====================================================================
// Formularios
// =====================================================================
class Campo extends StatelessWidget {
  final String etiqueta;
  final TextEditingController control;
  final String? pista;
  final TextInputType? teclado;
  final bool oculto;
  final int lineas;
  final Widget? prefijo;
  final Widget? sufijo;
  final String? Function(String?)? validar;
  final ValueChanged<String>? alCambiar;
  final TextCapitalization mayusculas;
  final Iterable<String>? autollenado;

  const Campo(
    this.etiqueta,
    this.control, {
    this.pista,
    this.teclado,
    this.oculto = false,
    this.lineas = 1,
    this.prefijo,
    this.sufijo,
    this.validar,
    this.alCambiar,
    this.mayusculas = TextCapitalization.sentences,
    this.autollenado,
    super.key,
  });

  /// Evita letras en montos, cantidades y teléfonos (el teclado físico o pegar texto las permitiría).
  List<TextInputFormatter>? get _filtros => switch (teclado?.index) {
    2 => [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    3 => [FilteringTextInputFormatter.allow(RegExp(r'[0-9+() -]'))],
    _ => null,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Etiqueta(etiqueta),
        TextFormField(
          controller: control,
          obscureText: oculto,
          keyboardType: teclado,
          maxLines: oculto ? 1 : lineas,
          minLines: 1,
          validator: validar,
          onChanged: alCambiar,
          textCapitalization: mayusculas,
          autofillHints: autollenado,
          inputFormatters: _filtros,
          decoration: InputDecoration(hintText: pista, prefixIcon: prefijo, suffixIcon: sufijo),
        ),
      ],
    ),
  );
}

class Seleccion<T> extends StatelessWidget {
  final String etiqueta;
  final T? valor;
  final List<T> opciones;
  final String Function(T) texto;
  final ValueChanged<T?> alCambiar;
  final String pista;

  const Seleccion({
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.texto,
    required this.alCambiar,
    this.pista = 'Seleccionar',
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Etiqueta(etiqueta),
        DropdownButtonFormField<T>(
          // La clave hace que el campo se reconstruya si el valor cambia desde fuera
          // (por ejemplo, al agregar un cliente nuevo y seleccionarlo).
          key: ValueKey<Object?>(valor),
          initialValue: valor,
          isExpanded: true,
          hint: Text(pista),
          icon: const Icon(Icons.keyboard_arrow_down),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          items: [for (final o in opciones) DropdownMenuItem(value: o, child: Text(texto(o)))],
          onChanged: alCambiar,
        ),
      ],
    ),
  );
}

/// Campo que abre un selector (fecha, hora, etc.).
class CampoToque extends StatelessWidget {
  final String etiqueta;
  final String texto;
  final bool vacio;
  final IconData icono;
  final VoidCallback alTocar;

  const CampoToque({
    required this.etiqueta,
    required this.texto,
    required this.alTocar,
    this.vacio = false,
    this.icono = Icons.chevron_right,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Etiqueta(etiqueta),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outline),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: alTocar,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        texto,
                        style: TextStyle(color: vacio ? cs.onSurfaceVariant : cs.onSurface, fontSize: 15),
                      ),
                    ),
                    Icon(icono, color: cs.primary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> elegirFechaHora(BuildContext c, {DateTime? inicial, bool soloFecha = false}) async {
  final ahora = DateTime.now();
  final base = inicial ?? DateTime(ahora.year, ahora.month, ahora.day + 1, 10);
  final plataforma = Theme.of(c).platform;
  if (plataforma == TargetPlatform.iOS) {
    var valor = base;
    final ok = await showModalBottomSheet<bool>(
      context: c,
      builder: (d) => SizedBox(
        height: 320,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Listo'))],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: soloFecha ? CupertinoDatePickerMode.date : CupertinoDatePickerMode.dateAndTime,
                initialDateTime: base,
                minimumDate: soloFecha ? null : ahora.subtract(const Duration(minutes: 5)),
                minuteInterval: 1,
                onDateTimeChanged: (v) => valor = v,
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true ? valor : null;
  }
  if (!c.mounted) return null;
  final f = await showDatePicker(
    context: c,
    initialDate: base,
    firstDate: soloFecha ? DateTime(2020) : DateTime(ahora.year, ahora.month, ahora.day),
    lastDate: DateTime(ahora.year + 2),
  );
  if (f == null || soloFecha || !c.mounted) return f;
  final h = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(base));
  if (h == null) return null;
  return DateTime(f.year, f.month, f.day, h.hour, h.minute);
}

// =====================================================================
// Botones
// =====================================================================
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? alTocar;
  final IconData? icono;
  final bool cargando;
  const BotonPrincipal(this.texto, this.alTocar, {this.icono, this.cargando = false, super.key});

  @override
  Widget build(BuildContext context) => FilledButton(
    // Mientras carga se ignoran los toques pero el botón conserva su color,
    // para que el indicador blanco se vea.
    onPressed: cargando ? () {} : alTocar,
    child: cargando
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[Icon(icono, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(texto, textAlign: TextAlign.center)),
            ],
          ),
  );
}

class BotonSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? alTocar;
  final IconData? icono;
  final Color? color;
  const BotonSecundario(this.texto, this.alTocar, {this.icono, this.color, super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: alTocar,
    style: color == null
        ? null
        : OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color!.withValues(alpha: .4)),
          ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[Icon(icono, size: 18), const SizedBox(width: 6)],
        Flexible(child: Text(texto, textAlign: TextAlign.center)),
      ],
    ),
  );
}

/// Pestañas tipo "píldora" de los mockups (Materiales | Herramientas).
class Pildoras extends StatelessWidget {
  final List<String> opciones;
  final int seleccion;
  final ValueChanged<int> alCambiar;
  const Pildoras(this.opciones, this.seleccion, this.alCambiar, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Siempre alineadas a la izquierda, aunque quepan en pantalla.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (var i = 0; i < opciones.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: i == seleccion ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => alCambiar(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Text(
                        opciones[i],
                        style: TextStyle(
                          color: i == seleccion ? Colors.white : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Tarjetas y estados
// =====================================================================
class Tarjeta extends StatelessWidget {
  final Widget child;
  final VoidCallback? alTocar;
  final EdgeInsets relleno;
  final Color? color;
  final EdgeInsets margen;
  const Tarjeta({
    required this.child,
    this.alTocar,
    this.relleno = const EdgeInsets.all(16),
    this.color,
    this.margen = const EdgeInsets.only(bottom: 10),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: margen,
      child: Material(
        color: color ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: color == null ? BorderSide(color: cs.outline) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alTocar,
          child: Padding(padding: relleno, child: child),
        ),
      ),
    );
  }
}

class ChipEstado extends StatelessWidget {
  final String texto;
  final Color color;
  const ChipEstado(this.texto, this.color, {super.key});

  factory ChipEstado.pedido(String estado) {
    final e = EstadoPedido.de(estado);
    return ChipEstado(e.etiqueta, e.color);
  }

  @override
  Widget build(BuildContext context) => Row(
    // Row mínima: la etiqueta mide lo que su texto, aunque esté en una lista.
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}

class Vacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? detalle;
  final Widget? accion;
  const Vacio(this.icono, this.texto, {this.detalle, this.accion, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: cs.primaryContainer,
              child: Icon(icono, size: 30, color: cs.primary),
            ),
            const SizedBox(height: 14),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 6),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 16), accion!],
          ],
        ),
      ),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator.adaptive());
}

class ErrorCarga extends StatelessWidget {
  final Object error;
  final VoidCallback reintentar;
  const ErrorCarga(this.error, this.reintentar, {super.key});

  @override
  Widget build(BuildContext context) => Vacio(
    Icons.cloud_off_outlined,
    'No se pudo cargar',
    detalle: mensajeError(error),
    accion: SizedBox(width: 180, child: BotonSecundario('Reintentar', reintentar, icono: Icons.refresh)),
  );
}

/// Carga datos asíncronos con estados de carga, error y refresco.
class Cargador<T> extends StatefulWidget {
  final Future<T> Function() cargar;
  final Widget Function(BuildContext, T, Future<void> Function()) construir;
  const Cargador({required this.cargar, required this.construir, super.key});

  @override
  State<Cargador<T>> createState() => CargadorState<T>();
}

class CargadorState<T> extends State<Cargador<T>> {
  T? _datos;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    try {
      final d = await widget.cargar();
      if (!mounted) return;
      setState(() {
        _datos = d;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _datos == null) return const Cargando();
    if (_error != null && _datos == null) {
      return ErrorCarga(_error!, () {
        setState(() => _cargando = true);
        recargar();
      });
    }
    return widget.construir(context, _datos as T, recargar);
  }
}

class Progreso extends StatelessWidget {
  final int valor;
  const Progreso(this.valor, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: valor / 100, minHeight: 8),
        ),
      ),
      const SizedBox(width: 10),
      Text('$valor%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    ],
  );
}

/// Indicador de pasos (Proyecto · Material · Cita / Cliente · Proyecto · Costos · Resumen).
class Pasos extends StatelessWidget {
  final List<String> pasos;
  final int actual;
  final bool numerados;
  const Pasos(this.pasos, this.actual, {this.numerados = true, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < pasos.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0 ? Colors.transparent : (i <= actual ? cs.primary : cs.outline),
                      ),
                    ),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: i <= actual ? cs.primary : cs.surfaceContainerHighest,
                      child: numerados
                          ? Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: i <= actual ? Colors.white : cs.onSurfaceVariant,
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == pasos.length - 1 ? Colors.transparent : (i < actual ? cs.primary : cs.outline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pasos[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: i <= actual ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Recuadro informativo (verde IA, amarillo aviso o color del rol).
class Aviso extends StatelessWidget {
  final String texto;
  final String? titulo;
  final IconData icono;
  final Color fondo;
  final Color colorTexto;
  const Aviso(
    this.texto, {
    this.titulo,
    this.icono = Icons.info,
    this.fondo = Colores.ia,
    this.colorTexto = Colores.iaTexto,
    super.key,
  });

  const Aviso.alerta(this.texto, {this.titulo, this.icono = Icons.warning_amber_rounded, super.key})
    : fondo = Colores.aviso,
      colorTexto = Colores.avisoTexto;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: colorTexto, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titulo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    titulo!,
                    style: TextStyle(color: colorTexto, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .4),
                  ),
                ),
              Text(texto, style: TextStyle(color: colorTexto, fontSize: 13.5, height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

class Avatar extends StatelessWidget {
  final String nombre;
  final double radio;
  final String? url;
  const Avatar(this.nombre, {this.radio = 22, this.url, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radio,
      backgroundColor: cs.primaryContainer,
      backgroundImage: url == null ? null : NetworkImage(url!),
      child: url == null
          ? Text(
              iniciales(nombre),
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: radio * .7),
            )
          : null,
    );
  }
}

/// Fila de dato: ETIQUETA  valor (como en las tarjetas de proveedor).
class Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final VoidCallback? alTocar;
  const Dato(this.etiqueta, this.valor, {this.alTocar, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                etiqueta.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: .4,
                ),
              ),
            ),
            Expanded(
              child: Text(valor, style: TextStyle(fontSize: 13.5, color: alTocar != null ? cs.primary : cs.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagen de Storage (privada con URL firmada o pública).
class ImagenStorage extends StatelessWidget {
  final String bucket;
  final String ruta;
  final bool publica;
  final BoxFit ajuste;
  const ImagenStorage(this.bucket, this.ruta, {this.publica = false, this.ajuste = BoxFit.cover, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget marco(Widget w) => Container(color: cs.surfaceContainerHighest, alignment: Alignment.center, child: w);
    if (publica) {
      return Image.network(
        Api.urlPublica(bucket, ruta),
        fit: ajuste,
        errorBuilder: (_, _, _) => marco(const Icon(Icons.broken_image_outlined)),
      );
    }
    return FutureBuilder<String>(
      future: Api.urlFirmada(bucket, ruta),
      builder: (c, s) {
        if (!s.hasData) {
          return marco(const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return Image.network(
          s.data!,
          fit: ajuste,
          errorBuilder: (_, _, _) => marco(const Icon(Icons.broken_image_outlined)),
        );
      },
    );
  }
}

void verImagen(BuildContext c, String bucket, String ruta, {bool publica = false, String? pie}) {
  ir(
    c,
    Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: ImagenStorage(bucket, ruta, publica: publica, ajuste: BoxFit.contain),
              ),
            ),
          ),
          if (pie != null && pie.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(pie, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Mosaico de acceso del panel principal (Bento grid de los mockups).
class Mosaico extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback alTocar;
  final int insignia;
  const Mosaico(this.icono, this.texto, this.alTocar, {this.insignia = 0, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: insignia > 0,
                label: Text('$insignia'),
                backgroundColor: Colores.error,
                child: Icon(icono, color: cs.primary, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                texto,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Saludo extends StatelessWidget {
  final String nombre;
  final String frase;
  const Saludo(this.nombre, this.frase, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DateTime.now().hour;
    final emoji = h < 12 ? '☀️' : (h < 19 ? '🌤️' : '🌙');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, ${primerNombre(nombre)} $emoji',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(frase, style: TextStyle(color: Colors.white.withValues(alpha: .92), fontSize: 15)),
        ],
      ),
    );
  }
}

/// Barra de búsqueda de los mockups.
class Buscador extends StatefulWidget {
  final String pista;
  final ValueChanged<String> alCambiar;
  const Buscador(this.pista, this.alCambiar, {super.key});

  @override
  State<Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends State<Buscador> {
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      // Al tocar fuera (p. ej. un resultado) se cierra el teclado y no vuelve a abrirse al regresar.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onChanged: (v) {
        _espera?.cancel();
        _espera = Timer(const Duration(milliseconds: 250), () => widget.alCambiar(v.trim().toLowerCase()));
      },
      decoration: InputDecoration(
        hintText: widget.pista,
        prefixIcon: const Icon(Icons.search),
        fillColor: cs.surfaceContainerHighest,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

/// Tarjeta de resumen de cotización (fondo arena).
class ResumenCostos extends StatelessWidget {
  final double materiales;
  final double manoObra;
  final double adicionales;
  const ResumenCostos(this.materiales, this.manoObra, this.adicionales, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget fila(String a, double v, {bool total = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              style: TextStyle(
                fontWeight: total ? FontWeight.w800 : FontWeight.w500,
                color: total ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            dinero(v),
            style: TextStyle(
              fontWeight: total ? FontWeight.w800 : FontWeight.w600,
              fontSize: total ? 20 : 14,
              color: total ? cs.primary : cs.onSurface,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Etiqueta('Resumen de cotización'),
          fila('Materiales', materiales),
          fila('Mano de obra', manoObra),
          fila('Costos adicionales', adicionales),
          const Divider(height: 18),
          fila('TOTAL', materiales + manoObra + adicionales, total: true),
        ],
      ),
    );
  }
}
