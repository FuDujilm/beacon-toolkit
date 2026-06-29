import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/app_endpoint_settings_service.dart';
import '../../services/auth_service.dart';

class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key});

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  final _examApiUrlController = TextEditingController();
  final _oauthBaseUrlController = TextEditingController();
  final _oauthClientIdController = TextEditingController();
  final _beaconApiUrlController = TextEditingController();
  final _beaconFrontendUrlController = TextEditingController();
  final _tiandituTokenController = TextEditingController();
  final _llmBaseUrlController = TextEditingController();
  final _llmApiKeyController = TextEditingController();
  final _llmModelController = TextEditingController();
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController(text: '587');
  final _smtpUsernameController = TextEditingController();
  final _smtpPasswordController = TextEditingController();
  final _smtpFromEmailController = TextEditingController();
  final _smtpFromNameController = TextEditingController(text: 'Beacon');
  final _endpointSettingsService = const AppEndpointSettingsService();

  bool _isLoading = true;
  bool _isSavingExamApi = false;
  bool _isSavingOpenOidc = false;
  bool _isSavingBeaconApi = false;
  bool _isSavingBeaconFrontend = false;
  bool _isSavingTianditu = false;
  bool _isSavingLlm = false;
  bool _isSavingSmtp = false;
  bool _llmEnabled = false;
  bool _smtpEnabled = false;
  bool _isTestingExamApi = false;
  bool _isTestingOpenOidc = false;
  bool _isTestingBeaconApi = false;
  Map<String, dynamic>? _examApiTestResult;
  Map<String, dynamic>? _openOidcTestResult;
  Map<String, dynamic>? _beaconApiTestResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _examApiUrlController.dispose();
    _oauthBaseUrlController.dispose();
    _oauthClientIdController.dispose();
    _beaconApiUrlController.dispose();
    _beaconFrontendUrlController.dispose();
    _tiandituTokenController.dispose();
    _llmBaseUrlController.dispose();
    _llmApiKeyController.dispose();
    _llmModelController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    _smtpFromEmailController.dispose();
    _smtpFromNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final authService = context.read<AuthService>();
    final results = await Future.wait([
      authService.getApiUrl(),
      _endpointSettingsService.getOpenOidcSettings(),
      _endpointSettingsService.getBeaconApiBaseUrl(),
      _endpointSettingsService.getBeaconFrontendBaseUrl(),
      _endpointSettingsService.getTiandituToken(),
      _endpointSettingsService.getLlmSettings(),
      _endpointSettingsService.getSmtpSettings(),
    ]);
    if (!mounted) return;
    final openOidcSettings = results[1] as OpenOidcSettings;
    final llmSettings = results[5] as LlmSettings;
    final smtpSettings = results[6] as SmtpSettings;
    setState(() {
      _examApiUrlController.text = results[0] as String;
      _oauthBaseUrlController.text = openOidcSettings.baseUrl;
      _oauthClientIdController.text = openOidcSettings.clientId;
      _beaconApiUrlController.text = results[2] as String;
      _beaconFrontendUrlController.text = results[3] as String;
      _tiandituTokenController.text = results[4] as String;
      _llmEnabled = llmSettings.enabled;
      _llmBaseUrlController.text = llmSettings.baseUrl;
      _llmApiKeyController.text = llmSettings.apiKey;
      _llmModelController.text = llmSettings.model;
      _smtpEnabled = smtpSettings.enabled;
      _smtpHostController.text = smtpSettings.host;
      _smtpPortController.text = smtpSettings.port.toString();
      _smtpUsernameController.text = smtpSettings.username;
      _smtpPasswordController.text = smtpSettings.password;
      _smtpFromEmailController.text = smtpSettings.fromEmail;
      _smtpFromNameController.text = smtpSettings.fromName;
      _isLoading = false;
    });
  }

  Future<void> _testExamApiConnection() async {
    setState(() {
      _isTestingExamApi = true;
      _examApiTestResult = null;
    });

    final authService = context.read<AuthService>();
    final previousUrl = await authService.getApiUrl();
    await authService.updateApiUrl(_examApiUrlController.text.trim());
    final result = await authService.checkConnectivity();
    await authService.updateApiUrl(previousUrl);

    if (!mounted) return;
    setState(() {
      _examApiTestResult = result;
      _isTestingExamApi = false;
    });
  }

  Future<void> _testBeaconApiConnection() async {
    setState(() {
      _isTestingBeaconApi = true;
      _beaconApiTestResult = null;
    });

    final result = await _endpointSettingsService.testBeaconApiConnection(
      _beaconApiUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _beaconApiTestResult = result;
      _isTestingBeaconApi = false;
    });
  }

  Future<void> _testOpenOidcConnection() async {
    setState(() {
      _isTestingOpenOidc = true;
      _openOidcTestResult = null;
    });

    final result = await _endpointSettingsService.testOpenOidcConnection(
      _oauthBaseUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _openOidcTestResult = result;
      _isTestingOpenOidc = false;
    });
  }

  Future<void> _saveExamApiUrl() async {
    final nextUrl = _examApiUrlController.text.trim();
    final authService = context.read<AuthService>();
    if (nextUrl.isEmpty) {
      _showSnackBar('请输入考试 API 地址');
      return;
    }

    setState(() => _isSavingExamApi = true);
    try {
      await authService.updateApiUrl(nextUrl);
      final currentUrl = await authService.getApiUrl();
      if (!mounted) return;
      setState(() => _examApiUrlController.text = currentUrl);
      _showSnackBar('考试 API 地址已保存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingExamApi = false);
    }
  }

  Future<void> _saveBeaconApiUrl() async {
    final nextUrl = _beaconApiUrlController.text.trim();
    if (nextUrl.isEmpty) {
      _showSnackBar('请输入 beacon-api 地址');
      return;
    }

    setState(() => _isSavingBeaconApi = true);
    try {
      await _endpointSettingsService.updateBeaconApiBaseUrl(nextUrl);
      final currentUrl = await _endpointSettingsService.getBeaconApiBaseUrl();
      if (!mounted) return;
      setState(() => _beaconApiUrlController.text = currentUrl);
      _showSnackBar('beacon-api 地址已保存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingBeaconApi = false);
    }
  }

  Future<void> _saveOpenOidcSettings() async {
    final nextBaseUrl = _oauthBaseUrlController.text.trim();
    final nextClientId = _oauthClientIdController.text.trim();
    if (nextBaseUrl.isEmpty) {
      _showSnackBar('请输入 OpenOIDC 地址');
      return;
    }
    if (nextClientId.isEmpty) {
      _showSnackBar('请输入 OAuth Client ID');
      return;
    }

    setState(() => _isSavingOpenOidc = true);
    try {
      await _endpointSettingsService.updateOpenOidcSettings(
        OpenOidcSettings(baseUrl: nextBaseUrl, clientId: nextClientId),
      );
      final current = await _endpointSettingsService.getOpenOidcSettings();
      if (!mounted) return;
      setState(() {
        _oauthBaseUrlController.text = current.baseUrl;
        _oauthClientIdController.text = current.clientId;
      });
      _showSnackBar('登录配置已保存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingOpenOidc = false);
    }
  }

  Future<void> _resetOpenOidcSettings() async {
    setState(() => _isSavingOpenOidc = true);
    try {
      await _endpointSettingsService.resetOpenOidcSettings();
      final current = await _endpointSettingsService.getOpenOidcSettings();
      if (!mounted) return;
      setState(() {
        _oauthBaseUrlController.text = current.baseUrl;
        _oauthClientIdController.text = current.clientId;
        _openOidcTestResult = null;
      });
      _showSnackBar('登录配置已恢复默认');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('恢复失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingOpenOidc = false);
    }
  }

  Future<void> _saveBeaconFrontendUrl() async {
    final nextUrl = _beaconFrontendUrlController.text.trim();
    if (nextUrl.isEmpty) {
      _showSnackBar('请输入 Beacon 前端地址');
      return;
    }

    setState(() => _isSavingBeaconFrontend = true);
    try {
      await _endpointSettingsService.updateBeaconFrontendBaseUrl(nextUrl);
      final currentUrl =
          await _endpointSettingsService.getBeaconFrontendBaseUrl();
      if (!mounted) return;
      setState(() => _beaconFrontendUrlController.text = currentUrl);
      _showSnackBar('Beacon 前端地址已保存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingBeaconFrontend = false);
    }
  }

  Future<void> _saveTiandituToken() async {
    setState(() => _isSavingTianditu = true);
    try {
      await _endpointSettingsService.updateTiandituToken(
        _tiandituTokenController.text,
      );
      final token = await _endpointSettingsService.getTiandituToken();
      if (!mounted) return;
      setState(() => _tiandituTokenController.text = token);
      _showSnackBar(token.isEmpty ? '天地图 Token 已清空' : '天地图 Token 已保存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingTianditu = false);
    }
  }

  Future<void> _saveLlmSettings() async {
    setState(() => _isSavingLlm = true);
    try {
      await _endpointSettingsService.updateLlmSettings(
        LlmSettings(
          enabled: _llmEnabled,
          baseUrl: _llmBaseUrlController.text,
          apiKey: _llmApiKeyController.text,
          model: _llmModelController.text.trim().isEmpty
              ? LlmSettings.defaultModel
              : _llmModelController.text,
        ),
      );
      final settings = await _endpointSettingsService.getLlmSettings();
      if (!mounted) return;
      setState(() {
        _llmEnabled = settings.enabled;
        _llmBaseUrlController.text = settings.baseUrl;
        _llmApiKeyController.text = settings.apiKey;
        _llmModelController.text = settings.model;
      });
      _showSnackBar('LLM 配置已保存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingLlm = false);
    }
  }

  Future<void> _saveSmtpSettings() async {
    setState(() => _isSavingSmtp = true);
    try {
      await _endpointSettingsService.updateSmtpSettings(
        SmtpSettings(
          enabled: _smtpEnabled,
          host: _smtpHostController.text,
          port: int.tryParse(_smtpPortController.text.trim()) ?? 587,
          username: _smtpUsernameController.text,
          password: _smtpPasswordController.text,
          fromEmail: _smtpFromEmailController.text,
          fromName: _smtpFromNameController.text,
        ),
      );
      final settings = await _endpointSettingsService.getSmtpSettings();
      if (!mounted) return;
      setState(() {
        _smtpEnabled = settings.enabled;
        _smtpHostController.text = settings.host;
        _smtpPortController.text = settings.port.toString();
        _smtpUsernameController.text = settings.username;
        _smtpPasswordController.text = settings.password;
        _smtpFromEmailController.text = settings.fromEmail;
        _smtpFromNameController.text = settings.fromName;
      });
      _showSnackBar('SMTP 配置已保存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('保存失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSavingSmtp = false);
    }
  }

  void _showSnackBar(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsSection(
                  title: '登录 / OpenOIDC',
                  icon: Icons.login,
                  description: 'OAuth 登录服务器与公开客户端 ID。客户端不会保存 client secret。',
                  children: [
                    TextField(
                      controller: _oauthBaseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'OpenOIDC 地址',
                        hintText: 'https://id.hamcy.work',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _oauthClientIdController,
                      decoration: const InputDecoration(
                        labelText: 'OAuth Client ID',
                        border: OutlineInputBorder(),
                      ),
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    const _HelpText(
                      '生产环境可填写 OpenOIDC 对外地址，例如 https://id.hamcy.work。修改后下次登录生效。',
                    ),
                    const SizedBox(height: 10),
                    const _ReadonlyInfoRow(
                      label: '移动端回调',
                      value: AppConstants.oauthMobileRedirectUri,
                    ),
                    const SizedBox(height: 6),
                    const _ReadonlyInfoRow(
                      label: '桌面端回调',
                      value: AppConstants.oauthDesktopRedirectUri,
                    ),
                    const SizedBox(height: 12),
                    if (_openOidcTestResult != null)
                      _ConnectionResultPanel(result: _openOidcTestResult!),
                    if (_openOidcTestResult != null) const SizedBox(height: 12),
                    _ActionRow(
                      testLabel: _isTestingOpenOidc ? '测试中...' : '测试 OpenOIDC',
                      saveLabel: _isSavingOpenOidc ? '保存中...' : '保存登录配置',
                      isTesting: _isTestingOpenOidc,
                      isSaving: _isSavingOpenOidc,
                      onTest: _testOpenOidcConnection,
                      onSave: _saveOpenOidcSettings,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed:
                            _isSavingOpenOidc ? null : _resetOpenOidcSettings,
                        icon: const Icon(Icons.restore),
                        label: const Text('恢复默认登录配置'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: '考试 API',
                  icon: Icons.assignment,
                  description: '题库、练习、考试、收藏和 AI 解析接口。',
                  children: [
                    TextField(
                      controller: _examApiUrlController,
                      decoration: const InputDecoration(
                        labelText: '考试 API 地址',
                        hintText: 'http://192.168.1.5:3001',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    const _HelpText('可填写服务器根地址，保存时会自动补全 /api/。'),
                    const SizedBox(height: 12),
                    if (_examApiTestResult != null)
                      _ConnectionResultPanel(result: _examApiTestResult!),
                    if (_examApiTestResult != null) const SizedBox(height: 12),
                    _ActionRow(
                      testLabel: _isTestingExamApi ? '测试中...' : '测试考试 API',
                      saveLabel: _isSavingExamApi ? '保存中...' : '保存考试 API',
                      isTesting: _isTestingExamApi,
                      isSaving: _isSavingExamApi,
                      onTest: _testExamApiConnection,
                      onSave: _saveExamApiUrl,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'beacon-api',
                  icon: Icons.api,
                  description: '频率表、卫星、QSO 与无线电工具接口。',
                  children: [
                    TextField(
                      controller: _beaconApiUrlController,
                      decoration: const InputDecoration(
                        labelText: 'beacon-api 地址',
                        hintText: 'http://192.168.1.5:3002',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    const _HelpText('可填写服务器根地址，保存时会自动补全 /api/v1/。'),
                    const SizedBox(height: 12),
                    if (_beaconApiTestResult != null)
                      _ConnectionResultPanel(result: _beaconApiTestResult!),
                    if (_beaconApiTestResult != null)
                      const SizedBox(height: 12),
                    _ActionRow(
                      testLabel:
                          _isTestingBeaconApi ? '测试中...' : '测试 beacon-api',
                      saveLabel:
                          _isSavingBeaconApi ? '保存中...' : '保存 beacon-api',
                      isTesting: _isTestingBeaconApi,
                      isSaving: _isSavingBeaconApi,
                      onTest: _testBeaconApiConnection,
                      onSave: _saveBeaconApiUrl,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _beaconFrontendUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Beacon 前端地址',
                        hintText: 'http://192.168.1.5:5273',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    const _HelpText(
                      '用于生成 beacon-api 相关公开页面链接，例如 QSL 收妥页面。保存服务器根地址即可。',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSavingBeaconFrontend
                            ? null
                            : _saveBeaconFrontendUrl,
                        icon: _isSavingBeaconFrontend
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSavingBeaconFrontend ? '保存中...' : '保存 Beacon 前端地址',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: '天地图',
                  icon: Icons.map_outlined,
                  description: 'GRID 地图定位页面的天地图底图 Token。',
                  children: [
                    TextField(
                      controller: _tiandituTokenController,
                      decoration: const InputDecoration(
                        labelText: '天地图 Token',
                        hintText: '请输入天地图 tk',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    const _HelpText('Token 仅保存在本机。留空保存会清空天地图配置。'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _isSavingTianditu ? null : _saveTiandituToken,
                        icon: _isSavingTianditu
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSavingTianditu ? '保存中...' : '保存天地图'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'LLM',
                  icon: Icons.auto_awesome,
                  description: '通用大模型接口，默认兼容 OpenAI /v1/chat/completions。',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用 LLM 功能'),
                      subtitle: const Text('传播预测等页面会复用此配置。'),
                      value: _llmEnabled,
                      onChanged: (value) => setState(() {
                        _llmEnabled = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _llmBaseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'OpenAI-compatible 接口地址',
                        hintText: 'https://api.openai.com/v1/chat/completions',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _llmApiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _llmModelController,
                      decoration: const InputDecoration(
                        labelText: '模型',
                        hintText: LlmSettings.defaultModel,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _HelpText(
                      'API Key 仅保存在本机。地址可填写服务根地址或 /v1，保存时会自动补全 chat/completions。',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSavingLlm ? null : _saveLlmSettings,
                        icon: _isSavingLlm
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSavingLlm ? '保存中...' : '保存 LLM'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'SMTP',
                  icon: Icons.outgoing_mail,
                  description: '用于向非 Beacon 用户发送 QSO 确认链接。配置仅保存在本机。',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用 SMTP 发送'),
                      subtitle: const Text('未启用或未填写对方邮箱时，只生成确认链接。'),
                      value: _smtpEnabled,
                      onChanged: (value) => setState(() {
                        _smtpEnabled = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smtpHostController,
                      decoration: const InputDecoration(
                        labelText: 'SMTP 服务器',
                        hintText: 'smtp.example.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _smtpPortController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        hintText: '587',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _smtpUsernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _smtpPasswordController,
                      decoration: const InputDecoration(
                        labelText: '密码 / 授权码（可选）',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _smtpFromEmailController,
                      decoration: const InputDecoration(
                        labelText: '发件邮箱',
                        hintText: 'me@example.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _smtpFromNameController,
                      decoration: const InputDecoration(
                        labelText: '发件名称',
                        hintText: 'Beacon',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _HelpText(
                      'SMTP 密码仅保存在本机。发起非平台用户 QSO 确认时，客户端会随本次请求发送给 beacon-api 用于发信。',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSavingSmtp ? null : _saveSmtpSettings,
                        icon: _isSavingSmtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSavingSmtp ? '保存中...' : '保存 SMTP'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HelpText extends StatelessWidget {
  final String text;

  const _HelpText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _ReadonlyInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String testLabel;
  final String saveLabel;
  final bool isTesting;
  final bool isSaving;
  final VoidCallback onTest;
  final VoidCallback onSave;

  const _ActionRow({
    required this.testLabel,
    required this.saveLabel,
    required this.isTesting,
    required this.isSaving,
    required this.onTest,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 180,
          child: OutlinedButton.icon(
            onPressed: isTesting ? null : onTest,
            icon: isTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(testLabel),
          ),
        ),
        SizedBox(
          width: 180,
          child: FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(saveLabel),
          ),
        ),
      ],
    );
  }
}

class _ConnectionResultPanel extends StatelessWidget {
  final Map<String, dynamic> result;

  const _ConnectionResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = result['success'] == true;
    final color = success ? Colors.green : scheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            success ? '连接成功' : '连接失败',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '${result['message']}\n耗时: ${result['latency']}ms',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
