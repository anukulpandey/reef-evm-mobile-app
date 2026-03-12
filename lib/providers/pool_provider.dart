import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pool.dart';
import 'service_providers.dart';

final poolsProvider = FutureProvider<List<Pool>>((ref) async {
  final poolService = ref.read(poolServiceProvider);
  return await poolService.getPools();
});
