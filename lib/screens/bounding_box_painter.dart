import 'dart:math';
import 'package:flutter/material.dart';
import '../models/detection_result.dart';

/// LỚP VẼ ĐÈ (OVERLAY): Chịu trách nhiệm "ánh xạ" tọa độ từ ảnh gốc lên màn hình
/// và vẽ các hộp chữ nhật xoay (OBB), tô màu, và đánh số thứ tự.
class BoundingBoxPainter extends CustomPainter {
  // Dữ liệu đầu vào
  final List<DetectionResult> results; // Danh sách các đối tượng phát hiện được
  final Size originalImageSize;        // Kích thước ảnh gốc (từ model)
  final Size screenImageSize;          // Kích thước widget ảnh trên màn hình (đã thay đổi)

  // Các tùy chọn hiển thị (bật/tắt)
  final bool showBoundingBoxes; // Hiển thị khung viền
  final bool showConfidence;    // Hiển thị độ tin cậy
  final bool showFillBox;       // Tô màu bên trong khung
  final bool showOrderNumber;   // Hiển thị số thứ tự

  // Các tùy chọn tùy chỉnh giao diện
  final double fillOpacity;     // Độ mờ khi tô màu
  final Color boxColor;         // Màu sắc của khung (khi dùng màu đơn)
  final bool isMultiColor;      // Bật/tắt chế độ đa màu sắc

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
    if (originalImageSize.width == 0 || originalImageSize.height == 0) return;

    // Bảng màu để dùng khi bật chế độ `isMultiColor`
    final List<Color> colorPalette = [
      Colors.red, Colors.blue, Colors.green, Colors.cyanAccent, Colors.purple, Colors.orange
    ];

    // 1. TÍNH TOÁN TỶ LỆ & ĐỘ LỆCH: Để "ánh xạ" tọa độ từ ảnh gốc sang màn hình
    final double scaleX = screenImageSize.width / originalImageSize.width;
    final double scaleY = screenImageSize.height / originalImageSize.height;
    final double scale = min(scaleX, scaleY); // Dùng tỷ lệ nhỏ nhất để giữ đúng tỷ lệ ảnh

    // Tính toán khoảng trống (lề) để căn giữa ảnh trên màn hình
    final double offsetX = (screenImageSize.width - originalImageSize.width * scale) / 2;
    final double offsetY = (screenImageSize.height - originalImageSize.height * scale) / 2;

    // Giới hạn vùng vẽ chỉ trong phạm vi của ảnh thật trên màn hình
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offsetX, offsetY, originalImageSize.width * scale, originalImageSize.height * scale));

    // Lặp qua từng kết quả phát hiện để vẽ
    for (var entry in results.asMap().entries) {
      final int index = entry.key;           // Số thứ tự của đối tượng
      final DetectionResult result = entry.value; // Dữ liệu của đối tượng

      if (result.rotatedVertices.isEmpty) continue; // Bỏ qua nếu không có tọa độ đỉnh

      // Chọn màu: Dùng bảng màu nếu `isMultiColor` là true, ngược lại dùng màu đã chọn
      final Color baseColor = isMultiColor
          ? colorPalette[index % colorPalette.length]
          : boxColor;

      // "Ánh xạ" các đỉnh của hộp từ tọa độ ảnh gốc sang tọa độ màn hình
      final scaledVertices = result.rotatedVertices.map((vertex) {
        return Offset(
          vertex.dx * scale + offsetX,
          vertex.dy * scale + offsetY,
        );
      }).toList();

      // Tính toán kích thước cạnh ngắn của hộp để điều chỉnh độ dày/cỡ chữ
      final double side1 = (scaledVertices[1] - scaledVertices[0]).distance;
      final double side2 = (scaledVertices[2] - scaledVertices[1]).distance;
      final double smallerSide = min(side1, side2);

      // Độ dày viền tự động điều chỉnh theo kích thước hộp, có giới hạn min/max
      final double dynamicStrokeWidth = (smallerSide * 0.05).clamp(0.5, 3.0);

      // Tạo một đường dẫn (Path) nối các đỉnh đã được scale
      final path = Path();
      path.moveTo(scaledVertices[0].dx, scaledVertices[0].dy);
      for (int i = 1; i < scaledVertices.length; i++) {
        path.lineTo(scaledVertices[i].dx, scaledVertices[i].dy);
      }
      path.close(); // Đóng đường dẫn để tạo thành hình khép kín

      // 2. TÔ MÀU BÊN TRONG HỘP
      if (showFillBox) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = baseColor.withOpacity(fillOpacity); // Dùng độ mờ đã chọn
        canvas.drawPath(path, fillPaint);
      }

      // 3. VẼ KHUNG VIỀN CỦA HỘP
      if (showBoundingBoxes) {
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dynamicStrokeWidth // Dùng độ dày động
          ..color = baseColor;
        canvas.drawPath(path, borderPaint);
      }

      // 4. VẼ NHÃN ĐỘ TIN CẬY (%)
      if (showConfidence) {
        // Cỡ chữ tự động điều chỉnh theo kích thước hộp
        final double dynamicFontSize = (smallerSide * 0.15).clamp(7.0, 12.0);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${(result.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: Colors.white, fontSize: dynamicFontSize, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Vẽ một hộp nền màu phía sau chữ để dễ đọc hơn
        final labelPos = scaledVertices[0]; // Đặt nhãn ở đỉnh đầu tiên
        final padding = dynamicFontSize * 0.3;
        final RRect labelBackground = RRect.fromRectAndRadius(
          Rect.fromLTRB(labelPos.dx, labelPos.dy - textPainter.height - padding, labelPos.dx + textPainter.width + (padding * 2), labelPos.dy),
          Radius.circular(padding),
        );

        canvas.drawRRect(labelBackground, Paint()..color = baseColor.withAlpha(230));
        // Vẽ chữ lên trên nền
        textPainter.paint(canvas, Offset(labelPos.dx + padding, labelPos.dy - textPainter.height - (padding/2)));
      }

      // 5. VẼ SỐ THỨ TỰ Ở TÂM HỘP
      if (showOrderNumber) {
        // Tìm tọa độ tâm của hộp
        double centerX = 0, centerY = 0;
        for (var v in scaledVertices) {
          centerX += v.dx;
          centerY += v.dy;
        }
        centerX /= scaledVertices.length;
        centerY /= scaledVertices.length;

        // Kích thước vòng tròn và cỡ chữ tự động điều chỉnh theo kích thước hộp
        final double circleRadius = min(smallerSide * 0.35, 15.0);
        final double fontSize = circleRadius * 1.1;

        // Vẽ vòng tròn nền
        canvas.drawCircle(
          Offset(centerX, centerY),
          circleRadius,
          Paint()..color = baseColor.withAlpha(200),
        );

        // Vẽ số thứ tự (index + 1)
        final orderPainter = TextPainter(
          text: TextSpan(
            text: '${index + 1}',
            style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        );
        orderPainter.layout();

        // Căn chữ vào chính giữa vòng tròn
        final Offset textOffset = Offset(centerX - (orderPainter.width / 2), centerY - (orderPainter.height / 2));
        orderPainter.paint(canvas, textOffset);
      }
    }
    canvas.restore(); // Khôi phục lại trạng thái canvas (bỏ clipRect)
  }

  @override
  // Phương thức này quyết định xem có cần vẽ lại widget hay không.
  // Nó sẽ trả về `true` (vẽ lại) nếu bất kỳ thuộc tính nào thay đổi so với lần vẽ trước.
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
