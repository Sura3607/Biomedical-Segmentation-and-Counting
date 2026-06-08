function finalRoot = setupFinalPath(finalRoot)
%SETUPFINALPATH Add project folders needed by the MATLAB demo.

if nargin < 1 || isempty(finalRoot)
    finalRoot = fileparts(mfilename("fullpath"));
end

finalRoot = char(finalRoot);
addpath(finalRoot);
addpath(fullfile(finalRoot, "methods"));
addpath(fullfile(finalRoot, "script"));

end
