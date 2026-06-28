import 'package:flutter/material.dart';

import '../../models/home_tool_entry.dart';
import '../../services/home_tool_preferences_service.dart';

class CommonToolsSettingsPage extends StatefulWidget {
  const CommonToolsSettingsPage({super.key});

  @override
  State<CommonToolsSettingsPage> createState() =>
      _CommonToolsSettingsPageState();
}

class _CommonToolsSettingsPageState extends State<CommonToolsSettingsPage> {
  final _preferencesService = HomeToolPreferencesService();
  List<String> _selectedIds = List<String>.from(defaultHomeToolIds);
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await _preferencesService.getSelectedToolIds();
    if (!mounted) return;
    setState(() {
      _selectedIds = ids;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个常用工具')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _preferencesService.saveSelectedToolIds(_selectedIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('常用工具设置已保存')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _selectedIds = List<String>.from(defaultHomeToolIds);
    });
  }

  void _toggleTool(HomeToolEntry tool, bool selected) {
    if (selected && _selectedIds.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少保留一个常用工具')),
      );
      return;
    }
    if (!selected &&
        _selectedIds.length >= HomeToolPreferencesService.maxHomeTools) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('首页最多展示 8 个常用工具')),
      );
      return;
    }

    setState(() {
      if (selected) {
        _selectedIds.remove(tool.id);
      } else {
        _selectedIds.add(tool.id);
      }
    });
  }

  void _reorderSelected(int oldIndex, int newIndex) {
    setState(() {
      final id = _selectedIds.removeAt(oldIndex);
      _selectedIds.insert(newIndex, id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedTools = _selectedTools();
    final unselectedTools = homeToolEntries
        .where((tool) => !_selectedIds.contains(tool.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('常用工具设置'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _reset,
            child: const Text('恢复默认'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_customize, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '选择并排序首页“常用工具”，最多展示 8 个。',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedIds.length}/8',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _SettingsLabel('首页显示'),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: selectedTools.length,
                  onReorderItem: _reorderSelected,
                  itemBuilder: (context, index) {
                    final tool = selectedTools[index];
                    return _ToolSettingTile(
                      key: ValueKey(tool.id),
                      tool: tool,
                      selected: true,
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      onChanged: () => _toggleTool(tool, true),
                    );
                  },
                ),
                const SizedBox(height: 14),
                const _SettingsLabel('可添加工具'),
                if (unselectedTools.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      '已添加全部可用工具',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  for (final tool in unselectedTools)
                    _ToolSettingTile(
                      key: ValueKey(tool.id),
                      tool: tool,
                      selected: false,
                      onChanged: () => _toggleTool(tool, false),
                    ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? '保存中...' : '保存'),
        ),
      ),
    );
  }

  List<HomeToolEntry> _selectedTools() {
    final byId = {for (final tool in homeToolEntries) tool.id: tool};
    return _selectedIds
        .map((id) => byId[id])
        .whereType<HomeToolEntry>()
        .toList();
  }
}

class _SettingsLabel extends StatelessWidget {
  final String text;

  const _SettingsLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ToolSettingTile extends StatelessWidget {
  final HomeToolEntry tool;
  final bool selected;
  final VoidCallback onChanged;
  final Widget? trailing;

  const _ToolSettingTile({
    super.key,
    required this.tool,
    required this.selected,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChanged,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onChanged()),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
