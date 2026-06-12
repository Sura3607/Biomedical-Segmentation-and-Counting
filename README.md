# Phân đoạn và Đếm Hồng Cầu (RBC) - Pipeline MATLAB

Đồ án xử lý ảnh y sinh: phân đoạn và đếm hồng cầu (RBC) trên ảnh kính hiển vi máu ngoại vi bằng MATLAB. Dự án so sánh hai nhánh phân đoạn chính:

- **Algorithm segmentation:** xử lý ảnh truyền thống dựa trên kênh màu, ngưỡng, morphology và loại trừ WBC.
- **K-means segmentation:** phân cụm không giám sát từng pixel bằng đặc trưng màu-không gian, sau đó gán cụm thành RBC/WBC/background bằng color-feature scores.

Cả hai nhánh phân đoạn đều sử dụng chung ba phương pháp đếm:

```text
algorithm segmentation -> connected components / watershed / area estimate
K-means segmentation   -> connected components / watershed / area estimate
```

Mục tiêu của repo là xây dựng pipeline MATLAB có khả năng tái lập, trực quan hóa được mask/overlay, và đánh giá định lượng bằng count metrics lẫn pixel metrics trên tập validation/test.

## 1. Tổng quan dự án

Pipeline hiện tại gồm các bước chính:

1. Đọc ảnh máu ngoại vi và metadata ground truth từ `data/metadata_coutingrbc.json`.
2. Tiền xử lý ảnh bằng chuẩn hóa, CLAHE và Gaussian blur.
3. Chọn kênh màu phù hợp cho RBC và WBC.
4. Phân đoạn WBC để tạo vùng loại trừ.
5. Phân đoạn RBC bằng hai nhánh:
   - Nhánh algorithm: threshold + morphology.
   - Nhánh K-means: pixel-level clustering bằng vector đặc trưng màu-không gian.
6. Đếm RBC bằng:
   - Connected components.
   - Watershed.
   - Area estimate.
7. Đánh giá bằng:
   - Count metrics: MAE, RMSE, MAPE, exact-match accuracy, normalized count accuracy.
   - Pixel metrics: accuracy, precision, recall, F1, IoU, AUC.
8. Xuất bảng CSV, biểu đồ, cluster diagnostics và report figures.

K-means trong workflow hiện tại **không dùng persisted annotation-trained model làm nhánh chính**. Thuật toán chạy trực tiếp trên từng ảnh, sau đó gán nhãn cụm bằng các điểm `RBCScore`, `WBCScore` và `BackgroundScore`. Các file `.mat` trong `models/` được giữ lại cho tính tương thích và các script cũ.

## 2. Thành viên và phân công

Bảng phân công được tổng hợp theo GitHub Project hiện tại.

| STT | Thành viên/GitHub | Công việc chính | Trạng thái |
| :--: | :-- | :-- | :--: |
| 1 | `@Sura3607` | Khởi tạo repo và cấu trúc thư mục; viết hàm đếm đối tượng bằng contours/connected components; phụ trách phần phương pháp học máy. | Done |
| 2 | `@Tommyhuy1705` | Cấu hình GitHub Project; tìm kiếm và chốt dataset y sinh; xây dựng phương pháp truyền thống; viết script inference/dự đoán. | Done |
| 3 | `@DDDm3` | Tiền xử lý và làm sạch dữ liệu; xây dựng app/web demo; tính toán metrics so sánh; tham gia báo cáo và slide. | Done |
| 4 | `@ngmhuy05` | Viết hàm parse metadata từ tên file; tham gia báo cáo và slide. | Done |

## 3. Cấu trúc repo

```text
.
|-- RBCApp.m                         # MATLAB app hiển thị kết quả 2x4 report view
|-- config_default.m                 # Cấu hình trung tâm cho pipeline
|-- setupFinalPath.m                 # Thêm các thư mục cần thiết vào MATLAB path
|-- mobile_capture_demo.m            # Demo với ảnh chụp/mobile input
|-- data/
|   `-- metadata_coutingrbc.json     # Metadata: image id, split, ground truth count, annotation path
|-- methods/
|   |-- countRBCPipeline.m           # Pipeline tổng thể
|   |-- selectBestChannels.m         # Tách và chuẩn bị kênh màu
|   |-- segmentWBC.m                 # Phân đoạn WBC để loại trừ
|   |-- segmentRBC.m                 # Nhánh algorithm segmentation
|   |-- segmentRBCKMeans.m           # Nhánh K-means color-feature segmentation
|   |-- buildKMeansPixelFeatures.m   # Tạo feature vector cho từng pixel
|   |-- assignKMeansCentroids.m      # Gán pixel vào centroid gần nhất
|   |-- countRBCMask.m               # Gọi ba phương pháp đếm
|   |-- countByConnectedComponents.m
|   |-- countByWatershed.m
|   |-- countByAreaEstimate.m
|   `-- countSummaryRows.m
|-- script/
|   |-- runRBCEvaluation.m           # Chọn k trên validation và đánh giá test
|   |-- evaluateRBCDataset.m         # Đánh giá từng split/dataset row
|   |-- aggregateEvaluationMetrics.m # Tổng hợp metrics
|   |-- computeBinaryMaskMetrics.m   # Pixel metrics
|   |-- computeCountMetrics.m        # Count metrics
|   |-- readRBCAnnotationMask.m      # Rasterize annotation RBC thành mask
|   |-- loadRBCMetadata.m
|   |-- lookupRBCGroundTruth.m
|   |-- exportKMeansClusterPlots.m
|   |-- exportKMeansScatterPlots.m
|   |-- exportReportSampleFigures.m
|   |-- showOverlay.m
|   |-- drawCountOverlay.m
|   |-- ensureImageMaskSize.m
|   `-- cleanupBinaryMask.m
|-- notebooks/
|   |-- run_evaluations.m            # Script chạy evaluation từ MATLAB
|   |-- evaluations.m                # Bản script của notebook evaluation
|   `-- evaluations.mlx              # Live script evaluation
|-- outputs/
|   |-- metrics/                     # CSV validation/test metrics
|   |-- plots/                       # Biểu đồ đánh giá
|   `-- report_figures/              # Hình report 2x4
|-- models/                          # K-means model artifacts cũ/legacy
`-- README.md
```

## 4. Dataset

Dataset ảnh máu ngoại vi được đặt local trong thư mục `data/`. Repo chỉ track file metadata, còn ảnh và annotation raw thường được ignore để tránh đẩy file lớn lên Git.

Layout mong đợi:

```text
data/
|-- metadata_coutingrbc.json
|-- train/
|   |-- img/
|   `-- ann/
|-- val/
|   |-- img/
|   `-- ann/
`-- test/
    |-- img/
    `-- ann/
```

File `metadata_coutingrbc.json` lưu:

- `id`: tên ảnh, ví dụ `BloodImage_00287.jpeg`.
- `groundTruth`: số RBC ground truth.
- `split`: `train`, `val` hoặc `test`.
- `annotation`: đường dẫn annotation tương ứng.

Ground-truth mask cho pixel metrics được xấp xỉ bằng cách rasterize annotation RBC. Do đó, pixel metrics nên được hiểu là chỉ số so sánh tương đối giữa các phương pháp, không phải biên tế bào ground truth hoàn hảo.

## 5. Phương pháp

### 5.1 Tiền xử lý và chọn kênh

`selectBestChannels.m` tách các kênh RGB, HSV, Lab và một số kênh phái sinh như `RminusG`, `BminusR`, `RratioG`. Cấu hình hiện tại trong `config_default.m` dùng:

- Kênh RBC: `G`
- Kênh WBC: `S`
- CLAHE: `NumTiles = [8 8]`, `ClipLimit = 0.01`
- Gaussian blur: `sigma = 1.2`

### 5.2 Phân đoạn WBC

`segmentWBC.m` kết hợp ngưỡng mean + standard deviation với adaptive threshold. Mask WBC sau đó được làm sạch bằng morphology và dilate thành vùng loại trừ, giúp giảm trường hợp đếm nhầm WBC thành RBC.

### 5.3 Phân đoạn RBC bằng algorithm

`segmentRBC.m` tạo mask RBC bằng các cách:

- Otsu threshold trên kênh RBC đã loại WBC.
- Adaptive threshold.
- Watershed-seed mask.

Mask cuối cùng được làm sạch bằng `cleanupBinaryMask.m`, gồm open/close morphology, fill holes và lọc diện tích nhỏ.

### 5.4 Phân đoạn RBC/WBC bằng K-means

`segmentRBCKMeans.m` xây dựng vector đặc trưng cho từng pixel:

```text
[L, A, BLab, S, V, rNorm, gNorm, bNorm, BminusR, RminusG, x, y]
```

Sau khi chạy K-means, mỗi cụm được thống kê theo giá trị màu trung bình và được gán nhãn bằng:

- `BackgroundScore`
- `WBCScore`
- `RBCScore`

Cụm có WBCScore cao nhất được gán là WBC. Cụm RBC được chọn trong các cụm không phải background/WBC, dựa trên RBCScore và `rbcScoreMargin`.

### 5.5 Đếm RBC

`countRBCMask.m` áp dụng ba cách đếm trên cùng một mask:

1. **Connected components:** mỗi thành phần liên thông hợp lệ được xem là một RBC.
2. **Watershed:** tách các vùng RBC dính nhau bằng distance transform và marker.
3. **Area estimate:** ước lượng số RBC theo diện tích vùng mask so với diện tích tế bào đơn.

## 6. Chạy App

Mở MATLAB tại thư mục gốc repo và chạy:

```matlab
setupFinalPath(pwd)
RBCApp
```

App hỗ trợ:

- Load ảnh máu ngoại vi.
- Chọn segmentation: `Algorithm`, `K-means`, hoặc `Both`.
- Chọn counting method: `Connected components`, `Watershed`, `Area estimate`.
- Chọn số cụm K-means: `k = 2, 3, 4, 5`.
- Hiển thị kết quả theo giao diện report 2x4:
  - Original.
  - Predicted RBC mask.
  - Predicted WBC mask.
  - Combined mask.
  - RBC overlay.
  - Connected components overlay.
  - Watershed overlay.
  - Area estimate overlay.

Nếu MATLAB vẫn giữ class cache cũ, chạy:

```matlab
close all force
clear classes
clear functions
rehash
setupFinalPath(pwd)
RBCApp
```

## 7. Chạy Evaluation

Mở MATLAB tại thư mục gốc repo và chạy:

```matlab
run("notebooks/run_evaluations.m")
```

Workflow evaluation:

1. Load `data/metadata_coutingrbc.json`.
2. Kiểm tra split `train`, `val`, `test`.
3. Chạy color-theory K-means với `k = 2, 3, 4, 5` trên tập `val`.
4. Chọn `k` theo MAE của K-means + Watershed; nếu gần bằng nhau thì ưu tiên pixel F1 cao hơn.
5. Đánh giá hai nhánh Algorithm và K-means tốt nhất trên tập `test`.
6. Xuất CSV metrics, plots và report figures.

Có thể tạo hình report mẫu bằng:

```matlab
config = config_default();
exportReportSampleFigures(config, "BloodImage_00287.jpeg")
```

## 8. Kết quả hiện tại

### 8.1 Lựa chọn k trên validation

Source: `outputs/metrics/validation_k_selection.csv`

| k | Pixel F1 | Pixel AUC | Count MAE | Count RMSE | Normalized Accuracy | Selected |
| --: | --: | --: | --: | --: | --: | :--: |
| 4 | 0.545 | 0.587 | 4.897 | 6.611 | 0.594 | Yes |
| 5 | 0.518 | 0.585 | 5.057 | 6.774 | 0.579 | No |
| 3 | 0.572 | 0.587 | 5.230 | 6.770 | 0.562 | No |
| 2 | 0.489 | 0.517 | 9.080 | 10.339 | 0.239 | No |

Kết quả hiện tại chọn **k = 4** vì có validation count MAE thấp nhất.

### 8.2 Kết quả test summary

Source: `outputs/metrics/test_summary_metrics.csv`

| Method | Images | Count MAE | Count RMSE | Count MAPE (%) | Exact Match | Pixel F1 | Pixel AUC |
| :-- | --: | --: | --: | --: | --: | --: | --: |
| Algorithm + Connected Components | 72 | 5.82 | 6.90 | 48.30 | 1.39% | 0.605 | 0.693 |
| Algorithm + Watershed | 72 | 5.79 | 7.10 | 48.97 | 4.17% | 0.605 | 0.693 |
| Algorithm + Area Estimate | 72 | 168.75 | 230.38 | 1705.00 | 0.00% | 0.605 | 0.693 |
| K-means + Connected Components | 72 | 5.60 | 6.81 | 46.90 | 6.94% | 0.550 | 0.602 |
| K-means + Watershed | 72 | 5.65 | 6.92 | 46.70 | 6.94% | 0.550 | 0.602 |
| K-means + Area Estimate | 72 | 169.99 | 240.08 | 1542.64 | 1.39% | 0.550 | 0.602 |

Nhận xét nhanh:

- Algorithm có pixel F1/AUC cao hơn K-means trên trung bình test set.
- K-means + Connected Components và K-means + Watershed có count MAE thấp nhất.
- Area Estimate không ổn định, sai số rất lớn ở cả hai nhánh.

## 9. Outputs

Kết quả evaluation được xuất vào:

```text
outputs/
|-- metrics/
|   |-- validation_k_selection.csv
|   |-- test_per_image_metrics.csv
|   `-- test_summary_metrics.csv
|-- plots/
|   |-- validation_k_selection.png
|   |-- test_pixel_f1_by_method.png
|   |-- test_count_mae_by_method.png
|   |-- test_auc_by_method.png
|   |-- *_kmeans_cluster_maps.png
|   |-- *_kmeans_pca_scatter_all_k.png
|   `-- *_kmeans_pca_clusters_centroids_all_k.png
`-- report_figures/
    |-- *_algorithm_report.png
    |-- *_algorithm_compact.png
    |-- *_kmeans_report.png
    |-- *_kmeans_compact.png
    `-- *_comparison_report.png
```

Một số hình quan trọng:

- `outputs/plots/validation_k_selection.png`
- `outputs/plots/test_pixel_f1_by_method.png`
- `outputs/plots/test_count_mae_by_method.png`
- `outputs/plots/test_auc_by_method.png`
- `outputs/report_figures/BloodImage_00287_kmeans_report.png`
- `outputs/report_figures/BloodImage_00287_comparison_report.png`

## 10. Toolboxes yêu cầu

- MATLAB R2023a hoặc phiên bản tương thích.
- Image Processing Toolbox.
- Statistics and Machine Learning Toolbox cho `kmeans`.
- Computer Vision Toolbox là tùy chọn; nếu không có, overlay vẫn chạy nhưng có thể không chèn text label bằng `insertText`.

## 11. Ghi chú về phạm vi hiện tại

- Dự án tập trung vào xử lý ảnh truyền thống và học máy không giám sát, không dùng deep learning.
- K-means segmentation hiện tại chạy trực tiếp trên từng ảnh, không phụ thuộc vào model đã train bằng annotation.
- Pixel ground truth mask là mask xấp xỉ từ annotation, nên pixel metrics phù hợp để so sánh tương đối hơn là kết luận biên tế bào tuyệt đối.
- Kết quả count hiện tại vẫn còn MAE khoảng 5–6 RBC với các phương pháp tốt nhất, nên pipeline phù hợp cho mục đích học thuật/thực nghiệm hơn là ứng dụng lâm sàng trực tiếp.
- `Area estimate` được giữ lại làm baseline tham khảo, nhưng không phải phương pháp đếm chính vì sai số lớn.
