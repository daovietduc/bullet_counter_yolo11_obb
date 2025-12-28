import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../screens/counting_screen.dart';
import '../helpers/ui_helpers.dart';

class BottomToolbar extends StatefulWidget {
  const BottomToolbar({super.key});

  @override
  State<BottomToolbar> createState() => _BottomToolbarState();
}

class _BottomToolbarState extends State<BottomToolbar> {
  final ImagePicker _picker = ImagePicker(); // Khởi tạo ImagePicker

  // Hàm để xử lý việc chọn ảnh từ thư viện
  Future<void> _pickImageFromGallery() async {
    try {
      // Sử dụng picker để mở thư viện ảnh và chờ người dùng chọn
      final XFile? pickedFile =
      await _picker.pickImage(source: ImageSource.gallery);

      // Thêm kiểm tra `mounted` để đảm bảo widget vẫn còn trong cây widget trước khi điều hướng
      if (!mounted || pickedFile == null) return;

      // Nếu người dùng đã chọn ảnh, hãy điều hướng đến CountingScreen và truyền đường dẫn của ảnh qua
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(imagePath: pickedFile.path),
        ),
      );
    } catch (e) {
      if (mounted) {
        // Sử dụng UIHelper để hiển thị lỗi nếu có sự cố khi chọn ảnh
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
                _buildAlbumButton(), // Nút Album bên trái

                _buildCaptureButton(), // Nút chụp ảnh ở giữa

                _buildHistoryButton(), // Nút History bên phải
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nút Album
  Widget _buildAlbumButton() {
    return GestureDetector(
      onTap: _pickImageFromGallery, // Gọi hàm chọn ảnh khi bấm vào
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8.0),
          // image: DecorationImage(image: ...), // Có thể thêm ảnh thumbnail ở đây
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
    final cameraService = Provider.of<CameraService>(context, listen: false);
    return GestureDetector(
      onTap: () async {
        try {
          // Bọc trong try-catch để xử lý lỗi nếu có
          await cameraService.takePictureAndNavigate(context);
        } catch (e) {
          if (mounted) {
            UIHelper.showErrorSnackBar(context, 'Chụp ảnh thất bại: $e');
          }
        }
      },
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
  Widget _buildHistoryButton() {
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
