function clusterId = assignKMeansCentroids(features, centroids)
%ASSIGNKMEANSCENTROIDS Assign rows to nearest K-means centroid.

rowCount = size(features, 1);
k = size(centroids, 1);
clusterId = zeros(rowCount, 1);
chunkSize = 50000;

for startIdx = 1:chunkSize:rowCount
    endIdx = min(startIdx + chunkSize - 1, rowCount);
    block = features(startIdx:endIdx, :);
    distances = zeros(size(block, 1), k);

    for clusterIdx = 1:k
        diff = block - centroids(clusterIdx, :);
        distances(:, clusterIdx) = sum(diff .^ 2, 2);
    end

    [~, clusterId(startIdx:endIdx)] = min(distances, [], 2);
end

end
