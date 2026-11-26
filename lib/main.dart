import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/tema.dart';
import 'core/ui.dart';
import 'datos/sesion.dart';
import 'ui/auth/acceso.dart';
import 'ui/carpintero/inicio_carpintero.dart';
import 'ui/cliente/inicio_cliente.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  Intl.defaultLocale = 'es_MX';
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  await sesion.iniciar();
  runApp(const CarpiApp());
}

class CarpiApp extends StatelessWidget {
  const CarpiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final esCliente = sesion.perfil != null && !sesion.esCarpintero;
        return MaterialApp(
          title: 'CarpiApp',
          debugShowCheckedModeBanner: false,
          theme: construirTema(esCliente ? paletaCliente : paletaCarpintero),
          locale: const Locale('es', 'MX'),
          supportedLocales: const [Locale('es', 'MX'), Locale('es')],
          // Ver core/ui.dart: se mantiene flutter/material hasta que los
          // paquetes de terceros migren a material_ui.
          localizationsDelegates: const [
            // ignore: deprecated_member_use
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            // ignore: deprecated_member_use
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _pantallaInicial(),
        );
      },
    );
  }

  Widget _pantallaInicial() {
    if (sesion.cargando) return const _Arranque();
    if (sesion.recuperandoClave) return const NuevaClave();
    final p = sesion.perfil;
    if (p == null) return const Bienvenida();
    return p.esCarpintero ? ShellCarpintero(key: ValueKey('c-${p.id}')) : ShellCliente(key: ValueKey('k-${p.id}'));
  }
}

class _Arranque extends StatelessWidget {
  const _Arranque();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Logo(tam: 160), SizedBox(height: 24), CircularProgressIndicator.adaptive()],
      ),
    ),
  );
}
