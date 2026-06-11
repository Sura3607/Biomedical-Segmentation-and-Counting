function metrics = computeCountMetrics(predictedCount, trueCount)
%COMPUTECOUNTMETRICS Compute per-image count error metrics.

absoluteError = abs(double(predictedCount) - double(trueCount));
squaredError = absoluteError .^ 2;

if trueCount == 0
    percentageError = NaN;
else
    percentageError = 100 * absoluteError / abs(double(trueCount));
end

metrics = struct();
metrics.absoluteError = absoluteError;
metrics.squaredError = squaredError;
metrics.percentageError = percentageError;
metrics.exactMatch = double(absoluteError == 0);
metrics.normalizedCountAccuracy = max(0, 1 - absoluteError / max(abs(double(trueCount)), 1));

end
