import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'tools/device_manager_screen.dart';
import 'tools/file_manager_screen.dart';
import 'tools/partition_manager_screen.dart';
import 'tools/task_manager_screen.dart';
import 'tools/adb_tools_screen.dart';
import 'tools/fastboot_tools_screen.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  @override
  Widget build(BuildContext context) {
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
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    final secColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY UTILITIES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: secColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Interactive Toolkit',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // System Power Tools Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final secColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
                    return Text(
                      'SYSTEM MANAGERS & POWER TOOLS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: secColor,
                      ),
                    );
                  },
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildListDelegate([
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.developer_board_rounded,
                    title: 'Device Manager',
                    description: 'Hardware tree & HAL drivers',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceManagerScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.memory_rounded,
                    title: 'Task Manager',
                    description: 'Processes, CPU & kill task',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskManagerScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.pie_chart_rounded,
                    title: 'Partition Manager',
                    description: 'Block tables, mounts & TRIM',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PartitionManagerScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.snippet_folder_rounded,
                    title: 'File Manager',
                    description: 'Root & storage VFS explorer',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FileManagerScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.terminal_rounded,
                    title: 'ADB Toolkit',
                    description: 'Wireless, OTG & power console',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdbToolsScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.flash_on_rounded,
                    title: 'Fastboot Toolkit',
                    description: 'Bootloader, AVB & flasher',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FastbootToolsScreen()));
                    },
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Tools Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final secColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
                    return Text(
                      'HANDY TOOLS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: secColor,
                      ),
                    );
                  },
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildListDelegate([
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.explore_rounded,
                    title: 'Spirit Bubble Level',
                    description: 'Real-time 2D level',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BubbleLevelScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.square_foot_rounded,
                    title: 'Screen Ruler',
                    description: 'Measure small items',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenRulerScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.highlight_rounded,
                    title: 'Screen Flashlight',
                    description: 'Max brightness torch',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashlightScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.timer_rounded,
                    title: 'Precision Stopwatch',
                    description: 'Track laps & splits',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StopwatchScreen()));
                    },
                  ),
                  _buildEditorialToolCard(
                    context,
                    icon: Icons.draw_rounded,
                    title: 'Whiteboard Canvas',
                    description: 'Quick sketch & notes',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WhiteboardScreen()));
                    },
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorialToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? theme.colorScheme.onSurface : Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 10.5,
              color: secColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// ==========================================
/// 1. Spirit Bubble Level Screen
/// ==========================================
class BubbleLevelScreen extends StatefulWidget {
  const BubbleLevelScreen({super.key});

  @override
  State<BubbleLevelScreen> createState() => _BubbleLevelScreenState();
}

class _BubbleLevelScreenState extends State<BubbleLevelScreen> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double _x = 0;
  double _y = 0;
  bool _isLevel = false;

  @override
  void initState() {
    super.initState();
    try {
      _sub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _x = event.x;
          _y = event.y;
          final wasLevel = _isLevel;
          _isLevel = _x.abs() < 0.25 && _y.abs() < 0.25;
          if (_isLevel && !wasLevel) {
            HapticFeedback.mediumImpact();
          }
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
    final pitchDeg = (_y / 9.8 * 90).clamp(-90.0, 90.0);
    final rollDeg = (-_x / 9.8 * 90).clamp(-90.0, 90.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
        title: Text('Sensor Bubble Level', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDegreeHUD(context, 'PITCH (Y)', '${pitchDeg.toStringAsFixed(1)}°'),
                  _buildDegreeHUD(context, 'ROLL (X)', '${rollDeg.toStringAsFixed(1)}°'),
                ],
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardBg,
                    border: Border.all(
                      color: _isLevel ? const Color(0xFF10B981) : borderColor,
                      width: _isLevel ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? const Color(0x30000000) : const Color(0x08000000),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 220, height: 1, color: borderColor),
                      Container(width: 1, height: 220, color: borderColor),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                      ),
                      Positioned(
                        left: (120 - 22) + (-_x * 8).clamp(-85.0, 85.0),
                        top: (120 - 22) + (_y * 8).clamp(-85.0, 85.0),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isLevel ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF111111)),
                          ),
                          child: Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isLevel ? Colors.white : (isDark ? const Color(0xFF111111) : Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _isLevel ? const Color(0xFF10B981) : (isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isLevel ? 'PERFECTLY LEVEL (0.0°)' : 'CALIBRATING ORIENTATION',
                  style: TextStyle(
                    color: isDark && !_isLevel ? theme.colorScheme.onSurface : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDegreeHUD(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: secColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// ==========================================
/// 2. Screen Ruler Tool
/// ==========================================
class ScreenRulerScreen extends StatelessWidget {
  const ScreenRulerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    // Approximation: 1 cm is ~ 38 logical pixels on average devices, but this is a rough estimate.
    const pixelsPerCm = 38.0; 
    final heightInCm = (size.height / pixelsPerCm).floor();

    return Scaffold(
      body: Row(
        children: [
          // Left ruler
          Container(
            width: 80,
            color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: heightInCm,
              itemBuilder: (context, index) {
                return SizedBox(
                  height: pixelsPerCm,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(width: 30, height: 2, color: Colors.white),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 36.0),
                          child: Text(
                            '$index',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      Positioned(top: pixelsPerCm / 4, left: 0, child: Container(width: 15, height: 1, color: Colors.white54)),
                      Positioned(top: pixelsPerCm / 2, left: 0, child: Container(width: 20, height: 1.5, color: Colors.white70)),
                      Positioned(top: pixelsPerCm * 3 / 4, left: 0, child: Container(width: 15, height: 1, color: Colors.white54)),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Column(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: theme.colorScheme.onSurface),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'SCREEN RULER',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5, color: AppTheme.getSecondaryText(context)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Place objects\nagainst the edge.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, height: 1.2),
                ),
                const SizedBox(height: 12),
                Text(
                  '1 unit ≈ 1 cm (Approximate)',
                  style: TextStyle(fontSize: 12, color: AppTheme.getSecondaryText(context)),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ==========================================
/// 3. Screen Flashlight Tool
/// ==========================================
class FlashlightScreen extends StatefulWidget {
  const FlashlightScreen({super.key});

  @override
  State<FlashlightScreen> createState() => _FlashlightScreenState();
}

class _FlashlightScreenState extends State<FlashlightScreen> {
  bool _isOn = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _isOn = !_isOn);
      },
      child: Scaffold(
        backgroundColor: _isOn ? Colors.white : Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                      size: 64,
                      color: _isOn ? Colors.amber : Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap anywhere to toggle',
                      style: TextStyle(
                        color: _isOn ? Colors.black54 : Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isOn ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: _isOn ? Colors.black : Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
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
/// 4. Precision Stopwatch Tool
/// ==========================================
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_stopwatch.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int milliseconds) {
    int hundreds = (milliseconds / 10).truncate() % 100;
    int seconds = (milliseconds / 1000).truncate() % 60;
    int minutes = (milliseconds / (1000 * 60)).truncate();

    String m = minutes.toString().padLeft(2, '0');
    String s = seconds.toString().padLeft(2, '0');
    String h = hundreds.toString().padLeft(2, '0');
    return "$m:$s.$h";
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(_stopwatch.elapsedMilliseconds);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
        title: Text('Precision Stopwatch', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBtn(
                  icon: Icons.refresh_rounded,
                  color: isDark ? theme.colorScheme.onSurface : const Color(0xFF4B5563),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _stopwatch.reset();
                    });
                  },
                ),
                const SizedBox(width: 24),
                _buildBtn(
                  icon: _stopwatch.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _stopwatch.isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  size: 80,
                  iconSize: 40,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      if (_stopwatch.isRunning) {
                        _stopwatch.stop();
                      } else {
                        _stopwatch.start();
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn({required IconData icon, required Color color, required VoidCallback onTap, double size = 64, double iconSize = 28}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}

/// ==========================================
/// 5. Whiteboard Canvas Tool
/// ==========================================
class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strokeColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _currentStroke = [details.localPosition];
                _strokes.add(_currentStroke);
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentStroke.add(details.localPosition);
              });
            },
            child: CustomPaint(
              painter: _WhiteboardPainter(_strokes, strokeColor: strokeColor),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outline),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? const Color(0x30000000) : const Color(0x10000000),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, size: 20, color: theme.colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outline),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? const Color(0x30000000) : const Color(0x10000000),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _strokes.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color strokeColor;

  _WhiteboardPainter(this.strokes, {required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}
