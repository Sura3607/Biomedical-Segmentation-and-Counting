function out = segmentRBC(rgb, rbcChannel, wbcMask, config)
%SEGMENTRBC Algorithm baseline: threshold RBC channel and remove WBC mask.

rbcImg = rbcChannel.blurred;
rbcNoWbc = rbcImg;
rbcNoWbc(wbcMask) = 1; % make WBC look like background for inverse threshold.

maskOtsu = segmentRBCOtsu(rbcNoWbc, wbcMask, config);
maskAdaptive = segmentRBCAdaptive(rbcNoWbc, wbcMask, config);
maskWatershedSeed = segmentRBCWatershedSeed(maskOtsu, config);

masks = struct();
masks.otsu = maskOtsu;
masks.adaptive = maskAdaptive;
masks.watershedSeed = maskWatershedSeed;

method = string(config.rbc.finalMethod);
switch method
    case "otsu"
        maskFinal = maskOtsu;
    case "adaptive"
        maskFinal = maskAdaptive;
    case "watershedSeed"
        maskFinal = maskWatershedSeed;
    otherwise
        warning("Unknown finalMethod '%s'. Falling back to otsu.", method);
        maskFinal = maskOtsu;
end

maskFinal(wbcMask) = false;
maskFinal = cleanupBinaryMask(maskFinal, config.rbc.minArea, config.rbc.openRadius, config.rbc.closeRadius, config.rbc.fillHoles);

out = struct();
out.rbcNoWbc = rbcNoWbc;
out.masks = masks;
out.maskFinal = maskFinal;
out.finalMethod = method;
out.channelName = rbcChannel.name;
out.notes = "Algorithm segmentation baseline. Shared counting methods use this mask for fair comparison.";

end

function mask = segmentRBCOtsu(img, wbcMask, config)
level = graythresh(img);
mask = img < level;
mask(wbcMask) = false;
mask = cleanupBinaryMask(mask, config.rbc.minArea, config.rbc.openRadius, config.rbc.closeRadius, config.rbc.fillHoles);
end

function mask = segmentRBCAdaptive(img, wbcMask, config)
try
    localT = adaptthresh(img, 0.45, "ForegroundPolarity", "dark");
    mask = imbinarize(img, localT);
catch
    mask = segmentRBCOtsu(img, wbcMask, config);
end
mask(wbcMask) = false;
mask = cleanupBinaryMask(mask, config.rbc.minArea, config.rbc.openRadius, config.rbc.closeRadius, config.rbc.fillHoles);
end

function mask = segmentRBCWatershedSeed(baseMask, config)
distanceMap = bwdist(~baseMask);
distanceMap = imhmin(distanceMap, config.counting.watershedHMin);
labels = watershed(-distanceMap);
mask = baseMask;
mask(labels == 0) = false;
mask = cleanupBinaryMask(mask, config.rbc.minArea, config.rbc.openRadius, config.rbc.closeRadius, config.rbc.fillHoles);
end
