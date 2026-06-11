function [mask, count] = readRBCAnnotationMask(annotationPath, imageSize)
%READRBCANNOTATIONMASK Rasterize RBC rectangle annotations into a mask.

[mask, count] = readAnnotationClassMask(annotationPath, imageSize, "RBC");

end
