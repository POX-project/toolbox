import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/command_runner.dart';
import '../services/device_health_service.dart';
import '../services/info_service.dart';
import '../theme/app_theme.dart';

/// Opens the Privilege Mode selection and diagnostic bottom sheet.
void showPrivilegeModeModal(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _PrivilegeModeSheet(),
  );
}

class _PrivilegeModeSheet extends ConsumerStatefulWidget {
  const _PrivilegeModeSheet();

  @override
  ConsumerState<_PrivilegeModeSheet> createState() => _PrivilegeModeSheetState();
}

class _PrivilegeModeSheetState extends ConsumerState<_PrivilegeModeSheet> {
  bool _isRechecking = false;

  Future<void> _applyAndRecheck(PrivilegeModePreference pref) async {
    setState(() => _isRechecking = true);
    HapticFeedback.mediumImpact();

    ref.read(privilegeModePreferenceProvider.notifier).state = pref;
    ref.invalidate(privilegeStatusProvider);
    ref.invalidate(deviceHealthReportProvider);
    ref.invalidate(androidInfoProvider);
    ref.invalidate(cpuInfoProvider);
    ref.invalidate(memInfoProvider);
    ref.invalidate(gpuInfoProvider);
    ref.invalidate(batteryInfoProvider);
    ref.invalidate(networkInfoProvider);
    ref.invalidate(storageInfoProvider);

    try {
      final updatedStatus = await ref.read(privilegeStatusProvider.future);
      if (mounted) {
        setState(() => _isRechecking = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Privilege Mode active: ${updatedStatus.label}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRechecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardTheme.color ?? (isDark ? const Color(0xFF161922) : Colors.white);
    final borderColor = theme.colorScheme.outline;

    final currentPriv = ref.watch(privilegeStatusProvider);
    final currentPref = ref.watch(privilegeModePreferenceProvider);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  currentPriv.value?.hasPrivilege == true ? Icons.security_rounded : Icons.lock_outline_rounded,
                  color: isDark ? theme.colorScheme.onSurface : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privilege & Execution Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentPriv.when(
                        data: (s) => 'Active: ${s.label}',
                        loading: () => 'Detecting system privileges...',
                        error: (err, stack) => 'Status detection error',
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: currentPriv.value?.hasPrivilege == true
                            ? const Color(0xFF10B981)
                            : AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            'Select how Toolbox executes diagnostics, hardware inspection, and system commands. Changes take effect immediately across all subsystems.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 18),

          // Preference Options
          ...PrivilegeModePreference.values.map((pref) {
            final isSelected = pref == currentPref;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                    : (isDark ? const Color(0xFF0F1218) : const Color(0xFFF9FAFB)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : borderColor,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _applyAndRecheck(pref);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? theme.colorScheme.primary : AppTheme.getSecondaryText(context),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pref.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pref.description,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.getSecondaryText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 12),

          // Recheck & Refresh Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
                foregroundColor: isDark ? theme.colorScheme.onSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
              icon: _isRechecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _isRechecking ? 'Re-detecting Privileges...' : 'Recheck System Privileges',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              onPressed: _isRechecking ? null : () => _applyAndRecheck(currentPref),
            ),
          ),
        ],
      ),
    );
  }
}
