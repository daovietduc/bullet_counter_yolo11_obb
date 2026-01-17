import 'dart:io';import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

// --- Các thành phần giao diện và logic được tách riêng trong dự án ---
import '../widgets/menu_mode_selector.dart'; // Widget để chọn chế độ đếm (ví dụ: đếm đạn, đếm xe).
import '../widgets/menu_display_options.dart'; // Widget chứa các tùy chọn hiển thị (Drawer bên phải).
import '../services/counting_service.dart'; // Service xử lý logic AI, giao tiếp với model TFLite.
import '../services/preferences_service.dart'; // Service để lưu và tải cài đặt của người dùng.
import '../models/detection_result.dart'; // Model định nghĩa cấu trúc của một đối tượng được phát hiện.
import '../helpers/ui_helpers.dart'; // Các hàm tiện ích cho giao diện (hiển thị thông báo, loading...).
import './bounding_box_painter.dart'; // Lớp CustomPainter để vẽ các hộp bao quanh đối tượng.

/// CountingScreen là màn hình chính, nơi người dùng xem ảnh,
/// chạy mô hình AI để đếm đối tượng và xem kết quả.
class CountingScreen extends StatefulWidget {
  // Đường dẫn của ảnh được chọn từ màn hình trước đó.
  // Biến này được truyền vào khi khởi tạo CountingScreen.
  final String imagePath;

  const CountingScreen({super.key, required this.imagePath});

  @override
  State<CountingScreen> createState() => _CountingScreenState();
}

class _CountingScreenState extends State<CountingScreen> {
  // 1. KHAI BÁO BIẾN & CONTROLLERS
  // Controller để điều khiển việc chụp ảnh màn hình của một widget cụ thể.
  final ScreenshotController _screenshotController = ScreenshotController();
  // Service chứa logic đếm đối tượng, bao gồm tải model và thực thi.
  final CountingService _countingService = CountingService();
  // Service để quản lý việc lưu và đọc các cài đặt của người dùng (như chế độ đã chọn, tùy chọn hiển thị).
  final PreferencesService _prefsService = PreferencesService();

  // 2. TRẠNG THÁI GIAO DIỆN (UI STATE)
  // Các biến boolean và giá trị để điều khiển cách các bounding box được hiển thị.
  bool _showBoundingBoxes = true;  // Hiển thị/ẩn tất cả các hộp bao.
  bool _showConfidence = true;    // Hiển thị/ẩn độ tin cậy của mô hình AI.
  bool _showFillBox = false;      // Hiển thị/ẩn lớp màu nền bên trong hộp bao.
  bool _showOrderNumber = false;  // Hiển thị/ẩn số thứ tự của đối tượng.
  bool _isMultiColor = true;      // true: mỗi hộp một màu, false: tất cả dùng một màu (_boxColor).
  double _fillOpacity = 0.4;      // Độ trong suốt của màu nền hộp bao (khi _showFillBox = true).
  Color _boxColor = Colors.amber; // Màu mặc định cho hộp bao khi _isMultiColor = false.

  // Dữ liệu và trạng thái xử lý của màn hình.
  List<DetectionResult> _detectionResults = []; // Danh sách lưu các đối tượng AI phát hiện được.
  bool _isCounting = false;                     // Cờ báo hiệu tiến trình đếm đang chạy, dùng để vô hiệu hóa các nút.
  ui.Image? _originalImage;                     // Đối tượng ảnh đã được giải mã, dùng để lấy kích thước gốc.
  SelectedMode? _selectedMode;                  // Chế độ đếm hiện tại đang được chọn (ví dụ: đếm loại đạn nào).

  @override
  void initState() {
    super.initState();
    // Khi widget được tạo lần đầu, thực hiện hai tác vụ bất đồng bộ:
    _loadPreferences(); // Tải các cài đặt đã lưu từ bộ nhớ (SharedPreferences).
    _loadImage();       // Tải và giải mã ảnh từ đường dẫn được cung cấp.
  }

  @override
  void dispose() {
    // Hàm này được gọi khi widget bị hủy khỏi cây widget.
    // Rất quan trọng để giải phóng tài nguyên, tránh rò rỉ bộ nhớ.
    _countingService.dispose(); // Gọi hàm dispose của service để giải phóng model TFLite.
    super.dispose();
  }

  // 3. CÁC HÀM HỖ TRỢ
  /// Tải các cài đặt hiển thị và chế độ đếm đã được người dùng lưu trước đó.
  Future<void> _loadPreferences() async {
    // Lấy chế độ và tùy chọn hiển thị từ SharedPreferences.
    final loadedMode = await _prefsService.loadSelectedMode();
    final displayPrefs = await _prefsService.loadDisplayPreferences();
    // Kiểm tra xem widget còn tồn tại không trước khi cập nhật state.
    if (mounted) {
      setState(() {
        _selectedMode = loadedMode;
        _showBoundingBoxes = displayPrefs.showBoundingBoxes;
        _showConfidence = displayPrefs.showConfidence;
        _showFillBox = displayPrefs.showFillBox;
        _showOrderNumber = displayPrefs.showOrderNumber;
        _isMultiColor = displayPrefs.showMultiColor;
        _fillOpacity = displayPrefs.opacity;
        _boxColor = displayPrefs.boxColor;
      });
    }
  }

  /// Đọc dữ liệu file ảnh từ `widget.imagePath` và chuyển thành đối tượng `ui.Image`.
  /// `ui.Image` cần thiết để lấy chiều rộng và chiều cao chính xác của ảnh.
  Future<void> _loadImage() async {
    final data = await File(widget.imagePath).readAsBytes(); // Đọc file ảnh thành một mảng bytes.
    final image = await decodeImageFromList(data); // Giải mã mảng bytes thành đối tượng ảnh.
    // Cập nhật state để hiển thị ảnh.
    if (mounted) setState(() => _originalImage = image);
  }

  // 4. HÀM XỬ LÝ CHÍNH (ĐẾM ĐỐI TƯỢNG)
  /// Kích hoạt quá trình xử lý ảnh bằng mô hình AI để phát hiện và đếm đối tượng.
  Future<void> _startCounting() async {
    // Ngăn chặn việc chạy lại nếu đang trong quá trình đếm hoặc chưa chọn mode.
    if (_isCounting || _selectedMode == null) return;

    // Cập nhật UI để báo hiệu quá trình bắt đầu.
    setState(() {
      _isCounting = true;
      _detectionResults = []; // Xóa kết quả của lần đếm trước.
    });

    if (!mounted) return;
    // Hiển thị vòng quay chờ với thông báo cho người dùng.
    UIHelper.showLoadingIndicator(context, message: 'AI is processing...');

    // Chờ một khoảng ngắn để đảm bảo UI kịp cập nhật trước khi bắt đầu tác vụ nặng.
    await Future.delayed(const Duration(milliseconds: 350));

    try {
      // Tải model TFLite từ assets.
      await _countingService.loadModel('assets/yolo11m_obb_bullet_couter_preview_float16.tflite');
      //await _countingService.loadModel('assets/yolo11s-obb_float16.tflite');
      // Gọi service để thực hiện nhận diện đối tượng trên ảnh.
      final results = await _countingService.countObjects(
          widget.imagePath,
          targetClass: _selectedMode!.targetClass // Chỉ đếm đối tượng thuộc lớp đã chọn trong mode.
      );

      // Nếu widget còn tồn tại, cập nhật state với kết quả nhận được.
      if (mounted) {
        setState(() => _detectionResults = results);
      }
    } catch (e) {
      // Bắt và hiển thị lỗi nếu có sự cố trong quá trình xử lý AI.
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi xử lý AI: $e');
    } finally {
      // Khối `finally` luôn được thực thi, dù có lỗi hay không.
      if (mounted) {
        UIHelper.hideLoadingIndicator(context); // Ẩn vòng quay chờ.
        setState(() => _isCounting = false);    // Cập nhật lại cờ trạng thái.
      }
    }
  }

  // 5. LƯU ẢNH KẾT QUẢ
  /// Chụp lại khu vực hiển thị ảnh (bao gồm cả các bounding box) và lưu vào thư viện của thiết bị.
  Future<void> _saveImageToGallery() async {
    // Không thực hiện nếu đang đếm hoặc widget không còn tồn tại.
    if (!mounted || _isCounting) return;

    // Hiển thị thông báo chờ cho người dùng.
    UIHelper.showLoadingIndicator(context, message: 'Đang chuẩn bị ảnh...');
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Sử dụng ScreenshotController để chụp widget được bao bọc bởi `Screenshot`.
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100), // Chờ 100ms để đảm bảo mọi thứ đã vẽ xong.
        pixelRatio: 2.0, // Tăng độ phân giải của ảnh chụp lên 2x để nét hơn.
      );

      if (imageBytes != null) {
        // Sử dụng package `image_gallery_saver_plus` để lưu mảng bytes của ảnh.
        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100, // Chất lượng ảnh cao nhất.
          name: "Result_${DateTime.now().millisecondsSinceEpoch}", // Đặt tên file duy nhất.
        );
        // Hiển thị thông báo thành công nếu lưu thành công.
        if (mounted && result['isSuccess'] == true) {
          UIHelper.showSuccessSnackBar(context, 'Đã lưu ảnh thành công!');
        }
      }
    } catch (e) {
      // Hiển thị lỗi nếu quá trình chụp hoặc lưu ảnh thất bại.
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi lưu ảnh: $e');
    } finally {
      // Luôn ẩn thông báo chờ sau khi hoàn tất.
      if (mounted) {
        UIHelper.hideLoadingIndicator(context);
      }
    }
  }

  // 6. DỰNG GIAO DIỆN (BUILD UI)
  @override
  Widget build(BuildContext context) {
    // Tính tổng số đối tượng đã được phát hiện.
    final int totalCount = _detectionResults.length;

    return PopScope(
      canPop: false, // Ngăn người dùng quay lại bằng cử chỉ hệ thống (ví dụ: vuốt back trên Android).
      child: Screenshot(
        controller: _screenshotController, // Bọc toàn bộ Scaffold để có thể chụp lại màn hình.
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: PreferredSize(
            // Đặt chiều cao cho toàn bộ khu vực AppBar
            preferredSize: const Size.fromHeight(70.0),
            child: AppBar(
              centerTitle: true,
              backgroundColor: Colors.black,
              // Nút 'X' để đóng màn hình hiện tại và quay về màn hình trước.
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              // Tiêu đề hiển thị tổng số đối tượng đếm được.
              title: Column(
                  children: [
                    RichText(
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
                              text: '$totalCount', // Số lượng đếm được
                              style: const TextStyle(
                                  fontFamily: 'Lexend',
                                  color: Colors.orangeAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    SizedBox(height: 5),
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                              text: '- Mode: ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,)),
                          TextSpan(
                              text: _selectedMode?.name ?? 'Chưa chọn',
                              style: const TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 14,)),
                          const TextSpan(
                              text: ' -', // Dấu ngoặc đơn đóng ở cuối
                              style: TextStyle(
                                color: Colors.white,
                                // Cùng style với chữ '(Mode: '
                                fontSize: 14,)),
                        ],
                      ),
                    ),
                  ]
              ),
              actions: [
                // Nút mở Drawer (menu cài đặt trượt ra từ bên phải).
                Builder(
                  builder: (context) =>
                      IconButton(
                        icon: const Icon(Icons.tune, color: Colors.white),
                        tooltip: 'Cài đặt hiển thị',
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      ),
                ),
              ],
            ),
          ),

          // Drawer: Thanh cài đặt trượt ra từ bên phải.
          endDrawer: DisplayOptionsDrawer(
            // Truyền các giá trị trạng thái hiện tại vào Drawer.
            showBoundingBoxes: _showBoundingBoxes,
            showConfidence: _showConfidence,
            showFillBox: _showFillBox,
            showOrderNumber: _showOrderNumber,
            isMultiColor: _isMultiColor,
            fillOpacity: _fillOpacity,
            boxColor: _boxColor,
            // Callback được gọi khi một tùy chọn trong Drawer thay đổi.
            onOptionChanged: (key, newValue) {
              // Cập nhật trạng thái UI tương ứng với tùy chọn đã thay đổi.
              setState(() {
                if (key == 'box') _showBoundingBoxes = newValue;
                if (key == 'fill') _showFillBox = newValue;
                if (key == 'order') _showOrderNumber = newValue;
                if (key == 'confidence') _showConfidence = newValue;
                if (key == 'multiColor') _isMultiColor = newValue;
                if (key == 'opacity') _fillOpacity = newValue;
                if (key == 'color') _boxColor = newValue;
              });

              // Sau khi cập nhật UI, lưu các cài đặt mới này vào bộ nhớ.
              _prefsService.saveDisplayPreferences(
                DisplayPreferences(
                  showBoundingBoxes: _showBoundingBoxes,
                  showConfidence: _showConfidence,
                  showFillBox: _showFillBox,
                  showOrderNumber: _showOrderNumber,
                  showMultiColor: _isMultiColor,
                  opacity: _fillOpacity,
                  boxColor: _boxColor,
                ),
              );
            },
          ),

          // Body: Khu vực trung tâm hiển thị ảnh và kết quả.
          body: _originalImage == null
              ? const Center(
              child: CircularProgressIndicator(color: Colors.amber))
              : LayoutBuilder(
            builder: (context, constraints) {
              // 1. Lấy kích thước thật của ảnh
              double imgW = _originalImage!.width.toDouble();
              double imgH = _originalImage!.height.toDouble();
              double ratio = imgW / imgH;

              // 2. Tính toán displayWidth và displayHeight để ảnh nằm gọn trong màn hình
              double displayWidth = constraints.maxWidth;
              double displayHeight = constraints.maxWidth / ratio;

              // Trường hợp ảnh quá cao so với màn hình
              if (displayHeight > constraints.maxHeight) {
                displayHeight = constraints.maxHeight;
                displayWidth = displayHeight * ratio;
              }

              return InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 1.0,
                maxScale: 4.0,
                child: Container( // Sử dụng Container bao toàn bộ vùng body
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  alignment: Alignment.center, // Căn giữa nội dung bên trong
                  child: SizedBox(
                    width: displayWidth,
                    height: displayHeight,
                    child: Stack(
                      children: [
                        // Lớp 1: Hiển thị ảnh (Khôi phục Image.file của bạn)
                        Positioned.fill(
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.fill,
                          ),
                        ),

                        // Lớp 2: Vẽ bounding box (Đảm bảo Painter nhận đúng kích thước)
                        if (_detectionResults.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: BoundingBoxPainter(
                                results: _detectionResults,
                                originalImageSize: Size(imgW, imgH),
                                screenImageSize: Size(
                                    displayWidth, displayHeight),
                                showBoundingBoxes: _showBoundingBoxes,
                                showConfidence: _showConfidence,
                                showFillBox: _showFillBox,
                                showOrderNumber: _showOrderNumber,
                                fillOpacity: _fillOpacity,
                                boxColor: _boxColor,
                                isMultiColor: _isMultiColor,
                              ),
                            ),
                          ),

                        // Lớp 3: Viền của ảnh
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.amber, width: 2),
                              ),
                            ),
                          ),
                        ),

                        // Lớp 4: Hứng tương tác
                        Positioned.fill(
                          child: Container(color: Colors.transparent),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Bottom Bar: Chứa các nút điều khiển chính.
          bottomNavigationBar: Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            // Chúng ta dùng chiều cao cố định hoặc để Container tự thích ứng
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              // Căn giữa tất cả các thành phần trong Stack
              children: [
                // 1. Nút COUNT nằm chính giữa Stack (và cũng là chính giữa màn hình)
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    onPressed: (_isCounting || _selectedMode == null)
                        ? null
                        : _startCounting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text(
                      'COUNT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Lexend',
                        shadows: [Shadow(blurRadius: 15.0, color: Colors.black, offset: Offset(0, 0))
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Nút bên trái và bên phải dùng Row để đẩy ra hai biên
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Nút Lưu ảnh
                    IconButton(
                      icon: const Icon(Icons.download_for_offline_rounded,
                          color: Colors.white, size: 45),
                      onPressed: _isCounting ? null : _saveImageToGallery,
                    ),

                    // Bộ chọn Mode
                    ModeSelector(
                      currentModeName: _selectedMode?.name ?? 'Chọn Mode',
                      currentModeImage: _selectedMode?.image,
                      onModeSelected: (id, name, img) {
                        final newMode = SelectedMode(
                            targetClass: id, name: name, image: img);
                        _prefsService.saveSelectedMode(newMode);
                        setState(() {
                          _selectedMode = newMode;
                          _detectionResults = [];
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
