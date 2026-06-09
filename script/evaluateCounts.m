function metrics = evaluateCounts(predictedCounts, trueCount)
%EVALUATECOUNTS Basic count metrics for a known ground-truth count.
% predictedCounts can be a table with columns method/count or a struct array.

if istable(predictedCounts)
    methods = predictedCounts.method;
    counts = predictedCounts.count;
else
    methods = string({predictedCounts.method})';
    counts = [predictedCounts.count]';
end

absoluteError = abs(counts - trueCount);

metrics = table();
metrics.method = methods;
metrics.predictedCount = counts;
metrics.trueCount = repmat(trueCount, numel(counts), 1);
metrics.absoluteError = absoluteError;
if trueCount ~= 0
    metrics.absolutePercentageError = 100 * absoluteError / trueCount;
else
    metrics.absolutePercentageError = NaN(size(absoluteError));
end

end

