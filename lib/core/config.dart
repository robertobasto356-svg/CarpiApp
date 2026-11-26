/// Configuración del proyecto de Supabase.
///
/// La llave publicable es segura en la app: el acceso a los datos lo controla
/// la seguridad por filas (RLS) de la base. Nunca pongas aquí la llave
/// `service_role` ni la llave secreta.
///
/// Se pueden sobrescribir al compilar con:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
class Config {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://koeahqzwxzikzzouoqti.supabase.co',
  );

  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_yyq8Mksaea_7vkNU-YGiJw_EARagObW',
  );

  /// Enlace profundo para confirmar correo y recuperar contraseña.
  /// Debe estar en Supabase → Authentication → URL Configuration → Redirect URLs.
  static const enlaceApp = 'io.carpiapp://login-callback';

  /// Carpeta pública con los modelos 3D de referencia (bucket `modelos`).
  static String modelo(String archivo) => '$supabaseUrl/storage/v1/object/public/modelos/$archivo';

  static const correoSoporte = 'soporte@carpiapp.mx';
}
