function exportKMeansScatterPlots(config, imageId)
%EXPORTKMEANSSCATTERPLOTS Save PCA scatter plots for K-means clusters.

if nargin < 1 || isempty(config)
    config = config_default();
end

setupFinalPath(config.projectRoot);

if nargin < 2 || strlength(string(imageId)) == 0
    imageId = "BloodImage_00287.jpeg";
else
    imageId = string(imageId);
end

metadata = loadRBCMetadata(config.metadataPath);
row = metadata(metadata.id == imageId, :);
if isempty(row)
    error("Image id not found in metadata: %s", imageId);
end
row = row(1, :);

rgb = imread(datasetImagePath(row, config));
gtCount = row.groundTruth;
if isnan(gtCount)
    gtLabel = "GT=n/a";
else
    gtLabel = sprintf("GT=%d", gtCount);
end

[featureRaw, ~] = buildKMeansPixelFeatures(rgb, config);
sampleIdx = selectScatterSample(size(featureRaw, 1), 9000, config.ml.kmeans.randomSeed);

plotsDir = fullfile(config.outputDir, "plots");
if ~isfolder(plotsDir)
    mkdir(plotsDir);
end

candidateK = config.ml.kmeans.training.candidateK;
fig = createScatterFigure([1650 980]);
tiledlayout(fig, 2, 2, "Padding", "compact", "TileSpacing", "compact");

for i = 1:numel(candidateK)
    k = candidateK(i);
    plotConfig = config;
    plotConfig.ml.kmeans.k = k;
    plotConfig.ml.kmeans.modelPath = "";
    prediction = segmentRBCKMeans(rgb, plotConfig);

    featureNorm = (featureRaw - prediction.featureMean) ./ prediction.featureStd;
    featureNorm(~isfinite(featureNorm)) = 0;
    clusterId = prediction.clusterMap(:);

    sampleFeatures = featureNorm(sampleIdx, :);
    sampleClusters = clusterId(sampleIdx);
    [projected, centroidProjected] = projectToTwoDimensions(sampleFeatures, prediction.centroids);

    nexttile;
    plotScatterForK(projected, sampleClusters, prediction, centroidProjected);
    title(sprintf("k=%d color-score clusters | %s", k, char(gtLabel)), ...
        "Color", "black", "Interpreter", "none");
end

exportPath = fullfile(plotsDir, sprintf("%s_kmeans_pca_clusters_centroids_all_k.png", erase(char(imageId), ".jpeg")));
exportgraphics(fig, exportPath, "BackgroundColor", "white", "Resolution", 160);
close(fig);
end

function sampleIdx = selectScatterSample(rowCount, maxRows, seed)
sampleIdx = (1:rowCount)';
if rowCount > maxRows
    rng(seed);
    sampleIdx = sort(randperm(rowCount, maxRows)');
end
end

function [projected, centroidProjected] = projectToTwoDimensions(features, centroids)
featureMean = mean(features, 1);
centeredFeatures = features - featureMean;
try
    [coeff, score] = pca(centeredFeatures, "NumComponents", 2);
    projected = score(:, 1:2);
catch
    [~, ~, v] = svd(centeredFeatures, "econ");
    coeff = v(:, 1:2);
    projected = centeredFeatures * coeff;
end

centroidProjected = (centroids - featureMean) * coeff(:, 1:2);
end

function plotScatterForK(projected, clusterId, prediction, centroidProjected)
colors = clusterColors(prediction);
hold on;

for clusterIdx = 1:prediction.k
    mask = clusterId == clusterIdx;
    scatter(projected(mask, 1), projected(mask, 2), 7, ...
        "MarkerFaceColor", colors(clusterIdx, :), ...
        "MarkerEdgeColor", "none", ...
        "MarkerFaceAlpha", 0.35);

    scatter(centroidProjected(clusterIdx, 1), centroidProjected(clusterIdx, 2), 150, ...
        "Marker", "x", ...
        "MarkerEdgeColor", [0 0 0], ...
        "LineWidth", 2.4, ...
        "HandleVisibility", "off");

    text(centroidProjected(clusterIdx, 1), centroidProjected(clusterIdx, 2), ...
        sprintf(" C%d", clusterIdx), ...
        "Color", "black", ...
        "FontWeight", "bold", ...
        "Interpreter", "none");
end

hold off;
grid on;
box on;
xlabel("PC1");
ylabel("PC2");
lgd = legend(clusterLegendLabels(prediction), "Location", "bestoutside", "Interpreter", "none");
lgd.Color = "white";
lgd.TextColor = "black";
lgd.EdgeColor = [0.8 0.8 0.8];
end

function colors = clusterColors(prediction)
base = [
    0.85 0.12 0.12
    0.10 0.62 0.22
    0.95 0.55 0.10
    0.55 0.18 0.78
    0.35 0.35 0.35
];
if prediction.k > size(base, 1)
    base = lines(prediction.k);
end
colors = base;
if ~isempty(prediction.wbcClusters)
    colors(prediction.wbcClusters, :) = repmat([0.10 0.32 0.90], numel(prediction.wbcClusters), 1);
end
if ~isempty(prediction.rbcClusters)
    colors(prediction.rbcClusters, :) = repmat([0.85 0.12 0.12], numel(prediction.rbcClusters), 1);
end
end

function labels = clusterLegendLabels(prediction)
labels = strings(1, prediction.k);
for clusterIdx = 1:prediction.k
    className = clusterClass(prediction.clusterStats, clusterIdx);
    row = prediction.clusterStats(prediction.clusterStats.Cluster == clusterIdx, :);
    rbcScore = row.RBCScore(1);
    wbcScore = row.WBCScore(1);
    suffix = "";
    if any(prediction.wbcClusters == clusterIdx)
        suffix = " | WBC max-score";
    end
    labels(clusterIdx) = sprintf("C%d %s | RBCscore %.2f WBCscore %.2f%s", ...
        clusterIdx, upper(className), rbcScore, wbcScore, suffix);
end
end

function className = clusterClass(clusterStats, clusterIdx)
className = "other";
if any(clusterStats.Cluster == clusterIdx)
    row = clusterStats(clusterStats.Cluster == clusterIdx, :);
    className = string(row.AssignedClass(1));
end
end

function fig = createScatterFigure(position)
fig = figure("Visible", "off", "Color", "white", "InvertHardcopy", "off");
fig.Position = [80 80 position];
set(fig, "DefaultAxesColor", "white");
set(fig, "DefaultAxesXColor", "black");
set(fig, "DefaultAxesYColor", "black");
set(fig, "DefaultAxesGridColor", [0.65 0.65 0.65]);
set(fig, "DefaultTextColor", "black");
end
