import 'dart:ui'; // Thư viện cấp thấp để xử lý ImageFilter (làm mờ pixel)
import 'package:flutter/material.dart'; // Thư viện giao diện Material Design

/// LỚP TIỆN ÍCH UI (UI HELPER): Quản lý tập trung các thông báo và trạng thái chờ.
/// Việc gom các hàm này vào một lớp tĩnh (static) giúp mã nguồn sạch sẽ và dễ bảo trì.
class UIHelper {

  /// --------------------------------------------------------------------------
  /// 1. HIỂN THỊ LOADING (FULL SCREEN BLUR)
  /// Hiển thị một lớp phủ mờ toàn màn hình để khóa tương tác khi AI đang tính toán.
  /// --------------------------------------------------------------------------
  static void showLoadingIndicator(BuildContext context, {String message = 'Đang xử lý...'}) {
    // Kiểm tra nếu context không còn tồn tại (màn hình đã đóng) thì thoát ngay
    if (!context.mounted) return;

    // Sử dụng showGeneralDialog thay vì showDialog thông thường
    // để có toàn quyền kiểm soát kích thước và hiệu ứng phủ kín màn hình.
    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Ngăn người dùng đóng loading bằng cách chạm ra ngoài
      barrierLabel: '',
      // Màu nền tối bao phủ bên dưới lớp mờ (tạo độ sâu cho giao diện)
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 200), // Tốc độ xuất hiện (0.2 giây)
      pageBuilder: (context, animation1, animation2) {

        // PopScope: "Lớp giáp" ngăn chặn nút quay lại (Back) vật lý trên Android
        // giúp bảo vệ quá trình đếm của AI không bị ngắt quãng giữa chừng.
        return PopScope(
          canPop: false, // Tuyệt đối không cho thoát khi chưa xử lý xong
          child: Scaffold(
            // Scaffold trong suốt làm nền tảng cho hiệu ứng làm mờ
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // LỚP 1: HIỆU ỨNG LÀM MỜ (BACKDROP FILTER)
                // Positioned.fill ép lớp mờ giãn ra 100% diện tích màn hình điện thoại.

                Positioned.fill(
                  child: BackdropFilter(
                    // Sigma càng cao ảnh càng mờ. X=8, Y=8 tạo hiệu ứng "kính mờ" (Frosted Glass)
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: Colors.transparent),
                  ),
                ),

                // LỚP 2: NỘI DUNG TRUNG TÂM (INDICATOR & TEXT)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Thu gọn kích thước theo nội dung
                    children: [
                      // Vòng xoay tiến trình màu vàng hổ phách (Amber)
                      /*const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        strokeWidth: 5, // Độ dày của vòng xoay
                      ),
                      const SizedBox(height: 25), // Khoảng cách giữa vòng xoay và chữ*/

                      // Thông điệp trạng thái (Ví dụ: "AI đang đếm...")
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0, // Giãn cách chữ giúp dễ đọc hơn trên nền mờ
                          decoration: TextDecoration.none, // Xóa gạch chân lỗi của Dialog
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// --------------------------------------------------------------------------
  /// 2. ẨN LOADING
  /// Đóng cửa sổ chờ ngay khi AI trả về kết quả hoặc có lỗi xảy ra.
  /// --------------------------------------------------------------------------
  static void hideLoadingIndicator(BuildContext context) {
    if (context.mounted) {
      // Sử dụng rootNavigator: true để đảm bảo Navigator tìm đúng lớp Dialog
      // nằm ở trên cùng của ứng dụng để đóng lại.
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// --------------------------------------------------------------------------
  /// 3. THÔNG BÁO THÀNH CÔNG (SUCCESS SNACKBAR)
  /// Hiển thị thanh thông báo nổi màu xanh lá khi lưu ảnh hoặc đếm hoàn tất.
  /// --------------------------------------------------------------------------
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    // Tắt các thông báo cũ đang hiện để tránh chồng chéo (Queue)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white), // Biểu tượng tích xanh
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade700, // Màu xanh lá tin cậy
        behavior: SnackBarBehavior.floating, // Hiển thị dạng hộp nổi (không bám đáy)
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Bo góc
        duration: const Duration(seconds: 2), // Tự biến mất sau 2 giây
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// 4. THÔNG BÁO LỖI (ERROR SNACKBAR)
  /// Dùng khi AI không load được model hoặc bộ nhớ đầy không lưu được ảnh.
  /// --------------------------------------------------------------------------
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white), // Biểu tượng cảnh báo
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red.shade800, // Màu đỏ cảnh báo
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3), // Lỗi nên hiện lâu hơn một chút (3s)
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// 5. THÔNG BÁO BẢO TRÌ (MAINTENANCE SNACKBAR)
  /// Dùng để thông báo cho các nút bấm chưa được lập trình tính năng.
  /// --------------------------------------------------------------------------
  static void showMaintenanceSnackBar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.engineering, color: Colors.white), // Biểu tượng kỹ sư
            SizedBox(width: 10),
            Text('Chức năng này đang được phát triển.', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.orange.shade800, // Màu cam chú ý
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}