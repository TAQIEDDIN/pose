import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';

// This file is responsible for allowing the user to select an image from the gallery,
// then applying pose detection to it and displaying the skeleton and calculated angles.

class ImagePoseProcessorScreen extends StatefulWidget {
  const ImagePoseProcessorScreen({super.key});

  @override
  State<ImagePoseProcessorScreen> createState() => _ImagePoseProcessorScreenState();
}

class _ImagePoseProcessorScreenState extends State<ImagePoseProcessorScreen> {
  File? _pickedImageFile; // To store the selected image file
  List<Pose> _poses = []; // To store the detected poses
  Size? _imageSize; // To store the original size of the image (on which detection was performed)
  bool _isProcessing = false; // To track the processing status
  String? _errorMessage; // To display error messages

  // Map to store all calculated angles
  Map<String, double?> _angles = {
    'leftElbow': null,
    'rightElbow': null,
    'leftKnee': null,
    'rightKnee': null,
    'leftShoulder': null,
    'rightShoulder': null,
    'topLeftTorso': null,
    'topRightTorso': null,
    'bottomLeftTorso': null,
    'bottomRightTorso': null,
  };

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
    //  mode: PoseDetectionMode.singleImage,
    ),
  );

  @override
  void dispose() {
    _poseDetector.close(); // Close the pose detector when the widget is disposed
    super.dispose();
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedImageFile = File(image.path);
        _poses = []; // Clear previous poses
        _imageSize = null; // Clear previous image size
        _angles.updateAll((key, value) => null); // Clear previous angles
        _isProcessing = true; // Start processing
        _errorMessage = null; // Clear previous error messages
      });
      await _processImage(image); // Process the selected image
    }
  }

  // Function to process the image using ML Kit Pose Detection
  Future<void> _processImage(XFile imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);

      // Get the actual image size
      final decodedImage = await decodeImageFromList(await imageFile.readAsBytes());
      _imageSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      final poses = await _poseDetector.processImage(inputImage);

      setState(() {
        _poses = poses;
        _isProcessing = false;
        if (poses.isNotEmpty) {
          _calculateAndSetAngles(poses.first); // Calculate angles for the first detected pose
        } else {
          _errorMessage = 'No poses detected in the image.';
        }
      });
    } catch (e) {
      debugPrint('Error processing image: $e');
      setState(() {
        _errorMessage = 'Error processing image: $e';
        _isProcessing = false;
      });
    }
  }

  // Helper function to calculate the angle between three points
  double _calculateAngle(PoseLandmark? p1, PoseLandmark? p2, PoseLandmark? p3) {
    if (p1 == null || p2 == null || p3 == null) {
      return double.nan;
    }
    final double angleRad = atan2(p3.y - p2.y, p3.x - p2.x) - atan2(p1.y - p2.y, p1.x - p2.x);
    double angleDeg = angleRad * 180 / pi;

    if (angleDeg < 0) {
      angleDeg += 360;
    }
    if (angleDeg > 180) {
      angleDeg = 360 - angleDeg;
    }
    return angleDeg;
  }

  // Function to calculate and set all important angles
  void _calculateAndSetAngles(Pose pose) {
    final landmarks = pose.landmarks;

    _angles['leftElbow'] = _calculateAngle(
      landmarks[PoseLandmarkType.leftShoulder],
      landmarks[PoseLandmarkType.leftElbow],
      landmarks[PoseLandmarkType.leftWrist],
    );

    _angles['rightElbow'] = _calculateAngle(
      landmarks[PoseLandmarkType.rightShoulder],
      landmarks[PoseLandmarkType.rightElbow],
      landmarks[PoseLandmarkType.rightWrist],
    );

    _angles['leftKnee'] = _calculateAngle(
      landmarks[PoseLandmarkType.leftHip],
      landmarks[PoseLandmarkType.leftKnee],
      landmarks[PoseLandmarkType.leftAnkle],
    );

    _angles['rightKnee'] = _calculateAngle(
      landmarks[PoseLandmarkType.rightHip],
      landmarks[PoseLandmarkType.rightKnee],
      landmarks[PoseLandmarkType.rightAnkle],
    );

    _angles['leftShoulder'] = _calculateAngle(
      landmarks[PoseLandmarkType.leftElbow],
      landmarks[PoseLandmarkType.leftShoulder],
      landmarks[PoseLandmarkType.leftHip],
    );

    _angles['rightShoulder'] = _calculateAngle(
      landmarks[PoseLandmarkType.rightElbow],
      landmarks[PoseLandmarkType.rightShoulder],
      landmarks[PoseLandmarkType.rightHip],
    );

    // Four main torso angles
    _angles['topLeftTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.leftHip],
      landmarks[PoseLandmarkType.leftShoulder],
      landmarks[PoseLandmarkType.rightShoulder],
    );

    _angles['topRightTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.rightHip],
      landmarks[PoseLandmarkType.rightShoulder],
      landmarks[PoseLandmarkType.leftShoulder],
    );

    _angles['bottomLeftTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.leftShoulder],
      landmarks[PoseLandmarkType.leftHip],
      landmarks[PoseLandmarkType.rightHip],
    );

    _angles['bottomRightTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.rightShoulder],
      landmarks[PoseLandmarkType.rightHip],
      landmarks[PoseLandmarkType.leftHip],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Pose Processing', style: TextStyle(color: Colors.black)), // Title in English, black color
        backgroundColor: Colors.white, // White background for AppBar
        elevation: 0, // No shadow
        iconTheme: const IconThemeData(color: Colors.black), // Black icons for AppBar
      ),
      backgroundColor: Colors.white, // White background for the whole screen
      body: Column(
        children: [
          Expanded(
            child: _pickedImageFile == null
                ? Center(
                    // "Select Image from Gallery" button with purple gradient
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A2BE2), Color(0xFFDA70D6)], // Purple gradient
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            spreadRadius: 3,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image, size: 28, color: Colors.white), // White icon
                        label: const Text(
                          'Select Image from Gallery',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // White text
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Transparent to show gradient
                          shadowColor: Colors.transparent, // No shadow from button itself
                          elevation: 0, // No elevation from button itself
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // Display the selected image
                      Image.file(
                        _pickedImageFile!,
                        fit: BoxFit.contain,
                      ),
                      // Display loading indicator
                      if (_isProcessing)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      // Display poses and angles
                      if (!_isProcessing && _poses.isNotEmpty && _imageSize != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: StaticImagePosePainter(
                              poses: _poses,
                              originalImageSize: _imageSize!,
                              angles: _angles,
                            ),
                          ),
                        ),
                      // Display error message or no poses detected message
                      if (!_isProcessing && _errorMessage != null)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            color: Colors.red.withOpacity(0.7),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          // Button to re-select image with blue gradient
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4169E1), Color(0xFF00BFFF)], // Blue gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 3,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.refresh, size: 28, color: Colors.white), // White icon
                label: const Text(
                  'Re-select Image',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, // Transparent to show gradient
                  shadowColor: Colors.transparent, // No shadow from button itself
                  elevation: 0, // No elevation from button itself
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CustomPainter for drawing poses and angles on a static image
class StaticImagePosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size originalImageSize;
  final Map<String, double?> angles;

  StaticImagePosePainter({
    required this.poses,
    required this.originalImageSize,
    required this.angles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red
      ..strokeWidth = 3.0;

    final Paint connectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.green
      ..strokeWidth = 3.0;

    final TextStyle angleTextStyle = TextStyle(
      color: Colors.yellowAccent,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    final double scaleX = size.width / originalImageSize.width;
    final double scaleY = size.height / originalImageSize.height;

    for (final pose in poses) {
      for (final landmark in pose.landmarks.values) {
        canvas.drawCircle(
          Offset(landmark.x * scaleX, landmark.y * scaleY),
          5.0,
          landmarkPaint,
        );
      }

      // Draw connections
      // Corrected typo: PoseLandlandType -> PoseLandmarkType
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.leftEye, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftEye, PoseLandmarkType.leftEar, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.rightEye, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightEye, PoseLandmarkType.rightEar, scaleX, scaleY);

      // Draw angles
      _drawAngleText(canvas, pose, angles['leftElbow'], PoseLandmarkType.leftElbow, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, pose, angles['rightElbow'], PoseLandmarkType.rightElbow, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, pose, angles['leftKnee'], PoseLandmarkType.leftKnee, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, pose, angles['rightKnee'], PoseLandmarkType.rightKnee, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, pose, angles['leftShoulder'], PoseLandmarkType.leftShoulder, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, pose, angles['rightShoulder'], PoseLandmarkType.rightShoulder, angleTextStyle, scaleX, scaleY);

      // Four torso angles
      _drawAngleText(canvas, pose, angles['topLeftTorso'], PoseLandmarkType.leftShoulder, angleTextStyle, scaleX, scaleY, offsetX: -20, offsetY: -20);
      _drawAngleText(canvas, pose, angles['topRightTorso'], PoseLandmarkType.rightShoulder, angleTextStyle, scaleX, scaleY, offsetX: 20, offsetY: -20);
      _drawAngleText(canvas, pose, angles['bottomLeftTorso'], PoseLandmarkType.leftHip, angleTextStyle, scaleX, scaleY, offsetX: -20, offsetY: 20);
      _drawAngleText(canvas, pose, angles['bottomRightTorso'], PoseLandmarkType.rightHip, angleTextStyle, scaleX, scaleY, offsetX: 20, offsetY: 20);
    }
  }

  void _drawLine(Canvas canvas, Pose pose, Paint paint, PoseLandmarkType type1, PoseLandmarkType type2, double scaleX, double scaleY) {
    final landmark1 = pose.landmarks[type1];
    final landmark2 = pose.landmarks[type2];
    if (landmark1 != null && landmark2 != null) {
      canvas.drawLine(
        Offset(landmark1.x * scaleX, landmark1.y * scaleY),
        Offset(landmark2.x * scaleX, landmark2.y * scaleY),
        paint,
      );
    }
  }

  void _drawAngleText(Canvas canvas, Pose pose, double? angle, PoseLandmarkType landmarkType, TextStyle textStyle, double scaleX, double scaleY, {double offsetX = 0, double offsetY = 0}) {
    if (angle != null && !angle.isNaN) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark != null) {
        final textSpan = TextSpan(
          text: '${angle.toStringAsFixed(0)}°',
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final Offset point = Offset(landmark.x * scaleX, landmark.y * scaleY);
        final Offset textOffset = Offset(
          point.dx - textPainter.width / 2 + offsetX,
          point.dy - textPainter.height / 2 + offsetY,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(StaticImagePosePainter oldDelegate) =>
      oldDelegate.poses != poses || oldDelegate.originalImageSize != originalImageSize || oldDelegate.angles != angles;
}
