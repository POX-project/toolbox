import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeState {
  final bool isDarkMode;

  const ThemeState({
    this.isDarkMode = false,
  });

  ThemeState copyWith({
    bool? isDarkMode,
  }) {
    return ThemeState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState());

  void toggleDarkMode(bool val) {
    state = state.copyWith(isDarkMode: val);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
