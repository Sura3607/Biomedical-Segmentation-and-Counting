function exportKMeansClusterPlots(config, imageId)
%EXPORTKMEANSCLUSTERPLOTS Save K-means cluster maps for candidate k values.

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

plotsDir = fullfile(config.outputDir, "plots");
if ~isfolder(plotsDir)
    mkdir(plotsDir);
end

candidateK = config.ml.kmeans.training.candidateK;
fig = createClusterFigure([1700 780]);
tiledlayout(fig, 2, numel(candidateK), "Padding", "compact", "TileSpacing", "compact");

for i = 1:numel(candidateK)
    k = candidateK(i);
    plotConfig = config;
    plotConfig.ml.kmeans.k = k;
    plotConfig.ml.kmeans.modelPath = "";
    prediction = segmentRBCKMeans(rgb, plotConfig);
    counts = countRBCMask(prediction.maskFinal, rgb, config);

    nexttile(i);
    imshow(clusterMapImage(prediction.clusterMap, k));
    title(sprintf("k=%d clusters | CC=%d", k, counts.connectedComponents.count), ...
        "Color", "black", "Interpreter", "none");

    nexttile(numel(candidateK) + i);
    plotClusterScores(prediction.clusterStats);
    title(sprintf("k=%d cluster color scores", k), ...
        "Color", "black", "Interpreter", "none");
end

exportPath = fullfile(plotsDir, sprintf("%s_kmeans_cluster_maps.png", erase(char(imageId), ".jpeg")));
exportgraphics(fig, exportPath, "BackgroundColor", "white", "Resolution", 160);
close(fig);
end

function img = clusterMapImage(clusterMap, k)
colors = [
    230 25 75
    60 180 75
    0 130 200
    245 130 48
    145 30 180
] ./ 255;

if k > size(colors, 1)
    colors = lines(k);
end

img = zeros([size(clusterMap), 3]);
for clusterIdx = 1:k
    mask = clusterMap == clusterIdx;
    for channel = 1:3
        current = img(:, :, channel);
        current(mask) = colors(clusterIdx, channel);
        img(:, :, channel) = current;
    end
end

img = im2uint8(img);
end

function plotClusterScores(clusterStats)
x = clusterStats.Cluster;
rbc = normalizeScore(clusterStats.RBCScore);
wbc = normalizeScore(clusterStats.WBCScore);

b = bar(x, [rbc, wbc], "grouped");
b(1).FaceColor = [0.85 0.12 0.12];
b(2).FaceColor = [0.10 0.32 0.90];
ylim([0 1]);
xlabel("Cluster");
ylabel("Normalized score");
lgd = legend(["RBC", "WBC"], "Location", "northoutside", "Orientation", "horizontal");
lgd.Color = "white";
lgd.TextColor = "black";
grid on;
end

function out = normalizeScore(values)
values = double(values(:));
minValue = min(values);
maxValue = max(values);
if maxValue > minValue
    out = (values - minValue) ./ (maxValue - minValue);
else
    out = zeros(size(values));
end
end

function fig = createClusterFigure(position)
fig = figure("Visible", "off", "Color", "white", "InvertHardcopy", "off");
fig.Position = [80 80 position];
set(fig, "DefaultAxesColor", "white");
set(fig, "DefaultAxesXColor", "black");
set(fig, "DefaultAxesYColor", "black");
set(fig, "DefaultAxesGridColor", [0.65 0.65 0.65]);
set(fig, "DefaultTextColor", "black");
end

function showTile(img, titleText)
nexttile;
imshow(img);
title(titleText, "Color", "black", "Interpreter", "none");
end
