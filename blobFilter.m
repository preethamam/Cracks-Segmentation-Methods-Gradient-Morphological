function outputImage = blobFilter(BW1, blobfilter_sigma)    
    % BLOBFILTER Filters out small blobs from a binary image.
    %   OUTPUTIMAGE = BLOBFILTER(BW1, BLOBFILTER_SIGMA) removes blobs from
    %   the binary image BW1 that are smaller than a threshold determined
    %   by BLOBFILTER_SIGMA and the standard deviation of the blob areas.
    %
    %   Example:
    %       BW1 = imread('binary_image.png');
    %       blobfilter_sigma = 1.5;
    %       outputImage = blobFilter(BW1, blobfilter_sigma);
    
    % Get connected components
    CC = bwconncomp(BW1);
    S  = regionprops(CC,'Area');

    % Normal distribution fit
    [mu_hessian, sigma_hessian] = normfit(cell2mat(struct2cell(S)));

    % check for sigma
    if ((isempty(sigma_hessian)) || (isnan (sigma_hessian)))
        sigma_hessian = 0;
    end

    % Remove smaller area lesser than sigma_morph
    outputImage = bwareaopen(BW1, ceil(blobfilter_sigma * ...
                                sigma_hessian), 8);
end