
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'package:image/image.dart' as img;


class HazardModelService {
  static Interpreter? _interpreter;
  static List<String>? _labels;

  static Future<void> loadModel() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset('assets/models/ocean_hazard_model.tflite');
    // Optionally load labels if you have a labels.txt file
    // _labels = await FileUtil.loadLabels('assets/models/labels.txt');
  }

  static Future<Map<String, dynamic>> runModelOnImage(String imagePath) async {
    if (_interpreter == null) {
      await loadModel();
    }

    // Load image and preprocess
    // Load and preprocess image using image package
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    img.Image? oriImage = img.decodeImage(bytes);
    if (oriImage == null) {
      return {"error": "Could not decode image"};
    }
    // Resize to 224x224 (or your model's input size)
    img.Image resized = img.copyResize(oriImage, width: 224, height: 224);

    // Convert image to Float32List for model input
    // Assuming input shape is [1, 224, 224, 3] and type is float32
    var input = List.generate(1 * 224 * 224 * 3, (i) => 0.0).reshape([1, 224, 224, 3]);
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0; // Red
        input[0][y][x][1] = pixel.g / 255.0; // Green
        input[0][y][x][2] = pixel.b / 255.0; // Blue
      }
    }

    // Prepare output
    var outputShapes = _interpreter!.getOutputTensors().map((t) => t.shape).toList();
    var output = List.filled(outputShapes[0][1], 0.0).reshape([1, outputShapes[0][1]]);

    _interpreter!.run(input, output);

    // Postprocess: find top result
    double maxScore = -1;
    int maxIndex = -1;
    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        maxIndex = i;
      }
    }

    String hazardClass = _labels != null && maxIndex >= 0 && maxIndex < _labels!.length
        ? _labels![maxIndex]
        : 'Class $maxIndex';

    return {
      "hazard_class": hazardClass,
      "intensity": (maxScore * 100).toStringAsFixed(1) + '%',
      "raw": output[0],
    };
  }

  static Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
