function trueCount = lookupRBCGroundTruth(imagePathOrName, metadataPath)
%LOOKUPRBCGROUNDTRUTH Return RBC count by image filename, or NaN if unknown.

if nargin < 2
    metadataPath = "";
end

trueCount = NaN;

if nargin < 1 || isempty(imagePathOrName)
    return;
end

if isempty(metadataPath)
    metadata = loadRBCMetadata();
else
    if ~isfile(metadataPath)
        return;
    end
    metadata = loadRBCMetadata(metadataPath);
end

[~, name, ext] = fileparts(char(imagePathOrName));
imageId = string(name + ext);
matchIdx = find(metadata.id == imageId, 1);

if ~isempty(matchIdx)
    trueCount = metadata.groundTruth(matchIdx);
end

end
