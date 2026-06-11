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
annotationPath = datasetAnnotationPath(row, config);
[~, gtCount] = readRBCAnnotationMask(annotationPath, [size(rgb, 1), size(rgb, 2)]);
if ~isnan(row.groundTruth)
    gtCount = row.groundTruth;
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
    modelPath = fullfile(config.modelDir, sprintf("kmeans_rbc_k%d.mat", k));
    if ~isfile(modelPath)
        error("K-means model file not found: %s", modelPath);
    end

    data = load(modelPath, "model");
    model = data.model;
    featureNorm = (featureRaw - model.featureMean) ./ model.featureStd;
    featureNorm(~isfinite(featureNorm)) = 0;
    clusterId = assignKMeansCentroids(featureNorm, model.centroids);

    sampleFeatures = featureNorm(sampleIdx, :);
    sampleClusters = clusterId(sampleIdx);
    [projected, centroidProjected] = projectToTwoDimensions(sampleFeatures, model.centroids);

    nexttile;
    wbcCluster = highestWbcCluster(model);
    plotScatterForK(projected, sampleClusters, model, centroidProjected, wbcCluster);
    title(sprintf("k=%d clusters + centroids | WBC-high=C%d | GT=%d", k, wbcCluster, gtCount), ...
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

function plotScatterForK(projected, clusterId, model, centroidProjected, wbcCluster)
colors = clusterColors(model, wbcCluster);
hold on;

for clusterIdx = 1:model.k
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
lgd = legend(clusterLegendLabels(model, wbcCluster), "Location", "bestoutside", "Interpreter", "none");
lgd.Color = "white";
lgd.TextColor = "black";
lgd.EdgeColor = [0.8 0.8 0.8];
end

function colors = clusterColors(model, wbcCluster)
base = [
    0.85 0.12 0.12
    0.10 0.62 0.22
    0.95 0.55 0.10
    0.55 0.18 0.78
    0.35 0.35 0.35
];
if model.k > size(base, 1)
    base = lines(model.k);
end
colors = base;
colors(wbcCluster, :) = [0.10 0.32 0.90];
end

function labels = clusterLegendLabels(model, wbcCluster)
labels = strings(1, model.k);
for clusterIdx = 1:model.k
    className = clusterClass(model, clusterIdx);
    rbcProb = model.clusterRbcProbability(clusterIdx);
    if isfield(model, "clusterWbcProbability") && ~isempty(model.clusterWbcProbability)
        wbcProb = model.clusterWbcProbability(clusterIdx);
    else
        wbcProb = 0;
    end
    suffix = "";
    if clusterIdx == wbcCluster
        suffix = " | WBC max";
    end
    labels(clusterIdx) = sprintf("C%d %s | RBC %.2f WBC %.2f%s", ...
        clusterIdx, upper(className), rbcProb, wbcProb, suffix);
end
end

function clusterIdx = highestWbcCluster(model)
if isfield(model, "clusterWbcProbability") && ~isempty(model.clusterWbcProbability)
    [~, clusterIdx] = max(model.clusterWbcProbability);
else
    clusterIdx = 1;
end
end

function className = clusterClass(model, clusterIdx)
className = "other";
if isfield(model, "clusterStats") && any(model.clusterStats.Cluster == clusterIdx)
    row = model.clusterStats(model.clusterStats.Cluster == clusterIdx, :);
    if ismember("AssignedClass", string(row.Properties.VariableNames))
        className = string(row.AssignedClass(1));
    end
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
