function out = countByWatershed(mask, rgb, config)
%COUNTBYWATERSHED Split attached cells using marker-controlled watershed.

filtered = filterCountingMask(mask, config, false);

distanceMap = bwdist(~filtered);
distanceMap = imhmin(distanceMap, config.counting.watershedHMin);

markers = imregionalmax(distanceMap);
markers = bwareaopen(markers, 2);

imposed = imimposemin(-distanceMap, markers | ~filtered);
labelsWs = watershed(imposed);

splitMask = filtered;
splitMask(labelsWs == 0) = false;
splitMask = filterCountingMask(splitMask, config, true);

cc = bwconncomp(splitMask);
stats = regionprops("table", cc, "Area", "Centroid", "Eccentricity", "MajorAxisLength", "MinorAxisLength", "Solidity");

out = struct();
out.method = "watershed";
out.count = cc.NumObjects;
out.componentCount = cc.NumObjects;
out.labels = labelmatrix(cc);
out.stats = stats;
out.overlay = drawCountOverlay(rgb, out.labels, out.count, out.method);
out.notes = "Splits mask by distance-transform watershed. Can over-segment if markers are noisy.";

end

