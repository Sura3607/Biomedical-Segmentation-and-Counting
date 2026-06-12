function overlay = drawCountOverlay(rgb, labels, count, methodName)
%DRAWCOUNTOVERLAY Visualize labeled components and a count label.

rgb = im2uint8(rgb);
labels = ensureImageMaskSize(labels, rgb, "count labels");

if isempty(labels) || ~any(labels(:))
    overlay = rgb;
else
    overlay = rgb;
    labelValues = setdiff(unique(labels(:))', 0);
    for labelValue = labelValues
        componentMask = labels == labelValue;
        boundaries = bwperim(componentMask, 8);
        boundaries = imdilate(boundaries, strel("disk", 1));
        overlay = paintMask(overlay, boundaries, uint8([255 30 30]));
    end
end

methodLabel = char(strrep(string(methodName), "_", " "));
label = sprintf("%s: %d", methodLabel, count);

try
    overlay = insertText(overlay, [10 10], label, ...
        "FontSize", 18, ...
        "BoxColor", "black", ...
        "TextColor", "white", ...
        "BoxOpacity", 0.55);
catch
    % insertText is in Computer Vision Toolbox. Keep overlay usable without it.
end

function img = paintMask(img, mask, color)
for c = 1:3
    channel = img(:, :, c);
    channel(mask) = color(c);
    img(:, :, c) = channel;
end
end

end
