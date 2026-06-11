function filtered = filterCountingMask(mask, config, applyMaxArea)
%FILTERCOUNTINGMASK Remove tiny objects before counting.

if nargin < 3
    applyMaxArea = true;
end

filtered = logical(mask);
filtered = bwareaopen(filtered, config.counting.minArea);
filtered = imclose(filtered, strel("disk", 1, 0));

if ~applyMaxArea
    return;
end

cc = bwconncomp(filtered);
stats = regionprops("table", cc, "Area");

if height(stats) == 0
    filtered = false(size(mask));
    return;
end

labels = labelmatrix(cc);
keep = stats.Area <= config.counting.maxArea;
filtered = ismember(labels, find(keep));

end

