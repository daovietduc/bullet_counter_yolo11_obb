import 'dart:math';
import 'package:flutter/material.dart';
import '../models/detection_result.dart';

/// Một [CustomPainter] để vẽ các hộp giới hạn xoay (Oriented Bounding Boxes - OBB)
/// và các thông tin liên quan lên trên một ảnh.
///
/// Lớp này chịu trách nhiệm chính trong việc:
/// 1. **Ánh xạ tọa độ:** Chuyển đổi tọa độ của các đối tượng được phát hiện từ
///    kích thước ảnh gốc (đầu vào của model) sang kích thước hiển thị trên màn hình.
/// 2. **Sắp xếp đối tượng:** Sắp xếp các đối tượng theo thứ tự zic-zac (snake sort)
///    để việc đánh số thứ tự trở nên trực quan hơn.
/// 3. **Vẽ tùy chỉnh:** Vẽ các thành phần như khung viền, màu nền, nhãn độ tin cậy
///    và số thứ tự dựa trên các tùy chọn được cung cấp.
class BoundingBoxPainter extends CustomPainter {
  //--- Thuộc tính đầu vào (Input Properties) ---
  final List<DetectionResult> results;  // Danh sách các kết quả phát hiện từ mô hình ML.
  final Size originalImageSize;  // Kích thước (width, height) của ảnh gốc được sử dụng để suy luận.
  final Size screenImageSize;  // Kích thước của widget `Image` hiển thị trên màn hình Flutter.

  // --- Tùy chọn hiển thị (Display Options) ---
  final bool showBoundingBoxes;  // Nếu `true`, vẽ khung viền cho mỗi đối tượng.
  final bool showConfidence;  // Nếu `true`, hiển thị nhãn chứa phần trăm độ tin cậy.
  final bool showFillBox;  // Nếu `true`, tô màu nền bên trong khung viền.
  final bool showOrderNumber;  // Nếu `true`, hiển thị số thứ tự ở tâm mỗi đối tượng.

  // --- Tùy chỉnh giao diện (UI Customization) ---
  final double fillOpacity; // Độ trong suốt của màu nền bên trong hộp bao.
  final Color boxColor;  // Màu nền cho các hộp bao quanh đối tượng.
  final bool isMultiColor; // Nếu `true`, các cột đối tượng sẽ được tô màu khác nhau.


  /// Khởi tạo một painter để vẽ các hộp giới hạn.
  /// Tất cả các tham số `required` phải được cung cấp. Các tham số khác
  /// có giá trị mặc định để dễ dàng sử dụng.
  BoundingBoxPainter({
    required this.results,
    required this.originalImageSize,
    required this.screenImageSize,
    this.showBoundingBoxes = true,
    this.showConfidence = true,
    this.showFillBox = false,
    this.showOrderNumber = false,
    required this.fillOpacity,
    required this.boxColor,
    required this.isMultiColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ngăn chặn lỗi chia cho 0 nếu kích thước ảnh đầu vào không hợp lệ.
    if (originalImageSize.width == 0 || originalImageSize.height == 0) return;

    // Bảng màu được sử dụng khi chế độ isMultiColor được bật.
    final List<Color> colorPalette = [
      Colors.red, Colors.blue, Colors.green, Colors.cyanAccent, Colors.purple,
    ];

    // --- LOGIC SẮP XẾP ZIC-ZAC DỌC (VERTICAL SNAKE SORT) ---
    // Mục tiêu: Sắp xếp các đối tượng từ trên xuống dưới, theo từng cột,
    // theo thứ tự zic-zac để tạo ra một luồng đếm tự nhiên.
    final List<DetectionResult> sortedResults = [];
    final Map<DetectionResult, int> columnMapping = {}; // Lưu chỉ số cột của mỗi đối tượng.
    if (results.isNotEmpty) {
      final List<DetectionResult> tempResults = List.from(results);

      // 1. Sắp xếp sơ bộ theo trục X:
      // Sắp xếp các đối tượng từ trái qua phải dựa trên tọa độ X trung bình.
      // Điều này làm tiền đề để phân nhóm chúng thành các cột.
      tempResults.sort((a, b) {
        double ax = a.rotatedVertices.map((v) => v.dx).reduce((v1, v2) =>
        v1 + v2) / a.rotatedVertices.length;
        double bx = b.rotatedVertices.map((v) => v.dx).reduce((v1, v2) =>
        v1 + v2) / b.rotatedVertices.length;
        return ax.compareTo(bx);
      });

      // 2. Phân nhóm đối tượng thành các cột dọc:
      // Duyệt qua các đối tượng đã sắp xếp và nhóm chúng vào các "cột" dựa trên
      // sự gần gũi về tọa độ X. Ngưỡng để xác định một đối tượng có thuộc cột
      // hay không được tính linh động dựa trên chiều rộng của chính đối tượng đó.
      List<List<DetectionResult>> columns = [];
      for (var result in tempResults) {
        double rx = result.rotatedVertices.map((v) => v.dx).reduce((v1, v2) => v1 + v2) / result.rotatedVertices.length;
        bool addedToCol = false;
        for (var col in columns) {
          double colX = col.map((e) => e.rotatedVertices.map((v) => v.dx).reduce((v1, v2) => v1 + v2) / e.rotatedVertices.length).reduce((a, b) => a + b) / col.length;

          // Ngưỡng phân cột (tolerance) được tính bằng 1.5 lần chiều rộng của đối tượng.
          // Đây là một cách ước tính linh hoạt để các đối tượng không thẳng hàng hoàn hảo
          // vẫn có thể được nhóm vào cùng một cột.
          double rWidth = (result.rotatedVertices[0] - result.rotatedVertices[3]).distance;
          if ((rx - colX).abs() < rWidth * 1.5) {
            col.add(result);
            addedToCol = true;
            break;
          }
        }
        if (!addedToCol) columns.add([result]);
      }

      // 3. Sắp xếp trong từng cột và tạo hiệu ứng zic-zac:
      for (int i = 0; i < columns.length; i++) {
        // Gán chỉ số cột cho từng đối tượng để phục vụ việc tô màu sau này.
        for (var resultInCol in columns[i]) {
          columnMapping[resultInCol] = i;
        }

        // Sắp xếp các đối tượng trong cột theo trục Y (từ trên xuống dưới).
        columns[i].sort((a, b) {
          double ay = a.rotatedVertices.map((v) => v.dy).reduce((v1, v2) => v1 + v2) / a.rotatedVertices.length;
          double by = b.rotatedVertices.map((v) => v.dy).reduce((v1, v2) => v1 + v2) / b.rotatedVertices.length;
          return ay.compareTo(by);
        });

        // Đảo ngược thứ tự của các cột chẵn (1, 3, 5...) để tạo thành đường đi zic-zac.
        // Cột 0, 2, 4...: Sắp xếp từ trên xuống.
        // Cột 1, 3, 5...: Sắp xếp từ dưới lên.
        if (i % 2 != 0) {
          sortedResults.addAll(columns[i].reversed);
        } else {
          sortedResults.addAll(columns[i]);
        }
      }
    }

    // --- LOGIC VẼ (DRAWING LOGIC) ---

    // 1. TÍNH TOÁN TỶ LỆ VÀ ĐỘ DỊCH CHUYỂN (SCALE & OFFSET)
    // Để đảm bảo ảnh được hiển thị đúng tỷ lệ và được căn giữa trong widget.
    final double scaleX = screenImageSize.width / originalImageSize.width;
    final double scaleY = screenImageSize.height / originalImageSize.height;
    final double scale = min(scaleX, scaleY); // Giữ đúng tỷ lệ khung hình (aspect ratio).

    // Tính toán khoảng trống lề để căn giữa ảnh.
    final double offsetX = (screenImageSize.width - originalImageSize.width * scale) / 2;
    final double offsetY = (screenImageSize.height - originalImageSize.height * scale) / 2;

    // Giới hạn vùng vẽ chỉ trong phạm vi của ảnh đã được scale và căn chỉnh.
    // Điều này ngăn các thành phần vẽ bị tràn ra ngoài khu vực ảnh.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offsetX, offsetY, originalImageSize.width * scale, originalImageSize.height * scale));

    // Lặp qua danh sách các đối tượng đã được sắp xếp để vẽ.
    for (var entry in sortedResults.asMap().entries) {
      final int index = entry.key;
      final DetectionResult result = entry.value;

      if (result.rotatedVertices.isEmpty) continue;

      // Chọn màu sắc dựa trên tùy chọn `isMultiColor` và chỉ số cột.
      final int colIdx = columnMapping[result] ?? 0;
      final Color baseColor = isMultiColor
          ? colorPalette[colIdx % colorPalette.length]
          : boxColor;

      // Ánh xạ tọa độ các đỉnh từ không gian ảnh gốc sang không gian màn hình.
      final scaledVertices = result.rotatedVertices.map((vertex) {
        return Offset(
          vertex.dx * scale + offsetX,
          vertex.dy * scale + offsetY,
        );
      }).toList();

      // Tính kích thước cạnh ngắn hơn của hộp để điều chỉnh động độ dày nét vẽ, cỡ chữ.
      final double side1 = (scaledVertices[1] - scaledVertices[0]).distance;
      final double side2 = (scaledVertices[2] - scaledVertices[1]).distance;
      final double smallerSide = min(side1, side2);

      // Độ dày viền tự động điều chỉnh theo kích thước hộp, có giới hạn min/max.
      final double dynamicStrokeWidth = (smallerSide * 0.05).clamp(0.5, 3.0);

      // Tạo một Path khép kín từ các đỉnh đã được scale.
      final path = Path()
        ..moveTo(scaledVertices[0].dx, scaledVertices[0].dy);
      for (int i = 1; i < scaledVertices.length; i++) {
        path.lineTo(scaledVertices[i].dx, scaledVertices[i].dy);
      }
      path.close();

      // 2. TÔ MÀU NỀN
      if (showFillBox) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = baseColor.withOpacity(fillOpacity);
        canvas.drawPath(path, fillPaint);
      }

      // 3. VẼ KHUNG VIỀN (NỔI BẬT CÁC GÓC)
      if (showBoundingBoxes) {
        // Vẽ một đường viền mỏng, hơi mờ làm nền.
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dynamicStrokeWidth
          ..color = baseColor.withOpacity(0.7);

        // Chuẩn bị paint để vẽ các góc dày, nổi bật hơn.
        // StrokeJoin.round giúp loại bỏ các "khe hở" ở các điểm nối,
        // tạo ra góc được bo tròn mềm mại.
        final cornerPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dynamicStrokeWidth * 1.75 // Góc dày hơn viền.
          ..color = Colors.white70
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.round;

        // Vẽ toàn bộ đường viền mỏng trước.
        canvas.drawPath(path, edgePaint);

        // Sau đó, vẽ 4 góc dày đè lên.
        final double cornerPercentage = 0.25; // Độ dài của mỗi cạnh góc bằng 25% cạnh ngắn hơn.
        final double maxCornerLength = 20.0; // Giới hạn độ dài tối đa của góc.

        for (int i = 0; i < scaledVertices.length; i++) {
          final Offset pCurrent = scaledVertices[i];
          final Offset pPrev = scaledVertices[(i - 1 + scaledVertices.length) % scaledVertices.length];
          final Offset pNext = scaledVertices[(i + 1) % scaledVertices.length];

          // Tính toán các vector từ đỉnh hiện tại đến đỉnh trước và sau.
          final Offset vPrev = pPrev - pCurrent;
          final Offset vNext = pNext - pCurrent;

          if (vPrev.distance > 0 && vNext.distance > 0) {
            double cornerLength = min(vPrev.distance, vNext.distance) * cornerPercentage;
            cornerLength = min(cornerLength, maxCornerLength);

            // Tính 2 điểm cuối của góc hình chữ L.
            final Offset point1 = pCurrent + (vPrev / vPrev.distance) * cornerLength;
            final Offset point2 = pCurrent + (vNext / vNext.distance) * cornerLength;

            // Vẽ một Path hình chữ L (point1 -> pCurrent -> point2).
            // Việc này cho phép thuộc tính StrokeJoin.round hoạt động hiệu quả.
            final cornerPath = Path()
              ..moveTo(point1.dx, point1.dy)
              ..lineTo(pCurrent.dx, pCurrent.dy)
              ..lineTo(point2.dx, point2.dy);
            canvas.drawPath(cornerPath, cornerPaint);
          }
        }
      }

      // 4. VẼ NHÃN ĐỘ TIN CẬY
      if (showConfidence) {
        final double dynamicFontSize = (smallerSide * 0.15).clamp(7.0, 12.0);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${(result.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: Colors.white, fontSize: dynamicFontSize, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // Vẽ một hộp nền phía sau chữ để tăng độ tương phản.
        final labelPos = scaledVertices[0]; // Đặt nhãn ở đỉnh đầu tiên.
        final padding = dynamicFontSize * 0.3;
        final RRect labelBackground = RRect.fromRectAndRadius(
          Rect.fromLTRB(labelPos.dx, labelPos.dy - textPainter.height - padding, labelPos.dx + textPainter.width + (padding * 2), labelPos.dy),
          Radius.circular(padding),
        );

        canvas.drawRRect(labelBackground, Paint()..color = baseColor.withAlpha(230));
        textPainter.paint(canvas, Offset(labelPos.dx + padding, labelPos.dy - textPainter.height - (padding / 2)));
      }

      // 5. VẼ SỐ THỨ TỰ Ở TÂM
      if (showOrderNumber) {
        // Tính tọa độ tâm của hộp bằng cách lấy trung bình cộng tọa độ các đỉnh.
        double centerX = scaledVertices.map((v) => v.dx).reduce((a, b) => a + b) / scaledVertices.length;
        double centerY = scaledVertices.map((v) => v.dy).reduce((a, b) => a + b) / scaledVertices.length;

        final double circleRadius = min(smallerSide * 0.35, 15.0);
        final double fontSize = circleRadius * 1.1;

        // Vẽ vòng tròn nền cho số thứ tự.
        canvas.drawCircle(
          Offset(centerX, centerY),
          circleRadius,
          Paint()..color = baseColor.withAlpha(200),
        );

        // Vẽ số thứ tự (index + 1)
        final orderPainter = TextPainter(
          text: TextSpan(
            text: '${index + 1}',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // Căn chỉnh chữ vào chính giữa vòng tròn.
        final Offset textOffset = Offset(centerX - (orderPainter.width / 2), centerY - (orderPainter.height / 2));
        orderPainter.paint(canvas, textOffset);
      }
    }
    canvas.restore(); // Khôi phục lại trạng thái canvas (bỏ clipRect).
  }

  @override
  /// Quyết định xem có cần vẽ lại widget hay không.
  ///
  /// Phương thức này so sánh các thuộc tính của delegate cũ và mới. Nếu bất kỳ
  /// thuộc tính nào thay đổi, nó sẽ trả về `true` để kích hoạt một lần vẽ lại,
  /// giúp tối ưu hóa hiệu năng bằng cách tránh các lần vẽ lại không cần thiết.
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.results != results ||
        oldDelegate.showFillBox != showFillBox ||
        oldDelegate.showOrderNumber != showOrderNumber ||
        oldDelegate.showBoundingBoxes != showBoundingBoxes ||
        oldDelegate.showConfidence != showConfidence ||
        oldDelegate.screenImageSize != screenImageSize ||
        oldDelegate.originalImageSize != originalImageSize ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.boxColor != boxColor ||
        oldDelegate.isMultiColor != isMultiColor;
  }
}
