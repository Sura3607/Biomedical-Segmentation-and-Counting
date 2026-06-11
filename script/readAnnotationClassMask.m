function [mask, count] = readAnnotationClassMask(annotationPath, imageSize, classTitle)
%READANNOTATIONCLASSMASK Rasterize rectangle annotations for one class.
% Dataset annotations store 0-based rectangle coordinates.

if ~isfile(annotationPath)
    error("Annotation file not found: %s", annotationPath);
end

height = imageSize(1);
width = imageSize(2);
mask = false(height, width);
classTitle = string(classTitle);

text = fileread(annotationPath);
text = erase(text, char(65279));
data = jsondecode(strtrim(text));
if ~isfield(data, "objects") || isempty(data.objects)
    count = 0;
    return;
end

objects = data.objects;
count = 0;

for i = 1:numel(objects)
    obj = objects(i);
    if ~isfield(obj, "classTitle") || ~strcmpi(string(obj.classTitle), classTitle)
        continue;
    end

    count = count + 1;
    exterior = obj.points.exterior;
    xs = double(exterior(:, 1));
    ys = double(exterior(:, 2));

    x1 = max(1, floor(min(xs)) + 1);
    x2 = min(width, ceil(max(xs)));
    y1 = max(1, floor(min(ys)) + 1);
    y2 = min(height, ceil(max(ys)));

    if x1 <= x2 && y1 <= y2
        mask(y1:y2, x1:x2) = true;
    end
end

end
