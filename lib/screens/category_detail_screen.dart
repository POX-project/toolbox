import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String title;
  final Map<String, String> data;

  const CategoryDetailScreen({
    super.key,
    required this.title,
    required this.data,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCategory(BuildContext context) {
    HapticFeedback.mediumImpact();
    final buffer = StringBuffer();
    buffer.writeln('# 📱 ${widget.title}');
    buffer.writeln('');
    for (final entry in widget.data.entries) {
      buffer.writeln('- **${entry.key}**: ${entry.value}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} specs copied to clipboard!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = widget.data.entries.where((e) {
      if (e.value.isEmpty) return false;
      if (_searchQuery.isEmpty) return true;
      return e.key.toLowerCase().contains(_searchQuery) || e.value.toLowerCase().contains(_searchQuery);
    }).toList();

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
        title: Text(
          widget.title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: IconButton(
                icon: Icon(Icons.share_outlined, size: 18, color: theme.colorScheme.onSurface),
                onPressed: () => _exportCategory(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppTheme.getSecondaryText(context), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Filter ${widget.title.toLowerCase()}...',
                          hintStyle: TextStyle(color: AppTheme.getSecondaryText(context), fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppTheme.getSecondaryText(context), size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Staggered Bento Grid
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(
                      child: Text(
                        'No matching parameters.',
                        style: TextStyle(color: AppTheme.getSecondaryText(context)),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      physics: const BouncingScrollPhysics(),
                      child: StaggeredGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: filteredEntries.map((entry) {
                          final bool isWide = entry.value.length > 24 || entry.key.length > 16 || entry.value.contains('\n');
                          return StaggeredGridTile.fit(
                            crossAxisCellCount: isWide ? 2 : 1,
                            child: _buildEditorialBentoCard(context, entry.key, entry.value),
                          );
                        }).toList(),
                      ),
                    ),
            ),

            // Bottom Action
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF111111),
                    foregroundColor: isDark ? theme.colorScheme.onSurface : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  onPressed: () => _exportCategory(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Copy All Specifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorialBentoCard(BuildContext context, String key, String value) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      onTap: () {
        HapticFeedback.lightImpact();
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied "$key": $value'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getSecondaryText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.copy_rounded, color: AppTheme.getSecondaryText(context), size: 14),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
