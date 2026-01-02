import 'dart:ui';
import 'package:flutter/material.dart';

class UIHelper {
  /// 1. HIỂN THỊ LOADING (FULL SCREEN BLUR)
  /// Hiển thị một hộp thoại loading toàn màn hình với hiệu ứng mờ nền.
  static void showLoadingIndicator(BuildContext context, {String message = 'AI IS PROCESSING'}) {
    // Kiểm tra xem widget có còn trên cây widget hay không trước khi hiển thị.
    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false, // Không cho phép đóng bằng cách chạm bên ngoài.
      barrierLabel: '',
      barrierColor: Colors.black12, // Màu nền mờ nhẹ.
      transitionDuration: const Duration(milliseconds: 50), // Thời gian của hiệu ứng chuyển cảnh.

      // --- Hiệu ứng chuyển cảnh xuất hiện ---
      // Builder để tạo hiệu ứng chuyển cảnh (ở đây là mờ dần).
      transitionBuilder: (context, anim1, anim2, child) {
        // Sử dụng FadeTransition để hộp thoại hiện ra một cách mượt mà.
        return FadeTransition(opacity: anim1, child: child);
      },

      // --- Nội dung của hộp thoại ---
      // Builder để tạo nội dung chính của dialog.
      pageBuilder: (context, animation1, animation2) {
        return PopScope(
          canPop: false, // Chặn người dùng nhấn nút back của hệ thống.
          child: Scaffold(
            backgroundColor: Colors.transparent, // Nền trong suốt để thấy hiệu ứng blur.
            body: Stack(
              children: [
                // LỚP 1: HIỆU ỨNG LÀM MỜ (BACKDROP FILTER)
                // Chiếm toàn bộ không gian màn hình.
                Positioned.fill(
                  child: BackdropFilter(
                    // Áp dụng bộ lọc làm mờ cho khu vực phía sau widget này.
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      // Thêm một lớp phủ màu đen mờ để làm nổi bật văn bản.
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                ),

                // LỚP 2: NỘI DUNG VĂN BẢN VÀ ICON
                // Căn giữa nội dung.
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      message.toUpperCase(), // In hoa thông điệp.
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Lexend',
                        letterSpacing: 3.0, // Tăng khoảng cách giữa các ký tự.
                        decoration: TextDecoration.none, // Bỏ gạch chân mặc định.
                        shadows: [
                          // Thêm bóng đổ để chữ dễ đọc hơn trên nền bất kỳ.
                          Shadow(
                            blurRadius: 15.0,
                            color: Colors.black,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 2. ẨN LOADING
  /// Đóng hộp thoại loading đang được hiển thị.
  static void hideLoadingIndicator(BuildContext context) {
    if (context.mounted) {
      // Đóng dialog trên cùng trong cây điều hướng.
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// 3. THÔNG BÁO THÀNH CÔNG
  /// Hiển thị một SnackBar (thông báo nhanh) với màu xanh lá cây.
  static void showSuccessSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green.shade700, Icons.check_circle);
  }

  /// 4. THÔNG BÁO LỖI
  /// Hiển thị một SnackBar màu đỏ để báo lỗi.
  static void showErrorSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red.shade800, Icons.error_outline, duration: 3);
  }

  /// 5. THÔNG BÁO BẢO TRÌ
  /// Hiển thị một SnackBar màu cam cho các tính năng đang phát triển.
  static void showMaintenanceSnackBar(BuildContext context) {
    _showSnackBar(context, 'Tính năng đang phát triển.', Colors.orange.shade800, Icons.engineering);
  }

  // Hàm private dùng chung để hiển thị các loại SnackBar.
  static void _showSnackBar(BuildContext context, String message, Color bg, IconData icon, {int duration = 2}) {
    if (!context.mounted) return;
    // Ẩn SnackBar hiện tại (nếu có) trước khi hiển thị cái mới.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white), // Icon ở đầu.
            const SizedBox(width: 10),
            // Dùng Expanded để văn bản tự động xuống dòng nếu quá dài.
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: bg, // Màu nền của SnackBar.
        behavior: SnackBarBehavior.floating, // Kiểu hiển thị "nổi" trên màn hình.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Bo góc.
        duration: Duration(seconds: duration), // Thời gian tự động ẩn.
      ),
    );
  }
}
