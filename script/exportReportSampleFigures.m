function exportReportSampleFigures(config, imageId)
%EXPORTREPORTSAMPLEFIGURES Save synchronized report figures for one image.

if nargin < 1 || isempty(config)
    config = config_default();
end

if nargin < 2 || strlength(string(imageId)) == 0
    imageId = selectBestKMeansSample(config);
else
    imageId = string(imageId);
end

setupFinalPath(config.projectRoot);
metadata = loadRBCMetadata(config.metadataPath);
row = metadata(metadata.id == imageId, :);
if isempty(row)
    error("Image id not found in metadata: %s", imageId);
end
row = row(1, :);

imagePath = datasetImagePath(row, config);
rgb = imread(imagePath);
if ~isnan(row.groundTruth)
    gtCount = row.groundTruth;
else
    annotationPath = datasetAnnotationPath(row, config);
    [~, gtCount] = readRBCAnnotationMask(annotationPath, [size(rgb, 1), size(rgb, 2)]);
end

channelInfo = selectBestChannels(rgb, config);
wbcAlgorithm = segmentWBC(rgb, channelInfo.wbc, config);
rbcAlgorithm = segmentRBC(rgb, channelInfo.rbc, wbcAlgorithm.maskForExclusion, config);
algorithmCounts = countRBCMask(rbcAlgorithm.maskFinal, rgb, config);

kmeansConfig = config;
kmeansConfig.ml.kmeans.k = selectedKMeansK(config);
kmeansConfig.ml.kmeans.modelPath = "";
kmeansPrediction = segmentRBCKMeans(rgb, kmeansConfig);
kmeansCounts = countRBCMask(kmeansPrediction.maskFinal, rgb, config);

reportDir = fullfile(config.outputDir, "report_figures");
if ~isfolder(reportDir)
    mkdir(reportDir);
end

exportOneComposite(reportDir, "algorithm", rgb, wbcAlgorithm.mask, ...
    rbcAlgorithm.maskFinal, algorithmCounts, gtCount, row.id);
exportOneComposite(reportDir, "kmeans", rgb, kmeansPrediction.maskWBC, ...
    kmeansPrediction.maskFinal, kmeansCounts, gtCount, row.id, kmeansConfig.ml.kmeans.k);
exportComparisonComposite(reportDir, rgb, wbcAlgorithm.mask, rbcAlgorithm.maskFinal, ...
    kmeansPrediction.maskWBC, kmeansPrediction.maskFinal, algorithmCounts, kmeansCounts, ...
    gtCount, row.id, kmeansConfig.ml.kmeans.k);

end

function imageId = selectBestKMeansSample(config)
metricsPath = fullfile(config.outputDir, "metrics", "test_per_image_metrics.csv");
if ~isfile(metricsPath)
    error("Metrics file not found. Run notebooks/run_evaluations.m first: %s", metricsPath);
end

rows = readtable(metricsPath, "TextType", "string");
rows = rows(rows.method == "kmeans_connected_components", :);
rows = sortrows(rows, {'absoluteError', 'pixelF1'}, {'ascend', 'descend'});
imageId = rows.imageId(1);

try
    metadata = loadRBCMetadata(config.metadataPath);
    imageId = selectBestWbcAwareSample(rows, metadata, config, selectedKMeansK(config));
catch
    imageId = rows.imageId(1);
end
end

function imageId = selectBestWbcAwareSample(rows, metadata, config, k)
fallback = rows.imageId(1);
bestAnyWbc = "";
kmeansConfig = config;
kmeansConfig.ml.kmeans.k = k;
kmeansConfig.ml.kmeans.modelPath = "";

for i = 1:height(rows)
    row = metadata(metadata.id == rows.imageId(i), :);
    if isempty(row)
        continue;
    end

    rgb = imread(datasetImagePath(row(1, :), kmeansConfig));
    prediction = segmentRBCKMeans(rgb, kmeansConfig);
    wbcRatio = nnz(prediction.maskWBC) / numel(prediction.maskWBC);

    if wbcRatio >= 0.005 && bestAnyWbc == ""
        bestAnyWbc = rows.imageId(i);
    end

    if wbcRatio >= 0.005 && rows.absoluteError(i) <= 5
        imageId = rows.imageId(i);
        return;
    end
end

if bestAnyWbc ~= ""
    imageId = bestAnyWbc;
else
    imageId = fallback;
end
end

function k = selectedKMeansK(config)
k = config.ml.kmeans.k;
selectionPath = fullfile(config.outputDir, "metrics", "validation_k_selection.csv");
if ~isfile(selectionPath)
    return;
end

rows = readtable(selectionPath, "TextType", "string");
if isempty(rows) || ~ismember("isSelected", string(rows.Properties.VariableNames))
    return;
end

selectedRows = rows(logical(rows.isSelected), :);
if ~isempty(selectedRows)
    k = selectedRows.k(1);
end
end

function exportOneComposite(reportDir, name, rgb, wbcMask, rbcMask, counts, gtCount, imageId, k)
if nargin < 9
    k = [];
end

countCC = counts.connectedComponents.count;
countWatershed = counts.watershed.count;
countArea = counts.areaEstimate.count;
rbcOverlay = showOverlay(rgb, rbcMask, [1 0 0], 0.35);
combinedMask = classMaskImage(rbcMask, wbcMask);

fig = createReportFigure([1650 760]);
tiledlayout(fig, 2, 4, "Padding", "compact", "TileSpacing", "compact");

titlePrefix = sprintf("%s | GT=%d | CC=%d | WS=%d | Area=%d", ...
    upper(char(name)), gtCount, countCC, countWatershed, countArea);
if ~isempty(k)
    titlePrefix = sprintf("%s | k=%d", titlePrefix, k);
end

showTile(rgb, "Original");
showTile(rbcMask, "Predicted RBC mask");
showTile(wbcMask, "Predicted WBC mask");
showTile(combinedMask, "Combined mask");
showTile(rbcOverlay, "RBC overlay");
showTile(counts.connectedComponents.overlay, sprintf("Connected components | Count=%d", countCC));
showTile(counts.watershed.overlay, sprintf("Watershed | Count=%d", countWatershed));
showTile(counts.areaEstimate.overlay, sprintf("Area estimate | Count=%d", countArea));

sgtitle(fig, sprintf("%s - %s", char(imageId), titlePrefix), "Color", "black", "Interpreter", "none");
exportgraphics(fig, fullfile(reportDir, sprintf("%s_%s_report.png", erase(char(imageId), ".jpeg"), name)), ...
    "BackgroundColor", "white", "Resolution", 160);
close(fig);

fig = createReportFigure([1650 500]);
tiledlayout(fig, 1, 5, "Padding", "compact", "TileSpacing", "compact");
showTile(rgb, "Original");
showTile(rbcMask, "Predicted RBC mask");
showTile(wbcMask, "Predicted WBC mask");
showTile(combinedMask, "Combined mask");
showTile(rbcOverlay, "RBC overlay");
sgtitle(fig, sprintf("%s - %s compact", char(imageId), upper(char(name))), "Color", "black", "Interpreter", "none");
exportgraphics(fig, fullfile(reportDir, sprintf("%s_%s_compact.png", erase(char(imageId), ".jpeg"), name)), ...
    "BackgroundColor", "white", "Resolution", 160);
close(fig);
end

function exportComparisonComposite(reportDir, rgb, algorithmWbcMask, algorithmRbcMask, kmeansWbcMask, kmeansRbcMask, algorithmCounts, kmeansCounts, gtCount, imageId, k)
algorithmCount = algorithmCounts.connectedComponents.count;
kmeansCount = kmeansCounts.connectedComponents.count;

fig = createReportFigure([1650 760]);
tiledlayout(fig, 2, 4, "Padding", "compact", "TileSpacing", "compact");
showTile(rgb, sprintf("Original | GT=%d", gtCount));
showTile(algorithmRbcMask, sprintf("Algorithm RBC mask | CC=%d", algorithmCount));
showTile(algorithmWbcMask, "Algorithm WBC mask");
showTile(classMaskImage(algorithmRbcMask, algorithmWbcMask), "Algorithm combined mask");
showTile(kmeansRbcMask, sprintf("K-means RBC mask | k=%d | CC=%d", k, kmeansCount));
showTile(kmeansWbcMask, "K-means WBC mask");
showTile(classMaskImage(kmeansRbcMask, kmeansWbcMask), "K-means combined mask");
showTile(sideBySideOverlay(rgb, algorithmRbcMask, kmeansRbcMask), "RBC overlays | Algorithm / K-means");
exportgraphics(fig, fullfile(reportDir, sprintf("%s_comparison_report.png", erase(char(imageId), ".jpeg"))), ...
    "BackgroundColor", "white", "Resolution", 160);
close(fig);
end

function maskImg = classMaskImage(rbcMask, wbcMask)
maskImg = ones([size(rbcMask), 3], "uint8") * 255;
rbcMask = logical(rbcMask);
wbcMask = logical(wbcMask);

maskImg = paintMask(maskImg, rbcMask, uint8([220 40 40]));
maskImg = paintMask(maskImg, wbcMask, uint8([40 90 230]));
end

function img = paintMask(img, mask, color)
for c = 1:3
    channel = img(:, :, c);
    channel(mask) = color(c);
    img(:, :, c) = channel;
end
end

function img = sideBySideOverlay(rgb, algorithmMask, kmeansMask)
algorithmOverlay = showOverlay(rgb, algorithmMask, [1 0 0], 0.35);
kmeansOverlay = showOverlay(rgb, kmeansMask, [1 0 0], 0.35);
separator = uint8(ones(size(rgb, 1), 8, 3) * 255);
img = cat(2, algorithmOverlay, separator, kmeansOverlay);
end

function fig = createReportFigure(position)
if nargin < 1
    position = [1400 760];
end
fig = figure("Visible", "off", "Color", "white", "InvertHardcopy", "off");
fig.Position = [80 80 position];
set(fig, "DefaultAxesColor", "white");
set(fig, "DefaultAxesXColor", "black");
set(fig, "DefaultAxesYColor", "black");
set(fig, "DefaultTextColor", "black");
end

function showTile(img, titleText)
nexttile;
imshow(img);
title(titleText, "Color", "black", "Interpreter", "none");
end
