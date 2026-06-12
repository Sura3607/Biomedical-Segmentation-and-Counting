function result = countRBCPipeline(imagePathOrRgb, config)
%COUNTRBCPIPELINE End-to-end demo pipeline.
% Input:
%   imagePathOrRgb: image path or RGB image matrix.
%   config: struct from config_default().
% Output:
%   result: masks, counts, overlays, and intermediate channels.

methodDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(methodDir);
addpath(repoRoot);
addpath(methodDir);
addpath(fullfile(repoRoot, "script"));

if nargin < 2 || isempty(config)
    config = config_default();
end

if isstring(imagePathOrRgb) || ischar(imagePathOrRgb)
    rgb = imread(imagePathOrRgb);
else
    rgb = imagePathOrRgb;
end

if size(rgb, 3) ~= 3
    error("Input must be an RGB image.");
end

rgb = im2uint8(rgb);
rgb = maybeResizeImage(rgb, config.preprocessing.resizeMaxSide);

channelInfo = selectBestChannels(rgb, config);

wbcAlgorithm = segmentWBC(rgb, channelInfo.wbc, config);
rbcAlgorithm = segmentRBC(rgb, channelInfo.rbc, wbcAlgorithm.maskForExclusion, config);
rbcKMeans = segmentRBCKMeans(rgb, config);

rbcAlgorithm.maskFinal = logical(ensureImageMaskSize(rbcAlgorithm.maskFinal, rgb, "algorithm RBC mask"));
rbcKMeans.maskFinal = logical(ensureImageMaskSize(rbcKMeans.maskFinal, rgb, "K-means RBC mask"));
rbcKMeans.maskWBC = logical(ensureImageMaskSize(rbcKMeans.maskWBC, rgb, "K-means WBC mask"));

algorithmCounts = countRBCMask(rbcAlgorithm.maskFinal, rgb, config);
kmeansCounts = countRBCMask(rbcKMeans.maskFinal, rgb, config);

result = struct();
result.original = rgb;
result.channels = struct();
result.channels.info = channelInfo;
result.channels.wbcDisplay = channelInfo.wbc.enhanced;
result.channels.rbcDisplay = channelInfo.rbc.enhanced;
result.channels.rbcNoWbc = rbcAlgorithm.rbcNoWbc;

result.masks = struct();
result.masks.wbcAlgorithm = wbcAlgorithm.mask;
result.masks.wbcExclusion = wbcAlgorithm.maskForExclusion;
result.masks.wbcKMeans = rbcKMeans.maskWBC;
result.masks.rbcCandidates = rbcAlgorithm.masks;
result.masks.rbcAlgorithm = rbcAlgorithm.maskFinal;
result.masks.rbcKMeans = rbcKMeans.maskFinal;
result.masks.rbcFinal = rbcAlgorithm.maskFinal; % Legacy alias for older scripts.

result.segmentation = struct();
result.segmentation.wbcAlgorithm = wbcAlgorithm;
result.segmentation.rbcAlgorithm = rbcAlgorithm;
result.segmentation.rbcKMeans = rbcKMeans;

result.countDetails = struct();
result.countDetails.algorithm = algorithmCounts;
result.countDetails.kmeans = kmeansCounts;

result.counts = [
    countSummaryRows(algorithmCounts, "algorithm")
    countSummaryRows(kmeansCounts, "kmeans")
];

result.overlays = struct();
result.overlays.algorithmMask = showOverlay(rgb, rbcAlgorithm.maskFinal, [1 0 0], config.display.alpha);
result.overlays.kmeansMask = showOverlay(rgb, rbcKMeans.maskFinal, [0 0.75 1], config.display.alpha);
result.overlays.finalMask = result.overlays.algorithmMask; % Legacy alias for older scripts.
result.overlays.counts = struct();
result.overlays.counts = collectCountOverlays(algorithmCounts, kmeansCounts);

end

function rgb = maybeResizeImage(rgb, maxSide)
if maxSide <= 0
    return;
end

height = size(rgb, 1);
width = size(rgb, 2);
scale = maxSide / max(height, width);

if scale < 1
    rgb = imresize(rgb, scale);
end
end

function overlays = collectCountOverlays(algorithmCounts, kmeansCounts)
overlays = struct();
overlays = addCountOverlays(overlays, algorithmCounts, "algorithm");
overlays = addCountOverlays(overlays, kmeansCounts, "kmeans");
end

function overlays = addCountOverlays(overlays, counts, segmentationName)
countFields = fieldnames(counts);
for i = 1:numel(countFields)
    fieldName = sprintf("%s_%s", segmentationName, countFields{i});
    overlays.(fieldName) = counts.(countFields{i}).overlay;
end
end
