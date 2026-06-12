function mask = ensureImageMaskSize(mask, rgb, maskName)
%ENSUREIMAGEMASKSIZE Align a 2-D mask/label image with an RGB image.

if nargin < 3
    maskName = "mask";
end

targetSize = [size(rgb, 1), size(rgb, 2)];

if isempty(mask)
    mask = false(targetSize);
    return;
end

if ndims(mask) > 2
    mask = mask(:, :, 1);
end

if isequal(size(mask), targetSize)
    return;
end

if numel(mask) == prod(targetSize)
    mask = reshape(mask, targetSize);
    return;
end

warning("RBC:MaskSizeAdjusted", ...
    "%s size [%s] did not match image size [%s]. Resizing with nearest-neighbor interpolation.", ...
    char(maskName), num2str(size(mask)), num2str(targetSize));
mask = imresize(mask, targetSize, "nearest");

end
