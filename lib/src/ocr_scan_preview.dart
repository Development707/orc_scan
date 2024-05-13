import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ocr_scan/src/utils/coordinates_translator.dart';

import 'ocr_scan_zone_painter.dart';

class OcrScanPreview extends StatefulWidget {
  const OcrScanPreview({
    super.key,

    /// Camera config
    this.enableAudio = false,
    this.controller,
    this.textRecognizer,
    this.child,

    /// OCR config
    this.ocrProcess = true,
    this.ocrDuration = const Duration(seconds: 2),
    required this.ocrZonePainter,
    required this.onOcrTextLine,
  });

  final bool enableAudio;
  final CameraController? controller;
  final TextRecognizer? textRecognizer;
  final Widget? child;

  final bool ocrProcess;
  final Duration ocrDuration;
  final OcrScanZonePainter ocrZonePainter;
  final ValueChanged<(int, List<TextLine>)>? onOcrTextLine;

  @override
  State<OcrScanPreview> createState() => _OcrScanPreviewState();
}

class _OcrScanPreviewState extends State<OcrScanPreview>
    with WidgetsBindingObserver {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  TextRecognizer? _textRecognizer;
  int _cameraIndex = -1;
  bool _canProcess = true;

  /// Controls a device camera.
  CameraController? get controller {
    return widget.controller ?? _controller;
  }

  /// A text recognizer that recognizes text from a given [InputImage].
  TextRecognizer get textRecognizer {
    return widget.textRecognizer ?? (_textRecognizer ??= TextRecognizer());
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
    _textRecognizer?.close();
  }

  @override
  void didUpdateWidget(covariant OcrScanPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ocrProcess != widget.ocrProcess) {
      if (controller?.value.isInitialized ?? false) {
        if (widget.ocrProcess && !controller!.value.isStreamingImages) {
          /// Start image stream
          controller?.startImageStream(_processImage);
        } else if (controller!.value.isStreamingImages) {
          /// Stop image stream
          controller?.stopImageStream();
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startLiveFeed(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return CameraPreview(
      controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: widget.ocrZonePainter),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }

  Future<void> _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection ==
          widget.ocrZonePainter.cameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1 || widget.controller != null) {
      _startLiveFeed(null);
    }
  }

  Future _startLiveFeed(CameraDescription? description) async {
    description ??= _cameras[_cameraIndex];

    /// Create camera controller form package.
    if (widget.controller == null) {
      _controller = CameraController(
        description,

        /// Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
        ResolutionPreset.veryHigh,
        enableAudio: widget.enableAudio,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
    }

    /// Set size preview
    controller?.value = controller!.value.copyWith(
      previewSize: widget.ocrZonePainter.imageSize,
    );

    /// Initialize camera controller
    await controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });

    /// Start image stream
    if (widget.ocrProcess) {
      controller?.startImageStream(_processImage);
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (!_canProcess) return;
    _canProcess = false;

    try {
      final InputImage? inputImage = _inputImageFromCameraImage(image);
      if (inputImage != null) {
        await Future.wait([
          processTextRecognizer(inputImage),
          Future.delayed(widget.ocrDuration),
        ]);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _canProcess = true;
    }
  }

  Future<void> processTextRecognizer(InputImage inputImage) async {
    /// Process image
    final result = await textRecognizer.processImage(inputImage);

    /// Callback
    if (widget.onOcrTextLine != null) {
      /// Create lines
      List<TextLine> lines = result.blocks.fold(<TextLine>[], (pre, e) {
        return pre..addAll(e.lines);
      });

      /// Filter zones
      final OcrScanZonePainter ocrZonePainter = widget.ocrZonePainter;

      if (inputImage.metadata == null) return;
      final Size imageSize = inputImage.metadata!.size;
      final InputImageRotation rotation = inputImage.metadata!.rotation;

      if (controller == null) return;
      final cameraLensDirection = controller!.description.lensDirection;

      for (int i = 0; i < ocrZonePainter.elements.length; i++) {
        final OcrScanZone zone = ocrZonePainter.elements[i];
        final List<TextLine> filtered = [];

        for (TextLine textLine in lines) {
          final Rect boundingBox = Rect.fromLTRB(
            translateX(
              textLine.boundingBox.left,
              ocrZonePainter.imageSize,
              imageSize,
              rotation,
              cameraLensDirection,
            ),
            translateY(
              textLine.boundingBox.top,
              ocrZonePainter.imageSize,
              imageSize,
              rotation,
              cameraLensDirection,
            ),
            translateX(
              textLine.boundingBox.right,
              ocrZonePainter.imageSize,
              imageSize,
              rotation,
              cameraLensDirection,
            ),
            translateY(
              textLine.boundingBox.bottom,
              ocrZonePainter.imageSize,
              imageSize,
              rotation,
              cameraLensDirection,
            ),
          );

          if (boundingBox.top < zone.boundingBox.top ||
              boundingBox.bottom > zone.boundingBox.bottom ||
              boundingBox.left < zone.boundingBox.left ||
              boundingBox.right > zone.boundingBox.right) {
            continue;
          }

          filtered.add(textLine);
        }

        widget.onOcrTextLine!.call((i, filtered));
      }
    }
  }

  /// Convert [CameraImage] to [InputImage]
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (controller == null) return null;

    /// Get camera rotation
    final CameraDescription camera = controller!.description;
    final InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    /// Get image format
    /// Validate format depending on platform
    /// only supported formats:
    /// * nv21 for Android
    /// * bgra8888 for iOS
    final InputImageFormat? format =
        InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    /// Since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final Plane plane = image.planes.first;

    /// Compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
}