import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 클라이언트 접근 헬퍼
class SupabaseService {
  SupabaseService._();
  static SupabaseClient get client => Supabase.instance.client;
}
