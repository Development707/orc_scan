import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:ocr_scan/ocr_scan.dart';

/// Scan file
class ScanFile extends StatefulWidget {
  /// Scan file
  const ScanFile({
    super.key,
    this.children,

    /// File config
    required this.scanFile,
    this.previewSize = const Size(1280, 720),
    this.onPreviewSizeChange,

    /// Text recognizer config
    this.textRecognizerConfig = const TextRecognizerConfig(onTextLine: null),

    /// Barcode scanner config
    this.barcodeScannerConfig = const BarcodeScannerConfig(onBarcode: null),
  });

  /// Children in Stack
  final List<Widget>? children;

  /// File: Scan process
  final File scanFile;

  /// File: Preview size
  final Size previewSize;

  /// File: Callback when size image change
  final ValueChanged<Size>? onPreviewSizeChange;

  /// MLKit: Text recognizer config
  final TextRecognizerConfig textRecognizerConfig;

  /// MLKit: Barcode scanner config
  final BarcodeScannerConfig barcodeScannerConfig;

  @override
  State<ScanFile> createState() => ScanFileState();
}

/// Scan file state
class ScanFileState extends ScanFileStateDelegate with FileMixin {
  @override
  TextRecognizerConfig get textRecognizerConfig => widget.textRecognizerConfig;

  @override
  BarcodeScannerConfig get barcodeConfig => widget.barcodeScannerConfig;
}

/// Scan file state delegate
abstract class ScanFileStateDelegate extends State<ScanFile>
    with TextRecognizerMixin, BarcodeScannerMixin {
  /// Preview size
  ValueNotifier<Size> get previewSize;

  /// Process image
  Future<void> processImage(File file);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Size>(
      valueListenable: previewSize,
      builder: (context, Size value, _) {
        return AspectRatio(
          aspectRatio: value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(widget.scanFile, fit: BoxFit.fill),
              CustomPaint(
                painter: widget.textRecognizerConfig.zonePainter
                  ?..previewSize = value
                  ..cameraLensDirection = CameraLensDirection.back,
              ),
              CustomPaint(
                painter: widget.barcodeScannerConfig.zonePainter
                  ?..previewSize = value
                  ..cameraLensDirection = CameraLensDirection.back,
              ),
              ...?widget.children,
            ],
          ),
        );
      },
    );
  }
}
