import 'package:cari_takip/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// main() içinde açılmış örnekle override edilir.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(
    'appDatabaseProvider, main() içinde override edilmelidir.',
  ),
);
