import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_awesome_icon/awesome_icons.dart';

import '../widgets/app_awesome_icon.dart';
import 'diagnostics_screen.dart';
import 'phone_info_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<AnimationController> _scaleControllers;
  late final List<Animation<double>> _scaleAnimations;

  final List<Widget> _screens = const [
    PhoneInfoScreen(),
    DiagnosticsScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _scaleControllers = List.generate(4, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 150),
      );
    });
    _scaleAnimations = _scaleControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutCubic),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _scaleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
    ref.read(homeTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Main Page Content
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),

          // Floating Capsule Dock
          Positioned(
            left: 28,
            right: 28,
            bottom: bottomInset > 0 ? bottomInset + 8 : 22,
            child: _buildEditorialDock(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialDock() {
    final navItems = [
      _NavItem(
        outlineIcon: AwesomeIcons.electronicsCpuSettingOutline,
        boldIcon: AwesomeIcons.electronicsCpuSettingBold,
        label: 'Intel',
      ),
      _NavItem(
        outlineIcon: AwesomeIcons.businessActivityOutline,
        boldIcon: AwesomeIcons.businessActivityBold,
        label: 'Diagnostics',
      ),
      _NavItem(
        outlineIcon: AwesomeIcons.grid3squareOutline,
        boldIcon: AwesomeIcons.grid3squareBold,
        label: 'Tools',
      ),
      _NavItem(
        outlineIcon: AwesomeIcons.setting2Outline,
        boldIcon: AwesomeIcons.setting2Bold,
        label: 'Settings',
      ),
    ];

    // ── Dock geometry ──
    // Dock outer height = circleSize + 2 * verticalPadding
    // With circle=52 and vPad=10 → dockHeight=72
    const double circleSize = 52.0;
    const double vPad = 10.0;
    const double dockHeight = circleSize + (vPad * 2);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: dockHeight,
      padding: const EdgeInsets.symmetric(horizontal: vPad, vertical: vPad),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2126) : const Color(0xFF141618),
        borderRadius: BorderRadius.circular(dockHeight / 2),
        border: Border.all(
          color: isDark ? const Color(0xFF2E333D) : const Color(0x22000000),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(navItems.length, (index) {
          final item = navItems[index];
          final isSelected = _currentIndex == index;

          return GestureDetector(
            onTapDown: (_) => _scaleControllers[index].forward(),
            onTapUp: (_) {
              _scaleControllers[index].reverse();
              _onTabTapped(index);
            },
            onTapCancel: () => _scaleControllers[index].reverse(),
            behavior: HitTestBehavior.opaque,
            child: ScaleTransition(
              scale: _scaleAnimations[index],
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppAwesomeIcon(
                    icon: isSelected ? item.boldIcon : item.outlineIcon,
                    isBold: isSelected,
                    color: isSelected
                        ? const Color(0xFF141618)
                        : Colors.white.withValues(alpha: 0.80),
                    size: 22,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final String outlineIcon;
  final String boldIcon;
  final String label;

  const _NavItem({
    required this.outlineIcon,
    required this.boldIcon,
    required this.label,
  });
}
