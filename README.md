# MATLAB Demo: RBC Segmentation and Counting

This demo follows the comparison structure:

```text
algorithm segmentation -> shared counting
kmeans segmentation    -> shared counting
```

The counting stage is intentionally shared so the comparison focuses on
segmentation quality first.

## Pipeline

1. Read an RGB blood-cell image.
2. Extract configured color channels for the algorithm baseline.
3. Build `rbc_algorithm_mask` using thresholding and morphology.
4. Build `rbc_kmeans_mask` using pixel-level K-means features.
5. Count each mask with the same methods:
   - connected components
   - watershed
   - area estimate
6. Save masks, overlays, summary table, and metrics if a ground-truth count is configured.

## K-means Segmentation Input

For each pixel, the K-means branch builds this feature row:

```text
[L, A, BLab, S, V, rNorm, gNorm, bNorm, BminusR, RminusG, x, y]
```

Where:

- `L, A, BLab` come from Lab color.
- `S, V` come from HSV.
- `rNorm, gNorm, bNorm` are RGB normalized by `R + G + B`.
- `BminusR` helps identify purple/blue WBC regions.
- `RminusG` helps identify pink/red RBC regions.
- `x, y` are normalized coordinates with a small weight.

K-means clusters pixels into color/position groups. The code then scores each
cluster as RBC, WBC, background, or other. The WBC cluster is excluded from the
RBC mask before cleanup.

## Project Structure

```text
Biomedical-Segmentation-and-Counting/
|-- README.md
|-- config_default.m
|-- setupFinalPath.m
|-- dataset/
|   `-- raw/
|-- docs/
|   |-- evaluation_charts.ipynb
|   |-- report_assets/
|   `-- .gitkeep
|-- methods/
|   |-- countByAreaEstimate.m
|   |-- countByConnectedComponents.m
|   |-- countByWatershed.m
|   |-- countRBCPipeline.m
|   |-- segmentRBC.m
|   |-- segmentRBCKMeans.m
|   |-- segmentWBC.m
|   `-- selectBestChannels.m
|-- report/
|   |-- *.png
|   |-- *.csv
|   `-- demo_result.mat
`-- script/
    |-- cleanupBinaryMask.m
    |-- drawCountOverlay.m
    |-- evaluateCounts.m
    |-- filterCountingMask.m
    `-- showOverlay.m
```

- `report`: stores generated result images, result tables, metrics, and MAT files.
- `docs`: stores report assets and evaluation notebooks.
- `docs/evaluation_charts.ipynb`: evaluation notebook for charts and visual result grids.
- `script`: stores reusable helper functions and standalone utility code.
- `dataset`: stores input data and raw images.
- `methods`: stores segmentation algorithms, counting methods, and model-based methods.
- Root files such as `README.md`, `config_default.m`, and `setupFinalPath.m` stay at the project root.

## Run

Open MATLAB at the repository root:

```matlab
main_demo
```

For MATLAB Mobile/MATLAB Online:

```matlab
mobile_capture_demo
```

If mobile capture fails, the mobile script falls back to the default image.

## Main Outputs

Outputs are saved in:

```text
report/
```

Important files:

- `summary.csv`
- `metrics.csv`
- `kmeans_cluster_stats.csv`
- `demo_result.mat`
- `wbc_algorithm_mask.png`
- `wbc_kmeans_mask.png`
- `rbc_algorithm_mask.png`
- `rbc_kmeans_mask.png`
- `overlay_algorithm.png`
- `overlay_kmeans.png`
- `kmeans_cluster_map.png`
- `count_overlay_algorithm_*.png`
- `count_overlay_kmeans_*.png`

## Required Toolboxes

- Image Processing Toolbox
- Statistics and Machine Learning Toolbox for K-means
- Computer Vision Toolbox is optional for text labels on overlays

If `kmeans` is unavailable, the algorithm segmentation branch still runs and the
K-means segmentation branch returns an empty mask with a diagnostic note.
