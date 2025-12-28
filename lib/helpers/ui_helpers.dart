import 'dart:ui';
import 'package:flutter/material.dart';

class UIHelper {
  /// 1. HIỂN THỊ LOADING (FULL SCREEN BLUR)
  /// Đã lược bỏ hiệu ứng động để tránh bị lag khi AI chiếm dụng tài nguyên luồng chính.
  static void showLoadingIndicator(BuildContext context, {String message = 'AI IS PROCESSING'}) {
    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black12, // Trong suốt để đồng bộ với FadeTransition
      transitionDuration: const Duration(milliseconds: 50),

      // Hiệu ứng Fade-in mượt mà khi bắt đầu
      // --- Hiệu ứng chuyển cảnh xuất hiện ---
      transitionBuilder: (context, anim1, anim2, child) {
        // FadeTransition giúp màn hình mờ dần vào thay vì xuất hiện đột ngột
        return FadeTransition(opacity: anim1, child: child);
      },

      pageBuilder: (context, animation1, animation2) {
        return PopScope(
          canPop: false, // Ngăn nút Back trong khi AI đang tính toán
          child: Scaffold(
            backgroundColor: Colors.transparent, // Giữ nền trong suốt để thấy lớp Blur
            body: Stack(
              children: [
                // LỚP 1: HIỆU ỨNG LÀM MỜ (BACKDROP FILTER)
                Positioned.fill(
                  child: BackdropFilter(
                    // SigmaX/Y = 8 tạo độ mờ vừa phải, đủ để che chi tiết nhưng vẫn thấy màu sắc nền
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      // Lớp phủ tối nhẹ (20%) giúp chữ trắng nổi bật hơn
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                ),

                // LỚP 2: NỘI DUNG VĂN BẢN
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      message.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Lexend',
                        letterSpacing: 3.0,   // Giãn chữ tạo phong cách kỹ thuật (Futuristic)
                        decoration: TextDecoration.none,
                        shadows: [
                          // Đổ bóng 360 độ xung quanh chữ để đảm bảo đọc được trên mọi nền ảnh
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
  static void hideLoadingIndicator(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// 3. THÔNG BÁO THÀNH CÔNG
  static void showSuccessSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green.shade700, Icons.check_circle);
  }

  /// 4. THÔNG BÁO LỖI
  static void showErrorSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red.shade800, Icons.error_outline, duration: 3);
  }

  /// 5. THÔNG BÁO BẢO TRÌ
  static void showMaintenanceSnackBar(BuildContext context) {
    _showSnackBar(context, 'Tính năng đang phát triển.', Colors.orange.shade800, Icons.engineering);
  }

  // Hàm dùng chung cho SnackBar
  static void _showSnackBar(BuildContext context, String message, Color bg, IconData icon, {int duration = 2}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: duration),
      ),
    );
  }
}