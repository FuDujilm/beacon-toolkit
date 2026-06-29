import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_endpoint_settings_service.dart';
import '../../services/qso_management_service.dart';

class QslPublicPage extends StatefulWidget {
  final String linkType;
  final String token;
  final String? apiBaseUrl;

  const QslPublicPage({
    super.key,
    required this.linkType,
    required this.token,
    this.apiBaseUrl,
  });

  @override
  State<QslPublicPage> createState() => _QslPublicPageState();
}

class _QslPublicPageState extends State<QslPublicPage> {
  final _service = QsoManagementService();
  final _endpointSettingsService = const AppEndpointSettingsService();
  final _verifierController = TextEditingController();
  final _callsignController = TextEditingController();
  final _noteController = TextEditingController();

  QslPublicPageData? _data;
  String _apiBaseUrl = '';
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = true;
  bool _isConfirming = false;
  bool _receiptDone = false;

  bool get _isDynamic => widget.linkType == 'dynamic';
  bool get _isStatic => widget.linkType == 'static';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _verifierController.dispose();
    _callsignController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load({bool keepSuccessMessage = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (!keepSuccessMessage) {
        _successMessage = null;
      }
    });
    try {
      final fallbackApi = await _endpointSettingsService.getBeaconApiBaseUrl();
      final apiBaseUrl = widget.apiBaseUrl?.trim().isNotEmpty == true
          ? widget.apiBaseUrl!.trim()
          : fallbackApi;
      if (!_isStatic && !_isDynamic) {
        throw const FormatException('链接类型无效');
      }
      if (widget.token.trim().isEmpty) {
        throw const FormatException('链接缺少 token');
      }
      final data = await _service.fetchPublicQslPage(
        linkType: widget.linkType,
        token: widget.token,
        apiBaseUrl: apiBaseUrl,
        verifierCode: _verifierController.text,
      );
      if (!mounted) return;
      setState(() {
        _apiBaseUrl = apiBaseUrl;
        _data = data;
        _receiptDone = data.items
            .any((item) => item.qslStatus.toLowerCase() == 'received');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm() async {
    final data = _data;
    if (data == null || data.items.isEmpty) return;
    final callsign = _callsignController.text.trim().toUpperCase();
    if (callsign.isEmpty) {
      setState(() => _errorMessage = '请输入自己的呼号后再登记收妥');
      return;
    }
    setState(() {
      _isConfirming = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final confirmed = await _service.confirmPublicQsl(
        linkType: widget.linkType,
        token: widget.token,
        apiBaseUrl: _apiBaseUrl,
        qsoIds: data.items.map((item) => item.id).toList(),
        verifierCode: _verifierController.text,
        confirmerCallsign: callsign,
        note: _noteController.text,
      );
      if (!mounted) return;
      setState(() {
        _receiptDone = true;
        _successMessage = confirmed > 0
            ? '已登记 $confirmed 条 QSL 卡片收妥'
            : '该 QSL 卡片此前已经收妥，无需重复提交';
        _data = QslPublicPageData(
          linkType: data.linkType,
          verifierRequired: data.verifierRequired,
          items: [
            for (final item in data.items)
              QslPublicQsoItem(
                id: item.id,
                dateTime: item.dateTime,
                callsign: item.callsign,
                stationCallsign: item.stationCallsign,
                band: item.band,
                mode: item.mode,
                frequency: item.frequency,
                satName: item.satName,
                propMode: item.propMode,
                qsoConfirmStatus: item.qsoConfirmStatus,
                qslStatus: 'received',
              ),
          ],
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 403) return '验证码不正确或已过期，请联系对方重新生成';
      if (status == 404) return 'QSL 链接不存在或已失效';
      if (status != null && status >= 500) return '服务器暂时不可用，请稍后重试';
      return '无法加载 QSL 信息，请检查网络或链接配置';
    }
    return '无法加载 QSL 信息，请稍后重试';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QSL 收妥确认'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _HeaderCard(
                linkType: widget.linkType,
                token: widget.token,
                apiBaseUrl: _apiBaseUrl,
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                _MessageCard(
                  icon: Icons.error_outline,
                  title: '无法打开链接',
                  message: _errorMessage!,
                  color: scheme.error,
                  action: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                )
              else ...[
                if (_successMessage != null) ...[
                  _InlineNotice(
                    icon: Icons.check_circle_outline,
                    text: _successMessage!,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_data?.verifierRequired == true) ...[
                  _VerifierCard(
                    controller: _verifierController,
                    onSubmit: _load,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_data?.items.isEmpty == true)
                  _MessageCard(
                    icon: Icons.mark_email_read_outlined,
                    title: _data?.verifierRequired == true
                        ? '请输入验证码查看待确认通联'
                        : '暂无待确认通联',
                    message: _data?.verifierRequired == true
                        ? '动态 QSL 链接需要对方提供的验证码，验证后会显示可收妥的通联记录。'
                        : '当前链接下没有需要确认收妥的通联记录。',
                    color: scheme.primary,
                  )
                else ...[
                  if (_data!.items.isNotEmpty) ...[
                    _SenderCard(
                      callsign: _data!.items
                          .map((item) => item.stationCallsign)
                          .firstWhere(
                            (value) => value.trim().isNotEmpty,
                            orElse: () => '未填写',
                          ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_receiptDone) ...[
                    const _MessageCard(
                      icon: Icons.check_circle_outline,
                      title: 'QSL 卡片已标记收妥',
                      message:
                          '该操作只更新发出方日志里的 QSL 收妥状态；QSO 通联确认需要通过独立的 QSO 确认流程完成。',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'QSL 卡片对应记录',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in _data!.items) ...[
                    _QslQsoCard(item: item),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  if (!_receiptDone)
                    _ReceiptForm(
                      callsignController: _callsignController,
                      noteController: _noteController,
                      isConfirming: _isConfirming,
                      count: _data!.items.length,
                      onConfirm: _confirm,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String linkType;
  final String token;
  final String apiBaseUrl;

  const _HeaderCard({
    required this.linkType,
    required this.token,
    required this.apiBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = linkType == 'dynamic' ? '动态 QSL 链接' : '静态 QSL 链接';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '请核对通联信息后确认 QSL 收妥。',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(text: linkType == 'dynamic' ? '动态' : '静态'),
                if (apiBaseUrl.isNotEmpty) const _Pill(text: 'beacon-api'),
                _Pill(text: token.length > 8 ? token.substring(0, 8) : token),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifierCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _VerifierCard({
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '动态验证码',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: onSubmit,
              child: const Text('验证'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QslQsoCard extends StatelessWidget {
  final QslPublicQsoItem item;

  const _QslQsoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateText = item.dateTime == null
        ? '未知时间'
        : DateFormat('yyyy-MM-dd HH:mm').format(item.dateTime!.toLocal());
    final satelliteText = [
      if (item.propMode.isNotEmpty) item.propMode,
      if (item.satName.isNotEmpty) item.satName,
    ].join(' · ');
    final qsoStatus = item.qsoConfirmStatus.toLowerCase() == 'confirmed'
        ? 'QSO 已确认'
        : 'QSO 未确认';
    final qslStatus =
        item.qslStatus.toLowerCase() == 'received' ? 'QSL 已收妥' : 'QSL 待收妥';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'QSL 卡片记录',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Pill(text: item.mode.isEmpty ? 'MODE' : item.mode),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '发出方 ${item.stationCallsign.isEmpty ? '未填写' : item.stationCallsign} / $qsoStatus / $qslStatus',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.calendar_month, text: dateText),
                if (item.band.isNotEmpty)
                  _InfoChip(
                      icon: Icons.settings_input_antenna, text: item.band),
                if (item.frequency.isNotEmpty)
                  _InfoChip(icon: Icons.graphic_eq, text: item.frequency),
                if (satelliteText.isNotEmpty)
                  _InfoChip(icon: Icons.satellite_alt, text: satelliteText),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '登记后，发出方的 beacon-api 日志会标记为 QSL 已收妥；这不是 QSO 通联确认。',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SenderCard extends StatelessWidget {
  final String callsign;

  const _SenderCard({required this.callsign});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发出 QSL 方呼号',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              callsign,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptForm extends StatelessWidget {
  final TextEditingController callsignController;
  final TextEditingController noteController;
  final bool isConfirming;
  final int count;
  final VoidCallback onConfirm;

  const _ReceiptForm({
    required this.callsignController,
    required this.noteController,
    required this.isConfirming,
    required this.count,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '收妥信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: callsignController,
              decoration: const InputDecoration(
                labelText: '我的呼号（收妥方）',
                hintText: '例如 BA4QBQ',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: isConfirming ? null : onConfirm,
              icon: isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_read_outlined),
              label: Text(isConfirming ? '提交中...' : '登记 $count 条 QSL 卡片收妥'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Widget? action;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
