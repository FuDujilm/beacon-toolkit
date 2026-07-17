import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/radio_profile.dart';
import '../../services/auth_service.dart';
import '../../services/beacon_radio_profile_service.dart';
import '../../services/local_data_backup_service.dart';
import '../../services/local_database_service.dart';
import '../../services/grid_locator_service.dart';
import '../../services/theme_controller.dart';
import '../../services/user_settings_service.dart';
import 'common_tools_settings_page.dart';
import 'discovery_settings_page.dart';
import 'qrz_settings_page.dart';
import 'theme_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _userSettingsService = UserSettingsService();
  final _beaconRadioProfileService = BeaconRadioProfileService();
  final _backupService = LocalDataBackupService();
  final _databaseService = LocalDatabaseService();
  final _gridLocatorService = const GridLocatorService();
  final _callsignController = TextEditingController();
  final _qthController = TextEditingController();
  final _gridController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _altitudeController = TextEditingController();
  final _licenseExpiryController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocating = false;
  bool _isLoggedIn = false;
  bool _enableWrongQuestionWeight = false;
  double _dailyQuestionLimit = 10;
  String _examQuestionPreference = 'SYSTEM_PRESET';
  String _licenseClass = 'A 级';
  String? _accountEmail;
  String? _accountName;
  String? _accountAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _callsignController.dispose();
    _qthController.dispose();
    _gridController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _altitudeController.dispose();
    _licenseExpiryController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final authService = context.read<AuthService>();
    final isLoggedIn = await authService.isLoggedIn();
    final accountInfo =
        isLoggedIn ? await authService.getCurrentUserInfo() : null;
    final settings = await _userSettingsService.getSettings();
    var radioProfile = await _databaseService.getRadioProfile();
    if (isLoggedIn) {
      try {
        final onlineProfile =
            await _beaconRadioProfileService.getRadioProfile();
        if (onlineProfile != null) {
          radioProfile = onlineProfile;
          await _databaseService.saveRadioProfile(onlineProfile);
        }
      } catch (_) {
        // beacon-api profile sync is optional; local profile remains usable.
      }
    }
    final callsign = radioProfile.callsign;

    if (!mounted) return;
    setState(() {
      _isLoggedIn = isLoggedIn;
      _accountEmail = accountInfo?['email']?.toString();
      _accountName = accountInfo?['name']?.toString() ??
          accountInfo?['display_name']?.toString();
      _accountAvatarUrl = accountInfo?['image']?.toString() ??
          accountInfo?['avatar_url']?.toString();
      _callsignController.text =
          callsign == RadioProfile.defaults.callsign ? '' : callsign;
      _qthController.text =
          radioProfile.qth == RadioProfile.defaults.qth ? '' : radioProfile.qth;
      _gridController.text = radioProfile.grid == RadioProfile.defaults.grid
          ? ''
          : radioProfile.grid;
      _latitudeController.text = radioProfile.latitude == null
          ? ''
          : _formatCoordinate(radioProfile.latitude!);
      _longitudeController.text = radioProfile.longitude == null
          ? ''
          : _formatCoordinate(radioProfile.longitude!);
      _altitudeController.text = _formatAltitude(radioProfile.altitudeMeters);
      _licenseClass = radioProfile.licenseClass;
      _licenseExpiryController.text =
          radioProfile.licenseExpiry == RadioProfile.defaults.licenseExpiry
              ? ''
              : radioProfile.licenseExpiry;
      _enableWrongQuestionWeight =
          settings['enableWrongQuestionWeight'] == true;
      final dailyTarget = settings['dailyPracticeTarget'];
      if (dailyTarget is num) {
        _dailyQuestionLimit = dailyTarget.toDouble().clamp(5, 50);
      }
      final preference = settings['examQuestionPreference'];
      if (preference == 'FULL_RANDOM' || preference == 'SYSTEM_PRESET') {
        _examQuestionPreference = preference as String;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final saved = <String>[];
    final skipped = <String>[];
    try {
      final learningPreferences = {
        'enableWrongQuestionWeight': _enableWrongQuestionWeight,
        'examQuestionPreference': _examQuestionPreference,
        'dailyPracticeTarget': _dailyQuestionLimit.round(),
      };
      final radioProfile = RadioProfile(
        callsign: _callsignController.text.trim().isEmpty
            ? RadioProfile.defaults.callsign
            : _callsignController.text.trim().toUpperCase(),
        qth: _qthController.text.trim().isEmpty
            ? RadioProfile.defaults.qth
            : _qthController.text.trim(),
        grid: _gridController.text.trim().isEmpty
            ? RadioProfile.defaults.grid
            : _gridController.text.trim().toUpperCase(),
        latitude: _parseCoordinate(
          _latitudeController.text,
          min: -90,
          max: 90,
          label: '纬度',
        ),
        longitude: _parseCoordinate(
          _longitudeController.text,
          min: -180,
          max: 180,
          label: '经度',
        ),
        altitudeMeters: _parseAltitude(_altitudeController.text),
        licenseClass: _licenseClass,
        licenseExpiry: _licenseExpiryController.text.trim().isEmpty
            ? RadioProfile.defaults.licenseExpiry
            : _licenseExpiryController.text.trim(),
      );

      await _databaseService.saveRadioProfile(radioProfile);
      saved.add('本地电台资料');

      if (_isLoggedIn) {
        try {
          await _beaconRadioProfileService.saveRadioProfile(radioProfile);
          saved.add('beacon-api 电台资料');
        } catch (e) {
          skipped.add('beacon-api 电台资料（${_friendlySaveError(e)}）');
        }
      }

      try {
        await _userSettingsService.updateSettings(
          learningPreferences,
        );
        saved.add('学习偏好');
      } catch (e) {
        skipped.add('在线学习偏好（${_friendlySaveError(e)}）');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_saveSummary(saved: saved, skipped: skipped)),
          backgroundColor: skipped.isEmpty ? null : Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fillFromDeviceLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const FormatException('定位服务未开启');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const FormatException('定位权限未授权');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const FormatException('定位权限被永久拒绝，请在系统设置中开启');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final grid = _gridLocatorService.encodeMaidenhead(
        latitude: position.latitude,
        longitude: position.longitude,
        precision: 6,
      );
      final qth =
          '当前位置 ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      if (!mounted) return;
      setState(() {
        _qthController.text = qth;
        _gridController.text = grid.toUpperCase();
        _latitudeController.text = _formatCoordinate(position.latitude);
        _longitudeController.text = _formatCoordinate(position.longitude);
        _altitudeController.text = _formatAltitude(position.altitude);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已根据设备定位填写 QTH、Grid、经纬度和海拔')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('定位失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  double? _parseCoordinate(
    String value, {
    required double min,
    required double max,
    required String label,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < min || parsed > max) {
      throw FormatException('$label 必须在 $min 到 $max 之间');
    }
    return parsed;
  }

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(6);
  }

  double _parseAltitude(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    final parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite) {
      throw const FormatException('海拔必须是有效数字');
    }
    return parsed;
  }

  String _formatAltitude(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
  }

  String _saveSummary({
    required List<String> saved,
    required List<String> skipped,
  }) {
    final parts = <String>[];
    if (saved.isNotEmpty) {
      parts.add('已保存：${saved.join('、')}');
    }
    if (skipped.isNotEmpty) {
      parts.add('未保存：${skipped.join('、')}');
    }
    return parts.isEmpty ? '没有可保存的设置' : parts.join('\n');
  }

  String _friendlySaveError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return 'API $statusCode';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'API 超时';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'API 不可用';
      }
    }
    final message = error.toString();
    return message.length > 60 ? '${message.substring(0, 60)}...' : message;
  }

  Future<void> _logout() async {
    await context.read<AuthService>().logout();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _accountEmail = null;
      _accountName = null;
      _accountAvatarUrl = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已退出登录')),
    );
  }

  Future<void> _login() async {
    try {
      final user = await context.read<AuthService>().loginWithOAuth();
      final callsign = user['callsign'] as String?;
      if (callsign != null && callsign.trim().isNotEmpty) {
        final profile = await _databaseService.getRadioProfile();
        await _databaseService.saveRadioProfile(
          profile.copyWith(callsign: callsign.trim().toUpperCase()),
        );
      }
      if (!mounted) return;
      setState(() {
        _accountEmail = user['email']?.toString();
        _accountName = user['name']?.toString();
        _accountAvatarUrl =
            user['image']?.toString() ?? user['avatar_url']?.toString();
      });
      await _loadSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportLocalData() async {
    try {
      final path = await _backupService.exportToJsonFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到 $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importLocalData() async {
    try {
      await _backupService.importFromJsonFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入完成')),
      );
      await context.read<ThemeController>().load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLoggedIn ? '个人设置' : '学习偏好')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_isLoggedIn) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        _AccountAvatar(
                          imageUrl: _accountAvatarUrl,
                          label: _accountName ?? _accountEmail,
                          radius: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _accountEmail?.trim().isNotEmpty == true
                                    ? _accountEmail!
                                    : '已登录账号',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                _accountName?.trim().isNotEmpty == true
                                    ? _accountName!
                                    : 'OpenOIDC 已登录',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isLoggedIn)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              child: Icon(Icons.person_outline, size: 30),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '未登录',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text('登录后同步学习进度和考试记录'),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _login,
                              icon: const Icon(Icons.login),
                              label: const Text('登录'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const Divider(),
                const _SectionTitle('电台资料'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OutlinedButton.icon(
                    onPressed: _isLocating ? null : _fillFromDeviceLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isLocating ? '定位中...' : '根据设备定位填写'),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('电台呼号'),
                  subtitle: const Text('登录后优先同步账号呼号，也可手动修改'),
                  trailing: SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _callsignController,
                      textAlign: TextAlign.end,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '未设置',
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('QTH'),
                  subtitle: const Text('所在地展示在首页资料卡'),
                  trailing: SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _qthController,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '北京',
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Grid'),
                  subtitle: const Text('Maidenhead 网格定位'),
                  trailing: SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _gridController,
                      textAlign: TextAlign.end,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'CN87uj',
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.explore),
                  title: const Text('纬度'),
                  subtitle: const Text('设备定位或手动填写，范围 -90 到 90'),
                  trailing: SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _latitudeController,
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '39.904200',
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.explore_outlined),
                  title: const Text('经度'),
                  subtitle: const Text('设备定位或手动填写，范围 -180 到 180'),
                  trailing: SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _longitudeController,
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '116.407400',
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.terrain),
                  title: const Text('海拔'),
                  subtitle: const Text('单位米，用于卫星多普勒和可见性计算'),
                  trailing: SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _altitudeController,
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        suffixText: 'm',
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium),
                  title: const Text('执照等级'),
                  trailing: DropdownButton<String>(
                    value: _licenseClass,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'A 级', child: Text('A 级')),
                      DropdownMenuItem(value: 'B 级', child: Text('B 级')),
                      DropdownMenuItem(value: 'C 级', child: Text('C 级')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _licenseClass = value);
                      }
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.event_available),
                  title: const Text('执照到期日'),
                  subtitle: const Text('例如 2027-05-01'),
                  trailing: SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _licenseExpiryController,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '未设置',
                      ),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('主题'),
                  subtitle: const Text('主题模式、配色方案和自定义颜色'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ThemePage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize),
                  title: const Text('常用工具设置'),
                  subtitle: const Text('配置首页常用工具入口和展示顺序'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CommonToolsSettingsPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.explore),
                  title: const Text('发现源配置'),
                  subtitle: const Text('地区推荐、资讯源、卫星过境 TLE'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DiscoverySettingsPage(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.travel_explore),
                  title: const Text('QRZ.COM 配置'),
                  subtitle: const Text('呼号查询账号、密码和查询路径'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QrzSettingsPage(),
                    ),
                  ),
                ),
                const Divider(),
                const _SectionTitle('学习偏好'),
                SwitchListTile(
                  secondary: const Icon(Icons.priority_high),
                  title: const Text('错题权重增强'),
                  subtitle: const Text('在随机练习中提高错题出现的概率'),
                  value: _enableWrongQuestionWeight,
                  onChanged: (val) =>
                      setState(() => _enableWrongQuestionWeight = val),
                ),
                ListTile(
                  leading: const Icon(Icons.shuffle),
                  title: const Text('模拟考试出题偏好'),
                  trailing: DropdownButton<String>(
                    value: _examQuestionPreference,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'SYSTEM_PRESET', child: Text('系统预设')),
                      DropdownMenuItem(
                          value: 'FULL_RANDOM', child: Text('完全随机')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _examQuestionPreference = val);
                      }
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text('每日练习题量'),
                  subtitle: Text('${_dailyQuestionLimit.round()} 题 / 天'),
                  trailing: SizedBox(
                    width: 120,
                    child: Slider(
                      value: _dailyQuestionLimit,
                      min: 5,
                      max: 50,
                      divisions: 9,
                      label: _dailyQuestionLimit.round().toString(),
                      onChanged: (val) =>
                          setState(() => _dailyQuestionLimit = val),
                    ),
                  ),
                ),
                if (_isLoggedIn) ...[
                  const Divider(),
                  const _SectionTitle('AI 助手'),
                  const ListTile(
                    leading: Icon(Icons.smart_toy),
                    title: Text('解析风格'),
                    subtitle: Text('移动端暂使用系统默认风格'),
                    trailing: Text('系统默认'),
                  ),
                ],
                const Divider(),
                const _SectionTitle('本地数据'),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('导出本地数据'),
                  subtitle: const Text('导出通联日志等非考试本地数据'),
                  onTap: _exportLocalData,
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入本地数据'),
                  subtitle: const Text('从 Beacon JSON 备份恢复本地数据'),
                  onTap: _importLocalData,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? '保存中...' : '保存设置'),
                  ),
                ),
                if (_isLoggedIn)
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title:
                        const Text('退出登录', style: TextStyle(color: Colors.red)),
                    onTap: _logout,
                  ),
                const SizedBox(height: 32),
                const Center(
                    child:
                        Text('版本 1.0.0', style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? label;
  final double radius;

  const _AccountAvatar({
    required this.imageUrl,
    required this.label,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        _avatarLabel(label),
        style: TextStyle(fontSize: radius * 0.72, fontWeight: FontWeight.w900),
      ),
    );
    if (url.isEmpty || uri == null || !uri.hasScheme) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  String _avatarLabel(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '人';
    return trimmed.characters.first.toUpperCase();
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
