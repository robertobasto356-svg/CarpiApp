import 'package:intl/intl.dart';

final _moneda = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 2);
final _monedaCorta = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);
final _fecha = DateFormat("d 'de' MMMM 'de' y", 'es_MX');
final _fechaCorta = DateFormat('d MMM y', 'es_MX');
final _dia = DateFormat("EEEE d 'de' MMMM", 'es_MX');
final _hora = DateFormat('h:mm a', 'es_MX');
final _mes = DateFormat('MMMM y', 'es_MX');

String dinero(num? v) => _moneda.format(v ?? 0);
String dineroCorto(num? v) => _monedaCorta.format(v ?? 0);
String fechaLarga(DateTime d) => _fecha.format(d);
String fechaCorta(DateTime d) => _fechaCorta.format(d);
String diaLargo(DateTime d) => _capitalizar(_dia.format(d));
String hora(DateTime d) => _hora.format(d);
String mesAnio(DateTime d) => _capitalizar(_mes.format(d));
String fechaHora(DateTime d) => '${fechaCorta(d)} · ${hora(d)}';

String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String primerNombre(String n) {
  final t = n.trim();
  return t.isEmpty ? '' : t.split(RegExp(r'\s+')).first;
}

String iniciales(String n) {
  final partes = n.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}

/// Convierte texto como "1,250.50" o "1250,5" a número.
double? aNumero(String s) {
  final limpio = s.replaceAll(RegExp(r'[^0-9.,-]'), '');
  if (limpio.isEmpty) return null;
  final normal = limpio.contains('.')
      ? limpio.replaceAll(',', '')
      : limpio.replaceAll(',', '.');
  return double.tryParse(normal);
}

/// Muestra un número sin decimales innecesarios ("75", "75.5").
String numeroCorto(num? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Hace legibles los errores de Supabase/Postgres para el usuario.
String mensajeError(Object e) {
  final t = e.toString();
  final m = RegExp(r'message:\s*([^,}]+)').firstMatch(t);
  final base = (m?.group(1) ?? t).replaceAll('Exception: ', '').trim();
  if (base.contains('Invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (base.contains('Email not confirmed')) {
    return 'Confirma tu correo antes de iniciar sesión.';
  }
  if (base.contains('User already registered')) {
    return 'Ya existe una cuenta con ese correo.';
  }
  if (base.contains('rate limit') || base.contains('over_email_send_rate_limit')) {
    return 'Se enviaron demasiados correos. Intenta de nuevo en unos minutos.';
  }
  if (base.contains('SocketException') || base.contains('Failed host lookup')) {
    return 'Sin conexión a internet.';
  }
  return base;
}
