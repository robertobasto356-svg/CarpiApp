
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'state.dart';
import 'widgets.dart';
import 'carpenter.dart';
import 'client.dart';

// =====================================================
// INICIALIZACIÓN DE CARPIAPP Y SUPABASE
// =====================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://koeahqzwxzikzzouoqti.supabase.co',
    publishableKey: 'sb_publishable_yyq8Mksaea_7vkNU-YGiJw_EARagObW',
  );

  // Restaurar sesión guardada
  await app.restoreSession();

  runApp(const CarpiApp());
}

// Cliente global de Supabase
final supabase = Supabase.instance.client;

// =====================================================
// APLICACIÓN PRINCIPAL
// =====================================================

class CarpiApp extends StatelessWidget {
  const CarpiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CARPIAPP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(seedColor: brown),
          appBarTheme: const AppBarTheme(
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            iconTheme: IconThemeData(color: Colors.black),
          ),
        ),
        home: Obs((_) {
          final me = app.me;

          if (me == null) return const RoleScreen();

          final carp = me.role == Role.carpintero;

          return Shell(
            key: ValueKey('${me.email}-${me.role.name}'),
            pages: carp
                ? const [
                    CHome(),
                    OrdersScreen(),
                    VisitsScreen(),
                    ProfileScreen(),
                  ]
                : const [
                    KHome(),
                    MyOrdersScreen(),
                    ClientChatTab(),
                    ProfileScreen(),
                  ],
            labels: carp
                ? const ['Inicio', 'Pedidos', 'Visitas', 'Perfil']
                : const ['Inicio', 'Pedidos', 'Mensajes', 'Perfil'],
            icons: carp
                ? const [
                    Icons.home_outlined,
                    Icons.inventory_2_outlined,
                    Icons.event_outlined,
                    Icons.person_outline,
                  ]
                : const [
                    Icons.home_outlined,
                    Icons.inventory_2_outlined,
                    Icons.chat_bubble_outline,
                    Icons.person_outline,
                  ],
          );
        }),
      );
}

// =====================================================
// SELECCIÓN DE TIPO DE CUENTA
// =====================================================

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  void _go(BuildContext c, Role r) {
    Navigator.push(
      c,
      MaterialPageRoute(
        builder: (_) => AuthScreen(role: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Logo(size: 220),
                const SizedBox(height: 28),
                Btn(
                  'Soy carpintero',
                  () => _go(context, Role.carpintero),
                  color: brown,
                ),
                const SizedBox(height: 12),
                Btn(
                  'Soy cliente',
                  () => _go(context, Role.cliente),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tu madera, tu idea, nuestro oficio.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// =====================================================
// INICIO DE SESIÓN Y REGISTRO
// =====================================================

class AuthScreen extends StatefulWidget {
  final Role role;

  const AuthScreen({
    required this.role,
    super.key,
  });

  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final pass2 = TextEditingController();

  bool signup = false;
  bool loading = false;

  String? error;

  bool get carp => widget.role == Role.carpintero;

  // ---------------------------------------------------
  // REGISTRO E INICIO DE SESIÓN
  // ---------------------------------------------------

  Future<void> _submit() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final err = signup
          ? await app.register(
              name.text,
              email.text,
              pass.text,
              pass2.text,
              widget.role,
            )
          : await app.login(
              email.text,
              pass.text,
              widget.role,
            );

      if (!mounted) return;

      if (err != null) {
        setState(() => error = err);
        return;
      }

      if (signup && app.me == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cuenta creada. Revisa tu correo para confirmar tu registro.',
            ),
          ),
        );
      }

      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Ocurrió un error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ---------------------------------------------------
  // RECUPERAR CONTRASEÑA
  // ---------------------------------------------------

  Future<void> _forgot() async {
    final r = await askFields(
      context,
      'Recuperar contraseña',
      ['Correo electrónico'],
      ok: 'Enviar enlace',
    );

    if (r == null || !mounted) return;

    final errorMessage = await app.resetPassword(
      r[0],
      widget.role,
    );

    if (!mounted) return;

    snack(
      context,
      errorMessage ??
          'Revisa tu correo para recuperar tu contraseña.',
    );
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    pass2.dispose();
    super.dispose();
  }

  // ---------------------------------------------------
  // INTERFAZ
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(
                child: Logo(size: 180),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  signup
                      ? 'Crear cuenta - ${carp ? 'Carpintero' : 'Cliente'}'
                      : (carp
                          ? 'Tu taller, bajo control'
                          : 'Bienvenido a CARPIAPP'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Center(
                child: Text(
                  carp
                      ? 'Acceso para carpinteros y administradores'
                      : 'Diseñamos contigo. Creamos para ti.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (signup)
                Field('Nombre completo', name),

              Field(
                'Correo electrónico',
                email,
                type: TextInputType.emailAddress,
              ),

              Field(
                'Contraseña',
                pass,
                obscure: true,
              ),

              if (signup)
                Field(
                  'Confirmar contraseña',
                  pass2,
                  obscure: true,
                ),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),

              if (!signup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading ? null : _forgot,
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                    ),
                  ),
                ),

              const SizedBox(height: 4),

              Btn(
                loading
                    ? 'Procesando...'
                    : signup
                        ? 'Crear cuenta'
                        : 'Iniciar sesión',
                loading ? () {} : _submit,
                color: green,
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: loading
                    ? null
                    : () {
                        setState(() {
                          signup = !signup;
                          error = null;
                        });
                      },
                child: Text(
                  signup
                      ? 'Ya tengo cuenta'
                      : 'Crear cuenta nueva',
                ),
              ),
            ],
          ),
        ),
      );
}

// =====================================================
// BARRA DE NAVEGACIÓN
// =====================================================

class Shell extends StatefulWidget {
  final List<Widget> pages;
  final List<String> labels;
  final List<IconData> icons;

  const Shell({
    required this.pages,
    required this.labels,
    required this.icons,
    super.key,
  });

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: i,
          children: widget.pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) {
            setState(() => i = v);
          },
          destinations: [
            for (var k = 0; k < widget.labels.length; k++)
              NavigationDestination(
                icon: Icon(widget.icons[k]),
                label: widget.labels[k],
              ),
          ],
        ),
      );
}

// =====================================================
// PERFIL DE USUARIO
// =====================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Obs((c) {
        final me = app.me!;

        final carp = me.role == Role.carpintero;

        Widget row(
          IconData ic,
          String t,
          VoidCallback f, {
          Color? col,
        }) =>
            Box(
              onTap: f,
              child: Row(
                children: [
                  Icon(ic, size: 20, color: col),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(color: col),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            );

        Future<void> edit(
          String title,
          List<String> labels,
          List<String> init,
          void Function(List<String>) save,
        ) async {
          final r = await askFields(
            c,
            title,
            labels,
            initial: init,
          );

          if (r != null) {
            save(r);
            app.update();
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi perfil'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: carp ? brown : green,
                  child: Text(
                    me.name.isNotEmpty
                        ? me.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  me.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Center(
                child: Text(
                  carp ? 'Carpintero' : 'Cliente',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              row(
                Icons.person_outline,
                'Editar perfil',
                () {
                  edit(
                    'Editar perfil',
                    ['Nombre', 'Teléfono'],
                    [me.name, me.phone],
                    (r) {
                      if (r[0].isNotEmpty) me.name = r[0];
                      me.phone = r[1];
                    },
                  );
                },
              ),

              if (carp)
                row(
                  Icons.receipt_long_outlined,
                  'Mis datos fiscales',
                  () {
                    edit(
                      'Datos fiscales',
                      ['RFC'],
                      [me.rfc],
                      (r) => me.rfc = r[0],
                    );
                  },
                )
              else
                row(
                  Icons.location_on_outlined,
                  'Mis direcciones',
                  () {
                    edit(
                      'Mi dirección',
                      ['Dirección de entrega'],
                      [me.address],
                      (r) => me.address = r[0],
                    );
                  },
                ),

              row(
                Icons.credit_card_outlined,
                'Métodos de pago',
                () {
                  edit(
                    'Método de pago',
                    ['Ej. Efectivo, transferencia'],
                    [me.payment],
                    (r) => me.payment = r[0],
                  );
                },
              ),

              row(
                Icons.notifications_none,
                'Notificaciones',
                () {
                  showDialog(
                    context: c,
                    builder: (_) => StatefulBuilder(
                      builder: (d, set) => AlertDialog(
                        title: const Text('Notificaciones'),
                        content: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Avisos de pedidos y mensajes',
                          ),
                          value: me.notifications,
                          onChanged: (v) {
                            me.notifications = v;
                            set(() {});
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              row(
                Icons.help_outline,
                carp ? 'Soporte' : 'Ayuda y soporte',
                () {
                  showDialog(
                    context: c,
                    builder: (d) => AlertDialog(
                      title: const Text('Soporte'),
                      content: const Text(
                        'Escríbenos a soporte@carpiapp.com',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              row(
                Icons.logout,
                'Cerrar sesión',
                () {
                  app.logout();
                },
                col: Colors.red,
              ),
            ],
          ),
        );
      });
}
