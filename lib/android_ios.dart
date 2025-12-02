// part of flutter_tesseract_ocr;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tesseract_ocr/constants.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class FlutterTesseractOcr {
  static const String TESS_DATA_CONFIG = 'assets/tessdata_config.json';
  static const String TESS_DATA_PATH = 'assets/tessdata';
  static const String _channelName = 'flutter_tesseract_ocr';

  static String? _cachedTessDataPath;

  static Future<void> init() async {
    _cachedTessDataPath = await prepareTessData();
  }

  static String get tessDataPath {
    assert(_cachedTessDataPath != null, 'FlutterTesseractOcr.init() must be called before using tessDataPath');
    return _cachedTessDataPath!;
  }

  /// image to  text
  ///```
  /// String _ocrText = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  static Future<String> extractText(
    String imagePath, {
    String? language,
    String? tessDataPath,
    Map<String, String>? args,
  }) async {
    return await _extractImageData(
      imagePath: imagePath,
      imageBytes: null,
      method: Constants.methodExtractText,
      language: language,
      args: args,
      tessDataPath: tessDataPath,
    );
  }

  /// image to text with image data (Uint8List)
  /// ```
  /// String _ocrText = await FlutterTesseractOcr.extractTextFromData(imageData, language: langs, args: {
  ///   "preserve_interword_spaces": "1",});
  /// ```
  static Future<String> extractTextFromData(
    Uint8List imageBytes, {
    String? language,
    String? tessDataPath,
    Map<String, String>? args,
  }) async {
    return await _extractImageData(
      imagePath: null,
      imageBytes: imageBytes,
      method: Constants.methodExtractText,
      language: language,
      args: args,
      tessDataPath: tessDataPath,
    );
  }

  /// image to  html text(hocr)
  ///```
  /// String _ocrHocr = await FlutterTesseractOcr.extractText(url, language: langs, args: {
  ///    "preserve_interword_spaces": "1",});
  ///```
  static Future<String> extractHocr(
    String imagePath, {
    String? language,
    String? tessDataPath,
    Map<String, String>? args,
  }) async {
    return await _extractImageData(
      imagePath: imagePath,
      imageBytes: null,
      method: Constants.methodExtractHocr,
      language: language,
      args: args,
      tessDataPath: tessDataPath,
    );
  }

  /// image to html text (hocr) with image data (Uint8List)
  /// ```
  /// String _ocrHocr = await FlutterTesseractOcr.extractHocrFromData(imageData, language: langs, args: {
  ///   "preserve_interword_spaces": "1",});
  /// ```
  static Future<String> extractHocrFromData(
    Uint8List imageBytes, {
    String? language,
    String? tessDataPath,
    Map<String, String>? args,
  }) async {
    return await _extractImageData(
      imagePath: null,
      imageBytes: imageBytes,
      method: Constants.methodExtractHocr,
      language: language,
      args: args,
      tessDataPath: tessDataPath,
    );
  }

  static Future<String> prepareTessData() async {
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String tessdataDirectory = join(appDirectory.path, 'tessdata');

    if (!await Directory(tessdataDirectory).exists()) {
      await Directory(tessdataDirectory).create(recursive: true);
    }

    await _copyTessDataToAppDocumentsDirectory(tessdataDirectory);

    return appDirectory.path;
  }

  static Future<String> getTessdataPath() => prepareTessData();

  static Future _copyTessDataToAppDocumentsDirectory(String tessdataDirectory) async {
    final String config = await rootBundle.loadString(TESS_DATA_CONFIG);
    Map<String, dynamic> files = jsonDecode(config);
    for (var file in files["files"]) {
      if (!await File('$tessdataDirectory/$file').exists()) {
        final ByteData data = await rootBundle.load('$TESS_DATA_PATH/$file');
        final Uint8List bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File('$tessdataDirectory/$file').writeAsBytes(bytes);
      }
    }
  }

  static Future<String> _extractImageData({
    String? imagePath,
    Uint8List? imageBytes,
    required String method,
    required String? tessDataPath,
    String? language,
    Map<String, String>? args,
  }) async {
    assert(imagePath?.isNotEmpty ?? false || imageBytes != null, 'You must provide either imagePath or imageBytes');

    if (imagePath?.isNotEmpty ?? false) {
      assert(await File(imagePath!).exists(), true);
    }

    final String tessData = await _resolveTessDataPath(tessDataPath);
    final MethodChannel channel = _channelForCurrentIsolate();

    final String extractedText = await channel.invokeMethod(method, <String, dynamic>{
      'imagePath': imagePath?.isNotEmpty ?? false ? imagePath : null,
      'imageBytes': imageBytes,
      'tessData': tessData,
      'language': language,
      'args': args,
    });

    return extractedText;
  }

  static Future<String> _resolveTessDataPath(String? providedPath) async {
    if (providedPath != null) {
      return providedPath;
    }

    final String? cachedPath = _cachedTessDataPath;

    if (cachedPath != null) {
      return cachedPath;
    }

    return await prepareTessData();
  }

  // Return channel for actual isolate
  static MethodChannel _channelForCurrentIsolate() {
    BinaryMessenger messenger;

    try {
      messenger = ServicesBinding.instance.defaultBinaryMessenger;
    } catch (_) {
      messenger = BackgroundIsolateBinaryMessenger.instance;
    }

    return MethodChannel(
      _channelName,
      const StandardMethodCodec(),
      messenger,
    );
  }
}
