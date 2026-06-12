function out = segmentWBC(rgb, wbcChannel, config)
%SEGMENTWBC Segment WBC so it can be excluded from the RBC mask.
% Search terms: rgb2hsv, rgb2lab, normalized blue, imopen, imclose.

[score, colorParts] = buildWBCColorScore(rgb);
score = imgaussfilt(score, config.preprocessing.gaussianSigma);

mu = mean(score(:));
sigma = std(score(:));
threshold = min(1, mu + config.wbc.stdMultiplier * sigma);

% WBC nuclei are the purple/blue high-saturation outliers. A saturation-only
% adaptive mask also catches RBCs, so keep a blue-normalized color guard.
purpleGuard = colorParts.S > 0.18 & colorParts.bNorm > 0.30;
mask = score > threshold & purpleGuard;

mask = cleanupBinaryMask(mask, config.wbc.minArea, config.wbc.openRadius, config.wbc.closeRadius, true);

if config.wbc.excludeDilateRadius > 0
    maskForExclusion = imdilate(mask, strel("disk", config.wbc.excludeDilateRadius, 0));
else
    maskForExclusion = mask;
end

out = struct();
out.mask = mask;
out.maskForExclusion = maskForExclusion;
out.channelName = wbcChannel.name;
out.threshold = threshold;
out.meanIntensity = mu;
out.stdIntensity = sigma;
out.scoreMap = score;
out.notes = "WBC mask uses purple/blue color score; RBC-like high saturation is rejected by normalized-blue guards.";

end

function [score, parts] = buildWBCColorScore(rgb)
rgb = im2double(rgb);
hsvImg = rgb2hsv(rgb);
labImg = rgb2lab(rgb);

R = rgb(:, :, 1);
B = rgb(:, :, 3);
S = hsvImg(:, :, 2);
V = hsvImg(:, :, 3);

sumRGB = sum(rgb, 3) + eps;
rNorm = R ./ sumRGB;
bNorm = B ./ sumRGB;
blueLabScore = mat2gray(-labImg(:, :, 3));

score = 1.30 * S + ...
    1.20 * bNorm + ...
    0.80 * max(B - R, 0) + ...
    0.70 * blueLabScore - ...
    0.50 * rNorm - ...
    0.15 * V;
score = mat2gray(score);

parts = struct();
parts.S = S;
parts.bNorm = bNorm;
end
