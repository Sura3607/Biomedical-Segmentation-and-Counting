function out = segmentRBCKMeans(rgb, config)
%SEGMENTRBCKMEANS Pixel-level K-means segmentation for RBC/WBC/background.
% The feature row for each pixel is:
% [L, A, BLab, S, V, rNorm, gNorm, bNorm, BminusR, RminusG, x, y].

rgb = im2double(rgb);
[imgHeight, imgWidth, channels] = size(rgb);
if channels ~= 3
    error("Input must be an RGB image.");
end

if ~isfield(config, "ml") || ~isfield(config.ml, "kmeans") || ~config.ml.kmeans.enabled
    out = emptyKMeansSegmentation(imgHeight, imgWidth, "K-means segmentation is disabled.");
    return;
end

if exist("kmeans", "file") ~= 2
    out = emptyKMeansSegmentation(imgHeight, imgWidth, ...
        "kmeans is unavailable. Install Statistics and Machine Learning Toolbox.");
    return;
end

[featureRaw, featureNames] = buildPixelFeatures(rgb, config);
featureRaw(~isfinite(featureRaw)) = 0;

sampleIdx = selectSampleRows(size(featureRaw, 1), config);
[featureNorm, mu, sigma] = standardizeFeatures(featureRaw, sampleIdx);
sampleFeatures = featureNorm(sampleIdx, :);

k = min(config.ml.kmeans.k, size(sampleFeatures, 1));
if k < 2
    out = emptyKMeansSegmentation(imgHeight, imgWidth, "Not enough pixels for K-means segmentation.");
    return;
end

rng(config.ml.kmeans.randomSeed);
[~, centroids] = kmeans(sampleFeatures, k, ...
    "Replicates", config.ml.kmeans.replicates, ...
    "MaxIter", config.ml.kmeans.maxIter, ...
    "Display", "off");

clusterId = assignToCentroids(featureNorm, centroids);
clusterMap = reshape(clusterId, imgHeight, imgWidth);

clusterStats = summarizeClusters(clusterId, featureRaw, featureNames, k);
[classInfo, clusterStats] = classifyClusters(clusterStats, config);

maskWBC = ismember(clusterMap, classInfo.wbcClusters);
maskRBC = ismember(clusterMap, classInfo.rbcClusters);
maskRBC(maskWBC) = false;
maskRBC = cleanupBinaryMask(maskRBC, ...
    config.rbc.minArea, ...
    config.rbc.openRadius, ...
    config.rbc.closeRadius, ...
    config.rbc.fillHoles);

out = struct();
out.maskFinal = maskRBC;
out.maskWBC = maskWBC;
out.clusterMap = clusterMap;
out.clusterStats = clusterStats;
out.featureNames = featureNames;
out.featureMean = mu;
out.featureStd = sigma;
out.rbcClusters = classInfo.rbcClusters;
out.wbcClusters = classInfo.wbcClusters;
out.backgroundClusters = classInfo.backgroundClusters;
out.finalMethod = "kmeans_pixel_features";
out.notes = "K-means pixel segmentation. RBC/WBC/background clusters are selected by color-feature scores.";

end

function [features, featureNames] = buildPixelFeatures(rgb, config)
[imgHeight, imgWidth, ~] = size(rgb);

hsvImg = rgb2hsv(rgb);
labImg = rgb2lab(rgb);

R = rgb(:, :, 1);
G = rgb(:, :, 2);
B = rgb(:, :, 3);
S = hsvImg(:, :, 2);
V = hsvImg(:, :, 3);
L = labImg(:, :, 1);
A = labImg(:, :, 2);
BLab = labImg(:, :, 3);

sumRGB = R + G + B + eps;
rNorm = R ./ sumRGB;
gNorm = G ./ sumRGB;
bNorm = B ./ sumRGB;
BminusR = B - R;
RminusG = R - G;

[xGrid, yGrid] = meshgrid(0:max(imgWidth - 1, 0), 0:max(imgHeight - 1, 0));
xNorm = xGrid ./ max(imgWidth - 1, 1);
yNorm = yGrid ./ max(imgHeight - 1, 1);
spatialWeight = config.ml.kmeans.spatialWeight;

features = [
    L(:), ...
    A(:), ...
    BLab(:), ...
    S(:), ...
    V(:), ...
    rNorm(:), ...
    gNorm(:), ...
    bNorm(:), ...
    BminusR(:), ...
    RminusG(:), ...
    spatialWeight * xNorm(:), ...
    spatialWeight * yNorm(:)
];

featureNames = [
    "L", ...
    "A", ...
    "BLab", ...
    "S", ...
    "V", ...
    "rNorm", ...
    "gNorm", ...
    "bNorm", ...
    "BminusR", ...
    "RminusG", ...
    "X", ...
    "Y"
];
end

function sampleIdx = selectSampleRows(rowCount, config)
sampleIdx = (1:rowCount)';
maxSamplePixels = config.ml.kmeans.maxSamplePixels;

if maxSamplePixels > 0 && rowCount > maxSamplePixels
    rng(config.ml.kmeans.randomSeed);
    sampleIdx = sort(randperm(rowCount, maxSamplePixels)');
end
end

function [featureNorm, mu, sigma] = standardizeFeatures(featureRaw, sampleIdx)
sampleFeatures = featureRaw(sampleIdx, :);
mu = mean(sampleFeatures, 1);
sigma = std(sampleFeatures, 0, 1);
sigma(sigma == 0 | ~isfinite(sigma)) = 1;
featureNorm = (featureRaw - mu) ./ sigma;
featureNorm(~isfinite(featureNorm)) = 0;
end

function clusterId = assignToCentroids(features, centroids)
rowCount = size(features, 1);
k = size(centroids, 1);
clusterId = zeros(rowCount, 1);
chunkSize = 50000;

for startIdx = 1:chunkSize:rowCount
    endIdx = min(startIdx + chunkSize - 1, rowCount);
    block = features(startIdx:endIdx, :);
    distances = zeros(size(block, 1), k);

    for clusterIdx = 1:k
        diff = block - centroids(clusterIdx, :);
        distances(:, clusterIdx) = sum(diff .^ 2, 2);
    end

    [~, clusterId(startIdx:endIdx)] = min(distances, [], 2);
end
end

function clusterStats = summarizeClusters(clusterId, featureRaw, featureNames, k)
rowCount = numel(clusterId);
cluster = (1:k)';
count = zeros(k, 1);
fraction = zeros(k, 1);
means = zeros(k, numel(featureNames));

for clusterIdx = 1:k
    memberMask = clusterId == clusterIdx;
    count(clusterIdx) = nnz(memberMask);
    fraction(clusterIdx) = count(clusterIdx) / rowCount;

    if count(clusterIdx) > 0
        means(clusterIdx, :) = mean(featureRaw(memberMask, :), 1);
    end
end

clusterStats = table(cluster(:), count(:), fraction(:), ...
    'VariableNames', {'Cluster', 'Count', 'Fraction'});

for featureIdx = 1:numel(featureNames)
    clusterStats.(char(featureNames(featureIdx))) = means(:, featureIdx);
end
end

function [classInfo, clusterStats] = classifyClusters(clusterStats, config)
s = clusterStats.S;
v = clusterStats.V;
r = clusterStats.rNorm;
b = clusterStats.bNorm;
aScore = rescaleColumn(clusterStats.A);
blueLabScore = 1 - rescaleColumn(clusterStats.BLab);
positiveBminusR = max(clusterStats.BminusR, 0);
positiveRminusG = max(clusterStats.RminusG, 0);

backgroundScore = 0.55 * v + 0.45 * rescaleColumn(clusterStats.L) - 0.70 * s;
wbcScore = 1.30 * s + 1.10 * b + 0.80 * positiveBminusR + ...
    0.70 * blueLabScore + 0.30 * aScore - 0.40 * r;
rbcScore = 1.10 * s + 1.00 * r + 0.70 * positiveRminusG + ...
    0.40 * aScore - 0.70 * positiveBminusR - 0.40 * backgroundScore;

isBackground = ...
    (v >= config.ml.kmeans.backgroundVMin & s <= config.ml.kmeans.backgroundSMax) | ...
    backgroundScore >= prctile(backgroundScore, 75);

[~, wbcIdx] = max(wbcScore);
isWBC = false(size(s));
isWBC(wbcIdx) = true;

candidateMask = ~isBackground & ~isWBC;
candidateClusters = clusterStats.Cluster(candidateMask);
candidateScores = rbcScore(candidateMask);

if isempty(candidateClusters)
    candidateMask = ~isWBC;
    candidateClusters = clusterStats.Cluster(candidateMask);
    candidateScores = rbcScore(candidateMask);
end

[sortedScores, order] = sort(candidateScores, "descend");
sortedClusters = candidateClusters(order);

if isempty(sortedClusters)
    rbcClusters = [];
else
    bestScore = sortedScores(1);
    keep = sortedScores >= bestScore - config.ml.kmeans.rbcScoreMargin;
    sortedClusters = sortedClusters(keep);
    maxRbcClusters = min(config.ml.kmeans.maxRbcClusters, numel(sortedClusters));
    rbcClusters = sortedClusters(1:maxRbcClusters)';
end

clusterStats.BackgroundScore = backgroundScore;
clusterStats.WBCScore = wbcScore;
clusterStats.RBCScore = rbcScore;
clusterStats.AssignedClass = repmat("background", height(clusterStats), 1);
clusterStats.AssignedClass(ismember(clusterStats.Cluster, rbcClusters)) = "rbc";
clusterStats.AssignedClass(ismember(clusterStats.Cluster, clusterStats.Cluster(isWBC))) = "wbc";
clusterStats.AssignedClass(~isBackground & ~isWBC & ~ismember(clusterStats.Cluster, rbcClusters)) = "other";

classInfo = struct();
classInfo.rbcClusters = rbcClusters;
classInfo.wbcClusters = clusterStats.Cluster(isWBC)';
classInfo.backgroundClusters = clusterStats.Cluster(isBackground)';
end

function out = rescaleColumn(values)
values = double(values);
minValue = min(values);
maxValue = max(values);

if maxValue > minValue
    out = (values - minValue) ./ (maxValue - minValue);
else
    out = zeros(size(values));
end
end

function out = emptyKMeansSegmentation(imgHeight, imgWidth, notes)
out = struct();
out.maskFinal = false(imgHeight, imgWidth);
out.maskWBC = false(imgHeight, imgWidth);
out.clusterMap = zeros(imgHeight, imgWidth);
out.clusterStats = table();
out.featureNames = strings(0);
out.featureMean = [];
out.featureStd = [];
out.rbcClusters = [];
out.wbcClusters = [];
out.backgroundClusters = [];
out.finalMethod = "kmeans_pixel_features";
out.notes = notes;
end
