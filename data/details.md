# Chi tiết dữ liệu BBBC005 (Synthetic Cells)

## 1. Bối cảnh bộ dữ liệu
BBBC005 là bộ dữ liệu ảnh tế bào mô phỏng thuộc Broad Bioimage Benchmark Collection (BBBC), được thiết kế để đánh giá:
- Chất lượng ảnh theo mức độ mất nét (focus blur).
- Khả năng phân đoạn đối tượng trong bối cảnh ảnh y sinh.
- Độ ổn định của thuật toán đếm tế bào khi ảnh có nhiễu và hiện tượng dính cụm.

Bộ ảnh được sinh bằng nền tảng SIMCEP cho bài toán High-Content Screening (HCS), với:
- Xác suất cụm tế bào: 25%.
- Phương sai nhiễu CCD: 0.0001.
- Mô phỏng mờ bằng Gaussian lowpass filter đối xứng tròn.
- Kích thước mỗi ảnh: 696 x 520 pixels.
- Định dạng: 8-bit TIF.
- Tổng số ảnh: 19,200.

## 2. Quy tắc đặt tên file
Tên file ảnh theo mẫu:

`SIMCEPImages_[well]_C[cells]_F[blur]_s[samples]_w[stain].TIF`

Ý nghĩa từng thành phần:
- `well`: vị trí giếng theo chuẩn plate 384 giếng (hàng A-P, cột 1-24).
- `C[cells]`: số lượng tế bào trong ảnh.
- `F[blur]`: mức độ mờ focus.
- `s[samples]`: số thứ tự mẫu (site) cho cùng tổ hợp `cells` và `blur`.
- `w[stain]`: loại kênh nhuộm.
  - `w1`: Cell body stain.
  - `w2`: Nuclei stain.

### Hai biến quan trọng cần bóc tách
- `C` đại diện cho số lượng tế bào, nằm trong khoảng từ 1 đến 100.
- `F` đại diện cho mức độ mờ, nằm trong khoảng từ 1 đến 48.

Ví dụ:
- `SIMCEPImages_A01_C12_F1_s03_w1.TIF`
  - Có 12 tế bào.
  - Mức mờ F1 (nét tốt nhất, dùng như dữ liệu đối chiếu).
  - Mẫu số 03, kênh nhuộm w1.

## 3. Hướng dẫn sử dụng Ground Truth (F1)
Trong BBBC005, các file có ký hiệu `F1` được xem là ảnh in-focus (nét hoàn toàn) và được sử dụng làm ground truth thực hành cho bài toán:
- Đánh giá phân đoạn foreground/background.
- Kiểm tra sai số đếm đối tượng.

Nguyên tắc sử dụng:
- Ưu tiên dùng ảnh `F1` làm mốc tham chiếu chất lượng segmentation.
- Với bài toán đếm, giá trị thật (count label) lấy trực tiếp từ biến `C[cells]` trong tên file.
- Với bài toán mask, dùng ảnh nhị phân ground truth (trắng là foreground, đen là background) nếu có sẵn trong gói dữ liệu đi kèm.

Lưu ý:
- Tổng số ảnh ground truth điển hình cho nhánh F1 là 1,200 ảnh.
- Cần giữ cùng quy ước tên file để ánh xạ ảnh đầu vào và ảnh nhãn chính xác.

## 4. Quy trình tổ chức thư mục dữ liệu
Khuyến nghị tổ chức như sau:

```text
data/
|-- raw/
|-- ground_truth/
`-- details.md
```

### 4.1 data/raw
Dùng để chứa toàn bộ ảnh gốc tải từ BBBC005, chưa tiền xử lý.

Nên tổ chức theo một trong hai cách:
- Cách 1 (đơn giản): đặt tất cả file TIF vào cùng một thư mục.
- Cách 2 (khuyến nghị): chia theo kênh nhuộm hoặc theo mức F để dễ truy vấn.

### 4.2 data/ground_truth
Dùng để chứa dữ liệu đối chiếu:
- Nhóm ảnh F1 được chọn làm mốc in-focus.
- Các file mask nhị phân (nếu tách riêng khỏi raw).
- Bảng mapping hoặc ghi chú ánh xạ giữa ảnh đầu vào và nhãn (nếu cần).

### 4.3 Quy tắc vận hành dữ liệu
- Không chỉnh sửa trực tiếp dữ liệu gốc trong `raw/`.
- Mọi file sinh thêm trong quá trình xử lý nên đặt ở thư mục riêng (sẽ bổ sung ở giai đoạn code).
- Đảm bảo tên file được giữ nguyên để việc parse metadata (`C`, `F`, `s`, `w`) luôn nhất quán.

## 5. Trích dẫn và giấy phép
Nếu sử dụng BBBC005 trong báo cáo hoặc bài viết học thuật, có thể dùng câu trích dẫn khuyến nghị:

"We used the image set BBBC005v1 from the Broad Bioimage Benchmark Collection [Ljosa et al., Nature Methods, 2012]."

Giấy phép:
- Dữ liệu được phát hành theo CC0 (Public Domain).
- Có thể sao chép, chỉnh sửa, phân phối, kể cả mục đích thương mại, không cần xin phép.

## 6. Checklist nhanh trước khi chạy thí nghiệm
- Đã tải đầy đủ dữ liệu BBBC005 vào `data/raw/`.
- Đã tách/đánh dấu tập `F1` vào `data/ground_truth/`.
- Đã thống nhất quy tắc parse `C` và `F` từ tên file.
- Đã ghi rõ nguồn dữ liệu và trích dẫn trong báo cáo.
