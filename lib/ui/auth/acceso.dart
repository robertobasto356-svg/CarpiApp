import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/ui.dart';
import '../../datos/sesion.dart';
import '../comunes/widgets.dart';

class Logo extends StatelessWidget {
  final double tam;
  const Logo({this.tam = 180, super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/logo.png',
        width: tam,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: tam / 3,
          backgroundColor: Colores.madera,
          child: Icon(Icons.carpenter, color: Colors.white, size: tam / 3),
        ),
      );
}

// =====================================================================
// Bienvenida: elegir tipo de cuenta
// =====================================================================
class Bienvenida extends StatelessWidget {
  const Bienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const Logo(tam: 220),
              const SizedBox(height: 12),
              const Text('Tu madera, tu idea, nuestro oficio.',
                  style: TextStyle(fontSize: 15, color: Colores.madera, fontWeight: FontWeight.w600)),
              const SizedBox(height: 36),
              Theme(
                data: construirTema(paletaCarpintero),
                child: Builder(
                  builder: (c) => BotonPrincipal('Soy carpintero', () => ir(c, const Acceso(rol: 'carpintero')),
                      icono: Icons.handyman_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Theme(
                data: construirTema(paletaCliente),
                child: Builder(
                  builder: (c) => BotonPrincipal('Soy cliente', () => ir(c, const Acceso(rol: 'cliente')),
                      icono: Icons.chair_outlined),
                ),
              ),
              const SizedBox(height: 28),
              if (sesion.error != null) Aviso.alerta(sesion.error!),
              Text('Diseñamos contigo. Creamos para ti.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Iniciar sesión / Crear cuenta
// =====================================================================
class Acceso extends StatefulWidget {
  final String rol;
  const Acceso({required this.rol, super.key});

  @override
  State<Acceso> createState() => _AccesoState();
}

class _AccesoState extends State<Acceso> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _taller = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  bool _registro = false;
  bool _cargando = false;
  bool _ver = false;
  String? _error;

  bool get _carp => widget.rol == 'carpintero';

  @override
  void dispose() {
    for (final c in [_nombre, _taller, _telefono, _correo, _clave, _clave2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_registro) {
        final conSesion = await sesion.registrar(
          nombre: _nombre.text,
          correo: _correo.text,
          clave: _clave.text,
          rol: widget.rol,
          telefono: _telefono.text,
          nombreCarpinteria: _taller.text,
        );
        if (!mounted) return;
        if (conSesion) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        } else {
          await showAdaptiveDialog<void>(
            context: context,
            builder: (d) => AlertDialog.adaptive(
              title: const Text('Revisa tu correo'),
              content: Text(
                  'Te enviamos un enlace a ${_correo.text.trim()} para confirmar tu cuenta. '
                  'Después de confirmarla, vuelve aquí e inicia sesión.'),
              actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Entendido'))],
            ),
          );
          if (mounted) setState(() => _registro = false);
        }
      } else {
        final problema = await sesion.entrar(_correo.text, _clave.text, widget.rol);
        if (!mounted) return;
        if (problema != null) {
          setState(() => _error = problema);
        } else {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvide() async {
    final correo = TextEditingController(text: _correo.text);
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Te enviaremos un enlace para crear una contraseña nueva.'),
          const SizedBox(height: 12),
          TextField(
            controller: correo,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Correo electrónico'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enviar enlace')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!correo.text.contains('@')) {
      avisar(context, 'Escribe un correo válido.', error: true);
      return;
    }
    await conCarga(context, () => sesion.recuperarClave(correo.text),
        exito: 'Listo. Revisa tu correo para crear una contraseña nueva.');
  }

  String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Este dato es obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final paleta = _carp ? paletaCarpintero : paletaCliente;
    return Theme(
      data: construirTema(paleta),
      child: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          body: SafeArea(
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                  children: [
                    Marca(_carp ? 'Carpintero' : 'Cliente', atras: true),
                    const SizedBox(height: 8),
                    const Center(child: Logo(tam: 140)),
                    Titulo(
                      _registro
                          ? 'Crear cuenta'
                          : (_carp ? 'Tu taller, bajo control' : 'Bienvenido a CarpiApp'),
                      subtitulo: _carp
                          ? 'Pedidos, cotizaciones y clientes en un solo lugar'
                          : 'Diseñamos contigo. Creamos para ti.',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Iniciar sesión')),
                            ButtonSegment(value: true, label: Text('Crear cuenta')),
                          ],
                          selected: {_registro},
                          showSelectedIcon: false,
                          onSelectionChanged: _cargando ? null : (s) => setState(() {
                                _registro = s.first;
                                _error = null;
                              }),
                        ),
                        const SizedBox(height: 16),
                        if (_registro) ...[
                          Campo('Nombre completo', _nombre,
                              validar: _requerido,
                              mayusculas: TextCapitalization.words,
                              autollenado: const [AutofillHints.name]),
                          if (_carp)
                            Campo('Nombre de tu carpintería', _taller,
                                pista: 'Ej. Carpintería Arbor',
                                validar: _requerido,
                                mayusculas: TextCapitalization.words),
                          Campo('Teléfono', _telefono,
                              teclado: TextInputType.phone,
                              pista: '10 dígitos',
                              autollenado: const [AutofillHints.telephoneNumber]),
                        ],
                        Campo('Correo electrónico', _correo,
                            teclado: TextInputType.emailAddress,
                            mayusculas: TextCapitalization.none,
                            autollenado: const [AutofillHints.email],
                            validar: (v) => (v == null || !v.contains('@') || !v.contains('.'))
                                ? 'Escribe un correo válido'
                                : null),
                        Campo('Contraseña', _clave,
                            oculto: !_ver,
                            mayusculas: TextCapitalization.none,
                            autollenado: [_registro ? AutofillHints.newPassword : AutofillHints.password],
                            sufijo: IconButton(
                              icon: Icon(_ver ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _ver = !_ver),
                            ),
                            validar: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
                        if (_registro)
                          Campo('Confirmar contraseña', _clave2,
                              oculto: !_ver,
                              mayusculas: TextCapitalization.none,
                              validar: (v) => v != _clave.text ? 'Las contraseñas no coinciden' : null),
                        if (_error != null) Aviso.alerta(_error!),
                        if (!_registro)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: _cargando ? null : _olvide, child: const Text('¿Olvidaste tu contraseña?')),
                          ),
                        const SizedBox(height: 8),
                        BotonPrincipal(_registro ? 'Crear cuenta' : 'Iniciar sesión', _enviar, cargando: _cargando),
                        const SizedBox(height: 16),
                        Text(
                          _carp
                              ? 'Cada carpintero administra su propia carpintería: sus clientes, pedidos y finanzas solo los ve él.'
                              : 'Puedes pedir cotizaciones a cualquier carpintería registrada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// =====================================================================
// Nueva contraseña (al abrir el enlace de recuperación)
// =====================================================================
class NuevaClave extends StatefulWidget {
  const NuevaClave({super.key});

  @override
  State<NuevaClave> createState() => _NuevaClaveState();
}

class _NuevaClaveState extends State<NuevaClave> {
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _cargando = false;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await sesion.nuevaClave(_clave.text);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const Center(child: Logo(tam: 140)),
              const Titulo('Crea tu nueva contraseña', subtitulo: 'Usa al menos 6 caracteres.'),
              Campo('Nueva contraseña', _clave,
                  oculto: true, validar: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
              Campo('Confirmar contraseña', _clave2,
                  oculto: true, validar: (v) => v != _clave.text ? 'Las contraseñas no coinciden' : null),
              const SizedBox(height: 8),
              BotonPrincipal('Guardar contraseña', _guardar, cargando: _cargando),
            ]),
          ),
        ),
      );
}
