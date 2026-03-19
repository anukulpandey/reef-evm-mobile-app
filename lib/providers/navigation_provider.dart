import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (index < 0) return;
    state = index;
  }

  void goHome() => state = 0;
}

final navigationTabProvider = NotifierProvider<NavigationTabNotifier, int>(
  NavigationTabNotifier.new,
);
