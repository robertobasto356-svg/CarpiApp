
import '../config/supabase_config.dart';

class AuthService {
  final _supabase = SupabaseConfig.client;

  // Registrar usuario
  Future<void> register({
    required String email,
    required String password,
    required String nombre,
    required String tipoCuenta,
    String? telefono,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'nombre': nombre,
        'tipo_cuenta': tipoCuenta,
        'telefono': telefono,
      },
    );

    if (response.user == null) {
      throw Exception('No se pudo completar el registro.');
    }
  }

  // Iniciar sesión
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('No se pudo iniciar sesión.');
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Obtener usuario actual
  User? get currentUser => _supabase.auth.currentUser;

  // Comprobar sesión
  bool get isLoggedIn => currentUser != null;
}
