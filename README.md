# bullet_counter 🎯

**bullet_counter** là một dự án phần mềm đa nền tảng được xây dựng bằng **Flutter** và ứng dụng mô hình học sâu **YOLOv8** để tự động đếm các vật thể (như đếm số lượng viên đạn, vật thể nhỏ, sản phẩm, linh kiện điện tử, v.v.) từ hình ảnh tĩnh hoặc luồng video thời gian thực.

Dự án này mang lại một giải pháp đếm vật thể hiệu quả, độ chính xác cao và linh hoạt, có thể triển khai native trên nhiều thiết bị khác nhau.

---

## 🧠 Tổng quan về Công nghệ AI

Dự án sử dụng **YOLOv8** (You Only Look Once, phiên bản 8) – một kiến trúc mạng nơ-ron tích chập (CNN) nổi tiếng về khả năng thực hiện **phân đoạn và nhận diện vật thể** với tốc độ cao, lý tưởng cho việc triển khai trên thiết bị biên (edge devices) như điện thoại di động.

* **Mục tiêu:** Nhận diện vị trí và phân loại từng vật thể ("bullet") trong khung hình.
* **Ứng dụng:** Sau khi nhận diện, hệ thống sẽ **đếm số lượng** các hộp giới hạn (bounding boxes) được phát hiện để đưa ra kết quả cuối cùng.
* **Tối ưu hóa Mobile:** Mô hình được chuyển đổi sang định dạng **TensorFlow Lite (TFLite)** để tối ưu hóa kích thước và hiệu suất tính toán, cho phép chạy trực tiếp trên Android và iOS.

---

## 🛠️ Công nghệ sử dụng và Yêu cầu Hệ thống

| Lĩnh vực | Công cụ/Công nghệ           | Chi tiết |
| :--- |:----------------------------| :--- |
| **Giao diện & Nền tảng** | **Flutter (Dart)**          | Phiên bản 3.x trở lên. Hỗ trợ đa nền tảng. |
| **Học máy** | **YOLOv11**                 | Mô hình đã được huấn luyện (pre-trained) và xuất ra định dạng **.tflite**. |
| **Thư viện AI** | **TFLite Flutter Plugin**   | Dùng để tải và thực thi mô hình `.tflite`. |
| **Yêu cầu hệ thống** | **RAM**                     | Tối thiểu 4GB RAM (Khuyến nghị 8GB trở lên). |
| **Hệ điều hành** | Windows, macOS, hoặc Linux. |

---

## 🚀 Getting Started

Các hướng dẫn sau đây sẽ giúp bạn thiết lập và chạy dự án trên máy cục bộ của mình.

### 1. Yêu cầu Tiên quyết (Prerequisites)

* **Flutter SDK:** Đã cài đặt và thiết lập biến môi trường.
    * Chạy `flutter doctor` để kiểm tra các phần phụ thuộc.
* **Trình chỉnh sửa:** VS Code hoặc Android Studio.
* **Thiết bị/Simulator:** Một thiết bị Android, iOS, hoặc trình duyệt web đã được thiết lập.

### 2. Cài đặt và Thiết lập Dự án

1.  **Clone repository:**
    ```bash
    git clone [https://github.com/yourusername/bullet_counter.git](https://github.com/yourusername/bullet_counter.git)
    cd bullet_counter
    ```

2.  **Tải các dependency (dependencies):**
    ```bash
    flutter pub get
    ```

### 3. Thiết lập Mô hình AI (YOLOv8 TFLite)

Để ứng dụng hoạt động, bạn cần có file mô hình YOLOv8 đã được tối ưu hóa:

1.  **Chuẩn bị File Mô hình:** Đảm bảo bạn có file mô hình đã được chuyển đổi:
    * **File:** `model_quantized.tflite` (hoặc tên tương tự)
    * **File Nhãn (Labels):** `labels.txt` (chứa tên các class, ví dụ: "bullet")

2.  **Đặt Mô hình vào Thư mục Assets:**
    * Tạo thư mục `assets/` trong thư mục gốc của dự án nếu nó chưa tồn tại.
    * Sao chép hai file trên vào thư mục **`assets/`**:
        ```
        bullet_counter/
        ├── assets/
        │   ├── model_quantized.tflite  <-- File mô hình
        │   └── labels.txt              <-- File nhãn
        └── lib/
        └── pubspec.yaml
        ```

3.  **Kiểm tra `pubspec.yaml`:**
    * Đảm bảo phần `assets:` trong file `pubspec.yaml` đã được định nghĩa chính xác để bao gồm các file mô hình:
        ```yaml
        flutter:
          uses-material-design: true
          assets:
            - assets/model_quantized.tflite
            - assets/labels.txt
        ```

### 4. Thiết lập Cấu hình Native (Quan trọng cho Camera)

* **Android:** Mở file `android/app/src/main/AndroidManifest.xml` và đảm bảo bạn có quyền sử dụng camera:
    ```xml
    <uses-permission android:name="android.permission.CAMERA" />
    ```

* **iOS:** Mở file `ios/Runner/Info.plist` và thêm khóa giải thích lý do sử dụng camera (bắt buộc bởi Apple):
    ```xml
    <key>NSCameraUsageDescription</key>
    <string>Ứng dụng cần truy cập camera để thực hiện việc đếm vật thể theo thời gian thực.</string>
    ```

### 5. Chạy Ứng dụng

Chạy ứng dụng trên thiết bị mục tiêu đã kết nối hoặc trình giả lập:
```
flutter run
```

## 📂 Cấu trúc Dự án Cơ bản

Dự án này tuân theo cấu trúc dự án Flutter tiêu chuẩn, với các bổ sung cụ thể cho việc tích hợp mô hình học máy:

```
bullet_counter/
├── android/            # Mã nguồn Native Android (Ví dụ: Cấu hình quyền camera)
├── ios/                # Mã nguồn Native iOS (Ví dụ: Cấu hình quyền camera, Info.plist)
├── assets/             # Chứa mô hình TFLite và nhãn (model_quantized.tflite, labels.txt)
├── lib/                # Mã nguồn Flutter (Dart) chính
│   ├── main.dart       # Điểm khởi động ứng dụng
│   ├── screens/        # Các màn hình chính (ví dụ: CameraScreen, ModelScreen)
│   └── services/       # Các lớp tiện ích, bao gồm logic xử lý TFLite
├── test/               # Các tệp kiểm thử đơn vị và widget
└── pubspec.yaml        # Danh sách các dependency của Flutter và định nghĩa assets
```

---

## 🤝 Đóng góp

Đóng góp là điều làm cho cộng đồng mã nguồn mở trở nên tuyệt vời. Mọi đóng góp của bạn đều được **chào đón nồng nhiệt**.

Để đóng góp cho dự án này, vui lòng làm theo các bước sau:

1.  **Fork** dự án
2.  Tạo một branch mới:
    ```bash
    git checkout -b feature/AmazingFeature
    ```
3.  **Commit** các thay đổi của bạn:
    ```bash
    git commit -m 'Add some AmazingFeature'
    ```
4.  **Push** lên branch:
    ```bash
    git push origin feature/AmazingFeature
    ```
5.  Mở một **Pull Request**

---

## 📜 Giấy phép (License)

Vui lòng xem file `LICENSE` để biết thêm chi tiết.

---

## 📧 Liên hệ (Contact)

Bạn có thể liên hệ với tôi qua:

* **Đào Việt Đức** - https://www.facebook.com/duc.boderguard/
* **Email:** daovietduc.bdbp@gmail.com