import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  File? _imageFile;
  List<ImageLabel>? _labels;
  bool _isLoading = false;
  String? _error;
  String? _userRole;
  Map<String, dynamic>? _metaResult;

  final List<String> _roles = ["Marine Official", "Fishermen", "Citizen"];
  bool _showQuestions = false;
  Map<String, bool?> _userAnswers = {};
  bool _showConfirm = false;
  String? _finalHazard;
  double? _finalScore;
  String? _userHazard;

  final List<String> _hazardTypes = ["High Waves", "Flooding", "Debris", "Oil Spill"];
  final Map<String, String> _labelToHazard = {
    'wave': 'High Waves',
    'flood': 'Flooding',
    'debris': 'Debris',
    'oil': 'Oil Spill',
  };

  Future<String> getModelPath(String asset) async {
    // Implementation to get the model path
    return asset; // Replace with actual path resolution logic
  }

  Future<void> _pickAndLabelImage() async {
    setState(() {
      _isLoading = true;
      _labels = null;
      _error = null;
      _metaResult = null;
      _showQuestions = false;
      _showConfirm = false;
    });

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final file = File(picked.path);
      final inputImage = InputImage.fromFile(file);
      
      // Use ML Kit base model
      final options = ImageLabelerOptions(confidenceThreshold: 0.5);
      final imageLabeler = ImageLabeler(options: options);
      final labels = await imageLabeler.processImage(inputImage);
      imageLabeler.close();

      // Check for hazard types in labels
      Map<String, bool?> userAnswers = {};
      for (final l in labels.take(5)) {
        final lower = l.label.toLowerCase();
        _labelToHazard.forEach((key, hazard) {
          if (lower.contains(key)) {
            userAnswers[hazard] = null;
          }
        });
      }

      // Assign weightage based on user role
      double weightage = 0.3;
      if (_userRole == "Marine Official") {
        weightage = 1.0;
      } else if (_userRole == "Fishermen") {
        weightage = 0.6;
      }

      // Compose metadata
      _metaResult = {
        "user_role": _userRole,
        "weightage": weightage,
        "labels": labels
            .map(
              (l) => {
                "label": l.label,
                "confidence": l.confidence,
                "index": l.index,
              },
            )
            .toList(),
        "timestamp": DateTime.now().toIso8601String(),
      };

      setState(() {
        _imageFile = file;
        _labels = labels;
        _isLoading = false;
        _showQuestions = true; // Always show questions for testing
        _userAnswers = userAnswers;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onQuestionsSubmit() {
    // Process user answers and determine final hazard
    Map<String, int> hazardCounts = {};
    
    _userAnswers.forEach((hazard, answer) {
      if (answer == true) {
        hazardCounts[hazard] = (hazardCounts[hazard] ?? 0) + 1;
      }
    });

    if (hazardCounts.isNotEmpty) {
      // Find hazard with highest user confirmation
      String topHazard = hazardCounts.keys.first;
      int maxCount = hazardCounts[topHazard] ?? 0;
      
      hazardCounts.forEach((hazard, count) {
        if (count > maxCount) {
          topHazard = hazard;
          maxCount = count;
        }
      });

      _finalHazard = topHazard;
      _finalScore = 0.8; // Placeholder confidence score
    }

    setState(() {
      _showQuestions = false;
      _showConfirm = true;
    });
  }

  void _onFinalConfirm(String? hazardType) {
    if (hazardType != null) {
      // Process final confirmation
      print('Final hazard confirmed: $hazardType');
      
      // You can add your final processing logic here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hazard "$hazardType" has been confirmed and reported.')),
      );
      
      // Reset the form
      setState(() {
        _imageFile = null;
        _labels = null;
        _metaResult = null;
        _showQuestions = false;
        _showConfirm = false;
        _userAnswers = {};
        _finalHazard = null;
        _finalScore = null;
        _userHazard = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MLKit Image Labeling Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DropdownButtonFormField<String>(
                value: _userRole,
                items: _roles
                    .map(
                      (role) => DropdownMenuItem(value: role, child: Text(role)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _userRole = val),
                decoration: const InputDecoration(
                  labelText: 'Select User Role',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading || _userRole == null ? null : _pickAndLabelImage,
                child: const Text('Pick Image and Label'),
              ),
              const SizedBox(height: 16),
              if (_isLoading) const CircularProgressIndicator(),
              if (_error != null)
                Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              if (_imageFile != null) 
                Image.file(_imageFile!, height: 200),
              if (_labels != null)
                Container(
                  height: 200,
                  child: ListView(
                    children: _labels!
                        .map(
                          (label) => ListTile(
                            title: Text(label.label),
                            subtitle: Text('Confidence: ${label.confidence.toStringAsFixed(2)}'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (_metaResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueGrey.shade800),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _metaResult.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showQuestions)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Please answer the following questions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Debug info
                    Text('Debug: Questions count: ${_userAnswers.length}'),
                    const SizedBox(height: 8),
                    // Always show all hazard types for testing
                    ...(_userAnswers.isEmpty ? _hazardTypes : _userAnswers.keys.toList()).map((hazard) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Do you see $hazard in this image?',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Radio<bool>(
                                    value: true,
                                    groupValue: _userAnswers[hazard],
                                    onChanged: (val) {
                                      setState(() {
                                        if (_userAnswers.isEmpty) {
                                          // Initialize all answers if empty
                                          for (String h in _hazardTypes) {
                                            _userAnswers[h] = null;
                                          }
                                        }
                                        _userAnswers[hazard] = val;
                                      });
                                    },
                                  ),
                                  const Text('Yes'),
                                  const SizedBox(width: 20),
                                  Radio<bool>(
                                    value: false,
                                    groupValue: _userAnswers[hazard],
                                    onChanged: (val) {
                                      setState(() {
                                        if (_userAnswers.isEmpty) {
                                          // Initialize all answers if empty
                                          for (String h in _hazardTypes) {
                                            _userAnswers[h] = null;
                                          }
                                        }
                                        _userAnswers[hazard] = val;
                                      });
                                    },
                                  ),
                                  const Text('No'),
                                ],
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _userAnswers.values.any((v) => v != null) ? _onQuestionsSubmit : null,
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              if (_showConfirm)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('System suggestion based on answers and model:'),
                    const SizedBox(height: 8),
                    if (_finalHazard != null)
                      Text('Detected Hazard: $_finalHazard (Confidence: ${(_finalScore ?? 0) * 100}%)'),
                    if (_finalHazard == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('No clear agreement. Please select the correct hazard type:'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _userHazard,
                            items: _hazardTypes
                                .map((hazard) => DropdownMenuItem(value: hazard, child: Text(hazard)))
                                .toList(),
                            onChanged: (val) => setState(() => _userHazard = val),
                            decoration: const InputDecoration(
                              labelText: 'Select Hazard Type',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: (_finalHazard != null || _userHazard != null) 
                          ? () => _onFinalConfirm(_finalHazard ?? _userHazard)
                          : null,
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}