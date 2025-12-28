import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../screens/counting_screen.dart';import '../helpers/ui_helpers.dart';
import '../services/camera_service.dart'; // Đảm bảo đã import CameraService

// --- THAY ĐỔI 1: Chuyển thành StatelessWidget và thêm callback ---
class BottomToolbar extends StatelessWidget {
  /// Callback này sẽ được gọi khi người dùng nhấn nút chụp ảnh.
  /// CameraScreen sẽ cung cấp hàm để thực thi.
  final VoidCallback onTakePhoto;

  const BottomToolbar({super.key, required this.onTakePhoto});

  // Hàm để xử lý việc chọn ảnh từ thư viện
  Future<void> _pickImageFromGallery(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      // Sử dụng picker để mở thư viện ảnh và chờ người dùng chọn
      final XFile? pickedFile =
      await picker.pickImage(source: ImageSource.gallery);

      // Nếu không có context hợp lệ hoặc không có ảnh nào được chọn, hãy thoát ra
      if (!context.mounted || pickedFile == null) return;

      // Nếu người dùng đã chọn ảnh, hãy điều hướng đến CountingScreen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(imagePath: pickedFile.path),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        // Sử dụng UIHelper để hiển thị lỗi nếu có sự cố
        UIHelper.showErrorSnackBar(
            context, 'Không thể mở thư viện ảnh: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Giúp Column chỉ chiếm không gian cần thiết
        children: <Widget>[
          Padding(
            // Thêm padding cho cả 4 phía, và tăng padding dưới để tạo khoảng trống an toàn
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // Đẩy các widget con ra 2 bên
              crossAxisAlignment: CrossAxisAlignment.center,
              // Căn giữa các widget theo chiều dọc
              children: <Widget>[
                _buildAlbumButton(context), // Nút Album bên trái

                _buildCaptureButton(), // Nút chụp ảnh ở giữa

                _buildHistoryButton(context), // Nút History bên phải
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nút Album
  Widget _buildAlbumButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickImageFromGallery(context), // Gọi hàm chọn ảnh khi bấm vào
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Icon(
          Icons.photo_library,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  /// Nút chụp ảnh
  Widget _buildCaptureButton() {
    return GestureDetector(
      // --- THAY ĐỔI 2: Gọi callback onTakePhoto ---
      // Khi nhấn nút, nó sẽ thực thi hàm mà CameraScreen đã truyền vào.
      onTap: onTakePhoto,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          // Vòng ngoài màu trắng
          border: Border.all(
            color: Colors.white,
            width: 4.0,
          ),
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            // Vòng trong màu trắng đặc
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// Nút History
  Widget _buildHistoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        UIHelper.showMaintenanceSnackBar(context);
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.history,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
