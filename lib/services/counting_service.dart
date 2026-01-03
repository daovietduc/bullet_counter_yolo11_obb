import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:image/image.dart' as img; // Thư viện xử lý pixel: dùng để resize và chuẩn hóa ảnh
import 'package:tflite_flutter/tflite_flutter.dart'; // Thư viện cầu nối chạy AI TensorFlow Lite
import '../models/detection_result.dart'; // Model chứa kết quả: đỉnh xoay, độ tự tin, class...

/// ============================================================================
/// SERVICE XỬ LÝ ĐẾM VẬT THỂ VỚI YOLOV11-OBB (ORIENTED BOUNDING BOX)
/// ============================================================================
///
/// [GIẢI THÍCH VỀ ĐẦU VÀO (INPUT TENSOR)]:
/// - Dạng mảng 4 chiều: [Batch_Size, Width, Height, Channels]
/// - Cụ thể trong code: [1, 640, 640, 3]
/// - Ý nghĩa: 1 ảnh mỗi lần chạy, kích thước 640x640 pixel, 3 kênh màu đỏ-xanh lá-xanh dương (RGB).
/// - Giá trị pixel: Đã được chuẩn hóa từ [0-255] về [0.0 - 1.0] dạng Float32.
///
/// [GIẢI THÍCH VỀ ĐẦU RA (OUTPUT TENSOR)]:
/// - Dạng mảng 3 chiều: [1, 21504, 7] (Số liệu có thể thay đổi nhẹ tùy phiên bản Model)
/// - Ý nghĩa 7 giá trị trong mỗi dự đoán (Feature Vector):
///   1. data[0]: Center X (Tọa độ tâm X của vật thể)
///   2. data[1]: Center Y (Tọa độ tâm Y của vật thể)
///   3. data[2]: Width (Chiều dài cạnh dài nhất của vật)
///   4. data[3]: Height (Chiều dài cạnh ngắn của vật)
///   5. data[4]: Confidence Score (Độ tin cậy từ 0.0 đến 1.0)
///   6. data[5]: Class ID (Số định danh loại vật thể: 0, 1, 2...)
///   7. data[6]: Angle (Góc xoay tính bằng Radian, thường từ -pi/2 đến pi/2)
/// ============================================================================

class CountingService {
  Interpreter? _interpreter; // Bộ máy thực thi mô hình AI
  List<String> _labels = []; // Danh sách tên nhãn đọc từ file labels.txt
  final _log = Logger('CountingServide'); // Tạo đối tượng lưu log

  // --- BIẾN PHỤ TRỢ CHO LETTERBOXING (MỚI THÊM) ---
  double _scale = 1.0; // Tỷ lệ phóng đại chung để không méo hình
  double _padX = 0;    // Khoảng bù đen theo trục X
  double _padY = 0;    // Khoảng bù đen theo trục Y

  // --------------------------------------------------------------------------
  // CẤU HÌNH THÔNG SỐ AI (HYPERPARAMETERS)
  // --------------------------------------------------------------------------
  static const int inputSize = 640;    // Kích thước ảnh đầu vào bắt buộc của YOLOv11
  static const double confThreshold = 0.4; // Loại bỏ các dự đoán yếu (AI không chắc chắn)
  static const double iouThreshold = 0.2;  // Ngưỡng chồng lấn: > 20% thì coi là trùng vật thể

  /// Tải Model và Danh sách nhãn từ thư mục Assets
  Future<void> loadModel(String modelPath, {String labelsPath = 'assets/labels.txt'}) async {
    if (_interpreter != null) return; // Nếu đã nạp rồi thì bỏ qua
    try {
      // Khởi tạo bộ máy suy luận với 4 luồng CPU để tối ưu tốc độ xử lý trên Mobile
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: InterpreterOptions()..threads = 4,
      );
      _interpreter!.allocateTensors(); // Cấp phát RAM cho các mảng dữ liệu AI

      // Đọc file nhãn và chuyển thành danh sách mảng (xử lý xuống dòng)
      final labelsData = await rootBundle.loadString(labelsPath);
      _labels = labelsData.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      _log.info("Model and labels loaded successfully. Found ${_labels.length} labels.");
    } catch (e, stackTrace) {
      _log.severe('Failed to load the model', e, stackTrace);
      rethrow; // Ném lại lỗi để lớp gọi có thể xử lý (ví dụ: hiển thị thông báo cho người dùng)
    }
  }

  /// HÀM CHÍNH: Nhận ảnh -> Trả về danh sách vật thể sau khi đếm
  Future<List<DetectionResult>> countObjects(String imagePath, {int? targetClass}) async {
    if (_interpreter == null) return [];

    // --- BƯỚC 1: TIỀN XỬ LÝ ẢNH (PRE-PROCESSING VỚI LETTERBOXING) ---
    final imageBytes = await File(imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return [];

    // Lưu kích thước gốc để ánh xạ (Mapping)
    final double originalWidth = originalImage.width.toDouble();
    final double originalHeight = originalImage.height.toDouble();

    // [CẬP NHẬT]: Tính toán tỷ lệ scale đồng nhất để bảo toàn góc vuông 90 độ
    _scale = min(inputSize / originalWidth, inputSize / originalHeight);
    final int newW = (originalWidth * _scale).toInt();
    final int newH = (originalHeight * _scale).toInt();

    // [CẬP NHẬT]: Tính toán phần bù (Padding) để căn giữa ảnh trong khung 640x640
    _padX = (inputSize - newW) / 2.0;
    _padY = (inputSize - newH) / 2.0;

    // Resize ảnh giữ tỷ lệ và tạo canvas 640x640 (vùng trống sẽ có màu đen)
    img.Image resizedImage = img.copyResize(originalImage, width: newW, height: newH);
    img.Image canvas = img.Image(width: inputSize, height: inputSize);
    img.compositeImage(canvas, resizedImage, dstX: _padX.toInt(), dstY: _padY.toInt());

    var input = _imageToArray(canvas);

    // --- BƯỚC 2: CHẠY SUY LUẬN (INFERENCE) ---
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final int numDetections = outputShape[1];
    final int numFeatures = outputShape[2];

    var output = List.filled(numDetections * numFeatures, 0.0).reshape([1, numDetections, numFeatures]);

    _interpreter!.run(input, output);

    final List<DetectionResult> detectionsForNMS = [];

    // --- BƯỚC 3: PHÂN TÍCH VÀ TRÍCH XUẤT DỮ LIỆU ---
    for (var i = 0; i < numDetections; i++) {
      final data = output[0][i];
      final confidence = data[4];
      final classId = data[5].toInt();

      if (confidence > confThreshold) {
        if (targetClass == null || classId == targetClass) {
          // Tọa độ lúc này là tọa độ trong khung 640x640 (bao gồm cả lề đen)
          final double cx = data[0] * inputSize;
          final double cy = data[1] * inputSize;
          double w = data[2] * inputSize;
          double h = data[3] * inputSize;
          double angle = data[6];

          // Chuẩn hóa Hình học: Đảm bảo cạnh W luôn là cạnh dài nhất
          if (w < h) {
            double temp = w; w = h; h = temp;
            angle += pi / 2;
          }

          // [TOÁN HỌC]: Chuyển (Tâm, Dài, Rộng, Góc) -> Tọa độ 4 đỉnh (A, B, C, D)
          final List<Offset> vertices640 = _calculateRotatedVertices(cx, cy, w, h, angle);

          detectionsForNMS.add(DetectionResult(
            rotatedVertices: vertices640,
            confidence: confidence,
            classId: classId,
            className: classId < _labels.length ? _labels[classId] : 'Unknown',
            boundingBox: _calculateAABB(vertices640),
          ));
        }
      }
    }

    // --- BƯỚC 4: LỌC TRÙNG VẬT THỂ (NMS VỚI ROTATED IOU) ---
    List<DetectionResult> nmsResults = _nonMaximumSuppression(detectionsForNMS);

    // --- BƯỚC 5: QUY ĐỔI TỌA ĐỘ VỀ ẢNH GỐC (COORDINATE MAPPING - SỬA LỖI MÉO HÌNH) ---
    return nmsResults.map((res) {
      // [QUAN TRỌNG]: Trừ padding và chia cho scale duy nhất để bảo toàn góc vuông
      final scaledVertices = res.rotatedVertices.map((p) {
        return Offset(
            (p.dx - _padX) / _scale,
            (p.dy - _padY) / _scale
        );
      }).toList();

      return DetectionResult(
        rotatedVertices: scaledVertices,
        confidence: res.confidence,
        classId: res.classId,
        className: res.className,
        boundingBox: _calculateAABB(scaledVertices),
      );
    }).toList();
  }

  // --------------------------------------------------------------------------
  // HÀM TOÁN HỌC HÌNH HỌC PHỨC TẠP
  // --------------------------------------------------------------------------

  /// [HÀM AABB]: Tìm khung hình chữ nhật đứng nhỏ nhất bao quanh đa giác xoay.
  Rect _calculateAABB(List<Offset> vertices) {
    if (vertices.isEmpty) return Rect.zero;
    double minX = vertices.map((p) => p.dx).reduce(min);
    double maxX = vertices.map((p) => p.dx).reduce(max);
    double minY = vertices.map((p) => p.dy).reduce(min);
    double maxY = vertices.map((p) => p.dy).reduce(max);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// [MA TRẬN XOAY]: Sử dụng công thức sin/cos để tìm tọa độ 4 đỉnh từ góc xoay.
  List<Offset> _calculateRotatedVertices(double cx, double cy, double w, double h, double angle) {
    final double cosA = cos(angle);
    final double sinA = sin(angle);
    final points = [Offset(-w/2, -h/2), Offset(w/2, -h/2), Offset(w/2, h/2), Offset(-w/2, h/2)];
    return points.map((p) => Offset(
        cx + p.dx * cosA - p.dy * sinA,
        cy + p.dx * sinA + p.dy * cosA
    )).toList();
  }

  /// [ROTATED IOU]: Tính toán độ trùng lấn của 2 hình chữ nhật bị xoay nghiêng.
  double _rotatedIoU(DetectionResult boxA, DetectionResult boxB) {
    final areaA = _getPolygonArea(boxA.rotatedVertices);
    final areaB = _getPolygonArea(boxB.rotatedVertices);
    if (areaA <= 0 || areaB <= 0) return 0.0;

    var intersection = boxA.rotatedVertices;
    for (int i = 0; i < boxB.rotatedVertices.length; i++) {
      final p1 = boxB.rotatedVertices[i];
      final p2 = boxB.rotatedVertices[(i + 1) % boxB.rotatedVertices.length];
      intersection = _clipPolygon(intersection, p1, p2);
      if (intersection.isEmpty) break;
    }

    final double interArea = _getPolygonArea(intersection);
    return interArea / (areaA + areaB - interArea);
  }

  /// [NMS]: Loại bỏ các dự đoán trùng lặp.
  List<DetectionResult> _nonMaximumSuppression(List<DetectionResult> detections) {
    if (detections.isEmpty) return [];
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<DetectionResult> selected = [];
    final List<bool> active = List.filled(detections.length, true);

    for (int i = 0; i < detections.length; i++) {
      if (!active[i]) continue;
      selected.add(detections[i]);
      for (int j = i + 1; j < detections.length; j++) {
        if (active[j] && detections[i].classId == detections[j].classId) {
          if (_rotatedIoU(detections[i], detections[j]) > iouThreshold) {
            active[j] = false;
          }
        }
      }
    }
    return selected;
  }

  /// [CLIPPING]: Thuật toán Sutherland-Hodgman để cắt đa giác.
  List<Offset> _clipPolygon(List<Offset> subject, Offset p1, Offset p2) {
    List<Offset> output = [];
    final double dcx = p2.dx - p1.dx;
    final double dcy = p2.dy - p1.dy;
    for (int i = 0; i < subject.length; i++) {
      final cur = subject[i];
      final prev = subject[(i + subject.length - 1) % subject.length];
      final double curSide = (cur.dx - p1.dx) * dcy - (cur.dy - p1.dy) * dcx;
      final double prevSide = (prev.dx - p1.dx) * dcy - (prev.dy - p1.dy) * dcx;
      if (curSide <= 0) {
        if (prevSide > 0) {
          final double t = prevSide / (prevSide - curSide);
          output.add(Offset(prev.dx + t * (cur.dx - prev.dx), prev.dy + t * (cur.dy - prev.dy)));
        }
        output.add(cur);
      } else if (prevSide <= 0) {
        final double t = prevSide / (prevSide - curSide);
        output.add(Offset(prev.dx + t * (cur.dx - prev.dx), prev.dy + t * (cur.dy - prev.dy)));
      }
    }
    return output;
  }

  /// [DIỆN TÍCH]: Tính diện tích đa giác bằng công thức Shoelace.
  double _getPolygonArea(List<Offset> polygon) {
    if (polygon.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      area += (p1.dx * p2.dy - p2.dx * p1.dy);
    }
    return (area / 2.0).abs();
  }

  /// [TRANSFORM]: Chuyển ảnh Image sang mảng 4 chiều [1, 640, 640, 3] cho AI.
  List<List<List<List<double>>>> _imageToArray(img.Image image) {
    // Khởi tạo mảng trống với đúng kích thước yêu cầu
    var input = List.generate(1, (_) =>
        List.generate(inputSize, (_) =>
            List.generate(inputSize, (_) => List.filled(3, 0.0))
        )
    );

    // Duyệt qua từng pixel để gán giá trị màu
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }
    return input;
  }

  /// Đóng mô hình để trả lại bộ nhớ RAM cho điện thoại.
  void dispose() { _interpreter?.close(); _interpreter = null; }
}