import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/detection_result.dart';

/// LỚP VẼ ĐÈ (OVERLAY): Chịu trách nhiệm "ánh xạ" tọa độ từ ảnh gốc lên màn hình
/// và vẽ các hộp chữ nhật xoay (OBB), tô màu, và đánh số thứ tự.
class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> results;
  final Size originalImageSize;
  final Size screenImageSize;
  final bool showBoundingBoxes;
  final bool showConfidence;
  final bool showFillBox;
  final bool showOrderNumber;

  BoundingBoxPainter({
    required this.results,
    required this.originalImageSize,
    required this.screenImageSize,
    this.showBoundingBoxes = true,
    this.showConfidence = true,
    this.showFillBox = false,
    this.showOrderNumber = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (originalImageSize.width == 0 || originalImageSize.height == 0) return;

    final List<Color> colorPalette = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.purpleAccent,
    ];

    // 1. TÍNH TOÁN TỶ LỆ (SCALE LOGIC)
    final double scaleX = screenImageSize.width / originalImageSize.width;
    final double scaleY = screenImageSize.height / originalImageSize.height;
    final double scale = min(scaleX, scaleY);

    final double offsetX = (screenImageSize.width - originalImageSize.width * scale) / 2;
    final double offsetY = (screenImageSize.height - originalImageSize.height * scale) / 2;

    // Giới hạn vùng vẽ
    final Rect realImageRect = Offset(offsetX, offsetY) & (originalImageSize * scale);
    canvas.save();
    canvas.clipRect(realImageRect);

    for (var entry in results.asMap().entries) {
      final int index = entry.key;
      final DetectionResult result = entry.value;

      if (result.rotatedVertices.isEmpty) continue;

      final Color baseColor = colorPalette[index % colorPalette.length];

      // TÍNH TOÁN CÁC ĐỈNH ĐÃ SCALE (Dùng chung cho cả Vẽ khung, Tô màu và Tìm tâm)
      final scaledVertices = result.rotatedVertices.map((vertex) {
        return Offset(
          vertex.dx * scale + offsetX,
          vertex.dy * scale + offsetY,
        );
      }).toList();

      // Tạo Path (Đường dẫn nối các điểm)
      final path = Path();
      path.moveTo(scaledVertices[0].dx, scaledVertices[0].dy);
      for (int i = 1; i < scaledVertices.length; i++) {
        path.lineTo(scaledVertices[i].dx, scaledVertices[i].dy);
      }
      path.close();

      // ========================================================================
      // 2. TÔ MÀU VÙNG CHỌN (FILL BOX)
      // ========================================================================
      if (showFillBox) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = baseColor.withOpacity(0.6); // Độ trong suốt 20% để nhìn thấy ảnh nền

        canvas.drawPath(path, fillPaint);
      }

      // ========================================================================
      // 3. VẼ KHUNG VIỀN (BORDER)
      // ========================================================================
      if (showBoundingBoxes) {
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 // Tăng độ dày một chút cho rõ
          ..color = baseColor
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(path, borderPaint);
      }

      // ========================================================================
      // 4. VẼ NHÃN (LABEL)
      // ========================================================================
      if (showConfidence) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${(result.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11, // Tăng nhẹ kích thước chữ
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Đặt nhãn tại đỉnh đầu tiên
        final labelPos = scaledVertices[0];

        // Vẽ nền cho nhãn
        final RRect labelBackground = RRect.fromRectAndRadius(
          Rect.fromLTRB(
              labelPos.dx,
              labelPos.dy - textPainter.height - 4,
              labelPos.dx + textPainter.width + 8,
              labelPos.dy
          ),
          const Radius.circular(4),
        );

        canvas.drawRRect(labelBackground, Paint()..color = baseColor.withOpacity(0.9));
        textPainter.paint(canvas, Offset(labelPos.dx + 4, labelPos.dy - textPainter.height - 2));
      }

      // ========================================================================
      // 5. VẼ SỐ THỨ TỰ (ORDER NUMBER) Ở TÂM - TỰ ĐỘNG CO DÃN
      // ========================================================================
      if (showOrderNumber) {
        // Tìm tâm (Centroid) của hình đa giác bằng cách cộng tọa độ 4 đỉnh chia 4
        double centerX = 0;
        double centerY = 0;
        for (var v in scaledVertices) {
          centerX += v.dx;
          centerY += v.dy;
        }
        centerX /= scaledVertices.length;
        centerY /= scaledVertices.length;

        // Tính toán kích thước cạnh ngắn hơn của vật thể để điều chỉnh kích thước số thứ tự.
        // Giả sử các đỉnh được trả về theo thứ tự.
        final double side1 = (scaledVertices[1] - scaledVertices[0]).distance;
        final double side2 = (scaledVertices[2] - scaledVertices[1]).distance;
        final double smallerSide = min(side1, side2);

        // Kích thước của vòng tròn và font chữ sẽ co dãn theo kích thước vật thể.
        // Bán kính vòng tròn là 40% của cạnh ngắn hơn, không có giới hạn dưới nhưng có giới hạn trên.
        final double circleRadius = min(smallerSide * 0.40, 18.0);
        final double fontSize = min(circleRadius * 0.9, 16.0); // Font chữ nhỏ hơn bán kính một chút
        final double strokeWidth = min(circleRadius * 0.12, 2.0);

        // Vẽ hình tròn
        canvas.drawCircle(
            Offset(centerX, centerY),
            circleRadius,
            Paint()..color = Colors.white.withOpacity(0.8), // Màu nền trong suốt
        );

        // Vẽ viền cho hình tròn (màu đỏ)
        canvas.drawCircle(
            Offset(centerX, centerY),
            circleRadius,
            Paint()..style = PaintingStyle.stroke..color = Colors.red..strokeWidth = strokeWidth
        );

        // Vẽ số thứ tự
        final orderPainter = TextPainter(
          text: TextSpan(
            text: '${index + 1}', // Bắt đầu từ 1 thay vì 0
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        orderPainter.layout();

        // Căn giữa số trong hình tròn
        orderPainter.paint(
            canvas,
            Offset(centerX - orderPainter.width / 2, centerY - orderPainter.height / 2)
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    // Cần vẽ lại nếu bất kỳ tham số nào thay đổi
    return oldDelegate.results != results ||
        oldDelegate.showFillBox != showFillBox ||
        oldDelegate.showOrderNumber != showOrderNumber ||
        oldDelegate.showBoundingBoxes != showBoundingBoxes ||
        oldDelegate.showConfidence != showConfidence ||
        oldDelegate.screenImageSize != screenImageSize ||
        oldDelegate.originalImageSize != originalImageSize;
  }
}
