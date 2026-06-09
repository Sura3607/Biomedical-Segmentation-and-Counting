%% MATLAB demo for RBC segmentation and counting
% Run this file from the project root:
%   main_demo

clear; clc; close all;

demoDir = fileparts(mfilename("fullpath"));
addpath(demoDir);
addpath(fullfile(demoDir, "methods"));
addpath(fullfile(demoDir, "script"));

config = config_default();

if ~isfile(config.imagePath)
    error("Default image not found: %s", config.imagePath);
end

fprintf("Running MATLAB RBC demo on:\n%s\n\n", config.imagePath);

result = countRBCPipeline(config.imagePath, config);

if ~isfolder(config.outputDir)
    mkdir(config.outputDir);
end

summary = struct2table(result.counts);
writetable(summary, fullfile(config.outputDir, "summary.csv"));

if isfield(config, "groundTruth") && isfield(config.groundTruth, "rbcCount") && ~isnan(config.groundTruth.rbcCount)
    metrics = evaluateCounts(summary, config.groundTruth.rbcCount);
    writetable(metrics, fullfile(config.outputDir, "metrics.csv"));
else
    metrics = table();
end

save(fullfile(config.outputDir, "demo_result.mat"), "result", "config");

if ~isempty(result.segmentation.rbcKMeans.clusterStats)
    writetable(result.segmentation.rbcKMeans.clusterStats, ...
        fullfile(config.outputDir, "kmeans_cluster_stats.csv"));
end

imwrite(result.masks.wbcAlgorithm, fullfile(config.outputDir, "wbc_algorithm_mask.png"));
imwrite(result.masks.wbcExclusion, fullfile(config.outputDir, "wbc_exclusion_mask.png"));
imwrite(result.masks.wbcKMeans, fullfile(config.outputDir, "wbc_kmeans_mask.png"));
imwrite(result.masks.rbcAlgorithm, fullfile(config.outputDir, "rbc_algorithm_mask.png"));
imwrite(result.masks.rbcKMeans, fullfile(config.outputDir, "rbc_kmeans_mask.png"));
imwrite(result.masks.rbcFinal, fullfile(config.outputDir, "rbc_mask_final.png"));
imwrite(result.overlays.algorithmMask, fullfile(config.outputDir, "overlay_algorithm.png"));
imwrite(result.overlays.kmeansMask, fullfile(config.outputDir, "overlay_kmeans.png"));
imwrite(result.overlays.finalMask, fullfile(config.outputDir, "overlay_final.png"));

try
    clusterPreview = label2rgb(result.segmentation.rbcKMeans.clusterMap);
    imwrite(clusterPreview, fullfile(config.outputDir, "kmeans_cluster_map.png"));
catch
    clusterPreview = [];
end

methodNames = fieldnames(result.overlays.counts);
for i = 1:numel(methodNames)
    name = methodNames{i};
    outName = sprintf("count_overlay_%s.png", name);
    overlayImg = result.overlays.counts.(name);
    if ~isempty(overlayImg)
        imwrite(overlayImg, fullfile(config.outputDir, outName));
    end
end

disp(summary);
if ~isempty(metrics)
    fprintf("\nMetrics against true RBC count = %d\n", config.groundTruth.rbcCount);
    disp(metrics);
end
fprintf("\nSaved demo outputs to: %s\n", config.outputDir);

figure("Name", "MATLAB RBC Demo", "Color", "w");
tiledlayout(2, 4, "Padding", "compact", "TileSpacing", "compact");

nexttile; imshow(result.original); title("Original RGB");
nexttile; imshow(result.masks.wbcAlgorithm); title("Algorithm WBC mask");
nexttile; imshow(result.masks.rbcAlgorithm); title("Algorithm RBC mask");
nexttile; imshow(result.overlays.algorithmMask); title("Algorithm overlay");
if isempty(clusterPreview)
    nexttile; imshow(result.segmentation.rbcKMeans.clusterMap, []); title("K-means clusters");
else
    nexttile; imshow(clusterPreview); title("K-means clusters");
end
nexttile; imshow(result.masks.wbcKMeans); title("K-means WBC mask");
nexttile; imshow(result.masks.rbcKMeans); title("K-means RBC mask");
nexttile; imshow(result.overlays.kmeansMask); title("K-means overlay");
