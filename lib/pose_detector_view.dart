// This file is responsible for displaying the camera preview and detecting poses in real-time using Google ML Kit Pose Detection.
// Gyroscope support has been added, important angles (including the four torso angles) are calculated and displayed,
// and the Frames Per Second (FPS) is shown.
// Angles are now displayed directly on the skeleton.
// Camera display has been adjusted to fill the entire screen and remove black spaces.

import 'dart:io';
import 'dart:math'; // For using mathematical functions like atan2 and pi
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart'; // Import sensors library
import 'dart:async'; // For using StreamSubscription
import 'dart:ui' as ui; // For using ui.ParagraphBuilder and ui.ParagraphStyle

import 'main.dart'; // Ensure this file contains the camera list (cameras)
import 'display_picture_screen.dart'; // Import the new screen to display the captured image

// Start of the main widget definition for Pose Detection
class PoseDetectorView extends StatefulWidget {
  const PoseDetectorView({super.key});

  @override
  State<PoseDetectorView> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  // Initialize PoseDetector
  // We use the base model and stream mode to process consecutive frames from the camera.
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );

  // Variables to control the detection and processing
  bool _canProcess = true; // Can the detector process new frames?
  bool _isBusy = false; // Is the detector currently busy processing a frame?
  String? _text; // To display text messages to the user (e.g., "No camera")
  CameraController? _cameraController; // To control the camera
  Size? _imageSize; // Size of the image (frame) being detected, used for drawing
  List<Pose> _poses = []; // List of poses detected in the current frame
  int _frameSkipCounter = 0; // Counter to skip frames for performance improvement

  // Timestamp of the last valid pose detection, and a threshold to clear poses if not detected for a period
  DateTime? _lastDetectionTime;
  static const Duration _poseDisplayThreshold = Duration(milliseconds: 1000);

  // Frame skip factor to reduce memory usage and CPU load
  // For example, if its value is 5, one frame out of every 5 frames will be processed.
  static const int _frameSkipFactor = 5;

  // Gyroscope specific variables
  GyroscopeEvent? _gyroscopeEvent; // To store the latest gyroscope event
  StreamSubscription? _gyroscopeSubscription; // To subscribe to gyroscope data stream

  // FPS calculation and display variables
  DateTime? _lastFrameProcessTime;
  double _fps = 0.0;
  // _ms was removed as per user's request to revert to original design without it

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


  @override
  void initState() {
    super.initState();
    _initializeCamera(); // Initialize camera
    _initializeGyroscope(); // Initialize gyroscope
  }

  // Function to initialize the camera and request necessary permissions
  Future<void> _initializeCamera() async {
    // Request camera access permission
    final status = await Permission.camera.request();
    if (status.isGranted) {
      // If no cameras are found
      if (cameras.isEmpty) {
        _text = 'No camera found.';
        if (mounted) setState(() {}); // Update UI to display message
        return;
      }

      // Select the back camera for pose detection
      // If no back camera is found, the first available camera will be used.
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Initialize CameraController
      _cameraController = CameraController(
        camera,
        ResolutionPreset.low, // Low resolution for better performance
        enableAudio: false, // Disable audio
        imageFormatGroup: ImageFormatGroup.yuv420, // Image format for ML Kit
      );

      try {
        // Start camera initialization
        await _cameraController!.initialize();
        if (!mounted) return; // Ensure the widget still exists

        // Start streaming images from the camera for processing
        await _cameraController!.startImageStream(_processCameraImage);
        setState(() {}); // Update UI after successful camera initialization
      } catch (e) {
        debugPrint('Error initializing camera: $e');
        _text = 'Error initializing camera.';
        if (mounted) setState(() {});
      }
    } else {
      _text = 'Camera permission denied.';
      if (mounted) setState(() {});
    }
  }

  // Function to initialize the gyroscope and subscribe to its data
  void _initializeGyroscope() {
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      // Update widget state with new gyroscope data
      setState(() {
        _gyroscopeEvent = event;
      });
    });
  }

  // Function to process incoming camera frames
  Future<void> _processCameraImage(CameraImage image) async {
    // Calculate FPS
    final currentTime = DateTime.now();
    if (_lastFrameProcessTime != null) {
      final duration = currentTime.difference(_lastFrameProcessTime!).inMilliseconds;
      if (duration > 0) {
        _fps = 1000 / duration;
      }
    }
    _lastFrameProcessTime = currentTime;


    _frameSkipCounter++;
    // Skip frames if we haven't reached the specified skip factor
    if (_frameSkipCounter < _frameSkipFactor) {
      if (mounted) setState(() {}); // Update UI to display FPS even if frame is skipped
      return;
    }
    _frameSkipCounter = 0; // Reset counter

    // If detector cannot process or is busy, exit
    if (!_canProcess || _isBusy) return;
    _isBusy = true; // Set detector as "busy"

    try {
      // Determine image rotation based on camera lens direction
      final InputImageRotation rotation =
          _cameraController!.description.lensDirection ==
                      CameraLensDirection.front
                  ? InputImageRotation.rotation270deg
                  : InputImageRotation.rotation90deg;

      // Determine the size of the raw image data
      final metadataSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // Determine the effective size that coordinates will have after applying rotation
      Size effectiveSizeForLandmarks;
      if (rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg) {
        effectiveSizeForLandmarks = Size(
          metadataSize.height, // Width becomes height
          metadataSize.width, // Height becomes width
        );
      } else {
        effectiveSizeForLandmarks = metadataSize;
      }

      // Update _imageSize if it changed (this size is used for drawing)
      bool imageSizeChanged =
          _imageSize == null || _imageSize != effectiveSizeForLandmarks;
      if (imageSizeChanged) {
        _imageSize = effectiveSizeForLandmarks;
      }

      // Create InputImage from camera data
      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes), // Concatenate image planes
        metadata: InputImageMetadata(
          size: metadataSize, // Buffer data size
          rotation: rotation, // Buffer data rotation
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      // Process image and detect poses
      final poses = await _poseDetector.processImage(inputImage);

      if (mounted) {
        final currentDetectionTime = DateTime.now();
        if (poses.isNotEmpty) {
          // If poses are detected, update the state
          setState(() {
            _poses = poses;
            _lastDetectionTime = currentDetectionTime; // Update last detection time
            _calculateAndSetAngles(poses.first); // Calculate angles for the first detected pose
          });
        } else if (_lastDetectionTime != null) {
          // If no poses are detected but there was a previous detection, check the time
          final timeSinceLastDetection =
              currentDetectionTime.difference(_lastDetectionTime!);
          if (timeSinceLastDetection > _poseDisplayThreshold) {
            // If enough time has passed without detection, clear displayed poses and angles
            setState(() {
              _poses = [];
              _clearAngles(); // Clear angles
            });
          }
        }
        // If image size changed, update the UI (even if poses didn't change)
        if (imageSizeChanged) {
          setState(() {
            /* Just to update the UI with the new image size */
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isBusy = false; // Reset detector to "not busy"
    }
  }

  // Helper function to concatenate camera image planes
  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // Function to calculate the angle between three points
  // p1 -> p2 (vertex) <- p3
  double _calculateAngle(PoseLandmark? p1, PoseLandmark? p2, PoseLandmark? p3) {
    // Check for point existence
    if (p1 == null || p2 == null || p3 == null) {
      return double.nan; // Return NaN if any point is missing
    }

    final double angleRad = atan2(p3.y - p2.y, p3.x - p2.x) - atan2(p1.y - p2.y, p1.x - p2.x);
    double angleDeg = angleRad * 180 / pi;

    // Convert angle to be between 0 and 360 degrees
    if (angleDeg < 0) {
      angleDeg += 360;
    }
    // Can convert to internal angle (less than 180) if needed
    if (angleDeg > 180) {
      angleDeg = 360 - angleDeg;
    }
    return angleDeg;
  }

  // Function to calculate and set all important angles
  void _calculateAndSetAngles(Pose pose) {
    final landmarks = pose.landmarks;

    // Four main torso angles (based on the image)
    // Top-left shoulder angle: left hip - left shoulder - right shoulder
    _angles['topLeftTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.leftHip],
      landmarks[PoseLandmarkType.leftShoulder],
      landmarks[PoseLandmarkType.rightShoulder],
    );

    // Top-right shoulder angle: right hip - right shoulder - left shoulder
    _angles['topRightTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.rightHip],
      landmarks[PoseLandmarkType.rightShoulder],
      landmarks[PoseLandmarkType.leftShoulder],
    );

    // Bottom-left hip angle: left shoulder - left hip - right hip
    _angles['bottomLeftTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.leftShoulder],
      landmarks[PoseLandmarkType.leftHip],
      landmarks[PoseLandmarkType.rightHip],
    );

    // Bottom-right hip angle: right shoulder - right hip - left hip
    _angles['bottomRightTorso'] = _calculateAngle(
      landmarks[PoseLandmarkType.rightShoulder],
      landmarks[PoseLandmarkType.rightHip],
      landmarks[PoseLandmarkType.leftHip],
    );
  }

  // Function to clear angle values
  void _clearAngles() {
    _angles.updateAll((key, value) => null);
  }


  @override
  void dispose() {
    _canProcess = false; // Stop processing
    _poseDetector.close(); // Close pose detector
    _cameraController?.stopImageStream(); // Stop camera stream
    _cameraController?.dispose(); // Dispose CameraController
    _gyroscopeSubscription?.cancel(); // Cancel gyroscope data subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If camera is not initialized yet, display a loading screen
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pose Detection')),
        body: Center(child: Text(_text ?? 'Loading...')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pose Detection',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black, // Black background to fill space
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview
                  FittedBox(
                    fit: BoxFit.cover, // This ensures the camera covers the entire space
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),

                  // Layer for drawing poses and angles
                  if (_poses.isNotEmpty && _imageSize != null)
                    CustomPaint(
                      painter: PosePainter(
                        poses: _poses,
                        imageSize: _imageSize!,
                        isBackCamera: _cameraController!.description.lensDirection ==
                            CameraLensDirection.back,
                        angles: _angles, // Pass angles to the painter
                      ),
                    ),
                  // Display FPS and Gyroscope data (in the top-left corner)
                  Positioned(
                    top: 10,
                    left: 10, // Position: top-left
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6), // Transparent black background
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row( // Row for FPS and its icon
                            children: [
                              Icon(Icons.speed, color: Colors.white, size: 18), // Icon for FPS
                              SizedBox(width: 5),
                              Text(
                                'FPS: ${_fps.toStringAsFixed(1)}', // Display FPS
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (_gyroscopeEvent != null) ...[ // Display gyroscope only if data is available
                            Row( // Row for Gyroscope label and its icon
                              children: [
                                Icon(Icons.rotate_right, color: Colors.white, size: 18), // Icon for Gyroscope
                                SizedBox(width: 5),
                                Text(
                                  'Gyroscope:',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              'X: ${_gyroscopeEvent?.x.toStringAsFixed(2) ?? 'N/A'}',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            Text(
                              'Y: ${_gyroscopeEvent?.y.toStringAsFixed(2) ?? 'N/A'}',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                            Text(
                              'Z: ${_gyroscopeEvent?.z.toStringAsFixed(2) ?? 'N/A'}',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom control section
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              color: Colors.deepPurple.withOpacity(0.9), // Transparent dark background
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Detected poses counter and camera info
                  Expanded( // This will take available space for the text
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_poses.length} pose(s) detected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis, // Ensures text doesn't overflow
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cameraController!.description.lensDirection ==
                                  CameraLensDirection.front
                              ? 'Front Camera'
                              : 'Back Camera',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis, // Ensures text doesn't overflow
                        ),
                      ],
                    ),
                  ),

                  const Spacer(), // This will push the buttons to the right

                  // Action buttons (will take their intrinsic size)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Camera switch button
                      _buildActionButton(
                        icon: Icons.switch_camera,
                        label: 'Switch',
                        onPressed: _switchCameraLogic,
                      ),
                      const SizedBox(width: 8), // Small spacing between buttons
                      // Capture image button
                      _buildActionButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Capture',
                        onPressed: _captureAndShowImage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to create action buttons
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: Colors.deepPurple.shade900,
        size: 22,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: Colors.deepPurple.shade900,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 5,
        shadowColor: Colors.black54,
      ),
    );
  }

  // Function to switch between front and back camera
  Future<void> _switchCameraLogic() async {
    if (_cameraController != null) {
      // Find the other camera
      final newCamera = cameras.firstWhere(
        (camera) =>
            camera.lensDirection != _cameraController!.description.lensDirection,
        orElse: () => cameras.first, // fallback if no other camera is found
      );

      // Dispose of the old camera controller
      await _cameraController!.dispose();

      // Create a new camera controller
      final controller = CameraController(
        newCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // Update state
      setState(() {
        _cameraController = controller;
        _poses = []; // Clear previous poses
        _lastDetectionTime = null; // Reset last detection time
        _clearAngles(); // Clear angles
      });

      try {
        // Initialize the new controller and start image stream
        await controller.initialize();
        if (mounted) {
          // Update _imageSize based on the new camera preview size
          _imageSize = Size(
            controller.value.previewSize!.height,
            controller.value.previewSize!.width,
          );
          await controller.startImageStream(_processCameraImage);
          setState(() {}); // Update UI
        }
      } catch (e) {
        debugPrint('Error switching camera: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error switching camera: $e')));
        }
      }
    }
  }

  // Function to capture an image and display it on a new screen
  Future<void> _captureAndShowImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _imageSize == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera not ready or image size not determined yet.'),
          ),
        );
      }
      return;
    }

    // Temporarily stop camera stream before capturing the image
    bool wasStreaming = _cameraController!.value.isStreamingImages;
    if (wasStreaming) {
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint("Error stopping stream for capture: $e");
      }
    }

    // Temporarily stop frame processing
    final oldCanProcess = _canProcess;
    _canProcess = false;

    // Capture current poses and image size to pass to the next screen
    final List<Pose> currentPoses = List.from(_poses); // Create a copy
    final Size currentPoseImageSize = _imageSize!;
    final bool currentIsBackCamera =
        _cameraController!.description.lensDirection == CameraLensDirection.back;
    final Map<String, double?> currentAngles = Map.from(_angles); // Copy current angles

    try {
      final XFile imageFile = await _cameraController!.takePicture(); // Capture image

      if (mounted) {
        // Navigate to image display screen, passing data
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DisplayPictureScreen(
              imagePath: imageFile.path,
              poses: currentPoses,
              poseImageSize: currentPoseImageSize,
              isBackCamera: currentIsBackCamera,
              angles: currentAngles, // Pass angles to display screen
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error capturing image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error capturing image: $e")));
      }
    } finally {
      _canProcess = oldCanProcess; // Restore processing flag
      // Resume image stream if it was active previously and controller is still valid
      if (wasStreaming &&
          _cameraController != null &&
          mounted &&
          _cameraController!.value.isInitialized) {
        try {
          await _cameraController!.startImageStream(_processCameraImage);
        } catch (e) {
          debugPrint("Error resuming stream after capture: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error resuming camera stream: $e')),
            );
          }
        }
      }
      _isBusy = false; // Reset busy flag
    }
  }
}

// PosePainter class for drawing poses and angles on the camera preview
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize; // Original size of the image (frame) on which poses were detected
  final bool isBackCamera; // Is the back camera used?
  final Map<String, double?> angles; // Calculated angles

  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.isBackCamera,
    required this.angles, // Receiving angles
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Brush settings for drawing landmarks
    final Paint landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red // Red color for landmarks
      ..strokeWidth = 3.0;

    // Brush settings for drawing connections between landmarks
    final Paint connectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.green // Green color for connections
      ..strokeWidth = 3.0;

    final TextStyle angleTextStyle = TextStyle(
      color: Colors.yellowAccent, // Text color for angles
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    // For each detected pose
    for (final pose in poses) {
      // Draw main landmarks
      for (final landmark in pose.landmarks.values) {
        canvas.drawCircle(
          _mapPoint(landmark.x, landmark.y, size), // Transform coordinates for drawing
          5.0, // Circle radius
          landmarkPaint,
        );
      }

      // Draw connections between main landmarks to form the skeleton
      // Main body connections
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // Face connections (nose, eyes, ears)
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.leftEye);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.leftEye, PoseLandmarkType.leftEar);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.rightEye);
      _drawLine(
          canvas, size, pose, connectionPaint, PoseLandmarkType.rightEye, PoseLandmarkType.rightEar);

      // Draw angles on the skeleton
      _drawAngleText(canvas, size, pose, angles['leftElbow'], PoseLandmarkType.leftElbow, angleTextStyle);
      _drawAngleText(canvas, size, pose, angles['rightElbow'], PoseLandmarkType.rightElbow, angleTextStyle);
      _drawAngleText(canvas, size, pose, angles['leftKnee'], PoseLandmarkType.leftKnee, angleTextStyle);
      _drawAngleText(canvas, size, pose, angles['rightKnee'], PoseLandmarkType.rightKnee, angleTextStyle);
      _drawAngleText(canvas, size, pose, angles['leftShoulder'], PoseLandmarkType.leftShoulder, angleTextStyle);
      _drawAngleText(canvas, size, pose, angles['rightShoulder'], PoseLandmarkType.rightShoulder, angleTextStyle);

      // Four torso angles
      _drawAngleText(canvas, size, pose, angles['topLeftTorso'], PoseLandmarkType.leftShoulder, angleTextStyle, offsetX: -20, offsetY: -20);
      _drawAngleText(canvas, size, pose, angles['topRightTorso'], PoseLandmarkType.rightShoulder, angleTextStyle, offsetX: 20, offsetY: -20);
      _drawAngleText(canvas, size, pose, angles['bottomLeftTorso'], PoseLandmarkType.leftHip, angleTextStyle, offsetX: -20, offsetY: 20);
      _drawAngleText(canvas, size, pose, angles['bottomRightTorso'], PoseLandmarkType.rightHip, angleTextStyle, offsetX: 20, offsetY: 20);
    }
  }

  // Helper function to draw a line between two landmarks
  void _drawLine(
    Canvas canvas,
    Size size,
    Pose pose,
    Paint paint,
    PoseLandmarkType type1,
    PoseLandmarkType type2,
  ) {
    final landmark1 = pose.landmarks[type1];
    final landmark2 = pose.landmarks[type2];

    if (landmark1 != null && landmark2 != null) {
      canvas.drawLine(
        _mapPoint(landmark1.x, landmark1.y, size),
        _mapPoint(landmark2.x, landmark2.y, size),
        paint,
      );
    }
  }

  // Function to transform point coordinates from original image space to screen space
  Offset _mapPoint(double x, double y, Size size) {
    // Calculate the width and height ratio between the original image size and the current screen size
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // Apply transformation
    double mappedX = x * scaleX;
    double mappedY = y * scaleY;

    // If it's the front camera, horizontally flip the coordinates
    // This is necessary because the front camera mirrors the image by default
    if (!isBackCamera) {
      mappedX = size.width - mappedX;
    }

    return Offset(mappedX, mappedY);
  }

  // Function to draw angle text near the joint
  void _drawAngleText(Canvas canvas, Size size, Pose pose, double? angle, PoseLandmarkType landmarkType, TextStyle textStyle, {double offsetX = 0, double offsetY = 0}) {
    if (angle != null && !angle.isNaN) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark != null) {
        final Offset point = _mapPoint(landmark.x, landmark.y, size);

        final textSpan = TextSpan(
          text: '${angle.toStringAsFixed(0)}°', // Display angle without decimal places
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr, // Text direction
        );
        textPainter.layout();

        // Calculate text position (can be adjusted for better placement)
        final Offset textOffset = Offset(
          point.dx - textPainter.width / 2 + offsetX,
          point.dy - textPainter.height / 2 + offsetY,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  // Determines whether the CustomPainter should repaint
  // Repainting occurs only if the list of poses, image size, or angles change
  bool shouldRepaint(PosePainter oldDelegate) =>
      oldDelegate.poses != poses || oldDelegate.imageSize != imageSize || oldDelegate.angles != angles;
}
