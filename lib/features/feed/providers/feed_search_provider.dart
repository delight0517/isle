import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 피드 제목 클라이언트 검색어
final feedSearchQueryProvider = StateProvider<String>((ref) => '');
