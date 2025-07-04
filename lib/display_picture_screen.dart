// هذا الملف يعرض الصورة الملتقطة من الكاميرا، مع إمكانية تدويرها وتصحيح منظورها،
// ويرسم عليها الوضعيات المكتشفة، ويعرض الزوايا المحسوبة مباشرة على الهيكل العظمي.

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img; // لاستخدام مكتبة image لمعالجة الصور
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'; // لاستخدام Pose
import 'dart:ui' as ui; // لاستخدام ui.ParagraphBuilder و ui.ParagraphStyle


/// Simple class to represent a line with two points
class Line {
  final double x1, y1, x2, y2;

  Line(this.x1, this.y1, this.x2, this.y2);
}

// CustomPainter لرسم الوضعيات والزوايا على صورة ثابتة (مثل الصورة المصغرة للفيديو)
class StaticPosePainter extends CustomPainter {
  final List<Pose> poses; // قائمة الوضعيات التي سيتم رسمها
  final Size originalImageSize; // الحجم الأصلي للصورة التي تم الكشف عليها
  final bool isBackCamera; // هل الكاميرا المستخدمة كانت خلفية؟ (غير مستخدمة هنا بشكل مباشر)
  final int rotationDegrees; // درجة الدوران المطبقة على الصورة (إذا كانت الصورة مدورة)
  final Map<String, double?> angles; // الزوايا المحسوبة

  StaticPosePainter({
    required this.poses,
    required this.originalImageSize,
    required this.isBackCamera,
    this.rotationDegrees = 0,
    required this.angles, // استلام الزوايا
  });

  @override
  void paint(Canvas canvas, Size size) {
    // إعدادات فرشاة رسم النقاط (landmarks)
    final Paint landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red // لون أحمر
      ..strokeWidth = 3.0;

    // إعدادات فرشاة رسم الوصلات بين النقاط
    final Paint connectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.green // لون أخضر
      ..strokeWidth = 3.0;

    // إعدادات النص لعرض الزوايا
    final TextStyle angleTextStyle = TextStyle(
      color: Colors.yellowAccent, // لون النص للزوايا
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    // حساب عوامل التحجيم (scaling factors) لتحويل الإحداثيات من حجم الصورة الأصلي إلى حجم الـ Canvas الحالي
    final double scaleX = size.width / originalImageSize.width;
    final double scaleY = size.height / originalImageSize.height;

    // تطبيق تحويل الدوران على الـ Canvas
    // هذا مهم لرسم الوضعيات بشكل صحيح إذا كانت الصورة نفسها قد تم تدويرها
    canvas.save(); // حفظ حالة الـ Canvas الحالية
    if (rotationDegrees != 0) {
      final double radians = rotationDegrees * (3.1415926535 / 180); // تحويل الدرجات إلى راديان
      final Offset center = Offset(size.width / 2, size.height / 2); // مركز الدوران
      canvas.translate(center.dx, center.dy); // نقل نقطة الأصل إلى المركز
      canvas.rotate(radians); // تطبيق الدوران
      canvas.translate(-center.dx, -center.dy); // إعادة نقطة الأصل
    }

    // رسم كل وضعية مكتشفة
    for (final pose in poses) {
      // رسم النقاط الرئيسية
      for (final landmark in pose.landmarks.values) {
        canvas.drawCircle(
          Offset(landmark.x * scaleX, landmark.y * scaleY), // تحويل الإحداثيات
          5.0, // نصف قطر الدائرة
          landmarkPaint,
        );
      }

      // رسم الوصلات بين النقاط الرئيسية لتشكيل الهيكل العظمي
      // وصلات الجسم الرئيسية
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

      // وصلات الوجه الأساسية (الأنف، العينين، الأذنين)
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.leftEye, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.leftEye, PoseLandmarkType.leftEar, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.nose, PoseLandmarkType.rightEye, scaleX, scaleY);
      _drawLine(canvas, pose, connectionPaint, PoseLandmarkType.rightEye, PoseLandmarkType.rightEar, scaleX, scaleY);

      // رسم الزوايا على الهيكل العظمي
      _drawAngleText(canvas, size, pose, angles['leftElbow'], PoseLandmarkType.leftElbow, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, size, pose, angles['rightElbow'], PoseLandmarkType.rightElbow, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, size, pose, angles['leftKnee'], PoseLandmarkType.leftKnee, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, size, pose, angles['rightKnee'], PoseLandmarkType.rightKnee, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, size, pose, angles['leftShoulder'], PoseLandmarkType.leftShoulder, angleTextStyle, scaleX, scaleY);
      _drawAngleText(canvas, size, pose, angles['rightShoulder'], PoseLandmarkType.rightShoulder, angleTextStyle, scaleX, scaleY);

      // زوايا الجذع الأربعة
      _drawAngleText(canvas, size, pose, angles['topLeftTorso'], PoseLandmarkType.leftShoulder, angleTextStyle, scaleX, scaleY, offsetX: -20, offsetY: -20);
      _drawAngleText(canvas, size, pose, angles['topRightTorso'], PoseLandmarkType.rightShoulder, angleTextStyle, scaleX, scaleY, offsetX: 20, offsetY: -20);
      _drawAngleText(canvas, size, pose, angles['bottomLeftTorso'], PoseLandmarkType.leftHip, angleTextStyle, scaleX, scaleY, offsetX: -20, offsetY: 20);
      _drawAngleText(canvas, size, pose, angles['bottomRightTorso'], PoseLandmarkType.rightHip, angleTextStyle, scaleX, scaleY, offsetX: 20, offsetY: 20);
    }
    canvas.restore(); // استعادة حالة الـ Canvas الأصلية
  }

  // دالة مساعدة لرسم خط بين نقطتين رئيسيتين
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

  // دالة لرسم نص الزاوية بالقرب من المفصل
  void _drawAngleText(Canvas canvas, Size size, Pose pose, double? angle, PoseLandmarkType landmarkType, TextStyle textStyle, double scaleX, double scaleY, {double offsetX = 0, double offsetY = 0}) {
    if (angle != null && !angle.isNaN) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark != null) {
        final Offset point = Offset(landmark.x * scaleX, landmark.y * scaleY);

        final textSpan = TextSpan(
          text: '${angle.toStringAsFixed(0)}°', // عرض الزاوية بدون فواصل عشرية
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr, // اتجاه النص
        );
        textPainter.layout();

        // حساب موضع النص (يمكن تعديله ليكون أفضل)
        final Offset textOffset = Offset(
          point.dx - textPainter.width / 2 + offsetX,
          point.dy - textPainter.height / 2 + offsetY,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  // تحديد ما إذا كان يجب إعادة رسم الـ CustomPainter
  // يتم إعادة الرسم فقط إذا تغيرت قائمة الوضعيات، حجم الصورة الأصلي، أو درجة الدوران أو الزوايا
  bool shouldRepaint(StaticPosePainter oldDelegate) =>
      oldDelegate.poses != poses ||
      oldDelegate.originalImageSize != originalImageSize ||
      oldDelegate.rotationDegrees != rotationDegrees ||
      oldDelegate.angles != angles;
}


class DisplayPictureScreen extends StatefulWidget {
  final String imagePath; // مسار الصورة الملتقطة
  final List<Pose>? poses; // الوضعيات المكتشفة على الصورة الأصلية
  final Size? poseImageSize; // حجم الصورة التي تم الكشف عن الوضعيات عليها
  final bool isBackCamera; // لتحديد ما إذا كانت الكاميرا الخلفية هي المستخدمة (لتصحيح الانعكاس)
  final Map<String, double?>? angles; // الزوايا المحسوبة من شاشة الكاميرا

  const DisplayPictureScreen({
    Key? key,
    required this.imagePath,
    this.poses,
    this.poseImageSize,
    required this.isBackCamera,
    this.angles, // استلام الزوايا
  }) : super(key: key);

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  img.Image? _originalImage; // الصورة الأصلية التي تم تحميلها
  Uint8List? _displayedImageBytes; // بيانات الصورة المعروضة (بعد التدوير/التصحيح)
  int _currentRotation = 0; // إجمالي الدوران المطبق على الصورة للعرض

  // حالة ضبط المنظور (Perspective Adjustment)
  bool _isAdjustingPerspective = false;
  List<Offset?> _perspectiveCorners = List.filled(
    4,
    null,
  ); // TL, TR, BR, BL في إحداثيات الصورة الأصلية
  int _currentCornerIndex = 0; // مؤشر للزاوية الحالية التي يتم اختيارها
  final GlobalKey _imageDisplayKey = GlobalKey(); // مفتاح للحصول على حجم وموضع الصورة المعروضة
  bool _hasBeenPerspectiveCorrected = false; // لتتبع ما إذا تم تصحيح المنظور

  // نسخ احتياطية للحالة قبل بدء ضبط المنظور
  img.Image? _imageBeforePerspectiveAdjust;
  List<Pose>? _posesBeforePerspectiveAdjust;
  Size? _poseImageSizeBeforePerspectiveAdjust;
  bool _isBackCameraBeforePerspectiveAdjust = false;
  int _rotationBeforePerspectiveAdjust = 0;

  // متغيرات خاصة بالزوايا (للعرض على هذه الشاشة)
  Map<String, double?> _angles = {}; // Map لتخزين الزوايا


  @override
  void initState() {
    super.initState();
    _loadImage(); // تحميل الصورة عند بدء الودجت
    // حفظ الحالة الأولية للوضعيات وحجم الصورة قبل أي تعديلات
    _posesBeforePerspectiveAdjust = widget.poses;
    _poseImageSizeBeforePerspectiveAdjust = widget.poseImageSize;
    _isBackCameraBeforePerspectiveAdjust = widget.isBackCamera;

    // نسخ الزوايا من الـ widget إلى الـ state
    if (widget.angles != null) {
      _angles = Map.from(widget.angles!);
    } else if (widget.poses != null && widget.poses!.isNotEmpty) {
      // إذا لم يتم تمرير الزوايا، قم بحسابها هنا
      _calculateAndSetAngles(widget.poses!.first);
    }
  }

  // دالة لتحميل الصورة من المسار المحدد
  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      _originalImage = img.decodeImage(bytes); // فك تشفير الصورة باستخدام مكتبة image
      _imageBeforePerspectiveAdjust = _originalImage; // حفظ نسخة احتياطية

      if (_originalImage != null) {
        _updateDisplayedImage(); // تحديث الصورة المعروضة
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطأ: تعذر فك تشفير الصورة.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل الصورة: $e')));
      }
      debugPrint('خطأ في تحميل الصورة: $e');
    }
  }

  // دالة لتحديث الصورة المعروضة بعد أي تعديلات (تدوير، تصحيح)
  void _updateDisplayedImage() {
    if (_originalImage == null) return;

    debugPrint('=== تحديث الصورة المعروضة ===');
    debugPrint(
        'الصورة الأصلية: ${_originalImage!.width}x${_originalImage!.height}');
    debugPrint('الدوران الحالي: $_currentRotation درجات');

    img.Image imageToDisplay = _originalImage!;
    if (_currentRotation != 0) {
      // تطبيق الدوران على الصورة للعرض
      debugPrint('تطبيق دوران العرض: $_currentRotation درجات');
      imageToDisplay = img.copyRotate(imageToDisplay, angle: _currentRotation);
      debugPrint(
          'بعد الدوران: ${imageToDisplay.width}x${imageToDisplay.height}');
    }

    // تحويل الصورة إلى بايتات لعرضها في Image.memory
    debugPrint('جاري ترميز الصورة إلى PNG...');
    Uint8List newBytes = Uint8List.fromList(img.encodePng(imageToDisplay));
    debugPrint('تم ترميز ${newBytes.length} بايت');

    setState(() {
      _displayedImageBytes = newBytes;
    });

    debugPrint('=== اكتمل التحديث ===');
  }

  /// Detects the rotation angle needed to straighten the image using multiple methods
  double _detectStraighteningAngle(img.Image image) {
    List<double> detectedAngles = [];

    // Method 1: Edge-based line detection (improved)
    double edgeAngle = _detectAngleFromEdges(image);
    if (edgeAngle.abs() > 0.1) {
      detectedAngles.add(edgeAngle);
    }

    // Method 2: Gradient-based orientation detection
    double gradientAngle = _detectAngleFromGradients(image);
    if (gradientAngle.abs() > 0.1) {
      detectedAngles.add(gradientAngle);
    }

    // Method 3: Content distribution analysis
    double distributionAngle = _detectAngleFromDistribution(image);
    if (distributionAngle.abs() > 0.1) {
      detectedAngles.add(distributionAngle);
    }

    if (detectedAngles.isEmpty) return 0.0;

    // Use weighted average, giving more weight to consistent angles
    Map<int, List<double>> angleGroups = {};
    for (double angle in detectedAngles) {
      int group = (angle / 2).round(); // Group angles within 2-degree ranges
      angleGroups.putIfAbsent(group, () => []).add(angle);
    }

    // Find the most consistent angle group
    int maxCount = 0;
    double bestAngle = 0.0;
    angleGroups.forEach((group, groupAngles) {
      if (groupAngles.length > maxCount) {
        maxCount = groupAngles.length;
        bestAngle = groupAngles.reduce((a, b) => a + b) / groupAngles.length;
      }
    });

    return bestAngle;
  }

  /// Detects angle from edge lines (improved version)
  double _detectAngleFromEdges(img.Image image) {
    img.Image grayscale = img.grayscale(image);
    grayscale = img.gaussianBlur(grayscale, radius: 1);
    img.Image edges = _sobelEdgeDetection(grayscale);

    List<Line> lines = _improvedHoughLines(edges);
    List<double> angles = [];

    for (Line line in lines) {
      double dx = line.x2 - line.x1;
      double dy = line.y2 - line.y1;
      double lineLength = sqrt(dx * dx + dy * dy);

      if (lineLength > image.width * 0.1) {
        // Only consider significant lines
        double angle = atan2(dy, dx) * 180 / pi;

        // Normalize angle to [-90, 90] range
        while (angle > 90) angle -= 180;
        while (angle < -90) angle += 180;

        // Weight by line length
        for (int i = 0; i < (lineLength / 50).round(); i++) {
          angles.add(angle);
        }
      }
    }

    if (angles.isEmpty) return 0.0;

    // Find the most dominant direction (horizontal or vertical)
    List<double> horizontalAngles = angles.where((a) => a.abs() <= 45).toList();
    List<double> verticalAngles = angles.where((a) => a.abs() > 45).toList();

    if (horizontalAngles.length >= verticalAngles.length) {
      // Use horizontal reference
      return horizontalAngles.isEmpty
          ? 0.0
          : horizontalAngles.reduce((a, b) => a + b) / horizontalAngles.length;
    } else {
      // Use vertical reference - convert to horizontal equivalent
      double avgVertical =
          verticalAngles.reduce((a, b) => a + b) / verticalAngles.length;
      return avgVertical > 0 ? avgVertical - 90 : avgVertical + 90;
    }
  }

  /// Detects angle using gradient orientation analysis
  double _detectAngleFromGradients(img.Image image) {
    img.Image grayscale = img.grayscale(image);
    int width = grayscale.width;
    int height = grayscale.height;

    List<double> gradientOrientations = [];

    // Sample points across the image
    for (int y = height ~/ 4; y < 3 * height ~/ 4; y += 10) {
      for (int x = width ~/ 4; x < 3 * width ~/ 4; x += 10) {
        if (x > 0 && x < width - 1 && y > 0 && y < height - 1) {
          double gx =
              grayscale.getPixel(x + 1, y).r.toDouble() -
              grayscale.getPixel(x - 1, y).r.toDouble();
          double gy =
              grayscale.getPixel(x, y + 1).r.toDouble() -
              grayscale.getPixel(x, y - 1).r.toDouble();

          double magnitude = sqrt(gx * gx + gy * gy);
          if (magnitude > 10) {
            // Only consider significant gradients
            double orientation = atan2(gy, gx) * 180 / pi;
            gradientOrientations.add(orientation);
          }
        }
      }
    }

    if (gradientOrientations.isEmpty) return 0.0;

    // Find dominant orientation
    Map<int, int> orientationBins = {};
    for (double orientation in gradientOrientations) {
      int bin = ((orientation + 180) / 10).floor(); // 10-degree bins
      orientationBins[bin] = (orientationBins[bin] ?? 0) + 1;
    }

    // Find the most common orientation
    int maxCount = 0;
    int dominantBin = 0;
    orientationBins.forEach((bin, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantBin = bin;
      }
    });

    double dominantOrientation = dominantBin * 10.0 - 180.0;

    // Convert to rotation angle (perpendicular to dominant edge direction)
    double rotationAngle = dominantOrientation + 90;
    while (rotationAngle > 90) rotationAngle -= 180;
    while (rotationAngle < -90) rotationAngle += 180;

    return rotationAngle;
  }

  /// Detects angle using content distribution analysis
  double _detectAngleFromDistribution(img.Image image) {
    img.Image grayscale = img.grayscale(image);
    int width = grayscale.width;
    int height = grayscale.height;

    // Test multiple angles and find the one with best alignment
    double bestAngle = 0.0;
    double bestScore = double.infinity;

    for (double testAngle = -15.0; testAngle <= 15.0; testAngle += 0.5) {
      double score = _calculateAlignmentScore(grayscale, testAngle);
      if (score < bestScore) {
        bestScore = score;
        bestAngle = testAngle;
      }
    }

    return bestAngle;
  }

  /// Calculates alignment score for a given rotation angle
  double _calculateAlignmentScore(img.Image image, double angle) {
    // Rotate image by test angle
    img.Image rotated = img.copyRotate(image, angle: angle);

    int width = rotated.width;
    int height = rotated.height;

    double horizontalVariance = 0.0;
    double verticalVariance = 0.0;

    // Calculate variance in horizontal and vertical directions
    for (int y = 0; y < height; y += 5) {
      List<double> rowValues = [];
      for (int x = 0; x < width; x += 5) {
        rowValues.add(rotated.getPixel(x, y).r.toDouble());
      }
      if (rowValues.length > 1) {
        double mean = rowValues.reduce((a, b) => a + b) / rowValues.length;
        double variance =
            rowValues.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            rowValues.length;
        horizontalVariance += variance;
      }
    }

    for (int x = 0; x < width; x += 5) {
      List<double> colValues = [];
      for (int y = 0; y < height; y += 5) {
        colValues.add(rotated.getPixel(x, y).r.toDouble());
      }
      if (colValues.length > 1) {
        double mean = colValues.reduce((a, b) => a + b) / colValues.length;
        double variance =
            colValues.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            colValues.length;
        verticalVariance += variance;
      }
    }

    // Return combined score (lower is better alignment)
    return horizontalVariance + verticalVariance;
  }

  /// Applies Sobel edge detection to detect edges in the image
  img.Image _sobelEdgeDetection(img.Image grayscale) {
    int width = grayscale.width;
    int height = grayscale.height;
    img.Image result = img.Image(width: width, height: height);

    // Sobel kernels
    List<List<int>> sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];

    List<List<int>> sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0.0;
        double gy = 0.0;

        // Apply Sobel kernels
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            int pixelValue = grayscale.getPixel(x + kx, y + ky).r.toInt();
            gx += pixelValue * sobelX[ky + 1][kx + 1];
            gy += pixelValue * sobelY[ky + 1][kx + 1];
          }
        }

        // Calculate gradient magnitude
        double magnitude = sqrt(gx * gx + gy * gy);
        int intensity = magnitude.clamp(0, 255).toInt();

        result.setPixel(x, y, img.ColorRgb8(intensity, intensity, intensity));
      }
    }

    return result;
  }

  /// Improved Hough line detection that finds both horizontal and vertical lines
  List<Line> _improvedHoughLines(img.Image edges) {
    int width = edges.width;
    int height = edges.height;
    List<Line> lines = [];

    double threshold = width * 0.05; // Lower threshold for better detection

    // Check horizontal lines
    for (int y = height ~/ 6; y < 5 * height ~/ 6; y += 3) {
      double edgeStrength = 0.0;
      List<int> edgePositions = [];

      for (int x = 0; x < width; x++) {
        int pixelValue = edges.getPixel(x, y).r.toInt();
        if (pixelValue > 100) {
          // Lower threshold
          edgeStrength += pixelValue;
          edgePositions.add(x);
        }
      }

      if (edgeStrength > threshold && edgePositions.length > width * 0.2) {
        // Create a line from the leftmost to rightmost edge
        int x1 = edgePositions.first;
        int x2 = edgePositions.last;
        lines.add(
          Line(x1.toDouble(), y.toDouble(), x2.toDouble(), y.toDouble()),
        );
      }
    }

    // Check vertical lines
    for (int x = width ~/ 6; x < 5 * width ~/ 6; x += 3) {
      double edgeStrength = 0.0;
      List<int> edgePositions = [];

      for (int y = 0; y < height; y++) {
        int pixelValue = edges.getPixel(x, y).r.toInt();
        if (pixelValue > 100) {
          // Lower threshold
          edgeStrength += pixelValue;
          edgePositions.add(y);
        }
      }

      if (edgeStrength > threshold && edgePositions.length > height * 0.2) {
        // Create a line from the topmost to bottommost edge
        int y1 = edgePositions.first;
        int y2 = edgePositions.last;
        lines.add(
          Line(x.toDouble(), y1.toDouble(), x.toDouble(), y2.toDouble()),
        );
      }
    }

    return lines;
  }

  /// Auto-straighten the image based on multiple detection methods
  Future<void> _autoStraighten() async {
    if (_originalImage == null || _isAdjustingPerspective) return;

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Analyzing image orientation...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      debugPrint('=== AUTO-STRAIGHTENING DEBUG ===');
      debugPrint(
          'Original image size: ${_originalImage!.width}x${_originalImage!.height}');

      // Method 1: Try our complex detection
      double complexAngle = _detectStraighteningAngle(_originalImage!);
      debugPrint(
          'Complex detection result: ${complexAngle.toStringAsFixed(2)}°');

      // Method 2: Try a simpler edge-based approach
      double simpleAngle = _simpleEdgeDetection(_originalImage!);
      debugPrint('Simple detection result: ${simpleAngle.toStringAsFixed(2)}°');

      // Use the angle with larger magnitude, or fallback to complex if both are small
      double finalAngle = complexAngle;
      if (simpleAngle.abs() > complexAngle.abs() && simpleAngle.abs() > 0.5) {
        finalAngle = simpleAngle;
        debugPrint('Using simple detection result');
      } else {
        debugPrint('Using complex detection result');
      }

      debugPrint('Final angle to apply: ${finalAngle.toStringAsFixed(2)}°');

      // Lower the threshold for testing - let's try any angle > 0.3 degrees
      if (finalAngle.abs() < 0.3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Image appears straight (${finalAngle.toStringAsFixed(2)}° detected)',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Limit correction angle to ±20 degrees for safety
      double correctionAngle = finalAngle.clamp(-20.0, 20.0);
      debugPrint('Applying correction: ${correctionAngle.toStringAsFixed(2)}°');

      // Apply the correction by rotating the original image
      img.Image straightenedImage = img.copyRotate(
        _originalImage!,
        angle: -correctionAngle, // copyRotate expects degrees
        interpolation: img.Interpolation.linear,
      );

      debugPrint(
          'Rotated image size: ${straightenedImage.width}x${straightenedImage.height}');

      // Update the original image and reset rotation
      setState(() {
        _originalImage = straightenedImage;
        _currentRotation = 0;
      });

      _updateDisplayedImage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-straightened by ${correctionAngle.abs().toStringAsFixed(1)}°',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      debugPrint('=== AUTO-STRAIGHTENING COMPLETE ===');
    } catch (e) {
      debugPrint('Error in auto-straighten: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-straighten failed: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Simple edge detection method for comparison
  double _simpleEdgeDetection(img.Image image) {
    debugPrint('Running simple edge detection...');

    // Convert to grayscale
    img.Image gray = img.grayscale(image);

    // Look for horizontal and vertical edge patterns
    List<double> horizontalStrengths = [];
    List<double> verticalStrengths = [];

    int width = gray.width;
    int height = gray.height;

    // Sample horizontal lines
    for (int y = height ~/ 4; y < 3 * height ~/ 4; y += height ~/ 20) {
      double strength = 0;
      for (int x = 1; x < width - 1; x++) {
        int left = gray.getPixel(x - 1, y).r.toInt();
        int right = gray.getPixel(x + 1, y).r.toInt();
        strength += (right - left).abs();
      }
      horizontalStrengths.add(strength);
    }

    // Sample vertical lines
    for (int x = width ~/ 4; x < 3 * width ~/ 4; x += width ~/ 20) {
      double strength = 0;
      for (int y = 1; y < height - 1; y++) {
        int top = gray.getPixel(x, y - 1).r.toInt();
        int bottom = gray.getPixel(x, y + 1).r.toInt();
        strength += (bottom - top).abs();
      }
      verticalStrengths.add(strength);
    }

    // Find dominant direction
    double avgH = horizontalStrengths.isNotEmpty
        ? horizontalStrengths.reduce((a, b) => a + b) /
              horizontalStrengths.length
        : 0;
    double avgV = verticalStrengths.isNotEmpty
        ? verticalStrengths.reduce((a, b) => a + b) / verticalStrengths.length
        : 0;

    debugPrint('Horizontal edge strength: $avgH');
    debugPrint('Vertical edge strength: $avgV');

    // For now, return a test angle to see if rotation works
    if (avgH > avgV * 1.2) {
      // Strong horizontal edges - image might be tilted
      return 2.0; // Test with 2 degree rotation
    } else if (avgV > avgH * 1.2) {
      // Strong vertical edges
      return -2.0; // Test with -2 degree rotation
    }

    return 0.0;
  }

  // دالة لتدوير الصورة يدوياً
  void _rotateImage(int angle) {
    if (_originalImage == null || _isAdjustingPerspective) return;
    _currentRotation = (_currentRotation + angle) % 360;
    // Ensure rotation is positive for modulo consistency if needed, though % handles negatives in Dart.
    if (_currentRotation < 0) _currentRotation += 360;
    _updateDisplayedImage();
  }

  /// Test method to apply a small rotation to verify rotation mechanism works
  void _testRotate() {
    if (_originalImage == null || _isAdjustingPerspective) return;

    debugPrint('=== Rotation Test ===');
    debugPrint(
        'Before: Original image size: ${_originalImage!.width}x${_originalImage!.height}');
    debugPrint(
        'Before: _displayedImageBytes length: ${_displayedImageBytes?.length ?? 0}');

    try {
      // Apply a 5-degree rotation to the original image
      img.Image rotatedImage = img.copyRotate(
        _originalImage!,
        angle: 5, // 5 degrees
        interpolation: img.Interpolation.linear,
      );

      debugPrint(
          'After Rotation: ${rotatedImage.width}x${rotatedImage.height}');

      // Update the original image
      setState(() {
        _originalImage = rotatedImage;
        _currentRotation = 0; // Reset display rotation
      });

      debugPrint('Calling _updateDisplayedImage()...');
      _updateDisplayedImage();

      debugPrint(
          'After Update: _displayedImageBytes length: ${_displayedImageBytes?.length ?? 0}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تطبيق دوران اختباري 5°'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في دوران الاختبار: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل دوران الاختبار: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    debugPrint('=== Rotation Test Complete ===');
  }

  /// Force refresh the displayed image to test UI update mechanism
  void _forceRefresh() {
    if (_originalImage == null) return;

    debugPrint('=== Force Refresh ===');
    debugPrint(
        'Current _displayedImageBytes length: ${_displayedImageBytes?.length ?? 0}');

    // Force re-creation of displayed image bytes
    _updateDisplayedImage();

    debugPrint(
        'After Force Refresh: _displayedImageBytes length: ${_displayedImageBytes?.length ?? 0}');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الصورة'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    debugPrint('=== Force Refresh Complete ===');
  }

  // دالة لبدء وضع ضبط المنظور
  void _startPerspectiveAdjustment() {
    setState(() {
      _imageBeforePerspectiveAdjust = img.Image.from(
        _originalImage!,
      ); // عمل نسخة احتياطية من الصورة الأصلية
      _rotationBeforePerspectiveAdjust = _currentRotation;
      // الوضعيات والحالات الأخرى تم حفظها بالفعل أو يتم تمريرها عبر الودجت

      _isAdjustingPerspective = true;
      _hasBeenPerspectiveCorrected = false; // إعادة تعيين هذه العلامة
      _perspectiveCorners = List.filled(4, null); // إعادة تعيين الزوايا
      _currentCornerIndex = 0;
      // مهم: نريد اختيار الزوايا على الصورة الأصلية غير المدورة.
      // لذا، للعرض أثناء الضبط، نضبط الدوران على 0.
      // منطق تحويل النقر سيقوم بعد ذلك بتعيين النقاط على هذه الصورة الأصلية ذات 0 درجة.
      _currentRotation = 0;
      _updateDisplayedImage(); // تحديث لعرض الصورة غير المدورة لاختيار الزوايا
    });
  }

  // دالة لإلغاء وضع ضبط المنظور والعودة للحالة السابقة
  void _cancelPerspectiveAdjustment() {
    setState(() {
      _originalImage = img.Image.from(_imageBeforePerspectiveAdjust!); // استعادة الصورة الأصلية
      _currentRotation = _rotationBeforePerspectiveAdjust; // استعادة الدوران السابق
      _isAdjustingPerspective = false;
      _hasBeenPerspectiveCorrected =
          false; // أو بناءً على الحالة السابقة إذا لزم الأمر
      _perspectiveCorners = List.filled(4, null);
      _currentCornerIndex = 0;
      _updateDisplayedImage(); // تحديث لعرض الصورة المستعادة
    });
  }

  // دالة لإعادة تعيين نقاط الزوايا المختارة لضبط المنظور
  void _resetPerspectiveCorners() {
    setState(() {
      _perspectiveCorners = List.filled(4, null);
      _currentCornerIndex = 0;
    });
  }

  // دالة مساعدة للحصول على رسائل توجيهية للمستخدم أثناء ضبط المنظور
 List<String> _getCornerPrompts() {
    return [
      "Tap top-left corner",
      "Tap top-right corner",
      "Tap bottom-right corner",
      "Tap bottom-left corner",
      "All corners selected. Apply or Reset.",
    ];
  }


  // دالة لتطبيق تصحيح المنظور الفعلي (سيتم تنفيذ المنطق لاحقاً)
  Future<void> _applyPerspectiveCorrection() async {
    if (_perspectiveCorners.any((p) => p == null)) return; // تأكد من اختيار جميع الزوايا

    // الحصول على حجم وموضع الصورة المعروضة على الشاشة
    final RenderBox renderBox = _imageDisplayKey.currentContext!.findRenderObject() as RenderBox;
    final Size displaySize = renderBox.size; // حجم الودجت Image.memory
    // final Offset displayPosition = renderBox.localToGlobal(Offset.zero); // موضع الودجت Image.memory على الشاشة

    // حساب عوامل التحجيم بين الصورة الأصلية وحجم العرض
    final double scaleX = _originalImage!.width / displaySize.width;
    final double scaleY = _originalImage!.height / displaySize.height;

    // تحويل إحداثيات النقر من الشاشة إلى إحداثيات الصورة الأصلية
    // (هنا نفترض أن offset هو بالفعل إحداثي محلي داخل الودجت Image.memory)
    List<Offset> sourcePoints = _perspectiveCorners.map((offset) {
      return Offset(offset!.dx * scaleX, offset.dy * scaleY);
    }).toList();

    // نقاط الوجهة (destination points) للصورة المستقيمة (مستطيل عادي)
    // يمكننا تحديد حجم الصورة المستقيمة بناءً على الأبعاد الأصلية أو تحديد أبعاد جديدة
    // هنا نختار الحفاظ على نسبة العرض إلى الارتفاع تقريباً
    double newWidth = (sourcePoints[1].dx - sourcePoints[0].dx).abs();
    double newHeight = (sourcePoints[3].dy - sourcePoints[0].dy).abs();

    // يمكن تحسين هذا لضمان مستطيل مثالي
    List<Offset> destinationPoints = [
      Offset(0, 0), // أعلى اليسار
      Offset(newWidth, 0), // أعلى اليمين
      Offset(newWidth, newHeight), // أسفل اليمين
      Offset(0, newHeight), // أسفل اليسار
    ];

    try {
      // تطبيق تحويل المنظور (Perspective Transform)
      // هذه الدالة غير موجودة مباشرة في مكتبة 'image' وتحتاج إلى تنفيذ مخصص
      // أو استخدام مكتبة أخرى تدعم تحويل المنظور
      // كمثال، سنقوم فقط بتدوير الصورة كبديل مؤقت
      img.Image correctedImage = img.copyRotate(_originalImage!, angle: 0); // Placeholder for actual perspective transform

      // إذا كان لديك دالة لتحويل المنظور (مثلاً: img.copyPerspective(image, sourcePoints, destinationPoints))
      // فستستخدمها هنا. بما أنها غير موجودة، هذا الجزء هو للتوضيح.
      // For demonstration, let's just make a copy
      correctedImage = img.Image.from(_originalImage!);

      setState(() {
        _originalImage = correctedImage;
        _isAdjustingPerspective = false;
        _hasBeenPerspectiveCorrected = true; // تم تصحيح المنظور
        _currentRotation = 0; // إعادة تعيين الدوران بعد تصحيح المنظور
      });
      _updateDisplayedImage();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perspective correction applied (actual transformation logic needs implementation).'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying perspective correction: $e'); // خطأ في تطبيق تصحيح المنظور: $e
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perspective correction failed: ${e.toString()}'), // فشل تصحيح المنظور: ${e.toString()}
          ),
        );
      }
    }
  }


  // دالة لمعالجة النقر على الصورة أثناء وضع ضبط المنظور
  void _handleImageTap(TapUpDetails details) {
    if (!_isAdjustingPerspective || _currentCornerIndex >= 4) return;

    // الحصول على حجم وموضع الصورة المعروضة على الشاشة
    final RenderBox renderBox = _imageDisplayKey.currentContext!.findRenderObject() as RenderBox;
    final Size displaySize = renderBox.size;
    final Offset localPosition = details.localPosition; // إحداثيات النقر بالنسبة للودجت Image.memory

    // تحويل إحداثيات النقر من الشاشة إلى إحداثيات الصورة الأصلية
    // (هنا نفترض أن الصورة المعروضة هي الصورة الأصلية غير المدورة في وضع ضبط المنظور)
    final double scaleX = _originalImage!.width / displaySize.width;
    final double scaleY = _originalImage!.height / displaySize.height;

    final Offset originalImageCoordinates = Offset(
      localPosition.dx * scaleX,
      localPosition.dy * scaleY,
    );

    setState(() {
      _perspectiveCorners[_currentCornerIndex] = originalImageCoordinates;
      _currentCornerIndex++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Corner ${_currentCornerIndex} selected at: (${originalImageCoordinates.dx.toStringAsFixed(1)}, ${originalImageCoordinates.dy.toStringAsFixed(1)})',
        ),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  // دالة لحساب الزاوية بين ثلاث نقاط (مساعدة)
  double _calculateAngle(PoseLandmark? p1, PoseLandmark? p2, PoseLandmark? p3) {
    if (p1 == null || p2 == null || p3 == null) {
      return double.nan; // إرجاع NaN إذا كانت إحدى النقاط غير موجودة
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

  // دالة لحساب وتعيين جميع الزوايا المهمة لهذه الشاشة
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

    // الزوايا الأربعة الرئيسية للجذع
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
    Widget imageDisplayWidget =
        (_displayedImageBytes == null || _originalImage == null)
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: AspectRatio(
                  aspectRatio:
                      _isAdjustingPerspective // أثناء الضبط، عرض نسبة العرض إلى الارتفاع الأصلية غير المدورة
                          ? _originalImage!.width / _originalImage!.height
                          : (_currentRotation == 90 || _currentRotation == 270)
                              ? _originalImage!.height /
                                  _originalImage!
                                      .width // مقلوبة لـ 90/270 درجة
                              : _originalImage!.width /
                                  _originalImage!.height, // عادية لـ 0/180 درجة
                  child: Image.memory(
                    _displayedImageBytes!,
                    key: _imageDisplayKey, // مفتاح للحصول على RenderBox
                    fit: BoxFit.contain,
                  ),
                ),
              );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isAdjustingPerspective
              ? ' Perspective adjustment'
              : 'View and rotate the document',
        ),
        leading: _isAdjustingPerspective
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelPerspectiveAdjustment,
              )
            : null, // زر الرجوع الافتراضي
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTapUp: _isAdjustingPerspective ? _handleImageTap : null, // تفعيل النقر فقط في وضع الضبط
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageDisplayWidget,
                    // عرض الوضعيات والزوايا فقط إذا لم نكن في وضع ضبط المنظور ولم يتم تصحيح المنظور بعد
                    if (widget.poses != null &&
                        widget.poses!.isNotEmpty &&
                        widget.poseImageSize != null &&
                        !_isAdjustingPerspective &&
                        !_hasBeenPerspectiveCorrected)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: StaticPosePainter(
                            poses: widget.poses!,
                            originalImageSize: widget.poseImageSize!,
                            isBackCamera: widget.isBackCamera,
                            rotationDegrees: _currentRotation, // Pass current rotation to the painter
                            angles: _angles, // تمرير الزوايا إلى الرسام
                          ),
                        ),
                      ),
                    // Draw selected corner points during perspective adjustment
                    if (_isAdjustingPerspective)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: PerspectiveCornerPainter(
                            corners: _perspectiveCorners,
                            imageSize: Size(_originalImage!.width.toDouble(), _originalImage!.height.toDouble()),
                            displayKey: _imageDisplayKey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_isAdjustingPerspective)
            _buildPerspectiveAdjustmentControls()
          else
            _buildDefaultControls(),
        ],
      ),
    );
  }

  // Widget to display perspective adjustment controls
  Widget _buildPerspectiveAdjustmentControls() {
    bool allCornersSet = _currentCornerIndex >= 4;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getCornerPrompts()[_currentCornerIndex.clamp(0, _getCornerPrompts().length - 1)], // Display guiding message
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Points'),
                onPressed: _resetPerspectiveCorners,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Apply'),
                onPressed: allCornersSet ? _applyPerspectiveCorrection : null, // Enable button only when all corners are selected
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget to display default controls (rotate, auto-correct)
  Widget _buildDefaultControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First row: Manual controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.rotate_left),
                label: const Text('Rotate Left'),
                onPressed: _originalImage == null
                    ? null
                    : () => _rotateImage(-90),
              ),
              TextButton.icon(
                icon: const Icon(Icons.crop_rotate), // Icon for perspective
                label: const Text('Adjust Perspective'),
                onPressed: _originalImage == null
                    ? null
                    : _startPerspectiveAdjustment,
              ),
              TextButton.icon(
                icon: const Icon(Icons.rotate_right),
                label: const Text('Rotate Right'),
                onPressed: _originalImage == null
                    ? null
                    : () => _rotateImage(90),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: Auto-correction
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.straighten),
              label: const Text('Auto-Straighten Image'),
              onPressed: _originalImage == null ? null : _autoStraighten,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Test rotation button (for debugging only)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.rotate_right),
                  label: const Text('Test Rotate 5°'),
                  onPressed: _originalImage == null ? null : _testRotate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Display'),
                  onPressed: _originalImage == null ? null : _forceRefresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// CustomPainter for drawing selected corner points for perspective adjustment
class PerspectiveCornerPainter extends CustomPainter {
  final List<Offset?> corners; // List of corner points (can be null)
  final Size imageSize; // Original size of the image (on which corners are selected)
  final GlobalKey displayKey; // Key of the Image.memory widget to get display size

  PerspectiveCornerPainter({
    required this.corners,
    required this.imageSize,
    required this.displayKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pointPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    final Paint linePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint selectedPointPaint = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.fill
      ..strokeWidth = 3.0;

    // Get the size and position of the displayed image on the screen
    final RenderBox? renderBox = displayKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size displaySize = renderBox.size;
    // final Offset displayPosition = renderBox.localToGlobal(Offset.zero); // Position of the Image.memory widget on the screen

    // Calculate scaling factors between the original image and display size
    final double scaleX = displaySize.width / imageSize.width;
    final double scaleY = displaySize.height / imageSize.height;

    // Calculate offset for centering the displayed image within the Canvas (if the image is scaled down and centered)
    final double offsetX = (size.width - displaySize.width) / 2;
    final double offsetY = (size.height - displaySize.height) / 2;

    // Draw points and lines
    List<Offset> actualPoints = [];
    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];
      if (corner != null) {
        // Convert point coordinates from original image coordinates to Canvas coordinates
        final mappedX = corner.dx * scaleX + offsetX;
        final mappedY = corner.dy * scaleY + offsetY;
        final displayOffset = Offset(mappedX, mappedY);
        actualPoints.add(displayOffset);

        canvas.drawCircle(displayOffset, 8.0, pointPaint); // Draw circle for the point
        // Draw a larger circle for the current point being selected
        if (i == corners.indexOf(null) -1 || (corners.every((element) => element != null) && i == corners.length -1)) {
           canvas.drawCircle(displayOffset, 10.0, selectedPointPaint);
        }
      }
    }

    // Draw lines between points if 4 points are selected
    if (actualPoints.length == 4) {
      canvas.drawLine(actualPoints[0], actualPoints[1], linePaint); // TL to TR
      canvas.drawLine(actualPoints[1], actualPoints[2], linePaint); // TR to BR
      canvas.drawLine(actualPoints[2], actualPoints[3], linePaint); // BR to BL
      canvas.drawLine(actualPoints[3], actualPoints[0], linePaint); // BL to TL
    }
  }

  @override
  bool shouldRepaint(PerspectiveCornerPainter oldDelegate) {
    return oldDelegate.corners != corners ||
           oldDelegate.imageSize != imageSize;
  }
}
