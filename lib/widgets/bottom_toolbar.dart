import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../screens/counting_screen.dart';
import '../helpers/ui_helpers.dart';
import '../services/camera_service.dart';

// Đã chuyển thành StatelessWidget để tối ưu và sử dụng callback cho sự kiện.
class BottomToolbar extends StatelessWidget {
  /// Callback được gọi khi người dùng nhấn nút chụp ảnh.
  final VoidCallback onTakePhoto;

  const BottomToolbar({super.key, required this.onTakePhoto});

  /// Mở thư viện và cho phép người dùng chọn một ảnh.
  Future<void> _pickImageFromGallery(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      // Thoát nếu context không còn hợp lệ hoặc người dùng không chọn ảnh.
      if (!context.mounted || pickedFile == null) return;

      // Điều hướng đến màn hình đếm với ảnh đã chọn.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(imagePath: pickedFile.path),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        UIHelper.showErrorSnackBar(context, 'Lỗi mở thư viện: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Chỉ chiếm không gian cần thiết.
        children: <Widget>[
          // Thêm padding để tạo khoảng trống an toàn và cân đối.
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Căn đều các phần tử.
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _buildAlbumButton(context),   // Nút mở thư viện ảnh.
                _buildCaptureButton(),        // Nút chụp ảnh chính.
                _buildHistoryButton(context), // Nút xem lịch sử.
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget cho nút mở thư viện ảnh.
  Widget _buildAlbumButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickImageFromGallery(context),
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

  /// Widget cho nút chụp ảnh.
  Widget _buildCaptureButton() {
    return GestureDetector(
      // Gọi callback onTakePhoto đã được truyền vào từ widget cha.
      onTap: onTakePhoto,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          // Viền ngoài.
          border: Border.all(
            color: Colors.white,
            width: 4.0,
          ),
        ),
        // Vòng tròn trắng bên trong.
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// Widget cho nút lịch sử (hiện đang hiển thị thông báo bảo trì).
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
