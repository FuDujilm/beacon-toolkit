import 'package:flutter/material.dart';

import '../../services/app_endpoint_settings_service.dart';
import '../../services/callsign_lookup_service.dart';

class QrzSettingsPage extends StatefulWidget {
  const QrzSettingsPage({super.key});

  @override
  State<QrzSettingsPage> createState() => _QrzSettingsPageState();
}

class _QrzSettingsPageState extends State<QrzSettingsPage> {
  final _settingsService = const AppEndpointSettingsService();
  final _lookupService = CallsignLookupService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  QrzLookupMode _mode = QrzLookupMode.automatic;
  bool _debugEnabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  _LoginTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _settingsService.getQrzSettings();
    if (!mounted) return;
    setState(() {
      _usernameController.text = settings.username;
      _passwordController.text = settings.password;
      _mode = settings.mode;
      _debugEnabled = settings.debugEnabled;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _settingsService.updateQrzSettings(
        QrzSettings(
          username: _usernameController.text,
          password: _passwordController.text,
          mode: _mode,
          debugEnabled: _debugEnabled,
        ),
      );
      await _settingsService.updateQrzSessionKey('');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QRZ.COM 配置已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testLogin() async {
    final settings = QrzSettings(
      username: _usernameController.text,
      password: _passwordController.text,
      mode: _mode,
      debugEnabled: _debugEnabled,
    );
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final sessionKey = await _lookupService.verifyQrzLogin(settings);
      if (!mounted) return;
      setState(() {
        _testResult = _LoginTestResult(
          success: true,
          message:
              'QRZ.COM 登录成功，Session Key ${_maskSessionKey(sessionKey)} 已缓存。',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult = _LoginTestResult(
          success: false,
          message: e is FormatException ? e.message : e.toString(),
        );
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _maskSessionKey(String value) {
    if (value.length <= 8) return '****';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRZ.COM 配置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'QRZ.COM 用户名',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'QRZ.COM 密码',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<QrzLookupMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(
                    labelText: '呼号查询模式',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: QrzLookupMode.automatic,
                      child: Text('自动：beacon-api 优先，回退 QRZ'),
                    ),
                    DropdownMenuItem(
                      value: QrzLookupMode.beaconOnly,
                      child: Text('仅 beacon-api'),
                    ),
                    DropdownMenuItem(
                      value: QrzLookupMode.qrzOnly,
                      child: Text('仅 QRZ.COM'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _mode = value);
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示呼号查询调试信息'),
                  subtitle: const Text(
                    '展示查询路径、接口状态和 Biography 长度，不显示密码或完整 Session Key。',
                  ),
                  value: _debugEnabled,
                  onChanged: (value) => setState(() {
                    _debugEnabled = value;
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  '账号密码仅保存在本机。默认查询会先走 beacon-api 代理，失败时再尝试 QRZ.COM 官方 XML API。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 14),
                  _LoginTestPanel(result: _testResult!),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 180,
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _testLogin,
                        icon: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(_testing ? '验证中...' : '测试登录'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? '保存中...' : '保存配置'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LoginTestResult {
  final bool success;
  final String message;

  const _LoginTestResult({
    required this.success,
    required this.message,
  });
}

class _LoginTestPanel extends StatelessWidget {
  final _LoginTestResult result;

  const _LoginTestPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = result.success ? Colors.green : scheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.success ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
