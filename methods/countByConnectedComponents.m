function out = countByConnectedComponents(mask, rgb, config)
%COUNTBYCONNECTEDCOMPONENTS Count RBC components on a supplied RBC mask.

filtered = filterCountingMask(mask, config);
cc = bwconncomp(filtered);
stats = regionprops("table", cc, "Area", "Centroid", "Eccentricity", "MajorAxisLength", "MinorAxisLength", "Solidity", "Perimeter");

if height(stats) > 0
    circularity = 4 * pi * stats.Area ./ max(stats.Perimeter .^ 2, eps);
    keep = stats.Area >= config.counting.minArea & ...
           stats.Area <= config.counting.maxArea & ...
           circularity >= config.counting.circularityMin;
else
    circularity = [];
    keep = [];
end

labels = labelmatrix(cc);
if ~isempty(keep)
    keepLabels = find(keep);
    filtered = ismember(labels, keepLabels);
else
    filtered = false(size(mask));
end

ccFinal = bwconncomp(filtered);
statsFinal = regionprops("table", ccFinal, "Area", "Centroid", "Eccentricity", "MajorAxisLength", "MinorAxisLength", "Solidity", "Perimeter");

out = struct();
out.method = "connected_components";
out.count = ccFinal.NumObjects;
out.componentCount = ccFinal.NumObjects;
out.labels = labelmatrix(ccFinal);
out.stats = statsFinal;
out.overlay = drawCountOverlay(rgb, out.labels, out.count, out.method);
out.notes = "Counts each valid connected component as one RBC. Under-counts attached cells.";

end
