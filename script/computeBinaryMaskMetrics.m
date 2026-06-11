function metrics = computeBinaryMaskMetrics(predMask, trueMask, scoreMap)
%COMPUTEBINARYMASKMETRICS Compute binary mask metrics and optional ROC/AUC.

pred = logical(predMask(:));
truth = logical(trueMask(:));

tp = sum(pred & truth);
tn = sum(~pred & ~truth);
fp = sum(pred & ~truth);
fn = sum(~pred & truth);
total = numel(truth);

precision = safeDivide(tp, tp + fp);
recall = safeDivide(tp, tp + fn);
f1 = safeDivide(2 * precision * recall, precision + recall);
iou = safeDivide(tp, tp + fp + fn);
accuracy = safeDivide(tp + tn, total);

if nargin < 3 || isempty(scoreMap)
    scores = double(pred);
else
    scores = double(scoreMap(:));
end

[auc, rocFpr, rocTpr] = computeRocAuc(truth, scores);

metrics = struct();
metrics.pixelAccuracy = accuracy;
metrics.pixelPrecision = precision;
metrics.pixelRecall = recall;
metrics.pixelF1 = f1;
metrics.pixelIoU = iou;
metrics.pixelAUC = auc;
metrics.truePositive = tp;
metrics.trueNegative = tn;
metrics.falsePositive = fp;
metrics.falseNegative = fn;
metrics.rocFpr = rocFpr;
metrics.rocTpr = rocTpr;

end

function value = safeDivide(numerator, denominator)
if denominator == 0
    value = NaN;
else
    value = numerator / denominator;
end
end

function [auc, fpr, tpr] = computeRocAuc(labels, scores)
labels = logical(labels(:));
scores = double(scores(:));
valid = isfinite(scores);
labels = labels(valid);
scores = scores(valid);

positiveCount = sum(labels);
negativeCount = sum(~labels);

if positiveCount == 0 || negativeCount == 0
    auc = NaN;
    fpr = [0; 1];
    tpr = [0; 1];
    return;
end

thresholds = sort(unique(scores), "descend");
tprValues = zeros(numel(thresholds), 1);
fprValues = zeros(numel(thresholds), 1);

for i = 1:numel(thresholds)
    pred = scores >= thresholds(i);
    tprValues(i) = sum(pred & labels) ./ positiveCount;
    fprValues(i) = sum(pred & ~labels) ./ negativeCount;
end

tpr = [0; tprValues; 1];
fpr = [0; fprValues; 1];
auc = trapz(fpr, tpr);

end
