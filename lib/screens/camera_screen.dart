import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // Import để sử dụng Timer

import '../services/camera_service.dart';
import '../widgets/bottom_toolbar.dart';
import '../helpers/ui_helpers.dart';

/// MÀN HÌNH CAMERA CHÍNH
/// Đây là giao diện cho phép người dùng xem luồng video trực tiếp và thực hiện chụp ảnh.
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Biến trạng thái để điều khiển hiệu ứng flash khi chụp ảnh
  bool _showFlashEffect = false;

  @override
  void initState() {
    super.initState();
    // KHỞI TẠO CAMERA:
    // Gọi thông qua Provider để CameraService quản lý vòng đời của Controller.
    // Dùng listen: false vì trong initState không được phép rebuild widget.
    Provider.of<CameraService>(context, listen: false).initialize();
  }

  /// Hàm kích hoạt hiệu ứng "nháy" màn hình.
  void _triggerFlashEffect() {
    if (!mounted) return;
    // 1. Bật lớp phủ màu trắng ngay lập tức
    setState(() {
      _showFlashEffect = true;
    });
    // 2. Sau một khoảng thời gian rất ngắn, tắt nó đi để AnimatedOpacity tạo hiệu ứng mờ dần
    Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _showFlashEffect = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe sự thay đổi trạng thái từ CameraService (VD: khi khởi tạo xong, khi đổi flash)
    final cameraService = Provider.of<CameraService>(context);

    // TRẠNG THÁI CHỜ:
    // Hiển thị vòng xoay tải nếu Camera chưa sẵn sàng.
    if (!cameraService.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      /// 1. THANH CÔNG CỤ PHÍA TRÊN (APPBAR)
      appBar: AppBar(
        // ĐIỀU KHIỂN FLASH:
        // Biểu tượng thay đổi dựa trên trạng thái hiện tại (On/Off/Auto).
        leading: IconButton(
          icon: Icon(
            cameraService.currentFlashMode == FlashMode.off
                ? Icons.flash_off
                : Icons.flash_on,
            color: cameraService.currentFlashMode == FlashMode.off
                ? Colors.white
                : Colors.yellow,
          ),
          onPressed: () {
            cameraService.toggleFlashMode();
          },
        ),
        title: const Text(
          'BULLET COUNTER',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'UTM_Helvet', // Font chữ đặc trưng của ứng dụng
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: <Widget>[
          // TÙY CHỈNH TỶ LỆ KHUNG HÌNH (Đang bảo trì)
          IconButton(
            icon: const Icon(Icons.aspect_ratio, color: Colors.white),
            onPressed: () {
              UIHelper.showMaintenanceSnackBar(context);
            },
          ),
        ],
        backgroundColor: Colors.black,
        centerTitle: true,
      ),

      /// 2. KHU VỰC XEM TRƯỚC (CAMERA PREVIEW)
      /// Sử dụng FittedBox kết hợp với BoxFit.cover để luồng video chiếm toàn màn hình
      /// mà không bị biến dạng tỷ lệ hình ảnh.
      body: Stack(
        fit: StackFit.expand, // Đảm bảo Stack chiếm toàn bộ không gian body
        children: [
          // LỚP 1: Màn hình camera preview
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // Lưu ý: PreviewSize thường bị ngược Width/Height
                width: cameraService.controller.value.previewSize!.height,
                height: cameraService.controller.value.previewSize!.width,
                child: CameraPreview(cameraService.controller),
              ),
            ),
          ),

          // LỚP 2: Viền cho camera (overlay)
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                // Padding nhẹ để các góc không dính sát mép ảnh quá
                padding: const EdgeInsets.all(2),
                child: CustomPaint(
                  painter: CornersPainter(color: Colors.white70),
                ),
              ),
            ),
          ),

          // LỚP 3: HIỆU ỨNG FLASH KHI CHỤP ẢNH
          // Lớp này nằm trên cùng để che phủ mọi thứ khác khi được kích hoạt
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showFlashEffect ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150), // Thời gian mờ dần
              curve: Curves.easeOut,
              child: IgnorePointer(
                child: Container(
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),

      /// 3. THANH CÔNG CỤ PHÍA DƯỚI (BOTTOM BAR)
      /// Chứa nút chụp ảnh, nút thư viện và chuyển đổi camera.
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Truyền một hàm callback vào BottomToolbar
            BottomToolbar(
              onTakePhoto: () {
                // Khi nút chụp được nhấn, hàm callback này sẽ được gọi
                // 1. Kích hoạt hiệu ứng "nháy" màn hình
                _triggerFlashEffect();

                // 2. Thực hiện hành động chụp ảnh
                Provider.of<CameraService>(context, listen: false)
                    .takePictureAndNavigate(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// HÀM HIỂN THỊ THÔNG BÁO LỖI/BẢO TRÌ
  /// Dùng SnackBar để phản hồi nhanh cho người dùng mà không làm gián đoạn trải nghiệm.
  void _showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Text('Chức năng đang bảo trì.'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Lớp CornersPainter: Sử dụng CustomPainter để vẽ 4 góc khung ngắm camera
class CornersPainter extends CustomPainter {
  final Color color;

  CornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Chiều dài mỗi góc = 1/5 chiều rộng màn hình
    final double dynamicLength = size.width / 5;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();

    // --- Góc trên bên trái ---
    path.moveTo(0, dynamicLength);
    path.lineTo(0, 0);
    path.lineTo(dynamicLength, 0);

    // --- Góc trên bên phải ---
    path.moveTo(size.width - dynamicLength, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, dynamicLength);

    // --- Góc dưới bên trái ---
    path.moveTo(0, size.height - dynamicLength);
    path.lineTo(0, size.height);
    path.lineTo(dynamicLength, size.height);

    // --- Góc dưới bên phải ---
    path.moveTo(size.width - dynamicLength, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, size.height - dynamicLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}