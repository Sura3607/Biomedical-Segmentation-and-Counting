function out = countByAreaEstimate(mask, rgb, config)
%COUNTBYAREAESTIMATE Estimate count from component area for attached cells.

filtered = filterCountingMask(mask, config);
cc = bwconncomp(filtered);
stats = regionprops("table", cc, "Area", "Centroid", "Eccentricity", "MajorAxisLength", "MinorAxisLength", "Solidity");

if height(stats) == 0
    estimatedCounts = [];
    totalCount = 0;
    medianSingleArea = NaN;
else
    areas = stats.Area;
    candidateSingle = areas(areas <= median(areas));
    if isempty(candidateSingle)
        candidateSingle = areas;
    end
    medianSingleArea = median(candidateSingle);
    estimatedCounts = max(1, round(areas / max(medianSingleArea, eps)));
    totalCount = sum(estimatedCounts);
    stats.EstimatedRBC = estimatedCounts;
end

labels = labelmatrix(cc);

out = struct();
out.method = "area_estimate";
out.count = totalCount;
out.componentCount = cc.NumObjects;
out.labels = labels;
out.stats = stats;
out.overlay = drawCountOverlay(rgb, labels, totalCount, out.method);
out.notes = "Estimates attached-cell count from component area relative to median single-cell area.";
out.medianSingleArea = medianSingleArea;

end
