import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../screens/counting_screen.dart';

/// Service quản lý Camera.
/// Tách biệt logic điều khiển camera khỏi UI, sử dụng ChangeNotifier để cập nhật trạng thái.
class CameraService extends ChangeNotifier {

  // 1. STATE

  /// Controller chính cho mọi tương tác với camera.
  late CameraController _cameraController;

  /// Future để theo dõi quá trình khởi tạo camera.
  late Future<void> initializeControllerFuture;

  /// Danh sách camera có sẵn trên thiết bị.
  List<CameraDescription> _cameras = [];

  /// Index của camera đang được chọn (mặc định là 0 - camera sau).
  int _selectedCameraIndex = 0;

  /// Chế độ flash hiện tại (off, always, auto, torch).
  FlashMode _currentFlashMode = FlashMode.off;

  /// Cờ báo hiệu camera đã sẵn sàng hiển thị preview.
  bool _isInitialized = false;

  // 2. GETTERS

  CameraController get controller => _cameraController;
  FlashMode get currentFlashMode => _currentFlashMode;
  bool get isInitialized => _isInitialized;

  // 3. INITIALIZATION

  /// Khởi tạo và kết nối tới phần cứng camera.
  Future<void> initialize() async {
    try {
      // Lấy danh sách camera có sẵn.
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print("Error: No cameras found on this device.");
        return;
      }

      // Khởi tạo controller với camera được chọn và độ phân giải cao.
      // Tắt audio vì không cần thiết cho việc chụp ảnh.
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      // Bắt đầu quá trình khởi tạo và đợi hoàn tất.
      initializeControllerFuture = _cameraController.initialize();
      await initializeControllerFuture;

      // Cấu hình các chế độ mặc định sau khi khởi tạo thành công.
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto);

      _isInitialized = true;

      // Thông báo cho các widget listener (UI) để cập nhật.
      notifyListeners();
    } catch (e) {
      print("Fatal error initializing camera: $e");
    }
  }

  // 4. ACTIONS

  /// Chụp ảnh và điều hướng tới màn hình xử lý.
  Future<void> takePictureAndNavigate(BuildContext context) async {
    // Đảm bảo camera đã sẵn sàng trước khi chụp.
    if (!isInitialized) return;

    try {
      // Chụp ảnh và lấy file.
      final XFile imageFile = await _cameraController.takePicture();

      // Tránh lỗi khi widget không còn trong cây (context is not mounted).
      if (!context.mounted) return;

      // Điều hướng sang CountingScreen, truyền đường dẫn ảnh để tiết kiệm bộ nhớ.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(imagePath: imageFile.path),
        ),
      );
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  /// Chuyển đổi giữa các chế độ flash (Off <-> Always).
  void toggleFlashMode() async {
    // Xác định chế độ mới.
    final newMode = _currentFlashMode == FlashMode.off ? FlashMode.always : FlashMode.off;

    try {
      await _cameraController.setFlashMode(newMode);
      _currentFlashMode = newMode;

      // Cập nhật UI.
      notifyListeners();
    } catch (e) {
      print("Error setting flash mode: $e");
    }
  }

  // 5. LIFECYCLE

  @override
  void dispose() {
    // Quan trọng: Giải phóng controller để camera có thể được sử dụng bởi
    // các ứng dụng khác và tránh rò rỉ bộ nhớ, hao pin.
    _cameraController.dispose();
    super.dispose();
  }
}
