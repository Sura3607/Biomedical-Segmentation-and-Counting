function imagePath = datasetImagePath(row, config)
%DATASETIMAGEPATH Build image path for a metadata table row.

if istable(row)
    splitName = string(row.split(1));
    imageId = string(row.id(1));
else
    splitName = string(row.split);
    imageId = string(row.id);
end

imagePath = fullfile(config.dataRoot, char(splitName), "img", char(imageId));

end
