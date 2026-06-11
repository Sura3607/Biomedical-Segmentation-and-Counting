function annotationPath = datasetAnnotationPath(row, config)
%DATASETANNOTATIONPATH Build annotation path for a metadata table row.

if istable(row)
    annotationValue = string(row.annotation(1));
    splitName = string(row.split(1));
    imageId = string(row.id(1));
else
    annotationValue = string(row.annotation);
    splitName = string(row.split);
    imageId = string(row.id);
end

if strlength(annotationValue) > 0
    relativePath = strrep(char(annotationValue), "/", filesep);
    annotationPath = fullfile(config.projectRoot, relativePath);
else
    annotationPath = fullfile(config.dataRoot, char(splitName), "ann", [char(imageId) '.json']);
end

end
