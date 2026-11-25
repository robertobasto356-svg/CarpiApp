import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente global de Supabase (se inicializa en main.dart).
SupabaseClient get supa => Supabase.instance.client;

String? get miId => supa.auth.currentUser?.id;
