%% Optional MATLAB Mobile capture demo
% Run this from MATLAB connected to MATLAB Mobile.
% Search terms: MATLAB Mobile, mobiledev, camera, snapshot.

clear; clc; close all;

demoDir = fileparts(mfilename("fullpath"));
addpath(demoDir);
addpath(fullfile(demoDir, "methods"));
addpath(fullfile(demoDir, "script"));

config = config_default();

try
    m = mobiledev;
    cam = camera(m, "back");
    img = snapshot(cam);
catch err
    warning("Could not capture from MATLAB Mobile camera: %s", err.message);
    fprintf("Falling back to default image:\n%s\n", config.imagePath);
    img = imread(config.imagePath);
end

result = countRBCPipeline(img, config);

figure("Name", "MATLAB Mobile RBC Demo", "Color", "w");
tiledlayout(1, 3, "Padding", "compact", "TileSpacing", "compact");
nexttile; imshow(result.original); title("Captured/Input image");
nexttile; imshow(result.overlays.algorithmMask); title("Algorithm RBC overlay");
nexttile; imshow(result.overlays.kmeansMask); title("K-means RBC overlay");

disp(struct2table(result.counts));
