import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

// --- IMPORT CÁC THÀNH PHẦN TRONG DỰ ÁN ---
import '../widgets/mode_selector.dart';
import '../widgets/display_options_menu.dart';
import '../services/counting_service.dart';
import '../services/preferences_service.dart';
import '../models/detection_result.dart';
import '../helpers/ui_helpers.dart';
import './bounding_box_painter.dart';

class CountingScreen extends StatefulWidget {
  final String imagePath; // Đường dẫn file ảnh được truyền từ màn hình trước
  const CountingScreen({super.key, required this.imagePath});

  @override
  State<CountingScreen> createState() => _CountingScreenState();
}

class _CountingScreenState extends State<CountingScreen> {
  // --------------------------------------------------------------------------
  // 1. KHỞI TẠO CÁC BIẾN ĐIỀU KHIỂN (CONTROLLERS)
  // --------------------------------------------------------------------------

  // Điều khiển việc chụp lại vùng ảnh kết quả
  final ScreenshotController _screenshotController = ScreenshotController();

  // Khởi tạo Service xử lý AI
  final CountingService _countingService = CountingService();

  // Khởi tạo Service quản lý cài đặt (Preferences)
  final PreferencesService _prefsService = PreferencesService();

  // --------------------------------------------------------------------------
  // 2. QUẢN LÝ TRẠNG THÁI GIAO DIỆN (UI STATE)
  // --------------------------------------------------------------------------

  bool _showBoundingBoxes = true; // Biến điều khiển việc ẩn/hiện khung bao quanh vật thể
  bool _showConfidence = true;    // Biến điều khiển việc ẩn/hiện phần trăm (%) độ tin cậy
  bool _showFillBox = false;
  bool _showOrderNumber = false;

  List<DetectionResult> _detectionResults = []; // Danh sách lưu các vật thể AI đã tìm thấy
  bool _isCounting = false; // Biến cờ: Bằng True khi AI đang chạy để khóa các thao tác khác

  ui.Image? _originalImage; // Lưu đối tượng ảnh gốc để lấy Width/Height chính xác (đơn vị pixel)
  SelectedMode? _selectedMode; // Lưu chế độ đếm hiện tại (Ví dụ: Class 0 - Máy bay)

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Tự động nạp cài đặt hiển thị khi vừa mở màn hình
    _loadImage();       // Giải mã file ảnh để lấy thông số kích thước thực
  }

  @override
  void dispose() {
    // Giải phóng bộ nhớ của mô hình AI khi thoát màn hình để máy không bị chậm/nóng
    _countingService.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // 3. LOGIC HỖ TRỢ (HELPER LOGIC)
  // --------------------------------------------------------------------------

  /// Nạp các tùy chọn người dùng đã chọn từ bộ nhớ (Shared Preferences)
  Future<void> _loadPreferences() async {
    final loadedMode = await _prefsService.loadSelectedMode();
    final displayPrefs = await _prefsService.loadDisplayPreferences();
    if (mounted) {
      setState(() {
        _selectedMode = loadedMode;
        _showBoundingBoxes = displayPrefs.showBoundingBoxes;
        _showConfidence = displayPrefs.showConfidence;
        _showFillBox = displayPrefs.showFillBox;
        _showOrderNumber = displayPrefs.showOrderNumber;
      });
    }
  }

  /// Chuyển đổi file ảnh từ đường dẫn (path) thành đối tượng ui.Image để tính toán tọa độ
  Future<void> _loadImage() async {
    final data = await File(widget.imagePath).readAsBytes();
    final image = await decodeImageFromList(data);
    if (mounted) setState(() => _originalImage = image);
  }

  // --------------------------------------------------------------------------
  // 4. HÀM XỬ LÝ CHÍNH: QUY TRÌNH CHẠY AI
  // --------------------------------------------------------------------------
  Future<void> _startCounting() async {
    // Bước 1: Kiểm tra an toàn (Không chạy nếu đang đếm hoặc chưa chọn chế độ)
    if (_isCounting || _selectedMode == null) return;

    // Bước 2: Cập nhật trạng thái UI bắt đầu xử lý
    setState(() {
      _isCounting = true;
      _detectionResults = []; // Xóa sạch các kết quả của lần đếm trước
    });

    // Bước 3: HIỂN THỊ THANH CHỜ (Làm mờ nền bằng BackdropFilter trong UIHelper)
    if (!mounted) return;
    UIHelper.showLoadingIndicator(context, message: 'Ai is processing...');

    // Bước 4: TẠO KHOẢNG NGHỈ (150ms)
    // Giúp Flutter có thời gian vẽ màn hình chờ trước khi CPU bị AI chiếm dụng
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      // Bước 5: Nạp File Model AI (.tflite) từ thư mục assets
      //await _countingService.loadModel('assets/yolo11l-obb_float16.tflite');
      //await _countingService.loadModel('assets/yolo11l-obb_float32.tflite');
      //await _countingService.loadModel('assets/yolo11m-obb_float32.tflite');
      await _countingService.loadModel('assets/yolo11s-obb_float32.tflite');

      // Bước 6: Gọi hàm xử lý đếm vật thể (Trả về tọa độ xoay OBB)
      final results = await _countingService.countObjects(
          widget.imagePath,
          targetClass: _selectedMode!.targetClass
      );

      // Bước 7: Cập nhật kết quả đếm vào biến trạng thái để hiển thị lên màn hình
      if (mounted) {
        setState(() => _detectionResults = results);
      }
    } catch (e) {
      // Bước 8: Hiển thị thông báo nếu có lỗi xảy ra (Sai file model, ảnh hỏng...)
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi xử lý AI: $e');
    } finally {
      // Bước 9: LUÔN LUÔN ẨN LOADING dù đếm thành công hay thất bại
      if (mounted) {
        UIHelper.hideLoadingIndicator(context);
        setState(() => _isCounting = false); // Mở khóa nút bấm "COUNT"
      }
    }
  }

  // --------------------------------------------------------------------------
  // 5. LOGIC LƯU KẾT QUẢ (SAVE IMAGE)
  // --------------------------------------------------------------------------

  /// Chụp lại vùng Stack (Ảnh + Khung vẽ) và lưu vào Gallery điện thoại
  Future<void> _saveImageToGallery() async {
    if (!mounted || _isCounting) return;

    UIHelper.showLoadingIndicator(context, message: 'Đang chuẩn bị ảnh...');
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Chụp màn hình với pixelRatio cao (2.0) để ảnh lưu lại cực kỳ sắc nét
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );

      if (imageBytes != null) {
        // Ghi dữ liệu byte vào thư viện ảnh của thiết bị
        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: "Result_${DateTime.now().millisecondsSinceEpoch}",
        );
        if (mounted && result['isSuccess'] == true) {
          UIHelper.showSuccessSnackBar(context, 'Đã lưu ảnh thành công!');
        }
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi lưu ảnh: $e');
    } finally {
      if (mounted) UIHelper.hideLoadingIndicator(context);
    }
  }

  // --------------------------------------------------------------------------
  // 6. XÂY DỰNG GIAO DIỆN NGƯỜI DÙNG (BUILD UI)
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Tính tổng số lượng vật thể tìm được
    final int totalCount = _detectionResults.length;

    return PopScope(
      canPop: false,
      child: Screenshot(
        controller: _screenshotController, // Gắn Controller để bao quát vùng cần chụp ảnh
        child: Scaffold(
          backgroundColor: Colors.black, // Nền đen chuyên nghiệp cho ứng dụng camera
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context), // Nút đóng màn hình kết quả
            ),
            // Hiển thị số lượng đếm được ngay trên tiêu đề
            title: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                      text: 'Target: ',
                      style: TextStyle(
                          fontFamily: 'Lexend',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: '$totalCount',
                      style: const TextStyle(
                          fontFamily: 'Lexend',
                          color: Colors.orangeAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              // Widget Menu tùy chỉnh hiển thị
              DisplayOptionsMenu(
                  showBoundingBoxes: _showBoundingBoxes,
                  showConfidence: _showConfidence,
                  showFillBox: _showFillBox,
                  showOrderNumber: _showOrderNumber,
                  onOptionChanged: ({
                    required bool showBoundingBoxes,
                    required bool showConfidence,
                    required bool showFillBox,
                    required bool showOrderNumber,
                  }) {
                    setState(() {
                      _showBoundingBoxes = showBoundingBoxes;
                      _showConfidence = showConfidence;
                      _showFillBox = showFillBox;
                      _showOrderNumber = showOrderNumber;
                    });
                    _prefsService.saveDisplayPreferences(
                      showBoundingBoxes: showBoundingBoxes,
                      showConfidence: showConfidence,
                      showFillBox: showFillBox,
                      showOrderNumber: showOrderNumber,
                    );
                  }),
            ],
          ),

          // --- KHU VỰC HIỂN THỊ NỘI DUNG CHÍNH ---
          body: Center(
            child: _originalImage == null
                ? const CircularProgressIndicator(color: Colors.amber)
                : LayoutBuilder(
              builder: (context, constraints) {
                double imgW = _originalImage!.width.toDouble();
                double imgH = _originalImage!.height.toDouble();
                double ratio = imgW / imgH;

                // Bắt đầu phần thêm Zoom ở đây
                return InteractiveViewer(
                  clipBehavior: Clip.none, // Cho phép nội dung hiển thị tràn ra ngoài khi zoom
                  minScale: 1.0,           // Tỉ lệ thu nhỏ tối thiểu (1x)
                  maxScale: 5.0,           // Tỉ lệ phóng to tối đa (5x)
                  child: AspectRatio(
                    aspectRatio: ratio,
                    child: Stack(
                      children: [
                        // Lớp 1: Hiển thị file ảnh thực tế
                        Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.fill,
                        ),

                        // Khung viền cho ảnh (Optional)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.amber, width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Lớp 2: Vẽ các khung AI (OBB)
                        if (_detectionResults.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: BoundingBoxPainter(
                                results: _detectionResults,
                                originalImageSize: Size(imgW, imgH),
                                screenImageSize: Size(
                                    constraints.maxWidth,
                                    constraints.maxWidth / ratio),
                                showBoundingBoxes: _showBoundingBoxes,
                                showConfidence: _showConfidence,
                                showFillBox: _showFillBox,
                                showOrderNumber: _showOrderNumber,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // --- THANH ĐIỀU KHIỂN DƯỚI CÙNG (BOTTOM BAR) ---
          bottomNavigationBar: Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nút Tải ảnh (Vô hiệu hóa khi đang bận xử lý AI)
                IconButton(
                  icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 42),
                  onPressed: _isCounting ? null : _saveImageToGallery,
                ),

                // Nút COUNT: Bắt đầu chạy AI
                ElevatedButton(
                  // Nếu đang đếm hoặc chưa chọn mode thì nút sẽ bị khóa (màu xám)
                  onPressed: (_isCounting || _selectedMode == null) ? null : _startCounting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('COUNT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Lexend',
                        letterSpacing: 0,   // Giãn chữ tạo phong cách kỹ thuật (Futuristic)
                        decoration: TextDecoration.none,
                        shadows: [
                          // Đổ bóng 360 độ xung quanh chữ để đảm bảo đọc được trên mọi nền ảnh
                          Shadow(
                            blurRadius: 15.0,
                            color: Colors.black,
                            offset: Offset(0, 0),
                          ),
                        ],
                      )
                  ),
                ),

                // Widget chọn đối tượng cần đếm
                ModeSelector(
                  currentModeName: _selectedMode?.name ?? 'Chọn Mode',
                  currentModeImage: _selectedMode?.image,
                  onModeSelected: (int id, String name, String img) {
                    final newMode = SelectedMode(targetClass: id, name: name, image: img);
                    _prefsService.saveSelectedMode(newMode); // Lưu mode mới vào máy
                    setState(() {
                      _selectedMode = newMode;
                      _detectionResults = []; // Xóa kết quả cũ khi người dùng đổi loại vật thể
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
