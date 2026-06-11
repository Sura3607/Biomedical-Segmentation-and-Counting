function rows = countSummaryRows(counts, segmentationName)
%COUNTSUMMARYROWS Convert counting outputs to a struct array summary.

countFields = fieldnames(counts);
template = struct( ...
    "segmentation", "", ...
    "countingMethod", "", ...
    "method", "", ...
    "count", NaN, ...
    "componentCount", NaN, ...
    "notes", "");
rows = repmat(template, numel(countFields), 1);

for i = 1:numel(countFields)
    countResult = counts.(countFields{i});
    countingMethod = string(countResult.method);
    rows(i).segmentation = string(segmentationName);
    rows(i).countingMethod = countingMethod;
    rows(i).method = string(segmentationName) + "_" + countingMethod;
    rows(i).count = countResult.count;
    rows(i).componentCount = countResult.componentCount;
    rows(i).notes = string(countResult.notes);
end

end
