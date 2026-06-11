%% RBC segmentation and counting evaluation
% This notebook trains K-means models on train, selects k on validation,
% retrains the best k on train+val, and evaluates algorithm vs K-means on test.

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

disp("Validation K selection");
disp(results.kSelection);

disp("Best K");
disp(results.bestK);

disp("Test summary metrics");
disp(results.testSummary);

fprintf("Saved metrics to: %s\n", fullfile(config.outputDir, "metrics"));
fprintf("Saved plots to: %s\n", fullfile(config.outputDir, "plots"));
fprintf("Saved overlays to: %s\n", fullfile(config.outputDir, "overlays", "test"));
fprintf("Saved models to: %s\n", config.modelDir);
