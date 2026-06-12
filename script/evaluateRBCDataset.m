function rows = evaluateRBCDataset(metadataRows, config, segmentationName, model, saveOverlayDir)
%EVALUATERBCDATASET Evaluate one segmentation branch on metadata rows.

if nargin < 4
    model = [];
end
if nargin < 5
    saveOverlayDir = "";
end

records = struct([]);

if strlength(string(saveOverlayDir)) > 0 && ~isfolder(saveOverlayDir)
    mkdir(saveOverlayDir);
end

for i = 1:height(metadataRows)
    row = metadataRows(i, :);
    imagePath = datasetImagePath(row, config);
    annotationPath = datasetAnnotationPath(row, config);

    if ~isfile(imagePath) || ~isfile(annotationPath)
        warning("Skipping missing image or annotation for %s.", char(row.id));
        continue;
    end

    rgb = imread(imagePath);
    [truthMask, annotationCount] = readRBCAnnotationMask(annotationPath, [size(rgb, 1), size(rgb, 2)]);
    trueCount = row.groundTruth;
    if isnan(trueCount)
        trueCount = annotationCount;
    end

    [predMask, scoreMap, counts] = runSegmentationBranch(rgb, config, segmentationName, model);
    pixelMetrics = computeBinaryMaskMetrics(predMask, truthMask, scoreMap);

    countFields = fieldnames(counts);
    for j = 1:numel(countFields)
        countResult = counts.(countFields{j});
        countMetrics = computeCountMetrics(countResult.count, trueCount);
        methodName = string(segmentationName) + "_" + string(countResult.method);

        record = struct();
        record.split = string(row.split);
        record.imageId = string(row.id);
        record.segmentation = string(segmentationName);
        record.countingMethod = string(countResult.method);
        record.method = methodName;
        record.trueCount = trueCount;
        record.predictedCount = double(countResult.count);
        record.componentCount = double(countResult.componentCount);
        record.absoluteError = countMetrics.absoluteError;
        record.squaredError = countMetrics.squaredError;
        record.percentageError = countMetrics.percentageError;
        record.exactMatch = countMetrics.exactMatch;
        record.normalizedCountAccuracy = countMetrics.normalizedCountAccuracy;
        record.pixelAccuracy = pixelMetrics.pixelAccuracy;
        record.pixelPrecision = pixelMetrics.pixelPrecision;
        record.pixelRecall = pixelMetrics.pixelRecall;
        record.pixelF1 = pixelMetrics.pixelF1;
        record.pixelIoU = pixelMetrics.pixelIoU;
        record.pixelAUC = pixelMetrics.pixelAUC;
        record.truePositive = double(pixelMetrics.truePositive);
        record.trueNegative = double(pixelMetrics.trueNegative);
        record.falsePositive = double(pixelMetrics.falsePositive);
        record.falseNegative = double(pixelMetrics.falseNegative);

        records = [records; record]; %#ok<AGROW>

        if strlength(string(saveOverlayDir)) > 0
            imageStem = erase(string(row.id), ".jpeg");
            overlayName = sprintf("%s_%s.png", char(imageStem), char(methodName));
            imwrite(countResult.overlay, fullfile(saveOverlayDir, overlayName));
        end
    end
end

if isempty(records)
    rows = table();
else
    rows = struct2table(records);
end

end

function [mask, scoreMap, counts] = runSegmentationBranch(rgb, config, segmentationName, model)
segmentationName = string(segmentationName);

switch true
    case startsWith(segmentationName, "algorithm")
        channelInfo = selectBestChannels(rgb, config);
        wbcAlgorithm = segmentWBC(rgb, channelInfo.wbc, config);
        rbcAlgorithm = segmentRBC(rgb, channelInfo.rbc, wbcAlgorithm.maskForExclusion, config);
        mask = rbcAlgorithm.maskFinal;
        scoreMap = double(mask);
        counts = countRBCMask(mask, rgb, config);

    case startsWith(segmentationName, "kmeans")
        %#ok<NASGU> model is kept in the signature for older callers.
        prediction = segmentRBCKMeans(rgb, config);
        mask = prediction.maskFinal;
        if isfield(prediction, "scoreMap")
            scoreMap = prediction.scoreMap;
        else
            scoreMap = double(mask);
        end
        counts = countRBCMask(mask, rgb, config);

    otherwise
        error("Unknown segmentation branch: %s", segmentationName);
end
end
