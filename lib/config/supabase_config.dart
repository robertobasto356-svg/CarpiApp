
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://koeahqzwxzikzzouoqti.supabase.co/rest/v1/';

  static const String supabasePublishableKey =
      'sb_publishable_yyq8Mksaea_7vkNU-YGiJw_EARagObW';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
