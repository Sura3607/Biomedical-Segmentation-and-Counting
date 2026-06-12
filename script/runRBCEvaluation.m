function results = runRBCEvaluation(config)
%RUNRBCEVALUATION Select color-theory K-means and evaluate RBC counting.

if nargin < 1 || isempty(config)
    config = config_default();
end

setupFinalPath(config.projectRoot);
ensureEvaluationFolders(config);
metadata = loadRBCMetadata(config.metadataPath);
validateDatasetSplits(metadata, config);

valRows = metadata(metadata.split == "val", :);
testRows = metadata(metadata.split == "test", :);
candidateK = config.ml.kmeans.training.candidateK;

selectionRecords = struct([]);

for i = 1:numel(candidateK)
    k = candidateK(i);
    modelConfig = config;
    modelConfig.ml.kmeans.k = k;
    modelConfig.ml.kmeans.modelPath = "";

    valRowsResult = evaluateRBCDataset(valRows, modelConfig, "kmeans_k" + string(k), [], "");
    valSummary = aggregateEvaluationMetrics(valRowsResult);
    selectionRow = selectWatershedSummary(valSummary);

    record = struct();
    record.k = k;
    record.segmentationMethod = "color_theory_kmeans";
    record.threshold = NaN;
    record.modelPath = "";
    record.validationPixelF1 = selectionRow.pixelF1;
    record.validationPixelAUC = selectionRow.pixelAUC;
    record.validationCountMAE = selectionRow.countMAE;
    record.validationCountRMSE = selectionRow.countRMSE;
    record.validationNormalizedCountAccuracy = selectionRow.normalizedCountAccuracy;
    selectionRecords = [selectionRecords; record]; %#ok<AGROW>
end

kSelection = struct2table(selectionRecords);
minCountMAE = min(kSelection.validationCountMAE);
tieTolerance = config.ml.kmeans.training.countMaeTieTolerance;
kSelection.isBestCandidate = kSelection.validationCountMAE <= minCountMAE + tieTolerance;
bestCandidates = kSelection(kSelection.isBestCandidate, :);
bestCandidates = sortrows(bestCandidates, {'validationPixelF1', 'validationCountMAE'}, {'descend', 'ascend'});
bestK = bestCandidates.k(1);
kSelection.isSelected = kSelection.k == bestK;
kSelection = sortrows(kSelection, {'isSelected', 'validationCountMAE'}, {'descend', 'ascend'});

bestConfig = config;
bestConfig.ml.kmeans.k = bestK;
bestConfig.ml.kmeans.modelPath = "";

if isfield(config, "evaluation") && isfield(config.evaluation, "saveTestOverlays") && config.evaluation.saveTestOverlays
    overlayDir = fullfile(config.outputDir, "overlays", "test");
else
    overlayDir = "";
end
algorithmRows = evaluateRBCDataset(testRows, config, "algorithm", [], overlayDir);
kmeansRows = evaluateRBCDataset(testRows, bestConfig, "kmeans", [], overlayDir);
testRowsAll = [algorithmRows; kmeansRows];
testSummary = aggregateEvaluationMetrics(testRowsAll);

metricsDir = fullfile(config.outputDir, "metrics");
writetable(kSelection, fullfile(metricsDir, "validation_k_selection.csv"));
writetable(testRowsAll, fullfile(metricsDir, "test_per_image_metrics.csv"));
writetable(testSummary, fullfile(metricsDir, "test_summary_metrics.csv"));

saveEvaluationPlots(kSelection, testSummary, config);

results = struct();
results.metadata = metadata;
results.kSelection = kSelection;
results.bestK = bestK;
results.kmeansMethod = "color_theory_kmeans";
results.bestModelPath = "";
results.testRows = testRowsAll;
results.testSummary = testSummary;

end

function ensureEvaluationFolders(config)
folders = [
    string(config.outputDir)
    string(fullfile(config.outputDir, "metrics"))
    string(fullfile(config.outputDir, "plots"))
    string(fullfile(config.outputDir, "overlays", "test"))
    string(config.modelDir)
];

for i = 1:numel(folders)
    if ~isfolder(folders(i))
        mkdir(folders(i));
    end
end
end

function validateDatasetSplits(metadata, config)
requiredSplits = ["train", "val", "test"];
for i = 1:numel(requiredSplits)
    splitName = requiredSplits(i);
    if ~any(metadata.split == splitName)
        error("Metadata is missing split: %s", splitName);
    end
    if ~isfolder(fullfile(config.dataRoot, char(splitName), "img"))
        error("Dataset image folder is missing for split: %s", splitName);
    end
    if ~isfolder(fullfile(config.dataRoot, char(splitName), "ann"))
        error("Dataset annotation folder is missing for split: %s", splitName);
    end
end
end

function row = selectWatershedSummary(summary)
idx = contains(summary.method, "_watershed");
if any(idx)
    row = summary(find(idx, 1), :);
else
    row = summary(1, :);
end
end

function saveEvaluationPlots(kSelection, testSummary, config)
plotsDir = fullfile(config.outputDir, "plots");
kPlot = sortrows(kSelection, 'k');

fig = createReportFigure();
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");
nexttile;
plot(kPlot.k, kPlot.validationPixelF1, "-o", "LineWidth", 1.5);
xlabel("k");
ylabel("Validation pixel F1");
title("K selection by F1");
grid on;
nexttile;
bar(kPlot.k, kPlot.validationCountMAE);
xlabel("k");
ylabel("Validation count MAE");
title("K selection count error");
grid on;
exportgraphics(fig, fullfile(plotsDir, "validation_k_selection.png"), "BackgroundColor", "white");
close(fig);

fig = createReportFigure();
bar(categorical(testSummary.method), testSummary.pixelF1);
ylabel("Mean pixel F1");
title("Test segmentation/counting methods");
grid on;
xtickangle(35);
exportgraphics(fig, fullfile(plotsDir, "test_pixel_f1_by_method.png"), "BackgroundColor", "white");
close(fig);

fig = createReportFigure();
bar(categorical(testSummary.method), testSummary.countMAE);
ylabel("Count MAE");
title("Test count error by method");
grid on;
xtickangle(35);
exportgraphics(fig, fullfile(plotsDir, "test_count_mae_by_method.png"), "BackgroundColor", "white");
close(fig);

fig = createReportFigure();
bar(categorical(testSummary.method), testSummary.pixelAUC);
ylabel("Mean pixel AUC");
title("Test AUC by method");
grid on;
xtickangle(35);
exportgraphics(fig, fullfile(plotsDir, "test_auc_by_method.png"), "BackgroundColor", "white");
close(fig);
end

function fig = createReportFigure()
fig = figure("Visible", "off", "Color", "white", "InvertHardcopy", "off");
set(fig, "DefaultAxesColor", "white");
set(fig, "DefaultAxesXColor", "black");
set(fig, "DefaultAxesYColor", "black");
set(fig, "DefaultAxesGridColor", [0.65 0.65 0.65]);
set(fig, "DefaultTextColor", "black");
end
