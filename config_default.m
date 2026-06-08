function config = config_default()
%CONFIG_DEFAULT Central config for the MATLAB demo.

demoDir = fileparts(mfilename("fullpath"));

config = struct();
config.imagePath = fullfile(demoDir, "dataset", "raw", "BloodImage_00001.jpeg");
config.outputDir = fullfile(demoDir, "report");

% Default label for BloodImage_00001.jpeg.
% Set to NaN when using an image without a known RBC count.
config.groundTruth.rbcCount = 18;

% Channel choices from the initial Python demo/plan.
% Search terms: rgb2hsv, rgb2lab, channel selection, imhist.
config.channels.rbc = "G";
config.channels.wbc = "S";

% Preprocessing.
config.preprocessing.resizeMaxSide = 0;     % 0 means keep original size.
config.preprocessing.claheNumTiles = [8 8];
config.preprocessing.claheClipLimit = 0.01;
config.preprocessing.gaussianSigma = 1.2;

% WBC segmentation.
config.wbc.stdMultiplier = 1.6;
config.wbc.minArea = 120;
config.wbc.closeRadius = 4;
config.wbc.openRadius = 2;
config.wbc.excludeDilateRadius = 8;

% RBC segmentation.
config.rbc.minArea = 80;
config.rbc.maxArea = 9000;
config.rbc.openRadius = 1;
config.rbc.closeRadius = 3;
config.rbc.fillHoles = true;
config.rbc.finalMethod = "otsu";            % "otsu", "adaptive", or "watershedSeed".

% Counting.
config.counting.minArea = 90;
config.counting.maxArea = 12000;
config.counting.circularityMin = 0.15;
config.counting.areaOutlierFactor = 1.65;
config.counting.peakMinDistance = 4;
config.counting.watershedHMin = 1.0;

% K-means pixel-level segmentation branch.
% This is the ML/non-deep-learning segmentation baseline. It clusters pixel
% features, maps clusters to RBC/WBC/background, then sends the RBC mask to
% the same counting methods used by the algorithm branch.
config.ml.kmeans.enabled = true;
config.ml.kmeans.k = 5;                     % color/texture groups, not cell count.
config.ml.kmeans.maxSamplePixels = 60000;   % sample pixels for centroids; 0 means all.
config.ml.kmeans.replicates = 5;
config.ml.kmeans.maxIter = 200;
config.ml.kmeans.randomSeed = 7;
config.ml.kmeans.spatialWeight = 0.08;      % keep x/y weak so color dominates.
config.ml.kmeans.maxRbcClusters = 2;
config.ml.kmeans.rbcScoreMargin = 0.25;
config.ml.kmeans.backgroundVMin = 0.78;
config.ml.kmeans.backgroundSMax = 0.28;

% Display/overlay.
config.display.alpha = 0.35;

end
