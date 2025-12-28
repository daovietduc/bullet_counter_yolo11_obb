import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../screens/counting_screen.dart';

/// CAMERA SERVICE: Quản lý logic điều khiển Camera bằng Provider (ChangeNotifier)
/// Lớp này tách biệt logic phần cứng ra khỏi giao diện (UI), giúp code dễ bảo trì và mở rộng.
class CameraService extends ChangeNotifier {

  // --------------------------------------------------------------------------
  // 1. KHAI BÁO BIẾN (STATE MANAGEMENT)
  // --------------------------------------------------------------------------

  /// Biến trung tâm điều khiển mọi hoạt động của Camera (xem trước, chụp, flash...)
  late CameraController _cameraController;

  /// Future dùng để theo dõi trạng thái khởi tạo phần cứng
  late Future<void> initializeControllerFuture;

  /// Lưu trữ danh sách các camera khả dụng trên thiết bị (trước, sau, góc rộng...)
  List<CameraDescription> _cameras = [];

  /// Chỉ số camera đang sử dụng (mặc định là 0 - thường là camera sau)
  int _selectedCameraIndex = 0;

  /// Quản lý trạng thái đèn Flash (Off, Always, Auto, Torch)
  FlashMode _currentFlashMode = FlashMode.off;

  /// Biến cờ (Flag) giúp UI biết khi nào đã có thể hiển thị luồng CameraPreview
  bool _isInitialized = false;

  // --------------------------------------------------------------------------
  // 2. GETTERS: Cung cấp dữ liệu ra bên ngoài (chỉ đọc)
  // --------------------------------------------------------------------------

  CameraController get controller => _cameraController;
  FlashMode get currentFlashMode => _currentFlashMode;
  bool get isInitialized => _isInitialized;

  // --------------------------------------------------------------------------
  // 3. KHỞI TẠO CAMERA (INITIALIZATION)
  // --------------------------------------------------------------------------

  /// Phương thức này thiết lập kết nối với phần cứng camera
  Future<void> initialize() async {
    try {
      // Bước A: Lấy danh sách các camera có sẵn trên điện thoại
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print("Thông báo: Không tìm thấy camera nào trên thiết bị.");
        return;
      }

      // Bước B: Khởi tạo Controller với độ phân giải cao (High)
      // ResolutionPreset.high: Thường là 1080p, phù hợp cho AI nhận diện vật thể nhỏ.
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false, // Tắt âm thanh để giảm tải tài nguyên vì chỉ cần chụp ảnh
      );

      // Bước C: Chạy lệnh khởi tạo và chờ phần cứng phản hồi
      initializeControllerFuture = _cameraController.initialize();
      await initializeControllerFuture;

      // Bước D: Thiết lập các thông số mặc định sau khi khởi tạo thành công
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto); // Tự động lấy nét

      _isInitialized = true;

      // Quan trọng: Thông báo cho UI (CameraScreen) để ẩn vòng quay Loading và hiển thị Camera
      notifyListeners();
    } catch (e) {
      print("Lỗi nghiêm trọng khi khởi tạo Camera: $e");
    }
  }

  // --------------------------------------------------------------------------
  // 4. CHỤP ẢNH VÀ ĐIỀU HƯỚNG (CAPTURE & NAVIGATE)
  // --------------------------------------------------------------------------

  /// Thực hiện chụp ảnh, lưu tạm thời và chuyển sang màn hình xử lý đếm vật thể
  Future<void> takePictureAndNavigate(BuildContext context) async {
    // Kiểm tra an toàn: Nếu camera chưa sẵn sàng mà nhấn chụp sẽ gây crash
    if (!isInitialized) return;

    try {
      // Bước A: Chụp ảnh. File được lưu vào thư mục tạm (Cache) của ứng dụng
      final XFile imageFile = await _cameraController.takePicture();

      // Bước B: Kiểm tra Widget còn nằm trong cây thư mục không (tránh lỗi context)
      if (!context.mounted) return;

      // Bước C: Chuyển sang màn hình CountingScreen.
      // Chúng ta truyền path (đường dẫn file) thay vì truyền cả file để tiết kiệm bộ nhớ.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(imagePath: imageFile.path),
        ),
      );
    } catch (e) {
      print('Lỗi trong quá trình chụp ảnh/điều hướng: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 5. ĐIỀU KHIỂN ĐÈN FLASH (FLASH CONTROL)
  // --------------------------------------------------------------------------

  /// Chuyển đổi qua lại giữa các chế độ Flash: Tắt -> Luôn bật -> Tắt
  void toggleFlashMode() async {
    FlashMode newMode;
    if (_currentFlashMode == FlashMode.off) {
      newMode = FlashMode.always; // Bật flash khi chụp
    } else {
      newMode = FlashMode.off;    // Tắt hoàn toàn
    }

    try {
      await _cameraController.setFlashMode(newMode);
      _currentFlashMode = newMode;

      // Cập nhật lại Icon Flash trên màn hình thông qua Provider
      notifyListeners();
    } catch (e) {
      print("Lỗi khi tương tác với phần cứng đèn Flash: $e");
    }
  }

  // --------------------------------------------------------------------------
  // 6. GIẢI PHÓNG TÀI NGUYÊN (DISPOSE)
  // --------------------------------------------------------------------------

  @override
  void dispose() {
    // Cực kỳ quan trọng: Phải tắt controller khi không dùng nữa để giải phóng
    // Camera cho các ứng dụng khác (như Facebook, Zalo) và tránh hao pin.
    _cameraController.dispose();
    super.dispose();
  }
}