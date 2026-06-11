function model = trainKMeansRBCModel(metadataRows, config, k, modelPath)
%TRAINKMEANSRBCMODEL Train a persisted RBC K-means model from annotations.

if exist("kmeans", "file") ~= 2
    error("kmeans is unavailable. Install Statistics and Machine Learning Toolbox.");
end

if nargin < 4
    modelPath = "";
end

metadataRows = sortrows(metadataRows, {'split', 'id'});
maxPixelsPerImage = config.ml.kmeans.training.maxPixelsPerImage;

featureBlocks = {};
labelBlocks = {};
wbcLabelBlocks = {};
sourceImages = strings(0, 1);

rng(config.ml.kmeans.randomSeed + k);

for i = 1:height(metadataRows)
    row = metadataRows(i, :);
    imagePath = datasetImagePath(row, config);
    annotationPath = datasetAnnotationPath(row, config);

    if ~isfile(imagePath) || ~isfile(annotationPath)
        continue;
    end

    rgb = imread(imagePath);
    imageSize = [size(rgb, 1), size(rgb, 2)];
    [gtMask, ~] = readAnnotationClassMask(annotationPath, imageSize, "RBC");
    [wbcMask, ~] = readAnnotationClassMask(annotationPath, imageSize, "WBC");
    [features, featureNames] = buildKMeansPixelFeatures(rgb, config);

    sampleIdx = balancedPixelSample(gtMask(:), wbcMask(:), maxPixelsPerImage);
    featureBlocks{end + 1, 1} = features(sampleIdx, :); %#ok<AGROW>
    labelBlocks{end + 1, 1} = gtMask(sampleIdx); %#ok<AGROW>
    wbcLabelBlocks{end + 1, 1} = wbcMask(sampleIdx); %#ok<AGROW>
    sourceImages(end + 1, 1) = row.id; %#ok<AGROW>
end

if isempty(featureBlocks)
    error("No training pixels were loaded for K-means model k=%d.", k);
end

sampleFeatures = vertcat(featureBlocks{:});
sampleLabels = logical(vertcat(labelBlocks{:}));
sampleWbcLabels = logical(vertcat(wbcLabelBlocks{:}));
sampleWbcLabels(sampleLabels) = false;

featureMean = mean(sampleFeatures, 1);
featureStd = std(sampleFeatures, 0, 1);
featureStd(featureStd == 0 | ~isfinite(featureStd)) = 1;
featureNorm = (sampleFeatures - featureMean) ./ featureStd;
featureNorm(~isfinite(featureNorm)) = 0;

rng(config.ml.kmeans.randomSeed + k);
[~, centroids] = kmeans(featureNorm, k, ...
    "Replicates", config.ml.kmeans.replicates, ...
    "MaxIter", config.ml.kmeans.maxIter, ...
    "Display", "off");

clusterId = assignKMeansCentroids(featureNorm, centroids);
clusterRbcProbability = zeros(k, 1);
clusterWbcProbability = zeros(k, 1);
clusterPixelCount = zeros(k, 1);
clusterPositiveCount = zeros(k, 1);
clusterWbcPositiveCount = zeros(k, 1);

for clusterIdx = 1:k
    memberMask = clusterId == clusterIdx;
    clusterPixelCount(clusterIdx) = nnz(memberMask);
    clusterPositiveCount(clusterIdx) = nnz(sampleLabels(memberMask));
    clusterWbcPositiveCount(clusterIdx) = nnz(sampleWbcLabels(memberMask));
    if clusterPixelCount(clusterIdx) > 0
        clusterRbcProbability(clusterIdx) = mean(sampleLabels(memberMask));
        clusterWbcProbability(clusterIdx) = mean(sampleWbcLabels(memberMask));
    end
end

[rbcThreshold, trainingMetrics] = chooseRbcThreshold(clusterRbcProbability(clusterId), sampleLabels);
if any(sampleWbcLabels)
    [wbcThreshold, trainingWbcMetrics] = chooseRbcThreshold(clusterWbcProbability(clusterId), sampleWbcLabels);
else
    wbcThreshold = Inf;
    trainingWbcMetrics = emptyTrainingMetrics();
end

clusterStats = table();
clusterStats.Cluster = (1:k)';
clusterStats.SamplePixelCount = clusterPixelCount;
clusterStats.SampleRBCPixelCount = clusterPositiveCount;
clusterStats.SampleWBCPixelCount = clusterWbcPositiveCount;
clusterStats.RBCProbability = clusterRbcProbability;
clusterStats.WBCProbability = clusterWbcProbability;
clusterStats.AssignedClass = repmat("background", k, 1);
clusterStats.AssignedClass(clusterRbcProbability >= rbcThreshold & clusterRbcProbability >= clusterWbcProbability) = "rbc";
clusterStats.AssignedClass(clusterWbcProbability >= wbcThreshold & clusterWbcProbability > clusterRbcProbability) = "wbc";

model = struct();
model.k = k;
model.centroids = centroids;
model.featureMean = featureMean;
model.featureStd = featureStd;
model.featureNames = featureNames;
model.clusterRbcProbability = clusterRbcProbability;
model.clusterWbcProbability = clusterWbcProbability;
model.rbcThreshold = max(rbcThreshold, max(clusterRbcProbability));
model.wbcThreshold = max(wbcThreshold, max(clusterWbcProbability));
model.clusterStats = clusterStats;
model.trainingMetrics = trainingMetrics;
model.trainingWbcMetrics = trainingWbcMetrics;
model.trainingImageIds = sourceImages;
model.trainingSplit = unique(string(metadataRows.split));
model.createdAt = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
model.notes = "K-means centroids trained from sampled pixels; clusters mapped to RBC/WBC using annotation rectangle masks.";

if strlength(string(modelPath)) > 0
    modelDir = fileparts(char(modelPath));
    if ~isfolder(modelDir)
        mkdir(modelDir);
    end
    save(modelPath, "model");
end

end

function sampleIdx = balancedPixelSample(rbcLabels, wbcLabels, maxPixels)
rbcLabels = logical(rbcLabels(:));
wbcLabels = logical(wbcLabels(:)) & ~rbcLabels;
backgroundLabels = ~(rbcLabels | wbcLabels);

positiveIdx = find(rbcLabels);
wbcIdx = find(wbcLabels);
negativeIdx = find(backgroundLabels);

if maxPixels <= 0 || numel(rbcLabels) <= maxPixels
    sampleIdx = (1:numel(rbcLabels))';
    return;
end

rbcTarget = min(numel(positiveIdx), ceil(maxPixels * 0.40));
wbcTarget = min(numel(wbcIdx), ceil(maxPixels * 0.25));
negativeTarget = min(numel(negativeIdx), maxPixels - rbcTarget - wbcTarget);

if rbcTarget > 0
    positiveIdx = positiveIdx(randperm(numel(positiveIdx), rbcTarget));
else
    positiveIdx = [];
end

if wbcTarget > 0
    wbcIdx = wbcIdx(randperm(numel(wbcIdx), wbcTarget));
else
    wbcIdx = [];
end

if negativeTarget > 0
    negativeIdx = negativeIdx(randperm(numel(negativeIdx), negativeTarget));
else
    negativeIdx = [];
end

sampleIdx = sort([positiveIdx(:); wbcIdx(:); negativeIdx(:)]);

remaining = maxPixels - numel(sampleIdx);
if remaining > 0
    allIdx = (1:numel(rbcLabels))';
    extraIdx = setdiff(allIdx, sampleIdx);
    remaining = min(remaining, numel(extraIdx));
    if remaining > 0
        extraIdx = extraIdx(randperm(numel(extraIdx), remaining));
        sampleIdx = sort([sampleIdx(:); extraIdx(:)]);
    end
end
end

function metrics = emptyTrainingMetrics()
metrics = struct();
metrics.pixelAccuracy = NaN;
metrics.pixelPrecision = NaN;
metrics.pixelRecall = NaN;
metrics.pixelF1 = NaN;
metrics.pixelIoU = NaN;
metrics.pixelAUC = NaN;
metrics.truePositive = NaN;
metrics.trueNegative = NaN;
metrics.falsePositive = NaN;
metrics.falseNegative = NaN;
metrics.threshold = Inf;
end

function [bestThreshold, metrics] = chooseRbcThreshold(scores, labels)
scores = double(scores(:));
labels = logical(labels(:));
thresholds = unique([0; scores; 1]);

bestF1 = -Inf;
bestThreshold = 0.5;
bestMetrics = struct();

for i = 1:numel(thresholds)
    threshold = thresholds(i);
    pred = scores >= threshold;
    current = computeBinaryMaskMetrics(pred, labels, scores);

    if current.pixelF1 > bestF1
        bestF1 = current.pixelF1;
        bestThreshold = threshold;
        bestMetrics = current;
    end
end

metrics = rmfield(bestMetrics, {'rocFpr', 'rocTpr'});
metrics.threshold = bestThreshold;
end
