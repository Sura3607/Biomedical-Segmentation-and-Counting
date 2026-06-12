function overlay = showOverlay(rgb, mask, color, alpha)
%SHOWOVERLAY Overlay a binary mask on an RGB image.

rgb = im2double(rgb);
mask = logical(mask);
color = reshape(color, 1, 1, 3);

overlay = rgb;
for c = 1:3
    channel = overlay(:, :, c);
    channel(mask) = (1 - alpha) * channel(mask) + alpha * color(:, :, c);
    overlay(:, :, c) = channel;
end

overlay = im2uint8(overlay);

end

