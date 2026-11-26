import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/supa.dart';
import '../core/ui.dart';
import '../modelos/modelos.dart';

/// Estado de la sesión: perfil del usuario y, si es carpintero, su carpintería.
class Sesion extends ChangeNotifier {
  Perfil? perfil;
  Carpinteria? carpinteria;
  bool cargando = true;
  bool recuperandoClave = false;
  String? error;
  StreamSubscription<AuthState>? _sub;

  bool get conSesion => perfil != null;
  bool get esCarpintero => perfil?.esCarpintero ?? false;

  Future<void> iniciar() async {
    _sub = supa.auth.onAuthStateChange.listen((datos) async {
      if (datos.event == AuthChangeEvent.passwordRecovery) {
        recuperandoClave = true;
      }
      if (datos.event == AuthChangeEvent.signedIn ||
          datos.event == AuthChangeEvent.signedOut ||
          datos.event == AuthChangeEvent.userUpdated ||
          datos.event == AuthChangeEvent.passwordRecovery) {
        await recargar();
      }
    });
    await recargar();
  }

  Future<void> recargar() async {
    final usuario = supa.auth.currentUser;
    if (usuario == null) {
      perfil = null;
      carpinteria = null;
      cargando = false;
      notifyListeners();
      return;
    }
    try {
      // El perfil lo crea un trigger al registrarse; reintenta por si tarda.
      Map<String, dynamic>? fila;
      for (var i = 0; i < 3 && fila == null; i++) {
        fila = await supa.from('perfiles').select().eq('id', usuario.id).maybeSingle();
        if (fila == null) await Future<void>.delayed(const Duration(milliseconds: 600));
      }
      if (fila == null) {
        error = 'No se encontró tu perfil. Cierra sesión e inicia de nuevo.';
        perfil = null;
      } else {
        perfil = Perfil.desde(fila);
        error = null;
        if (perfil!.esCarpintero) {
          final k = await supa.from('carpinterias').select().eq('propietario_id', usuario.id).maybeSingle();
          carpinteria = k == null ? null : Carpinteria.desde(k);
        } else {
          carpinteria = null;
        }
      }
    } catch (e) {
      error = e.toString();
    }
    cargando = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Autenticación
  // ------------------------------------------------------------------
  Future<bool> registrar({
    required String nombre,
    required String correo,
    required String clave,
    required String rol,
    String telefono = '',
    String nombreCarpinteria = '',
  }) async {
    final r = await supa.auth.signUp(
      email: correo.trim().toLowerCase(),
      password: clave,
      emailRedirectTo: Config.enlaceApp,
      data: {
        'nombre': nombre.trim(),
        'tipo_cuenta': rol,
        'telefono': telefono.trim(),
        if (nombreCarpinteria.trim().isNotEmpty) 'nombre_carpinteria': nombreCarpinteria.trim(),
      },
    );
    // true = sesión iniciada; false = falta confirmar el correo.
    return r.session != null;
  }

  /// Devuelve un mensaje si la cuenta no corresponde al tipo elegido.
  Future<String?> entrar(String correo, String clave, String rol) async {
    await supa.auth.signInWithPassword(email: correo.trim().toLowerCase(), password: clave);
    await recargar();
    if (perfil != null && perfil!.rol != rol) {
      final real = perfil!.esCarpintero ? 'carpintero' : 'cliente';
      await salir();
      return 'Esta cuenta es de $real. Entra desde "Soy $real".';
    }
    return null;
  }

  Future<void> recuperarClave(String correo) =>
      supa.auth.resetPasswordForEmail(correo.trim().toLowerCase(), redirectTo: Config.enlaceApp);

  Future<void> nuevaClave(String clave) async {
    await supa.auth.updateUser(UserAttributes(password: clave));
    recuperandoClave = false;
    notifyListeners();
  }

  Future<void> salir() async {
    await supa.auth.signOut();
    perfil = null;
    carpinteria = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Perfil y carpintería
  // ------------------------------------------------------------------
  Future<void> guardarPerfil(Map<String, dynamic> cambios) async {
    await supa.from('perfiles').update(cambios).eq('id', perfil!.id);
    await recargar();
  }

  Future<void> guardarCarpinteria(Map<String, dynamic> cambios) async {
    await supa.from('carpinterias').update(cambios).eq('id', carpinteria!.id);
    await recargar();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final sesion = Sesion();
