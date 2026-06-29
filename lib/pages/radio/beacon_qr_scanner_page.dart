import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/beacon_qr_parser.dart';
import 'qsl_public_page.dart';

class BeaconQrScannerPage extends StatefulWidget {
  const BeaconQrScannerPage({super.key});

  @override
  State<BeaconQrScannerPage> createState() => _BeaconQrScannerPageState();
}

class _BeaconQrScannerPageState extends State<BeaconQrScannerPage> {
  late final MobileScannerController _controller;
  final _manualController = TextEditingController();
  bool _handled = false;
  String? _lastInvalidValue;
  String? _message;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _manualController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue ?? barcode.displayValue ?? '')
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    await _handleValue(value);
  }

  Future<void> _handleValue(String value) async {
    final route = parseBeaconQslRouteFromText(value);
    if (route == null) {
      if (_lastInvalidValue == value) return;
      _lastInvalidValue = value;
      if (!mounted) return;
      setState(() => _message = '未识别到 Beacon QSL 收妥二维码');
      return;
    }

    _handled = true;
    await _controller.stop();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QslPublicPage(
          linkType: route.linkType,
          token: route.token,
          apiBaseUrl: route.apiBaseUrl,
        ),
      ),
    );
  }

  Future<void> _openManualInput() async {
    _manualController.clear();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('粘贴二维码内容'),
          content: TextField(
            controller: _manualController,
            decoration: const InputDecoration(
              labelText: 'Beacon 二维码链接',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_manualController.text),
              child: const Text('解析'),
            ),
          ],
        );
      },
    );
    if (value == null || value.trim().isEmpty) return;
    await _handleValue(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('扫描 Beacon 二维码'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '切换摄像头',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
          IconButton(
            tooltip: '手电筒',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
            placeholderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (context, error) => _ScannerError(
              message: _scannerErrorMessage(error),
              onManualInput: _openManualInput,
            ),
          ),
          const _ScannerOverlay(),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(0, 0, 0, 0.66),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _message ?? '对准 Beacon QSL 二维码，可自动解析日志确认/收妥信息。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openManualInput,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: scheme.primaryContainer),
                      ),
                      icon: const Icon(Icons.link),
                      label: const Text('手动粘贴链接'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scannerErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return '没有相机权限，请在系统设置中允许 Beacon 使用相机。';
      case MobileScannerErrorCode.unsupported:
        return '当前平台不支持相机扫码，请使用手动粘贴链接。';
      default:
        return '相机启动失败，请重试或手动粘贴链接。';
    }
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 238,
          height: 238,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Stack(
            children: [
              _Corner(alignment: Alignment.topLeft),
              _Corner(alignment: Alignment.topRight),
              _Corner(alignment: Alignment.bottomLeft),
              _Corner(alignment: Alignment.bottomRight),
            ],
          ),
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Alignment alignment;

  const _Corner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? const BorderSide(color: Color(0xff4fd2ff), width: 4)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? const BorderSide(color: Color(0xff4fd2ff), width: 4)
                : BorderSide.none,
            left: alignment.x < 0
                ? const BorderSide(color: Color(0xff4fd2ff), width: 4)
                : BorderSide.none,
            right: alignment.x > 0
                ? const BorderSide(color: Color(0xff4fd2ff), width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  final String message;
  final VoidCallback onManualInput;

  const _ScannerError({
    required this.message,
    required this.onManualInput,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white, size: 48),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onManualInput,
                icon: const Icon(Icons.link),
                label: const Text('手动粘贴链接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
