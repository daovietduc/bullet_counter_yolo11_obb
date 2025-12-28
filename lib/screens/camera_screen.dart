import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../widgets/bottom_toolbar.dart';
import '../helpers/ui_helpers.dart';

/// MÀN HÌNH CAMERA CHÍNH
/// Đây là giao diện cho phép người dùng xem luồng video trực tiếp và thực hiện chụp ảnh.
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera,});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {

  @override
  void initState() {
    super.initState();
    // KHỞI TẠO CAMERA:
    // Gọi thông qua Provider để CameraService quản lý vòng đời của Controller.
    // Dùng listen: false vì trong initState không được phép rebuild widget.
    Provider.of<CameraService>(context, listen: false).initialize();
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
            fontFamily: 'UTM_HelvetIns', // Font chữ đặc trưng của ứng dụng
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
        children: [
          // Màn hình camera preview
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

          // Thêm viền cho camera (overlay)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.amber, // xám đậm chuyên nghiệp
                    width: 2, // 1–2px là đẹp nhất
                  ),
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomToolbar(), // Widget tách rời để code gọn gàng hơn
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