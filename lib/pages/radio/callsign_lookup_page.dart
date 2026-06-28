import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/callsign_profile.dart';
import '../../services/app_endpoint_settings_service.dart';
import '../../services/callsign_lookup_service.dart';
import '../profile/qrz_settings_page.dart';
import 'callsign_biography_page.dart';
import 'radio_theme.dart';

class CallsignLookupPage extends StatefulWidget {
  const CallsignLookupPage({super.key});

  @override
  State<CallsignLookupPage> createState() => _CallsignLookupPageState();
}

class _CallsignLookupPageState extends State<CallsignLookupPage> {
  final _controller = TextEditingController();
  final _service = CallsignLookupService();
  final _settingsService = const AppEndpointSettingsService();

  bool _loading = false;
  bool _showDebug = false;
  CallsignLookupResult? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final callsign = _controller.text.trim();
    if (callsign.isEmpty) {
      setState(() => _error = '请输入呼号');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final settings = await _settingsService.getQrzSettings();
      final result = await _service.lookup(callsign);
      if (!mounted) return;
      setState(() {
        _showDebug = settings.debugEnabled;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is FormatException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = radioThemeColors(context);
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        title: const Text('呼号查询'),
        backgroundColor: colors.appBar,
        foregroundColor: colors.text,
        actions: [
          IconButton(
            tooltip: 'QRZ.COM 配置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrzSettingsPage()),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final content = _buildContent(context);
          if (!wide) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Text(
          '查询电台呼号、QTH 与基础资料。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '呼号',
                  hintText: 'BA1ABC',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _loading ? null : _search,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('查询'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _MessagePanel(message: _error!, error: true),
        ],
        if (result != null && result.warnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final warning in result.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MessagePanel(message: warning),
            ),
        ],
        if (_showDebug && result != null && result.debugLogs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DebugPanel(lines: result.debugLogs),
        ],
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (result != null && result.items.isEmpty)
          _EmptyPanel(onConfigureQrz: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrzSettingsPage()),
            );
          })
        else if (result != null)
          ...result.items.map((item) => _CallsignCard(profile: item)),
        const SizedBox(height: 12),
        Text(
          '仅供参考，请遵守当地法规和主管部门要求。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final List<String> lines;

  const _DebugPanel({required this.lines});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text('调试结果'),
        subtitle: Text('${lines.length} 条步骤'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              lines.join('\n'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String message;
  final bool error;

  const _MessagePanel({
    required this.message,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = error ? scheme.errorContainer : scheme.surfaceContainerHighest;
    final fg = error ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: fg)),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final VoidCallback onConfigureQrz;

  const _EmptyPanel({required this.onConfigureQrz});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 42),
          const SizedBox(height: 10),
          const Text('未找到呼号资料'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onConfigureQrz,
            icon: const Icon(Icons.settings),
            label: const Text('配置 QRZ.COM'),
          ),
        ],
      ),
    );
  }
}

class _CallsignCard extends StatelessWidget {
  final CallsignProfile profile;

  const _CallsignCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CallsignBiographyPage(profile: profile),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(profile: profile),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                profile.callsign,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Chip(
                                label: Text(_sourceLabel(profile.source)),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Icon(Icons.article_outlined, size: 18),
                            ],
                          ),
                          if (_displayName(profile) != null)
                            Text(
                              _displayName(profile)!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          if (profile.country?.isNotEmpty == true)
                            Text(
                              profile.country!,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          if (profile.dxcc?.name?.isNotEmpty == true)
                            Text(
                              'DXCC ${profile.dxcc?.dxcc ?? ''} · ${profile.dxcc!.name}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const Divider(height: 24),
                _InfoWrap(profile: profile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _displayName(CallsignProfile profile) {
    return profile.displayName?.isNotEmpty == true
        ? profile.displayName
        : profile.nickname;
  }

  String _sourceLabel(String source) {
    return source == 'qrz' ? 'QRZ.COM' : 'beacon-api';
  }
}

class _Avatar extends StatelessWidget {
  final CallsignProfile profile;

  const _Avatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final url = profile.imageUrl;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 64,
        height: 64,
        color: scheme.surfaceContainerHighest,
        child: url == null || url.isEmpty
            ? Icon(Icons.person, color: scheme.onSurfaceVariant)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person, color: scheme.onSurfaceVariant),
              ),
      ),
    );
  }
}

class _InfoWrap extends StatelessWidget {
  final CallsignProfile profile;

  const _InfoWrap({required this.profile});

  @override
  Widget build(BuildContext context) {
    final entries = <_InfoEntry>[
      _InfoEntry('Grid', profile.grid),
      if (profile.latitude != null && profile.longitude != null)
        _InfoEntry(
          '坐标',
          '${profile.latitude!.toStringAsFixed(5)}, ${profile.longitude!.toStringAsFixed(5)}',
        ),
      _InfoEntry('地址', profile.address),
      _InfoEntry('邮箱', profile.email),
      _InfoEntry('QSL', profile.qsl),
      _InfoEntry('CQ/ITU', _zones(profile)),
      _InfoEntry('DXCC', _dxcc(profile.dxcc)),
      _InfoEntry('更新', profile.rawUpdatedAt),
    ].where((entry) => entry.value?.isNotEmpty == true).toList();

    if (entries.isEmpty && profile.url?.isNotEmpty != true) {
      return const Text('暂无更多资料');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in entries) _InfoChip(entry: entry),
          ],
        ),
        if (profile.url?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(profile.url!),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('打开主页'),
          ),
        ],
      ],
    );
  }

  String? _zones(CallsignProfile profile) {
    final parts = [
      if (profile.cqZone?.isNotEmpty == true) 'CQ ${profile.cqZone}',
      if (profile.ituZone?.isNotEmpty == true) 'ITU ${profile.ituZone}',
    ];
    return parts.isEmpty ? null : parts.join(' / ');
  }

  String? _dxcc(DxccInfo? dxcc) {
    if (dxcc == null) return null;
    final parts = [
      if (dxcc.dxcc?.isNotEmpty == true) dxcc.dxcc!,
      if (dxcc.name?.isNotEmpty == true) dxcc.name!,
      if (dxcc.continent?.isNotEmpty == true) dxcc.continent!,
      if (dxcc.timezone?.isNotEmpty == true) 'UTC ${dxcc.timezone}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _InfoEntry {
  final String label;
  final String? value;

  const _InfoEntry(this.label, this.value);
}

class _InfoChip extends StatelessWidget {
  final _InfoEntry entry;

  const _InfoChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.value!,
                softWrap: true,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
