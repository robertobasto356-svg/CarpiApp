
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================
// ENUMERACIONES
// =====================================================

enum Role { carpintero, cliente }

enum JobStatus {
  solicitada,
  cotizada,
  enProceso,
  porEntregar,
  entregado,
  rechazada
}

extension JobStatusX on JobStatus {
  String get label => const {
        JobStatus.solicitada: 'Por cotizar',
        JobStatus.cotizada: 'Cotizada',
        JobStatus.enProceso: 'En proceso',
        JobStatus.porEntregar: 'Por entregar',
        JobStatus.entregado: 'Entregado',
        JobStatus.rechazada: 'Rechazada',
      }[this]!;

  Color get color => const {
        JobStatus.solicitada: Colors.blueGrey,
        JobStatus.cotizada: Colors.blue,
        JobStatus.enProceso: Colors.orange,
        JobStatus.porEntregar: Colors.purple,
        JobStatus.entregado: Colors.green,
        JobStatus.rechazada: Colors.red,
      }[this]!;
}

// =====================================================
// MODELO DE USUARIO
// =====================================================

class AppUser {
  String name;
  final String email;
  String password;
  final Role role;

  String phone = '';
  String address = '';
  String rfc = '';
  String payment = '';
  bool notifications = true;

  AppUser(
    this.name,
    this.email,
    this.password,
    this.role,
  );
}

// =====================================================
// MODELO DE PEDIDO
// =====================================================

class Job {
  final int id;

  String title, type, clientEmail, clientName;
  String material, color, desc, w, h, d;

  int images;
  double? price;
  JobStatus status;
  double progress;

  final DateTime date;

  bool inCatalog;
  int? rating;
  String opinion;

  Job({
    required this.id,
    required this.title,
    required this.type,
    required this.clientEmail,
    required this.clientName,
    this.material = '',
    this.color = '',
    this.desc = '',
    this.w = '',
    this.h = '',
    this.d = '',
    this.images = 0,
    this.price,
    this.status = JobStatus.solicitada,
    this.progress = 0,
    DateTime? date,
    this.inCatalog = false,
    this.rating,
    this.opinion = '',
  }) : date = date ?? DateTime.now();

  String get code => '#P-${id.toString().padLeft(3, '0')}';
}

// =====================================================
// MODELO DE VISITA
// =====================================================

class Visit {
  final String client;
  final String note;
  final DateTime date;
  final TimeOfDay time;

  Visit(this.client, this.note, this.date, this.time);

  DateTime get at => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
}

// =====================================================
// MODELO DE INVENTARIO
// =====================================================

class Item {
  String name;
  int qty;
  final bool isTool;

  Item(this.name, this.qty, this.isTool);
}

// =====================================================
// MODELO DE GASTOS
// =====================================================

class Expense {
  final String concept;
  final double amount;
  final DateTime date;

  Expense(this.concept, this.amount, this.date);
}

// =====================================================
// MODELO DE MENSAJES
// =====================================================

class Msg {
  final String clientEmail;
  final String text;
  final Role from;
  final DateTime time;

  Msg(this.clientEmail, this.from, this.text, this.time);
}

// =====================================================
// ESTADO PRINCIPAL
// =====================================================

class AppState extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;

  final users = <AppUser>[];
  final jobs = <Job>[];
  final visits = <Visit>[];
  final items = <Item>[];
  final expenses = <Expense>[];
  final msgs = <Msg>[];
  final favs = <String, Set<int>>{};

  AppUser? me;

  int _next = 1;

  int nextId() => _next++;

  void update() => notifyListeners();

  bool get isLoggedIn => _supabase.auth.currentUser != null;

  // ===================================================
  // CONVERTIR USUARIO
  // ===================================================

  AppUser? _convertUser(User? user) {
    if (user == null) return null;

    final metadata = user.userMetadata ?? {};

    final roleText = metadata['tipo_cuenta']?.toString();

    Role? role;

    for (final item in Role.values) {
      if (item.name == roleText) {
        role = item;
        break;
      }
    }

    if (role == null) return null;

    final appUser = AppUser(
      metadata['nombre']?.toString() ?? 'Usuario',
      user.email ?? '',
      '',
      role,
    );

    appUser.phone = metadata['telefono']?.toString() ?? '';
    appUser.address = metadata['direccion']?.toString() ?? '';

    return appUser;
  }

  // ===================================================
  // RESTAURAR SESIÓN
  // ===================================================

  Future<void> restoreSession() async {
    try {
      final user = _supabase.auth.currentUser;

      me = _convertUser(user);

      if (me != null) {
        users.removeWhere((u) => u.email == me!.email);
        users.add(me!);
      }
    } catch (e) {
      debugPrint('Error restaurando sesión: $e');
      me = null;
    }

    notifyListeners();
  }

  // ===================================================
  // REGISTRAR USUARIO
  // ===================================================

  Future<String?> register(
    String name,
    String email,
    String password,
    String password2,
    Role role,
  ) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (name.trim().isEmpty) {
        return 'Escribe tu nombre completo.';
      }

      if (!normalizedEmail.contains('@')) {
        return 'Introduce un correo válido.';
      }

      if (password.length < 6) {
        return 'La contraseña debe tener al menos 6 caracteres.';
      }

      if (password != password2) {
        return 'Las contraseñas no coinciden.';
      }

      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'nombre': name.trim(),
          'tipo_cuenta': role.name,
          'telefono': '',
          'direccion': '',
        },
      );

      if (response.user == null) {
        return 'No se pudo crear la cuenta.';
      }

      if (response.session != null) {
        final user = _convertUser(response.user);

        if (user == null) {
          return 'La cuenta se creó, pero falta configurar su tipo.';
        }

        me = user;
        users.removeWhere((u) => u.email == user.email);
        users.add(user);

        notifyListeners();

        return null;
      }

      return 'CUENTA_PENDIENTE_CONFIRMACION';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('Error de registro: $e');
      return 'Error al registrar la cuenta: $e';
    }
  }

  // ===================================================
  // INICIAR SESIÓN
  // ===================================================

  Future<String?> login(
    String email,
    String password,
    Role role,
  ) async {
    try {
      if (email.trim().isEmpty || password.isEmpty) {
        return 'Completa el correo y la contraseña.';
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = _convertUser(response.user);

      if (user == null) {
        await _supabase.auth.signOut();
        return 'No se encontró el tipo de cuenta. Verifica tu perfil.';
      }

      if (user.role != role) {
        await _supabase.auth.signOut();
        return 'Esta cuenta no corresponde al tipo seleccionado.';
      }

      me = user;

      users.removeWhere((u) => u.email == user.email);
      users.add(user);

      notifyListeners();

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('Error de inicio de sesión: $e');
      return 'Error al iniciar sesión: $e';
    }
  }

  // ===================================================
  // RECUPERAR CONTRASEÑA
  // ===================================================

  Future<String?> resetPassword(
    String email,
    Role role,
  ) async {
    try {
      if (email.trim().isEmpty || !email.contains('@')) {
        return 'Introduce un correo electrónico válido.';
      }

      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
      );

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo recuperar la contraseña: $e';
    }
  }

  // ===================================================
  // ACTUALIZAR PERFIL
  // ===================================================

  Future<String?> updateProfile({
    String? name,
    String? phone,
    String? address,
  }) async {
    try {
      if (me == null) return 'No hay una sesión iniciada.';

      final currentMetadata =
          _supabase.auth.currentUser?.userMetadata ?? {};

      final metadata = {
        ...currentMetadata,
        if (name != null) 'nombre': name,
        if (phone != null) 'telefono': phone,
        if (address != null) 'direccion': address,
      };

      await _supabase.auth.updateUser(
        UserAttributes(data: metadata),
      );

      if (name != null) me!.name = name;
      if (phone != null) me!.phone = phone;
      if (address != null) me!.address = address;

      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo actualizar el perfil: $e';
    }
  }

  // ===================================================
  // CERRAR SESIÓN
  // ===================================================

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      me = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
  }

  // ===================================================
  // PEDIDOS (TEMPORALES)
  // ===================================================

  void addJob(Job job) {
    jobs.add(job);
    notifyListeners();
  }

  List<Job> get orders => jobs
      .where((j) =>
          j.status == JobStatus.enProceso ||
          j.status == JobStatus.porEntregar ||
          j.status == JobStatus.entregado)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<Job> get quotes => jobs
      .where((j) =>
          j.status == JobStatus.solicitada ||
          j.status == JobStatus.cotizada ||
          j.status == JobStatus.rechazada)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  List<Job> get catalog =>
      jobs.where((j) => j.inCatalog && j.price != null).toList();

  // ===================================================
  // CLIENTES
  // ===================================================

  List<AppUser> get clients =>
      users.where((u) => u.role == Role.cliente).toList();

  AppUser? clientByName(String name) {
    for (final user in clients) {
      if (user.name.toLowerCase() == name.trim().toLowerCase()) {
        return user;
      }
    }

    return null;
  }

  List<Job> jobsOf(String email) => jobs
      .where((j) => j.clientEmail == email)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  // ===================================================
  // FAVORITOS
  // ===================================================

  Set<int> get myFavs {
    if (me == null) return <int>{};
    return favs.putIfAbsent(me!.email, () => <int>{});
  }

  // ===================================================
  // MENSAJES
  // ===================================================

  List<Msg> thread(String email) =>
      msgs.where((m) => m.clientEmail == email).toList();
}

// =====================================================
// INSTANCIA GLOBAL
// =====================================================

final app = AppState();
