function summary = aggregateEvaluationMetrics(rows)
%AGGREGATEEVALUATIONMETRICS Aggregate per-image evaluation rows by method.

if isempty(rows) || height(rows) == 0
    summary = table();
    return;
end

[groupId, methodNames] = findgroups(rows.method);
groupCount = numel(methodNames);

summary = table();
summary.method = methodNames;
summary.imageCount = splitapply(@numel, rows.predictedCount, groupId);
summary.countMAE = splitapply(@meanOmitNan, rows.absoluteError, groupId);
summary.countRMSE = sqrt(splitapply(@meanOmitNan, rows.squaredError, groupId));
summary.countMAPE = splitapply(@meanOmitNan, rows.percentageError, groupId);
summary.exactMatchAccuracy = splitapply(@meanOmitNan, rows.exactMatch, groupId);
summary.normalizedCountAccuracy = splitapply(@meanOmitNan, rows.normalizedCountAccuracy, groupId);
summary.pixelAccuracy = splitapply(@meanOmitNan, rows.pixelAccuracy, groupId);
summary.pixelPrecision = splitapply(@meanOmitNan, rows.pixelPrecision, groupId);
summary.pixelRecall = splitapply(@meanOmitNan, rows.pixelRecall, groupId);
summary.pixelF1 = splitapply(@meanOmitNan, rows.pixelF1, groupId);
summary.pixelIoU = splitapply(@meanOmitNan, rows.pixelIoU, groupId);
summary.pixelAUC = splitapply(@meanOmitNan, rows.pixelAUC, groupId);

if height(summary) ~= groupCount
    error("Failed to aggregate all evaluation groups.");
end

end

function value = meanOmitNan(values)
values = values(isfinite(values));
if isempty(values)
    value = NaN;
else
    value = mean(values);
end
end
