import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

/// ==========================================
/// 1. Screen & OLED Uniformity Tester Screen
/// ==========================================
class ScreenTesterScreen extends StatefulWidget {
  const ScreenTesterScreen({super.key});

  @override
  State<ScreenTesterScreen> createState() => _ScreenTesterScreenState();
}

class _ScreenTesterScreenState extends State<ScreenTesterScreen> {
  int _colorIndex = 0;
  final List<Color> _colors = const [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.white,
    Colors.black,
    Color(0xFF808080),
    Colors.amber,
    Colors.cyan,
    Colors.purple,
  ];

  final List<String> _colorNames = const [
    'Pure Red (Primary Test)',
    'Pure Green (Primary Test)',
    'Pure Blue (Primary Test)',
    'Pure White (Uniformity & Tint)',
    'True Black (OLED Dead Pixel Check)',
    '50% Gray (Gamma & Banding)',
    'Amber (Warm Gamut)',
    'Cyan (Cool Gamut)',
    'Magenta (Spectrum Test)',
  ];

  @override
  Widget build(BuildContext context) {
    final currentColor = _colors[_colorIndex];
    final isDark = currentColor == Colors.black || currentColor.computeLuminance() < 0.4;
    final textColor = isDark ? Colors.white : const Color(0xFF111111);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _colorIndex = (_colorIndex + 1) % _colors.length;
        });
      },
      child: Scaffold(
        backgroundColor: currentColor,
        body: Stack(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _colorNames[_colorIndex],
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tap screen to switch (${_colorIndex + 1}/${_colors.length})',
                      style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 48,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==========================================
/// 2. Multi-Touch Screen Tester
/// ==========================================
class MultiTouchTesterScreen extends StatefulWidget {
  const MultiTouchTesterScreen({super.key});

  @override
  State<MultiTouchTesterScreen> createState() => _MultiTouchTesterScreenState();
}

class _MultiTouchTesterScreenState extends State<MultiTouchTesterScreen> {
  final Map<int, Offset> _pointerPositions = {};

  final List<Color> _pointerColors = const [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text('Multi-Touch Pointer Tester', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
      ),
      body: Listener(
        onPointerDown: (event) {
          setState(() {
            _pointerPositions[event.pointer] = event.localPosition;
          });
        },
        onPointerMove: (event) {
          setState(() {
            _pointerPositions[event.pointer] = event.localPosition;
          });
        },
        onPointerUp: (event) {
          setState(() {
            _pointerPositions.remove(event.pointer);
          });
        },
        onPointerCancel: (event) {
          setState(() {
            _pointerPositions.remove(event.pointer);
          });
        },
        child: Stack(
          children: [
            Container(color: theme.scaffoldBackgroundColor),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_pointerPositions.length}',
                    style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
                  ),
                  Text(
                    'ACTIVE TOUCH POINTS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.getSecondaryText(context), letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Place multiple fingers on screen to test multi-touch tracking.',
                    style: TextStyle(fontSize: 13, color: AppTheme.getSecondaryText(context)),
                  ),
                ],
              ),
            ),
            ..._pointerPositions.entries.map((entry) {
              final color = _pointerColors[entry.key % _pointerColors.length];
              return Positioned(
                left: entry.value.dx - 40,
                top: entry.value.dy - 40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      '#${entry.key + 1}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// ==========================================
/// 3. Haptic & Vibration Tester Screen
/// ==========================================
class HapticTesterScreen extends StatelessWidget {
  const HapticTesterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text('Haptic & Vibration Tester', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FEEDBACK MOTOR PATTERNS',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppTheme.getSecondaryText(context)),
              ),
              const SizedBox(height: 14),
              _buildHapticCard(context, 'Light Impact Click', 'Subtle haptic tick for delicate interactions', () {
                HapticFeedback.lightImpact();
              }),
              const SizedBox(height: 10),
              _buildHapticCard(context, 'Medium Impact Pulse', 'Standard tactile feedback for buttons', () {
                HapticFeedback.mediumImpact();
              }),
              const SizedBox(height: 10),
              _buildHapticCard(context, 'Heavy Impact Pulse', 'Strong motor impulse for confirmations', () {
                HapticFeedback.heavyImpact();
              }),
              const SizedBox(height: 10),
              _buildHapticCard(context, 'Vibrate Alert Pattern', 'Continuous standard vibration waveform', () {
                HapticFeedback.vibrate();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHapticCard(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.vibration_rounded, color: isDark ? theme.colorScheme.onSurface : Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: AppTheme.getSecondaryText(context))),
              ],
            ),
          ),
          Icon(Icons.play_circle_fill_rounded, color: theme.colorScheme.onSurface, size: 26),
        ],
      ),
    );
  }
}

/// ==========================================
/// 4. Stereo Audio Channel Tester Screen
/// ==========================================
class AudioChannelTesterScreen extends StatelessWidget {
  const AudioChannelTesterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text('Stereo Audio Speaker Test', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPEAKER CHANNELS',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppTheme.getSecondaryText(context)),
              ),
              const SizedBox(height: 14),
              GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.headphones_rounded, size: 48, color: theme.colorScheme.onSurface),
                    const SizedBox(height: 12),
                    Text(
                      'Speaker Channel Separation',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify left and right audio channels and balance output.',
                      style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
                              foregroundColor: isDark ? theme.colorScheme.onSurface : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.volume_down_rounded, size: 18),
                            label: const Text('Left Ear', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              SystemSound.play(SystemSoundType.click);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
                              foregroundColor: isDark ? theme.colorScheme.onSurface : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.volume_up_rounded, size: 18),
                            label: const Text('Right Ear', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              SystemSound.play(SystemSoundType.alert);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==========================================
/// 5. Accelerometer G-Force Monitor Screen
/// ==========================================
class AccelerometerMonitorScreen extends StatefulWidget {
  const AccelerometerMonitorScreen({super.key});

  @override
  State<AccelerometerMonitorScreen> createState() => _AccelerometerMonitorScreenState();
}

class _AccelerometerMonitorScreenState extends State<AccelerometerMonitorScreen> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double _x = 0;
  double _y = 0;
  double _z = 0;

  @override
  void initState() {
    super.initState();
    try {
      _sub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _x = event.x;
          _y = event.y;
          _z = event.z;
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text('3-Axis Accelerometer Live', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIVE SENSOR VECTORS (m/s²)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AppTheme.getSecondaryText(context)),
              ),
              const SizedBox(height: 14),
              _buildAxisCard(context, 'X-AXIS (Lateral G)', _x, const Color(0xFF3B82F6)),
              const SizedBox(height: 10),
              _buildAxisCard(context, 'Y-AXIS (Longitudinal G)', _y, const Color(0xFF10B981)),
              const SizedBox(height: 10),
              _buildAxisCard(context, 'Z-AXIS (Vertical Gravitational G)', _z, const Color(0xFFF59E0B)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAxisCard(BuildContext context, String label, double val, Color color) {
    final progress = ((val + 19.6) / 39.2).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.getSecondaryText(context))),
              Text('${val.toStringAsFixed(2)} m/s²', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? const Color(0xFF2A2E37) : const Color(0xFFF1F3F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
