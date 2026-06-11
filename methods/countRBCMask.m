function counts = countRBCMask(mask, rgb, config)
%COUNTRBCMASK Run all shared RBC counting methods on one RBC mask.

counts = struct();
counts.connectedComponents = countByConnectedComponents(mask, rgb, config);
counts.watershed = countByWatershed(mask, rgb, config);
counts.areaEstimate = countByAreaEstimate(mask, rgb, config);

end
