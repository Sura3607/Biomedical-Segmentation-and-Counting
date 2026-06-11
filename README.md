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
- K-means model choice: `k = 2, 3, 4, 5`

K-means mode loads persisted models from `models/`. Run the evaluation notebook
first if model files are missing.

## Run Evaluation

Open and run:

```text
notebooks/evaluations.mlx
```

If your MATLAB installation cannot open the Live Script file directly, run the
same source as a script:

```matlab
run("notebooks/evaluations.m")
```

The evaluation workflow:

1. Loads `data/metadata_coutingrbc.json`.
2. Trains K-means models for `k = 2, 3, 4, 5` on `data/train`.
3. Selects the best `k` on `data/val` by watershed count MAE. If count MAE is
   effectively tied, the higher pixel F1 wins.
4. Retrains the selected `k` on train+val.
5. Evaluates algorithm and best K-means on `data/test`.

Ground-truth masks for pixel metrics are approximated by rasterizing RBC
annotation rectangles.

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
|   `-- test_auc_by_method.png
```

K-means models are saved to:

```text
models/
|-- kmeans_rbc_k2.mat
|-- kmeans_rbc_k3.mat
|-- kmeans_rbc_k4.mat
|-- kmeans_rbc_k5.mat
`-- kmeans_rbc_best.mat
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
