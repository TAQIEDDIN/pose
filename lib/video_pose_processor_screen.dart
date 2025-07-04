// This file processes an MP4 video, extracts a thumbnail from it,
// then detects poses in that image and stores the pose data in a JSON file.

import 'dart:convert'; // For using JSON
import 'dart:io'; // For file operations
import 'dart:typed_data'; // For handling image data
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For picking video
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'; // For pose detection
import 'package:video_player/video_player.dart'; // For video playback (optional, here only for initialization)
import 'package:video_thumbnail/video_thumbnail.dart'; // For extracting thumbnail
import 'package:path_provider/path_provider.dart'; // For saving temporary files
import 'package:image/image.dart' as img; // For using the image library to process images

// CustomPainter for drawing poses on a static image (like a video thumbnail)
// This class is defined here and should be defined only once in the project.
class StaticPosePainter extends CustomPainter {
  final List<Pose> poses; // List of poses to be drawn
  final Size originalImageSize; // Original size of the image on which poses were detected
  final bool isBackCamera; // Was the back camera used? (not directly used here)
  final int rotationDegrees; // Rotation degree applied to the image (if the image is rotated)

  StaticPosePainter({
    required this.poses,
    required this.originalImageSize,
    required this.isBackCamera,
    this.rotationDegrees = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint settings for drawing landmarks
    final Paint landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red // Red color
      ..strokeWidth = 3.0;

    // Paint settings for drawing connections between points
    final Paint connectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.green // Green color
      ..strokeWidth = 3.0;

    // Calculate scaling factors to transform coordinates from original image size to current Canvas size
    final double scaleX = size.width / originalImageSize.width;
    final double scaleY = size.height / originalImageSize.height;

    // Apply rotation transformation to the Canvas
    // This is important for drawing poses correctly if the image itself was rotated
    canvas.save(); // Save current Canvas state
    if (rotationDegrees != 0) {
      final double radians = rotationDegrees * (3.1415926535 / 180); // Convert degrees to radians
      final Offset center = Offset(size.width / 2, size.height / 2); // Center of rotation
      canvas.translate(center.dx, center.dy); // Move origin to center
      canvas.rotate(radians); // Apply rotation
      canvas.translate(-center.dx, -center.dy); // Restore origin
    }

    // Draw each detected pose
    for (final pose in poses) {
      // Draw landmarks
      for (final landmark in pose.landmarks.values) {
        canvas.drawCircle(
          Offset(landmark.x * scaleX, landmark.y * scaleY), // Transform coordinates
          5.0, // Circle radius
          landmarkPaint,
        );
      }

      // Draw connections between landmarks to form the skeleton
      // Main body connections
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, scaleX, scaleY);
      //_drawLine(canvas, pose, connectionPaint, PoseLandlandType.leftShoulder, PoseLandmarkType.leftElbow, scaleX, scaleY);
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

      // Basic face connections (nose, eyes, ears)
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.leftEye, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftEye, PoseLandmarkType.leftEar, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.rightEye, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightEye, PoseLandmarkType.rightEar, scaleX, scaleY);
    }
    canvas.restore(); // Restore original Canvas state
  }

  // Helper function to draw a line between two landmarks
  void _drawLine(
    Canvas canvas,
    Pose pose,
    Paint paint,
    PoseLandmarkType type1,
    PoseLandmarkType type2,
    double scaleX,
    double scaleY,
  ) {
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

  @override
  // Determine whether the CustomPainter should repaint
  // It repaints only if the list of poses, original image size, or rotation degree changes
  bool shouldRepaint(StaticPosePainter oldDelegate) =>
      oldDelegate.poses != poses ||
      oldDelegate.originalImageSize != originalImageSize ||
      oldDelegate.rotationDegrees != rotationDegrees;
}

// Helper function to draw a circle on an img.Image object
void _drawCircleOnImage(img.Image image, int x, int y, int radius, img.Color color) {
  for (int i = -radius; i <= radius; i++) {
    for (int j = -radius; j <= radius; j++) {
      if (i * i + j * j <= radius * radius) {
        if (x + i >= 0 && x + i < image.width && y + j >= 0 && y + j < image.height) {
          image.setPixel(x + i, y + j, color);
        }
      }
    }
  }
}

// Helper function to draw a line on an img.Image object (Bresenham's algorithm)
void _drawLineOnImage(img.Image image, int x1, int y1, int x2, int y2, img.Color color) {
  int dx = (x2 - x1).abs();
  int dy = (y2 - y1).abs();
  int sx = (x1 < x2) ? 1 : -1;
  int sy = (y1 < y2) ? 1 : -1;
  int err = dx - dy;

  while (true) {
    if (x1 >= 0 && x1 < image.width && y1 >= 0 && y1 < image.height) {
      image.setPixel(x1, y1, color);
    }
    if (x1 == x2 && y1 == y2) break;
    int e2 = 2 * err;
    if (e2 > -dy) {
      err -= dy;
      x1 += sx;
    }
    if (e2 < dx) {
      err += dx;
      y1 += sy;
    }
  }
}

// Function to draw poses on an img.Image object
void _drawPoseOnImage(img.Image image, Pose pose) {
  img.Color landmarkColor = img.ColorRgb8(255, 0, 0); // Red
  img.Color connectionColor = img.ColorRgb8(0, 255, 0); // Green
  int landmarkRadius = 5;
  int lineWidth = 3;

  // Draw landmarks
  for (final landmark in pose.landmarks.values) {
    int x = landmark.x.round();
    int y = landmark.y.round();
    _drawCircleOnImage(image, x, y, landmarkRadius, landmarkColor);
  }

  // Draw connections
  void drawConnection(PoseLandmarkType type1, PoseLandmarkType type2) {
    final landmark1 = pose.landmarks[type1];
    final landmark2 = pose.landmarks[type2];

    if (landmark1 != null && landmark2 != null) {
      int x1 = landmark1.x.round();
      int y1 = landmark1.y.round();
      int x2 = landmark2.x.round();
      int y2 = landmark2.y.round();

      for (int i = -(lineWidth ~/ 2); i <= (lineWidth ~/ 2); i++) {
        for (int j = -(lineWidth ~/ 2); j <= (lineWidth ~/ 2); j++) {
          _drawLineOnImage(image, x1 + i, y1 + j, x2 + i, y2 + j, connectionColor);
        }
      }
    }
  }

  // Main body connections
  drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
  drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
  drawConnection(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
  drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
  drawConnection(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
  drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
  drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
  drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
  drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
  drawConnection(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
  drawConnection(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
  drawConnection(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

  // Face connections
  drawConnection(PoseLandmarkType.nose, PoseLandmarkType.leftEye);
  drawConnection(PoseLandmarkType.leftEye, PoseLandmarkType.leftEar);
  drawConnection(PoseLandmarkType.nose, PoseLandmarkType.rightEye);
  drawConnection(PoseLandmarkType.rightEye, PoseLandmarkType.rightEar);
}


// The main widget for the video pose processing screen
class VideoPoseProcessorScreen extends StatefulWidget {
  const VideoPoseProcessorScreen({super.key});

  @override
  State<VideoPoseProcessorScreen> createState() => _VideoPoseProcessorScreenState();
}

class _VideoPoseProcessorScreenState extends State<VideoPoseProcessorScreen> {
  VideoPlayerController? _videoController; // To control video playback (optional, here only for initialization)
  File? _videoFile; // The selected video file
  Uint8List? _thumbnailBytes; // Extracted thumbnail data
  List<Pose>? _detectedPoses; // Detected poses in the thumbnail
  Size? _thumbnailSize; // Thumbnail size
  bool _isProcessing = false; // Processing state (is the app busy processing video/images?)
  String _statusMessage = 'Select an MP4 video to process poses.'; // Status message displayed to the user
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      ///mode: PoseDetectionMode.static, // This line is correct, ensure google_mlkit_pose_detection library is updated
    ),
  );

  @override
  void dispose() {
    _videoController?.dispose(); // Dispose video controller
    _poseDetector.close(); // Close pose detector
    super.dispose();
  }

  // Function to pick a video from the gallery
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      setState(() {
        _isProcessing = true; // Start processing
        _statusMessage = 'Loading video and extracting thumbnail...';
        _videoFile = File(video.path); // Save video file
        _thumbnailBytes = null; // Reset previous data
        _detectedPoses = null;
        _thumbnailSize = null;
      });

      // Initialize video controller (to ensure video is valid)
      _videoController = VideoPlayerController.file(_videoFile!);
      await _videoController!.initialize();

      // Extract thumbnail from video
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: (await getTemporaryDirectory()).path, // Save image to temporary directory
        imageFormat: ImageFormat.PNG, // Image format
        maxHeight: 400, // Set max thumbnail height
        maxWidth: 400,  // Set max thumbnail width
        quality: 75, // Image quality (0 to 100)
      );

      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);
        final bytes = await thumbnailFile.readAsBytes();
        setState(() {
          _thumbnailBytes = bytes; // Save thumbnail data
          _statusMessage = 'Detecting poses in thumbnail...';
        });

        // Get thumbnail size for pose detection
        final decodedImage = await decodeImageFromList(bytes);
        _thumbnailSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

        // Process thumbnail for poses
        await _processThumbnailForPoses(thumbnailFile);
      } else {
        setState(() {
          _statusMessage = 'Failed to extract thumbnail.';
          _isProcessing = false;
        });
      }
    } else {
      setState(() {
        _statusMessage = 'No video selected.';
      });
    }
  }

  // Function to process thumbnail and detect poses in it
  Future<void> _processThumbnailForPoses(File thumbnailFile) async {
    if (_thumbnailSize == null) {
      setState(() {
        _statusMessage = 'Error: Thumbnail size not defined.';
        _isProcessing = false;
      });
      return;
    }

    final inputImage = InputImage.fromFilePath(thumbnailFile.path);

    try {
      final List<Pose> poses = await _poseDetector.processImage(inputImage); // Detect poses
      setState(() {
        _detectedPoses = poses; // Save detected poses
        _statusMessage = poses.isNotEmpty
            ? 'Detected ${poses.length} pose(s) in the thumbnail.'
            : 'No poses detected in the thumbnail.';
      });

      if (poses.isNotEmpty) {
        await _savePosesToJson(poses); // Save poses to JSON file
      }
    } catch (e) {
      debugPrint('Error processing thumbnail for poses: $e');
      setState(() {
        _statusMessage = 'Error detecting poses: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false; // End processing
      });
    }
  }

  // Function to save pose data to a JSON file
  Future<void> _savePosesToJson(List<Pose> poses) async {
    final directory = await getTemporaryDirectory(); // Get temporary directory
    final file = File('${directory.path}/pose_data.json'); // Define file path

    // Convert list of poses to a list of Maps for easy JSON conversion
    final List<Map<String, dynamic>> posesData = poses.map((pose) {
      return {
        'landmarks': pose.landmarks.map((type, landmark) {
          return MapEntry(
            type.name, // Point name (e.g., 'leftShoulder')
            {'x': landmark.x, 'y': landmark.y, 'z': landmark.z, 'likelihood': landmark.likelihood},
          );
        }),
      };
    }).toList();

    await file.writeAsString(jsonEncode(posesData)); // Save data as JSON
    debugPrint('Pose data saved to: ${file.path}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pose data saved to: ${file.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Pose Processing', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _thumbnailBytes == null // If no thumbnail, display message
                  ? Text(_statusMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600]))
                  : Stack( // If thumbnail exists, display it with poses
                      alignment: Alignment.center,
                      children: [
                        Image.memory(
                          _thumbnailBytes!,
                          fit: BoxFit.contain,
                        ),
                        if (_detectedPoses != null && _detectedPoses!.isNotEmpty && _thumbnailSize != null)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: StaticPosePainter(
                                poses: _detectedPoses!,
                                originalImageSize: _thumbnailSize!,
                                isBackCamera: true, // Assume back camera is used for video files
                                rotationDegrees: 0, // Assume thumbnail is correctly oriented
                              ),
                            ),
                          ),
                        if (_isProcessing) // Display loading indicator if app is busy
                          const CircularProgressIndicator(color: Colors.deepPurple),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickVideo, // Disable button during processing
                  icon: const Icon(Icons.video_library),
                  label: Text(_isProcessing ? 'Processing...' : 'Select MP4 Video'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Note: This app processes a single thumbnail from the video. Full video processing (frame by frame) requires significant resources and may be slow on mobile devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
