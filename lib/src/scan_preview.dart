import 'package:flutter/material.dart';
import 'package:ocr_scan/ocr_scan.dart';

///  scan preview
class ScanPreview extends StatefulWidget {
  ///  scan preview
  const ScanPreview({
    super.key,
    this.children,

    /// Camera config
    this.enableAudio = false,
    this.previewSize = const Size(1280, 720),
    this.cameraLensDirection = CameraLensDirection.back,
    this.scanDuration = const Duration(seconds: 2),
    this.scanProcess = false,
    this.controller,

    /// Text recognizer config
    this.textRecognizerConfig = const TextRecognizerConfig(onTextLine: null),

    /// Barcode scanner config
    this.barcodeScannerConfig = const BarcodeScannerConfig(onBarcode: null),
  });

  /// Children in Stack
  final List<Widget>? children;

  /// Camera: Enable audio
  final bool enableAudio;

  /// Camera: Preview size
  ///
  /// Issue: https://github.com/flutter/flutter/issues/15953
  final Size previewSize;

  /// Camera: Camera lens direction
  final CameraLensDirection cameraLensDirection;

  /// Camera: scan duration
  final Duration scanDuration;

  /// Camera: scan process
  final bool scanProcess;

  /// Camera: Controller
  final CameraController? controller;

  /// MLKit: Text recognizer config
  final TextRecognizerConfig textRecognizerConfig;

  /// MLKit: Barcode scanner config
  final BarcodeScannerConfig barcodeScannerConfig;

  @override
  State<ScanPreview> createState() => ScanPreviewState();
}

///  scan preview state
class ScanPreviewState extends ScanPreviewStateDelegate
    with WidgetsBindingObserver, CameraMixin {
  @override
  TextRecognizerConfig get textRecognizerConfig => widget.textRecognizerConfig;

  @override
  BarcodeScannerConfig get barcodeConfig => widget.barcodeScannerConfig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  bool _isDisposed = false;

  /// Handling Lifecycle states
  /// https://pub.dev/packages/camera#handling-lifecycle-states
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _isDisposed = true;
    } else if (state == AppLifecycleState.resumed) {
      startLiveFeed(cameraController.description);
      _isDisposed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }
    return super.build(context);
  }
}

///  scan preview state delegate
abstract class ScanPreviewStateDelegate extends State<ScanPreview>
    with TextRecognizerMixin, BarcodeScannerMixin {
  /// Controls a device camera.
  CameraController? get controller;

  /// Process image
  Future<void> processImage(CameraImage image);

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = this.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return CameraPreview(
      controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: widget.textRecognizerConfig.zonePainter
              ?..cameraLensDirection = controller.description.lensDirection
              ..previewSize = controller.value.previewSize ?? Size.zero,
          ),
          CustomPaint(
            painter: widget.barcodeScannerConfig.zonePainter
              ?..cameraLensDirection = controller.description.lensDirection
              ..previewSize = controller.value.previewSize ?? Size.zero,
          ),
          ...?widget.children,
        ],
      ),
    );
  }
}
