import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../services/command_runner.dart';
import '../services/info_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/privilege_mode_modal.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privilegeAsync = ref.watch(privilegeStatusProvider);
    final modePref = ref.watch(privilegeModePreferenceProvider);
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = themeState.isDarkMode;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREFERENCES & SYSTEM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section 1: Appearance & Display
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('APPEARANCE & DISPLAY', context),
                    const SizedBox(height: 12),
                    GlassContainer(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFFF1F3F5) : const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: isDark ? const Color(0xFF111111) : Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dark Mode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  isDark ? 'Obsidian dark palette active' : 'Clean high-contrast light mode',
                                  style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isDark,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              HapticFeedback.mediumImpact();
                              ref.read(themeProvider.notifier).toggleDarkMode(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section 2: Environment & Privileges
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('SYSTEM ENVIRONMENT', context),
                    const SizedBox(height: 12),
                    GlassContainer(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFFF1F3F5) : const Color(0xFF111111),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.security_rounded,
                                  color: isDark ? const Color(0xFF111111) : Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      privilegeAsync.value?.label ?? 'Checking status...',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: theme.colorScheme.onSurface),
                                    ),
                                    Text(
                                      privilegeAsync.value?.description ?? 'Sandboxed mode',
                                      style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Preference: ${modePref.label}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.colorScheme.outline, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                foregroundColor: theme.colorScheme.onSurface,
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Configure Mode & Recheck', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              onPressed: () => showPrivilegeModeModal(context, ref),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section 2: Data & Reports
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('DATA & REPORTS', context),
                    const SizedBox(height: 12),
                    GlassContainer(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(20),
                      onTap: () => _exportFullReport(context, ref),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF22262E) : const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.description_outlined, color: theme.colorScheme.onSurface, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Export Complete Report',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: theme.colorScheme.onSurface),
                                ),
                                Text(
                                  'Copies full system specification summary',
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.getSecondaryText(context)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppTheme.getSecondaryText(context), size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Section 3: About App
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('ABOUT', context),
                    const SizedBox(height: 12),
                    GlassContainer(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFFF1F3F5) : const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.terminal_rounded, color: isDark ? const Color(0xFF111111) : Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Toolbox Intelligence',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: theme.colorScheme.onSurface),
                                ),
                                Text(
                                  'Version 1.0.0 • Editorial Design',
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.getSecondaryText(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppTheme.getSecondaryText(context),
      ),
    );
  }

  void _exportFullReport(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final androidInfo = ref.read(androidInfoProvider).value;
    final cpuInfo = ref.read(cpuInfoProvider).value;
    final memInfo = ref.read(memInfoProvider).value;
    final gpuInfo = ref.read(gpuInfoProvider).value;
    final batteryInfo = ref.read(batteryInfoProvider).value;
    final networkInfo = ref.read(networkInfoProvider).value;

    final buffer = StringBuffer();
    buffer.writeln('# 📱 System Intel Report - Toolbox');
    buffer.writeln('');
    buffer.writeln('### Device Specifications');
    buffer.writeln('- **Model**: ${androidInfo?.model ?? "Unknown"}');
    buffer.writeln('- **Manufacturer**: ${androidInfo?.manufacturer ?? "Unknown"}');
    buffer.writeln('- **Android Release**: ${androidInfo?.version.release ?? "Unknown"}');
    buffer.writeln('- **SDK**: ${androidInfo?.version.sdkInt ?? "Unknown"}');
    buffer.writeln('');
    buffer.writeln('### Hardware & SoC');
    if (cpuInfo != null) {
      for (final e in cpuInfo.entries) {
        buffer.writeln('- **${e.key}**: ${e.value}');
      }
    }
    if (gpuInfo != null) {
      for (final e in gpuInfo.entries) {
        buffer.writeln('- **${e.key}**: ${e.value}');
      }
    }
    buffer.writeln('');
    buffer.writeln('### Memory & Power');
    if (memInfo != null) {
      for (final e in memInfo.entries) {
        buffer.writeln('- **${e.key}**: ${e.value}');
      }
    }
    if (batteryInfo != null) {
      for (final e in batteryInfo.entries) {
        buffer.writeln('- **${e.key}**: ${e.value}');
      }
    }
    buffer.writeln('');
    buffer.writeln('### Connectivity');
    if (networkInfo != null) {
      for (final e in networkInfo.entries) {
        buffer.writeln('- **${e.key}**: ${e.value}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Complete system report copied to clipboard!'),
      ),
    );
  }
}
