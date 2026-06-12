# MATLAB RBC Segmentation and Counting

This project compares two RBC segmentation paths and applies shared counting
methods to each mask:

```text
algorithm segmentation -> connected components / watershed / area estimate
K-means segmentation   -> connected components / watershed / area estimate
```

The dataset annotations are expected locally under `data/`, while the tracked
metadata file `data/metadata_coutingrbc.json` stores image id, split, and RBC
ground-truth count.

## Run the App

Open MATLAB at the repository root and run:

```matlab
RBCApp
```

The app supports:

- segmentation choice: algorithm, K-means, or both
- counting method choice: connected components, watershed, or area estimate
- K-means cluster count: `k = 2, 3, 4, 5`

K-means mode clusters the current image and assigns clusters to RBC/WBC/background
with color-feature scores. It does not load persisted annotation-trained models.

## Run Evaluation

Open MATLAB at the repository root and run:

```matlab
run("notebooks/run_evaluations.m")
```

The evaluation workflow:

1. Loads `data/metadata_coutingrbc.json`.
2. Runs color-score K-means for `k = 2, 3, 4, 5` on `data/val`.
3. Selects the best `k` on `data/val` by watershed count MAE. If count MAE is
   effectively tied, the higher pixel F1 wins.
4. Evaluates algorithm and best K-means on `data/test`.
5. Exports validation/test plots plus K-means cluster/scatter diagnostics and
   report figures.

Ground-truth masks for pixel metrics are approximated by rasterizing RBC
annotation rectangles. K-means segmentation itself does not use those annotation
masks.

## Outputs

Evaluation artifacts are written to:

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
|   `-- *_kmeans_pca_clusters_centroids_all_k.png
`-- report_figures/
    |-- *_algorithm_report.png
    |-- *_kmeans_report.png
    `-- *_comparison_report.png
```

## Metrics

The evaluation computes:

- count metrics: MAE, RMSE, MAPE, exact-match accuracy, normalized count accuracy
- pixel metrics: accuracy, precision, recall, F1, IoU, ROC/AUC
- validation K-selection metrics and plots
- final test comparison plots for algorithm vs K-means/counting methods

Per-image overlays are disabled by default to avoid generating hundreds of
images. Set `config.evaluation.saveTestOverlays = true` in `config_default.m`
if you need them.

## Dataset Layout

Expected local layout:

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

Raw dataset files under `data/` are ignored by Git except
`data/metadata_coutingrbc.json`.

## Required Toolboxes

- Image Processing Toolbox
- Statistics and Machine Learning Toolbox for K-means
- Computer Vision Toolbox is optional for text labels on overlays
