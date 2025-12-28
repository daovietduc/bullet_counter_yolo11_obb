import 'package:shared_preferences/shared_preferences.dart';

/// 1. LỚP DỮ LIỆU CHẾ ĐỘ ĐẾM (MODEL CLASS)
/// Đại diện cho đối tượng vật thể mà người dùng chọn để AI nhận diện.
class SelectedMode {
  final int targetClass; // ID của lớp vật thể (Ví dụ: 0 cho Máy bay, 1 cho Tàu thuyền)
  final String name;      // Tên hiển thị trên giao diện (Ví dụ: "Đếm Máy Bay")
  final String image;     // Đường dẫn icon hoặc hình ảnh minh họa cho chế độ đó

  SelectedMode({required this.targetClass, required this.name, required this.image});
}

/// 2. LỚP TÙY CHỌN HIỂN THỊ (MODEL CLASS)
/// Lưu trữ các cài đặt về việc bật/tắt các thành phần đồ họa trên màn hình kết quả.
class DisplayPreferences {
  final bool showBoundingBoxes; // Có vẽ khung bao quanh vật thể hay không
  final bool showConfidence;    // Có hiện chỉ số % tin cậy của AI hay không
  final bool showFillBox;      // Có tô màu cho bounding box hay không
  final bool showOrderNumber;    // Có hiển thị số thứ tự của bounding box hay không

  DisplayPreferences({
    this.showBoundingBoxes = true,
    this.showConfidence = true,
    this.showFillBox = false,
    this.showOrderNumber = false,
  });
}

/// 3. DỊCH VỤ QUẢN LÝ TÙY CHỌN (SERVICE CLASS)
/// Sử dụng thư viện 'SharedPreferences' để lưu dữ liệu dưới dạng Key-Value vào bộ nhớ máy.
/// Giúp ứng dụng "ghi nhớ" cài đặt của người dùng kể cả khi đã tắt app hoàn toàn.
class PreferencesService {
  // Định nghĩa các "Khóa" (Keys) cố định để tránh sai sót khi truy xuất dữ liệu
  static const String _selectedTargetClassKey = 'selectedTargetClass';
  static const String _selectedModeNameKey = 'selectedModeName';
  static const String _selectedModeImageKey = 'selectedModeImage';
  static const String _showBoundingBoxesKey = 'showBoundingBoxes';
  static const String _showConfidenceKey = 'showConfidence';
  static const String _showFillBoxKey = 'showFillBox';
  static const String _showOrderNumberKey = 'showOrderNumber';

  // --------------------------------------------------------------------------
  // QUẢN LÝ CHẾ ĐỘ ĐẾM (SELECTED MODE)
  // --------------------------------------------------------------------------

  /// Ghi dữ liệu chế độ đếm xuống bộ nhớ điện thoại
  Future<void> saveSelectedMode(SelectedMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences chỉ lưu được kiểu dữ liệu cơ bản (int, String, bool)
    // nên ta cần bóc tách đối tượng SelectedMode ra từng phần để lưu.
    await prefs.setInt(_selectedTargetClassKey, mode.targetClass);
    await prefs.setString(_selectedModeNameKey, mode.name);
    await prefs.setString(_selectedModeImageKey, mode.image);
  }

  /// Đọc chế độ đếm đã lưu từ lần sử dụng trước
  Future<SelectedMode?> loadSelectedMode() async {
    final prefs = await SharedPreferences.getInstance();

    // Kiểm tra xem đã từng có dữ liệu được lưu hay chưa dựa trên khóa TargetClass
    if (prefs.containsKey(_selectedTargetClassKey)) {
      final targetClass = prefs.getInt(_selectedTargetClassKey);
      // Sử dụng toán tử ?? để gán giá trị mặc định nếu dữ liệu trả về bị null (Null-safety)
      final name = prefs.getString(_selectedModeNameKey) ?? 'Mode';
      final image = prefs.getString(_selectedModeImageKey) ?? '';

      if(targetClass != null){
        return SelectedMode(targetClass: targetClass, name: name, image: image);
      }
    }
    return null; // Trả về null nếu đây là lần đầu tiên mở app và chưa chọn chế độ nào
  }

  // --------------------------------------------------------------------------
  // QUẢN LÝ TÙY CHỌN HIỂN THỊ (DISPLAY SETTINGS)
  // --------------------------------------------------------------------------

  /// Lưu trạng thái Bật/Tắt của Bounding Box và Confidence
  Future<void> saveDisplayPreferences({
    required bool showBoundingBoxes,
    required bool showConfidence,
    required bool showFillBox,
    required bool showOrderNumber,
  }) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setBool(_showBoundingBoxesKey, showBoundingBoxes);
    await instance.setBool(_showConfidenceKey, showConfidence);
    await instance.setBool(_showFillBoxKey, showFillBox);
    await instance.setBool(_showOrderNumberKey, showOrderNumber);
  }

  /// Tải các cài đặt hiển thị
  Future<DisplayPreferences> loadDisplayPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Nếu người dùng chưa bao giờ cài đặt, mặc định sẽ hiển thị cả hai (true)
    final showBoxes = prefs.getBool(_showBoundingBoxesKey) ?? true;
    final showConfidence = prefs.getBool(_showConfidenceKey) ?? true;
    final showFillBox = prefs.getBool(_showFillBoxKey) ?? false;
    final showOrderNumber = prefs.getBool(_showOrderNumberKey) ?? false;

    return DisplayPreferences(
      showBoundingBoxes: showBoxes,
      showConfidence: showConfidence,
      showFillBox: showFillBox,
      showOrderNumber: showOrderNumber,
    );
  }
}