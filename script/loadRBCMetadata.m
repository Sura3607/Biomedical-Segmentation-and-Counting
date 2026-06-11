function metadata = loadRBCMetadata(metadataPath)
%LOADRBCMETADATA Load extracted RBC count metadata as a table.

if nargin < 1 || isempty(metadataPath)
    repoRoot = fileparts(fileparts(mfilename("fullpath")));
    metadataPath = fullfile(repoRoot, "data", "metadata_coutingrbc.json");
end

if ~isfile(metadataPath)
    error("RBC metadata file not found: %s", metadataPath);
end

text = fileread(metadataPath);
text = erase(text, char(65279));
raw = jsondecode(strtrim(text));
metadata = struct2table(raw);

metadata.id = string(metadata.id);
metadata.split = string(metadata.split);
metadata.annotation = string(metadata.annotation);
metadata.groundTruth = double(metadata.groundTruth);

end
