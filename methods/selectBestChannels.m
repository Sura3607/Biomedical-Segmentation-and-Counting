function channelInfo = selectBestChannels(rgb, config)
%SELECTBESTCHANNELS Extract configured RBC/WBC channels.
% This demo keeps channel selection simple and explicit. For the research
% version, extend this file with ROI-based scoring and histograms.

allChannels = extractColorChannels(rgb);

rbcName = char(config.channels.rbc);
wbcName = char(config.channels.wbc);

if ~isfield(allChannels, rbcName)
    error("Unknown RBC channel '%s'.", rbcName);
end

if ~isfield(allChannels, wbcName)
    error("Unknown WBC channel '%s'.", wbcName);
end

channelInfo = struct();
channelInfo.all = allChannels;
channelInfo.rbc = prepareChannel(allChannels.(rbcName), rbcName, config);
channelInfo.wbc = prepareChannel(allChannels.(wbcName), wbcName, config);
channelInfo.notes = "Configured channel selection. Extend with ROI scoring for the full study.";

end

function prepared = prepareChannel(channel, name, config)
channel = mat2gray(channel);
enhanced = adapthisteq(channel, ...
    "NumTiles", config.preprocessing.claheNumTiles, ...
    "ClipLimit", config.preprocessing.claheClipLimit);
blurred = imgaussfilt(enhanced, config.preprocessing.gaussianSigma);

prepared = struct();
prepared.name = string(name);
prepared.raw = channel;
prepared.enhanced = enhanced;
prepared.blurred = blurred;
end

function channels = extractColorChannels(rgb)
rgbDouble = im2double(rgb);
hsv = rgb2hsv(rgbDouble);
lab = rgb2lab(rgbDouble);

channels = struct();
channels.R = rgbDouble(:, :, 1);
channels.G = rgbDouble(:, :, 2);
channels.B = rgbDouble(:, :, 3);
channels.H = hsv(:, :, 1);
channels.S = hsv(:, :, 2);
channels.V = hsv(:, :, 3);
channels.L = lab(:, :, 1);
channels.A = lab(:, :, 2);
channels.BLab = lab(:, :, 3);
channels.RminusG = channels.R - channels.G;
channels.BminusR = channels.B - channels.R;
channels.RratioG = channels.R ./ (channels.G + eps);
end
