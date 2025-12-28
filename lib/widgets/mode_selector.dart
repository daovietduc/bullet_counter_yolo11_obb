import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  // Callback để truyền classID, modeName, modeImage tên chế độ ra cho widget cha
  final Function(int classId, String modeName, String modeImage) onModeSelected;
  final String currentModeName; // Tên của chế độ hiện tại để hiển thị trên nút
  final String? currentModeImage; // Ảnh của chế độ hiện tại để hiển thị trên nút

  const ModeSelector({
    super.key,
    required this.onModeSelected,
    required this.currentModeName,
    this.currentModeImage,
  });

  // Hàm để hiển thị Bottom Sheet
  void _showModeSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Truyền hàm onModeSelected xuống cho cửa sổ con
        return _ModeSelectorSheetContent(
          onModeSelected: onModeSelected,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    /// Nút chọn chế độ đếm
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => _showModeSelectionSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Mode", style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600),),
            const SizedBox(height: 4),
            SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: _buildImageWidget(
                    currentModeImage), // Dùng hàm build ảnh đã được đơn giản hóa
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

  // SỬA ĐỔI: Đơn giản hóa hàm này, chỉ xử lý ảnh asset hoặc icon mặc định
  Widget _buildImageWidget(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      // Nếu có đường dẫn ảnh, dùng Image.asset
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.error_outline, color: Colors.white, size: 28),
      );
    } else {
      // Nếu không có ảnh, hiển thị icon mặc định
      return const Icon(Icons.category, color: Colors.white, size: 28);
    }
  }
}

/// Widget bottom sheet chứa chế độ đếm
class _ModeSelectorSheetContent extends StatelessWidget {
  final Function(int classId, String modeName, String modeImage) onModeSelected;

  const _ModeSelectorSheetContent({required this.onModeSelected});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> modes = [
      {"name": "K51", "image": "assets/images/k51.png", "classID": 0},
      {"name": "K59", "image": "assets/images/k59.png", "classID": 1},
      {"name": "K56", "image": "assets/images/k56.png", "classID": 2},
      {"name": "K53", "image": "assets/images/k53.png", "classID": 9},
      {"name": "12,7mm", "image": "assets/images/12,7.png", "classID": 10},
      {"name": "14,5mm", "image": "assets/images/14,5.png", "classID": 5},
      {"name": "23mm", "image": "assets/images/k53.png", "classID": 9},
      {"name": "37mm", "image": "assets/images/12,7.png", "classID": 10},
      {"name": "57mm", "image": "assets/images/14,5.png", "classID": 5},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10))),
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
                    onModeSelected(selectedId, selectedName, selectedImage);
                    Navigator.pop(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: IgnorePointer(
                            // SỬA ĐỔI: Dùng trực tiếp Image.asset
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
