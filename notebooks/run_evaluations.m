%% RBC segmentation and counting evaluation artifacts
% Evaluates color-theory K-means without using annotation masks for training
% or cluster labeling. Annotation rectangles are used only as ground truth
% for validation/test metrics.

currentFolder = pwd;
[~, currentFolderName] = fileparts(currentFolder);
if strcmpi(string(currentFolderName), "notebooks")
    projectRoot = fileparts(currentFolder);
else
    projectRoot = currentFolder;
end
addpath(projectRoot);
addpath(fullfile(projectRoot, "methods"));
addpath(fullfile(projectRoot, "script"));

config = config_default();
results = runRBCEvaluation(config);
exportReportSampleFigures(config);
exportKMeansClusterPlots(config);
exportKMeansScatterPlots(config);

disp("Validation K selection");
disp(results.kSelection);

disp("Best K");
disp(results.bestK);

disp("Test summary metrics");
disp(results.testSummary);

fprintf("Saved metrics to: %s\n", fullfile(config.outputDir, "metrics"));
fprintf("Saved plots to: %s\n", fullfile(config.outputDir, "plots"));
fprintf("Saved overlays to: %s\n", fullfile(config.outputDir, "overlays", "test"));
fprintf("Saved report figures to: %s\n", fullfile(config.outputDir, "report_figures"));
