import 'package:flutter/material.dart';

// Widget để chọn chế độ (mode) và hiển thị lựa chọn hiện tại.
class ModeSelector extends StatelessWidget {
  // Callback được gọi khi một chế độ mới được chọn.
  final Function(int classId, String modeName, String modeImage) onModeSelected;
  // Tên chế độ đang được chọn.
  final String currentModeName;
  // Đường dẫn ảnh của chế độ đang được chọn.
  final String? currentModeImage;

  const ModeSelector({
    super.key,
    required this.onModeSelected,
    required this.currentModeName,
    this.currentModeImage,
  });

  // Hiển thị bottom sheet để người dùng chọn chế độ.
  void _showModeSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Truyền callback `onModeSelected` vào sheet.
        return _ModeSelectorSheetContent(
          onModeSelected: onModeSelected,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nút bấm để mở trang chọn chế độ.
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => _showModeSelectionSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Mode", style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600),),
            const SizedBox(height: 4),
            SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: _buildImageWidget(currentModeImage),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentModeName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Xây dựng widget hiển thị ảnh cho chế độ, hoặc icon mặc định nếu không có ảnh.
  Widget _buildImageWidget(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      // Hiển thị ảnh từ assets.
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.error_outline, color: Colors.white, size: 28),
      );
    } else {
      // Hiển thị icon mặc định.
      return const Icon(Icons.category, color: Colors.white, size: 28);
    }
  }
}

// Nội dung của bottom sheet, chứa danh sách các chế độ để lựa chọn.
class _ModeSelectorSheetContent extends StatelessWidget {
  final Function(int classId, String modeName, String modeImage) onModeSelected;

  const _ModeSelectorSheetContent({required this.onModeSelected});

  @override
  Widget build(BuildContext context) {
    // Danh sách các chế độ có sẵn.
    final List<Map<String, dynamic>> modes = [
      {"name": "K51", "image": "assets/images/K51.png", "classID": 0},
      {"name": "K59", "image": "assets/images/K59.png", "classID": 1},
      {"name": "K56", "image": "assets/images/K56.png", "classID": 2},
      {"name": "K53", "image": "assets/images/K53.png", "classID": 3},
      {"name": "12,7mm", "image": "assets/images/12,7.png", "classID": 4},
      {"name": "14,5mm", "image": "assets/images/14,5.png", "classID": 5},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Tay cầm (handle) để người dùng biết có thể kéo sheet.
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10))),
          // Thanh tiêu đề và nút đóng.
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text("Bullet", style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,)),
                    const Text("Phụ tùng", style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,)),
                    const Text("Chi tiết", style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ])),
          const Divider(),
          // Lưới hiển thị các chế độ.
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8),
              itemCount: modes.length,
              itemBuilder: (context, index) {
                final mode = modes[index];
                return GestureDetector(
                  onTap: () {
                    final int selectedId = mode["classID"];
                    final String selectedName = mode["name"];
                    final String selectedImage = mode["image"];
                    // Gọi callback để thông báo cho widget cha về lựa chọn mới.
                    onModeSelected(selectedId, selectedName, selectedImage);
                    // Đóng bottom sheet.
                    Navigator.pop(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // Ngăn chặn các tương tác chạm vào ảnh.
                          child: IgnorePointer(
                            child: Image.asset(mode["image"]!, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(mode["name"]!, textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
