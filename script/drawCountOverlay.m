function overlay = drawCountOverlay(rgb, labels, count, methodName)
%DRAWCOUNTOVERLAY Visualize labeled components and a count label.

rgb = im2uint8(rgb);

if isempty(labels) || ~any(labels(:))
    overlay = rgb;
else
    boundaries = labels > 0;
    try
        overlay = labeloverlay(rgb, boundaries, "Colormap", [1 0 0], "Transparency", 0.65);
    catch
        overlay = showOverlay(rgb, boundaries, [1 0 0], 0.35);
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

end
