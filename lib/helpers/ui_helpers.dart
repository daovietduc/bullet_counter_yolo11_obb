import 'dart:ui';
import 'package:flutter/material.dart';

class UIHelper {
  /// 1. HIỂN THỊ LOADING (FULL SCREEN BLUR ANIMATION)
  /// Hiển thị một hộp thoại loading với hiệu ứng mờ dần tăng dần theo thời gian.
  static void showLoadingIndicator(BuildContext context, {String message = ''}) {
    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black12,
      // Tăng thời gian lên để thấy rõ hiệu ứng mờ dần
      transitionDuration: const Duration(milliseconds: 300),

      transitionBuilder: (context, anim1, anim2, child) {
        // Làm mờ dần toàn bộ nội dung (bao gồm cả chữ và icon)
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },

      pageBuilder: (context, animation, secondaryAnimation) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // LỚP 1: HIỆU ỨNG LÀM MỜ TĂNG DẦN (ANIMATED BLUR)
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // Giá trị sigma chạy từ 0 đến 3 theo tiến trình của animation
                    double sigmaValue = animation.value * 3;
                    return Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: sigmaValue,
                          sigmaY: sigmaValue,
                        ),
                        child: Container(
                          // Độ đậm của lớp phủ đen cũng tăng dần
                          color: Colors.black.withOpacity(animation.value * 0.2),
                        ),
                      ),
                    );
                  },
                ),

                // LỚP 2: NỘI DUNG VĂN BẢN
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bạn có thể thêm CircularProgressIndicator ở đây nếu muốn
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Lexend',
                            letterSpacing: 3.0,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(
                                blurRadius: 15.0,
                                color: Colors.black,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // Hàm private dùng chung
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