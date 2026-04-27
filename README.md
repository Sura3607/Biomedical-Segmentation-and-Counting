# Biomedical Image Segmentation and Object Counting

> **Đề tài 3:** Ứng dụng các phương pháp segmentation (truyền thống & kết hợp Machine Learning) cho bài toán đếm đối tượng trong lĩnh vực y sinh.

---

## Danh sách thành viên

| STT | Họ và Tên | Lớp | MSSV | GitHub |
| :---: | :--- | :---: | :---: | :--- |
| 1 | **Trần Viết Gia Huy** | CS0001 | 31231027056 | @tommyhuy1705 |
| 2 | **Nguyễn Minh Nhựt** | CS0001 | [Mã số] | @username_nhut |
| 3 | **Dương Quang Đông** | CS0001 | [Mã số] | @username_dong |
| 4 | **Nguyễn Minh Huy** | CS0001 | [Mã số] | @username_huy |

---

## Giới thiệu dự án
Dự án này tập trung vào việc giải quyết bài toán phân đoạn (segmentation) và đếm số lượng tế bào sinh học từ hình ảnh vi thể. Trong môi trường y sinh thực tế, hình ảnh thường gặp các vấn đề về chất lượng như mất nét (focus blur) và các tế bào nằm dính chùm vào nhau (clustering). Chúng tôi triển khai và so sánh hiệu quả của các phương pháp Xử lý ảnh truyền thống và Machine Learning để đánh giá độ bền bỉ của chúng đối với các nhiễu ảnh này.

---

## Tập dữ liệu (Dataset)
Dự án sử dụng bộ dữ liệu **BBBC005 (Synthetic cells)** từ Broad Bioimage Benchmark Collection. 

Đây là tập dữ liệu chuyên dụng để kiểm thử các thuật toán đánh giá độ nét (focus metrics) và phân đoạn hình ảnh y sinh thông qua các hình ảnh tế bào được mô phỏng.

* **Nguồn:** [Broad Institute - BBBC005](https://bbbc.broadinstitute.org/BBBC005)
* **Đặc tính hình ảnh:** Toàn bộ là ảnh chụp sàng lọc thông lượng cao (HCS) mô phỏng bằng nền tảng SIMCEP. Các ảnh có xác suất tụ cụm tế bào là 25%. Hiệu ứng mất nét (Focus blur) được mô phỏng qua bộ lọc Gaussian.
* **Định dạng & Số lượng:** Gồm 19,200 ảnh định dạng `8-bit TIF` với kích thước `696 x 520` pixels. Diện tích tế bào/nhân được mô phỏng khớp với tế bào thực Human U2OS.
* **Cấu trúc đặt tên:** Các file được đặt tên theo định dạng khay 384 giếng: `SIMCEPImages_[well]_C[cells]_F[blur]_s[samples]_w[stain].TIF`.
    * `cells`: Chứa số lượng Ground Truth của tế bào (từ 1 đến 100).
    * `blur`: Mức độ mờ nét (từ 1 đến 48).
* **Dữ liệu gán nhãn (Ground Truth):** 1,200 ảnh chứa ký hiệu `F1` là các ảnh in-focus (nét hoàn toàn) đi kèm với nhãn mặt nạ nhị phân (trắng/đen) dùng để đánh giá mô hình.

*(Trích dẫn: We used the image set BBBC005v1 from the Broad Bioimage Benchmark Collection [Ljosa et al., Nature Methods, 2012].)*

---

## Phương pháp & Thuật toán

### 1. Phương pháp Truyền thống (Traditional CV)
* **Tiền xử lý:** Gaussian Blur, Contrast Limited Adaptive Histogram Equalization (CLAHE).
* **Phân đoạn:** Otsu's Global Thresholding / Adaptive Local Thresholding.
* **Tách đối tượng dính liền:** Áp dụng Distance Transform kết hợp **Watershed Algorithm**.
* **Đếm:** Trích xuất Contours và Connected Components.

### 2. Phương pháp Machine Learning
* **Phân đoạn bằng Gom cụm (Clustering):** Sử dụng thuật toán **K-Means Clustering** để tự động phân cụm các pixel thành vùng tế bào và vùng nền dựa trên cường độ màu.
* **(Hoặc) Học giám sát:** Trích xuất đặc trưng pixel và huấn luyện với Support Vector Machine (SVM) / Random Forest *(tùy chọn triển khai)*.

---

## Triển khai Ứng dụng (Web App)
Ứng dụng được xây dựng bằng **Streamlit**, cho phép người dùng tương tác trực tiếp:
* Tải lên hình ảnh tế bào (chọn từ tập BBBC005 với các độ mờ khác nhau).
* Lựa chọn thuật toán (Watershed hoặc K-Means).
* Hiển thị trực quan quá trình xử lý (Bounding box, Mask kết quả).
* Trả về số lượng tế bào đếm được và so sánh sai số với Ground Truth ẩn trong tên file.

## Công nghệ sử dụng
* **Ngôn ngữ:** Python 3.10+
* **Computer Vision:** OpenCV, scikit-image.
* **Machine Learning:** scikit-learn.
* **Web Framework:** Streamlit.
* **Quản lý mã nguồn:** GitHub.

## Hướng dẫn cài đặt

```bash
# 1. Clone repository
git clone [https://github.com/your-org/biomedical-segmentation-and-counting.git](https://github.com/your-org/biomedical-segmentation-and-counting.git)
cd biomedical-segmentation-and-counting

# 2. Tạo môi trường ảo (Khuyến nghị)
python -m venv venv
source venv/bin/activate  # (Với Windows: venv\Scripts\activate)

# 3. Cài đặt các thư viện cần thiết
pip install -r requirements.txt

# 4. Chạy ứng dụng Web
streamlit run app/main.py
