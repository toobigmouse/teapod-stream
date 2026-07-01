import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:zxing2/qrcode.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class QrScanScreenWindows extends StatefulWidget {
  const QrScanScreenWindows({super.key});

  @override
  State<QrScanScreenWindows> createState() => _QrScanScreenWindowsState();
}

class _QrScanScreenWindowsState extends State<QrScanScreenWindows> {
  String? _error;
  bool _loading = false;
  ui.Image? _previewImage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_pickAndDecode);
  }

  Future<void> _pickAndDecode() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final filePath = result.files.single.path;
    if (filePath == null) {
      setState(() => _error = 'Не удалось прочитать файл');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final bytes = await File(filePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final decoded = await _decodeQr(image);
      if (!mounted) return;
      if (decoded != null && decoded.isNotEmpty) {
        setState(() { _previewImage = image; _loading = false; });
        Navigator.pop(context, decoded);
      } else {
        setState(() { _error = 'QR-код не обнаружен'; _previewImage = image; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<String?> _decodeQr(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    final pixels = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final pixelCount = width * height;

    final argbPixels = Int32List(pixelCount);
    for (var i = 0; i < pixelCount; i++) {
      final offset = i * 4;
      final a = pixels[offset + 3];
      final r = pixels[offset];
      final g = pixels[offset + 1];
      final b = pixels[offset + 2];
      argbPixels[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }

    final source = RGBLuminanceSource(width, height, argbPixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = QRCodeReader();

    try {
      final result = reader.decode(bitmap);
      return result.text;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<TeapodTokens>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR из файла'),
      ),
      body: Center(
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: t.accent, strokeWidth: 1.5),
                  const SizedBox(height: 16),
                  Text('Декодирование...', style: AppTheme.mono(size: 12, color: t.textDim)),
                ],
              )
            : _previewImage != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: RawImage(
                            image: _previewImage,
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            color: t.danger.withAlpha(0x1A),
                            child: Text(_error!,
                                style: AppTheme.mono(size: 11, color: t.danger)),
                          ),
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _error = null; _previewImage = null; });
                          _pickAndDecode();
                        },
                        child: const Text('Выбрать другой файл'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 64,
                          color: AppColors.textDisabled),
                      const SizedBox(height: 16),
                      Text('Выберите изображение с QR-кодом',
                          style: AppTheme.sans(size: 14, color: t.textDim)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _pickAndDecode,
                        icon: const Icon(Icons.file_open_rounded, size: 18),
                        label: const Text('Выбрать файл'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
