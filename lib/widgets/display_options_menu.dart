import 'package:flutter/material.dart';

// Callback để thông báo cho widget cha về sự thay đổi
typedef OnDisplayOptionChanged = void Function({
  required bool showBoundingBoxes,
  required bool showConfidence,
  required bool showFillBox,
  required bool showOrderNumber,
});

class DisplayOptionsMenu extends StatelessWidget {
  final bool showBoundingBoxes;
  final bool showConfidence;
  final bool showFillBox;
  final bool showOrderNumber;
  final OnDisplayOptionChanged onOptionChanged;

  const DisplayOptionsMenu({
    super.key,
    required this.showBoundingBoxes,
    required this.showConfidence,
    required this.showFillBox,
    required this.showOrderNumber,
    required this.onOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF2d2d2d),
      onSelected: (String value) {
        if (value == 'toggle_bounding_box') {
          onOptionChanged(
            showBoundingBoxes: !showBoundingBoxes,
            showConfidence: showConfidence,
            showFillBox: showFillBox,
            showOrderNumber: showOrderNumber,
          );
        } else if (value == 'toggle_fill_box') {
          onOptionChanged(
            showBoundingBoxes: showBoundingBoxes,
            showConfidence: showConfidence,
            showFillBox: !showFillBox,
            showOrderNumber: showOrderNumber,
          );
        } else if (value == 'toggle_order_number') {
          onOptionChanged(
            showBoundingBoxes: showBoundingBoxes,
            showConfidence: showConfidence,
            showFillBox: showFillBox,
            showOrderNumber: !showOrderNumber,
          );
        } else if (value == 'toggle_confidence') {
          onOptionChanged(
            showBoundingBoxes: showBoundingBoxes,
            showConfidence: !showConfidence,
            showFillBox: showFillBox,
            showOrderNumber: showOrderNumber,
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        // Tùy chọn cho Bounding Box
        PopupMenuItem<String>(
          value: 'toggle_bounding_box',
          child: ListTile(
            leading: Icon(
              showBoundingBoxes ? Icons.select_all : Icons.deselect,
              color: Colors.white,
            ),
            title: Text(
              showBoundingBoxes ? 'Ẩn bounding box' : 'Hiện bounding box',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        // Tùy chọn cho tô màu boundingbox
        PopupMenuItem<String>(
          value: 'toggle_fill_box',
          child: ListTile(
            leading: Icon(
              showFillBox ? Icons.format_color_fill : Icons.format_color_reset,
              color: Colors.white,
            ),
            title: Text(
              showFillBox ? 'Xóa màu bounding box' : 'Tô màu bounding box',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        // Tùy chọn cho Số thứ tự vật thể
        PopupMenuItem<String>(
          value: 'toggle_order_number',
          child: ListTile(
            leading: Icon(
              showOrderNumber ? Icons.format_list_numbered : Icons.format_list_bulleted,
              color: Colors.white,
            ),
            title: Text(
              showOrderNumber ? 'Ẩn số thứ tự' : 'Hiện số thứ tự',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        // Tùy chọn cho Độ tin cậy
        PopupMenuItem<String>(
          value: 'toggle_confidence',
          child: ListTile(
            leading: Icon(
              showConfidence ? Icons.label : Icons.label_off,
              color: Colors.white,
            ),
            title: Text(
              showConfidence ? 'Ẩn độ tin cậy' : 'Hiện độ tin cậy',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
