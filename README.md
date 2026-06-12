# Biomedical Segmentation and Counting - MATLAB RBC Pipeline

Do an xu ly anh y sinh: phan doan va dem hong cau (RBC) tren anh kinh hien vi mau ngoai vi bang MATLAB. Du an so sanh hai nhanh phan doan chinh:

- **Algorithm segmentation:** xu ly anh truyen thong dua tren kenh mau, nguong, morphology va loai tru WBC.
- **K-means segmentation:** phan cum khong giam sat tung pixel bang dac trung mau-khong gian, sau do gan cum thanh RBC/WBC/background bang color-feature scores.

Ca hai nhanh phan doan deu su dung chung ba phuong phap dem:

```text
algorithm segmentation -> connected components / watershed / area estimate
K-means segmentation   -> connected components / watershed / area estimate
```

Muc tieu cua repo la xay dung pipeline MATLAB co kha nang tai lap, truc quan hoa duoc mask/overlay, va danh gia dinh luong bang count metrics lan pixel metrics tren tap validation/test.

## 1. Tong quan du an

Pipeline hien tai gom cac buoc chinh:

1. Doc anh mau ngoai vi va metadata ground truth tu `data/metadata_coutingrbc.json`.
2. Tien xu ly anh bang chuan hoa, CLAHE va Gaussian blur.
3. Chon kenh mau phu hop cho RBC va WBC.
4. Phan doan WBC de tao vung loai tru.
5. Phan doan RBC bang hai nhanh:
   - Nhanh algorithm: threshold + morphology.
   - Nhanh K-means: pixel-level clustering bang vector dac trung mau-khong gian.
6. Dem RBC bang:
   - Connected components.
   - Watershed.
   - Area estimate.
7. Danh gia bang:
   - Count metrics: MAE, RMSE, MAPE, exact-match accuracy, normalized count accuracy.
   - Pixel metrics: accuracy, precision, recall, F1, IoU, AUC.
8. Xuat bang CSV, bieu do, cluster diagnostics va report figures.

K-means trong workflow hien tai **khong dung persisted annotation-trained model lam nhanh chinh**. Thuat toan chay truc tiep tren tung anh, sau do gan nhan cum bang cac diem `RBCScore`, `WBCScore` va `BackgroundScore`. Cac file `.mat` trong `models/` duoc giu lai cho tinh tuong thich va cac script cu.

## 2. Thanh vien va phan cong

Bang phan cong duoc tong hop theo GitHub Project hien tai.

| STT | Thanh vien/GitHub | Cong viec chinh | Trang thai |
| :--: | :-- | :-- | :--: |
| 1 | `@Sura3607` | Khoi tao repo va cau truc thu muc; viet ham dem doi tuong bang contours/connected components; phu trach phan phuong phap hoc may. | Done |
| 2 | `@Tommyhuy1705` | Cau hinh GitHub Project; tim kiem va chot dataset y sinh; xay dung phuong phap truyen thong; viet script inference/du doan. | Done |
| 3 | `@DDDm3` | Tien xu ly va lam sach du lieu; xay dung app/web demo; tinh toan metrics so sanh; tham gia bao cao va slide. | Done |
| 4 | `@ngmhuy05` | Viet ham parse metadata tu ten file; tham gia bao cao va slide. | Done |

## 3. Cau truc repo

```text
.
|-- RBCApp.m                         # MATLAB app hien thi ket qua 2x4 report view
|-- config_default.m                 # Cau hinh trung tam cho pipeline
|-- setupFinalPath.m                 # Them cac thu muc can thiet vao MATLAB path
|-- mobile_capture_demo.m            # Demo voi anh chup/mobile input
|-- data/
|   `-- metadata_coutingrbc.json     # Metadata: image id, split, ground truth count, annotation path
|-- methods/
|   |-- countRBCPipeline.m           # Pipeline tong the
|   |-- selectBestChannels.m         # Tach va chuan bi kenh mau
|   |-- segmentWBC.m                 # Phan doan WBC de loai tru
|   |-- segmentRBC.m                 # Nhanh algorithm segmentation
|   |-- segmentRBCKMeans.m           # Nhanh K-means color-feature segmentation
|   |-- buildKMeansPixelFeatures.m   # Tao feature vector cho tung pixel
|   |-- assignKMeansCentroids.m      # Gan pixel vao centroid gan nhat
|   |-- countRBCMask.m               # Goi ba phuong phap dem
|   |-- countByConnectedComponents.m
|   |-- countByWatershed.m
|   |-- countByAreaEstimate.m
|   `-- countSummaryRows.m
|-- script/
|   |-- runRBCEvaluation.m           # Chon k tren validation va danh gia test
|   |-- evaluateRBCDataset.m         # Danh gia tung split/dataset row
|   |-- aggregateEvaluationMetrics.m # Tong hop metrics
|   |-- computeBinaryMaskMetrics.m   # Pixel metrics
|   |-- computeCountMetrics.m        # Count metrics
|   |-- readRBCAnnotationMask.m      # Rasterize annotation RBC thanh mask
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
|   |-- run_evaluations.m            # Script chay evaluation tu MATLAB
|   |-- evaluations.m                # Ban script cua notebook evaluation
|   `-- evaluations.mlx              # Live script evaluation
|-- outputs/
|   |-- metrics/                     # CSV validation/test metrics
|   |-- plots/                       # Bieu do danh gia
|   `-- report_figures/              # Hinh report 2x4
|-- models/                          # K-means model artifacts cu/legacy
`-- README.md
```

## 4. Dataset

Dataset anh mau ngoai vi duoc dat local trong thu muc `data/`. Repo chi track file metadata, con anh va annotation raw thuong duoc ignore de tranh day file lon len Git.

Layout mong doi:

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

File `metadata_coutingrbc.json` luu:

- `id`: ten anh, vi du `BloodImage_00287.jpeg`.
- `groundTruth`: so RBC ground truth.
- `split`: `train`, `val` hoac `test`.
- `annotation`: duong dan annotation tuong ung.

Ground-truth mask cho pixel metrics duoc xap xi bang cach rasterize annotation RBC. Do do, pixel metrics nen duoc hieu la chi so so sanh tuong doi giua cac phuong phap, khong phai bien te bao ground truth hoan hao.

## 5. Phuong phap

### 5.1 Tien xu ly va chon kenh

`selectBestChannels.m` tach cac kenh RGB, HSV, Lab va mot so kenh phai sinh nhu `RminusG`, `BminusR`, `RratioG`. Cau hinh hien tai trong `config_default.m` dung:

- Kenh RBC: `G`
- Kenh WBC: `S`
- CLAHE: `NumTiles = [8 8]`, `ClipLimit = 0.01`
- Gaussian blur: `sigma = 1.2`

### 5.2 Phan doan WBC

`segmentWBC.m` ket hop nguong mean + standard deviation voi adaptive threshold. Mask WBC sau do duoc lam sach bang morphology va dilate thanh vung loai tru, giup giam truong hop dem nham WBC thanh RBC.

### 5.3 Phan doan RBC bang algorithm

`segmentRBC.m` tao mask RBC bang cac cach:

- Otsu threshold tren kenh RBC da loai WBC.
- Adaptive threshold.
- Watershed-seed mask.

Mask cuoi cung duoc lam sach bang `cleanupBinaryMask.m`, gom open/close morphology, fill holes va loc dien tich nho.

### 5.4 Phan doan RBC/WBC bang K-means

`segmentRBCKMeans.m` xay dung vector dac trung cho tung pixel:

```text
[L, A, BLab, S, V, rNorm, gNorm, bNorm, BminusR, RminusG, x, y]
```

Sau khi chay K-means, moi cum duoc thong ke theo gia tri mau trung binh va duoc gan nhan bang:

- `BackgroundScore`
- `WBCScore`
- `RBCScore`

Cum co WBCScore cao nhat duoc gan la WBC. Cum RBC duoc chon trong cac cum khong phai background/WBC, dua tren RBCScore va `rbcScoreMargin`.

### 5.5 Dem RBC

`countRBCMask.m` ap dung ba cach dem tren cung mot mask:

1. **Connected components:** moi thanh phan lien thong hop le duoc xem la mot RBC.
2. **Watershed:** tach cac vung RBC dinh nhau bang distance transform va marker.
3. **Area estimate:** uoc luong so RBC theo dien tich vung mask so voi dien tich te bao don.

## 6. Chay App

Mo MATLAB tai thu muc goc repo va chay:

```matlab
setupFinalPath(pwd)
RBCApp
```

App ho tro:

- Load anh mau ngoai vi.
- Chon segmentation: `Algorithm`, `K-means`, hoac `Both`.
- Chon counting method: `Connected components`, `Watershed`, `Area estimate`.
- Chon so cum K-means: `k = 2, 3, 4, 5`.
- Hien thi ket qua theo giao dien report 2x4:
  - Original.
  - Predicted RBC mask.
  - Predicted WBC mask.
  - Combined mask.
  - RBC overlay.
  - Connected components overlay.
  - Watershed overlay.
  - Area estimate overlay.

Neu MATLAB van giu class cache cu, chay:

```matlab
close all force
clear classes
clear functions
rehash
setupFinalPath(pwd)
RBCApp
```

## 7. Chay Evaluation

Mo MATLAB tai thu muc goc repo va chay:

```matlab
run("notebooks/run_evaluations.m")
```

Workflow evaluation:

1. Load `data/metadata_coutingrbc.json`.
2. Kiem tra split `train`, `val`, `test`.
3. Chay color-theory K-means voi `k = 2, 3, 4, 5` tren tap `val`.
4. Chon `k` theo MAE cua K-means + Watershed; neu gan bang nhau thi uu tien pixel F1 cao hon.
5. Danh gia hai nhanh Algorithm va K-means tot nhat tren tap `test`.
6. Xuat CSV metrics, plots va report figures.

Co the tao hinh report mau bang:

```matlab
config = config_default();
exportReportSampleFigures(config, "BloodImage_00287.jpeg")
```

## 8. Ket qua hien tai

### 8.1 Lua chon k tren validation

Source: `outputs/metrics/validation_k_selection.csv`

| k | Pixel F1 | Pixel AUC | Count MAE | Count RMSE | Normalized Accuracy | Selected |
| --: | --: | --: | --: | --: | --: | :--: |
| 4 | 0.545 | 0.587 | 4.897 | 6.611 | 0.594 | Yes |
| 5 | 0.518 | 0.585 | 5.057 | 6.774 | 0.579 | No |
| 3 | 0.572 | 0.587 | 5.230 | 6.770 | 0.562 | No |
| 2 | 0.489 | 0.517 | 9.080 | 10.339 | 0.239 | No |

Ket qua hien tai chon **k = 4** vi co validation count MAE thap nhat.

### 8.2 Ket qua test summary

Source: `outputs/metrics/test_summary_metrics.csv`

| Method | Images | Count MAE | Count RMSE | Count MAPE (%) | Exact Match | Pixel F1 | Pixel AUC |
| :-- | --: | --: | --: | --: | --: | --: | --: |
| Algorithm + Connected Components | 72 | 5.82 | 6.90 | 48.30 | 1.39% | 0.605 | 0.693 |
| Algorithm + Watershed | 72 | 5.79 | 7.10 | 48.97 | 4.17% | 0.605 | 0.693 |
| Algorithm + Area Estimate | 72 | 168.75 | 230.38 | 1705.00 | 0.00% | 0.605 | 0.693 |
| K-means + Connected Components | 72 | 5.60 | 6.81 | 46.90 | 6.94% | 0.550 | 0.602 |
| K-means + Watershed | 72 | 5.65 | 6.92 | 46.70 | 6.94% | 0.550 | 0.602 |
| K-means + Area Estimate | 72 | 169.99 | 240.08 | 1542.64 | 1.39% | 0.550 | 0.602 |

Nhan xet nhanh:

- Algorithm co pixel F1/AUC cao hon K-means tren trung binh test set.
- K-means + Connected Components va K-means + Watershed co count MAE thap nhat.
- Area Estimate khong on dinh, sai so rat lon o ca hai nhanh.

## 9. Outputs

Ket qua evaluation duoc xuat vao:

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

Mot so hinh quan trong:

- `outputs/plots/validation_k_selection.png`
- `outputs/plots/test_pixel_f1_by_method.png`
- `outputs/plots/test_count_mae_by_method.png`
- `outputs/plots/test_auc_by_method.png`
- `outputs/report_figures/BloodImage_00287_kmeans_report.png`
- `outputs/report_figures/BloodImage_00287_comparison_report.png`

## 10. Toolboxes yeu cau

- MATLAB R2023a hoac phien ban tuong thich.
- Image Processing Toolbox.
- Statistics and Machine Learning Toolbox cho `kmeans`.
- Computer Vision Toolbox la tuy chon; neu khong co, overlay van chay nhung co the khong chen text label bang `insertText`.

## 11. Ghi chu ve pham vi hien tai

- Du an tap trung vao xu ly anh truyen thong va hoc may khong giam sat, khong dung deep learning.
- K-means segmentation hien tai chay truc tiep tren tung anh, khong phu thuoc vao model da train bang annotation.
- Pixel ground truth mask la mask xap xi tu annotation, nen pixel metrics phu hop de so sanh tuong doi hon la ket luan bien te bao tuyet doi.
- Ket qua count hien tai van con MAE khoang 5-6 RBC voi cac phuong phap tot nhat, nen pipeline phu hop cho muc dich hoc thuat/thuc nghiem hon la ung dung lam sang truc tiep.
- `Area estimate` duoc giu lai lam baseline tham khao, nhung khong phai phuong phap dem chinh vi sai so lon.
