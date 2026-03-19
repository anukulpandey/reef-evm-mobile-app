import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_item.dart';
import 'service_providers.dart';

final activityProvider = StreamProvider.autoDispose
    .family<List<ActivityItem>, String>((ref, address) async* {
      final normalizedAddress = address.trim();
      if (normalizedAddress.isEmpty) {
        yield const <ActivityItem>[];
        return;
      }

      final activityService = ref.watch(activityServiceProvider);

      yield await activityService.fetchActivity(normalizedAddress);

      while (true) {
        await Future<void>.delayed(const Duration(seconds: 30));
        yield await activityService.fetchActivity(normalizedAddress);
      }
    });
