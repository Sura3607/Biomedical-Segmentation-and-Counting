function out = predictKMeansRBC(rgb, config, model)
%PREDICTKMEANSRBC Predict RBC mask using a persisted K-means model.

if nargin < 3 || isempty(model)
    model = loadKMeansRBCModel(config);
end

rgb = im2double(rgb);
[imgHeight, imgWidth, channels] = size(rgb);
if channels ~= 3
    error("Input must be an RGB image.");
end

[featureRaw, featureNames] = buildKMeansPixelFeatures(rgb, config);
if numel(featureNames) ~= numel(model.featureNames)
    error("K-means model feature count does not match current feature extractor.");
end

featureNorm = (featureRaw - model.featureMean) ./ model.featureStd;
featureNorm(~isfinite(featureNorm)) = 0;

clusterId = assignKMeansCentroids(featureNorm, model.centroids);
clusterMap = reshape(clusterId, imgHeight, imgWidth);

clusterScores = double(model.clusterRbcProbability(:));
pixelScores = clusterScores(clusterId);
scoreMap = reshape(pixelScores, imgHeight, imgWidth);

rbcThreshold = model.rbcThreshold;
maskWBC = false(imgHeight, imgWidth);
wbcClusters = [];

if isfield(model, "clusterWbcProbability") && ~isempty(model.clusterWbcProbability)
    wbcScores = double(model.clusterWbcProbability(:));
    wbcPixelScores = reshape(wbcScores(clusterId), imgHeight, imgWidth);
    if isfield(model, "wbcThreshold")
        wbcThreshold = model.wbcThreshold;
    else
        wbcThreshold = max(wbcScores);
    end

    maskWBC = wbcPixelScores >= wbcThreshold & wbcPixelScores > scoreMap;
    maskWBC = cleanupBinaryMask(maskWBC, ...
        config.wbc.minArea, ...
        config.wbc.openRadius, ...
        config.wbc.closeRadius, ...
        true);
    wbcClusters = find(wbcScores >= wbcThreshold & wbcScores > clusterScores)';
end

maskRBC = scoreMap >= rbcThreshold & ~maskWBC;
maskRBC = cleanupBinaryMask(maskRBC, ...
    config.rbc.minArea, ...
    config.rbc.openRadius, ...
    config.rbc.closeRadius, ...
    config.rbc.fillHoles);
maskRBC(maskWBC) = false;

rbcClusters = find(clusterScores >= rbcThreshold)';
rbcClusters = setdiff(rbcClusters, wbcClusters);

out = struct();
out.maskFinal = maskRBC;
out.maskWBC = maskWBC;
out.clusterMap = clusterMap;
out.scoreMap = scoreMap;
out.clusterStats = model.clusterStats;
out.featureNames = featureNames;
out.featureMean = model.featureMean;
out.featureStd = model.featureStd;
out.rbcClusters = rbcClusters;
out.wbcClusters = wbcClusters;
out.backgroundClusters = setdiff(1:model.k, union(rbcClusters, wbcClusters));
out.model = model;
out.finalMethod = "kmeans_persisted_model";
out.notes = sprintf("Persisted K-means RBC model loaded for k=%d.", model.k);

end

function model = loadKMeansRBCModel(config)
if isfield(config.ml.kmeans, "model") && ~isempty(config.ml.kmeans.model)
    model = config.ml.kmeans.model;
    return;
end

if isfield(config.ml.kmeans, "modelPath") && strlength(string(config.ml.kmeans.modelPath)) > 0
    modelPath = char(config.ml.kmeans.modelPath);
else
    modelPath = fullfile(config.modelDir, sprintf("kmeans_rbc_k%d.mat", config.ml.kmeans.k));
end

if ~isfile(modelPath)
    error("K-means model file not found: %s", modelPath);
end

data = load(modelPath, "model");
model = data.model;
end
