%% Start parameters
%--------------------------------------------------------------------------
clear; close all; clc;
clcwaitbarz = findall(0,'type','figure','tag','TMWWaitbar');
delete(clcwaitbarz);
Start = tic;

%% Inputs
%--------------------------------------------------------------------------
% Image input
%--------------------------------------------------------------------------
imageIndex = 4;

%--------------------------------------------------------------------------
% Blob filtering
%--------------------------------------------------------------------------
blobFilterSigma = 0.5;
totalMethods = 3;

%--------------------------------------------------------------------------
% Jahanshahi Inputs
%--------------------------------------------------------------------------
nmin = 1; %pixel-1; %1;           %1 | 40  % minimum crack size in pixel (after transformation)
nmax = 200; %pixel-25; %200;      % maximum crack size in pixel (after transformation)
nstep = 5; %pixel-2; %5
crackLEN = nmin+2 : nstep : nmax+10; % Crack structural length % options:  [1 : max(size(image))] 

% Angle between
anglebetween = [0 45 90 135]; % [0 : delta : 179], use symmetry

%--------------------------------------------------------------------------
% Hessian options/Inputs
%--------------------------------------------------------------------------
frangiOptions.FrangiScaleRange = [1, 15];
frangiOptions.FrangiBetaOne     = 0.5;
frangiOptions.FrangiBetaTwo     = 50;
frangiOptions.BlackWhite        = 1;
frangiOptions.verbose           = 0;

%--------------------------------------------------------------------------
% Multiscale fractional anisotropic tensor options/Inputs
%--------------------------------------------------------------------------
MFAT_TYPE = 'ProbabilisticFAT';   % 'EigenFAT' | 'ProbabilisticFAT'

% MFAT filter options
MFAToptions.sigmas1       = 0.7181;  % 1
MFAToptions.sigmas2       = 5; % 12.5
MFAToptions.sigmasScaleRatio = 0.25;
MFAToptions.spacing       = 0.39; %0.4, 0.45 0.39
MFAToptions.tau           = 0.25; 
MFAToptions.tau2          = 0.5; 
MFAToptions.D             = 0.5; %0.85
MFAToptions.whiteondark   = false;

%% Input images
images = dir('images');
imFiles = images(~ismember({images.name},{'.','..'}));

labels = dir('labels');
labelsimFiles = labels(~ismember({labels.name},{'.','..'}));

%% Folders I/O
addpath('hessian', 'mfat', 'morphological')

%% Process images

% Image read
inputImage = imread(fullfile(imFiles(imageIndex).folder, imFiles(imageIndex).name));

% Labels
labels = imread(fullfile(labelsimFiles(imageIndex).folder, labelsimFiles(imageIndex).name));

% Convert to grayscale
imageGray = double(rgb2gray(inputImage));

%% Detect cracks using three methods
%-----------------------------------------------------------------------------------------------   
% Morphological crack detection
morphoOutputImage = crackDetectSalembierSinhaJahan(imageGray, crackLEN, anglebetween);

% Blob filtering
blobFilterImageMorpho = blobFilter(morphoOutputImage, blobFilterSigma);

%-----------------------------------------------------------------------------------------------
% Hessian/Frangi vessel filter crack detection
[Ivessel,Scale,Direction] = FrangiFilter2D(imageGray, frangiOptions);

% Binarize the image
hessianOutputImage = imbinarize(Ivessel, graythresh(Ivessel));

% Blob filtering
blobFilterImageHessian = blobFilter(hessianOutputImage, blobFilterSigma);

%-----------------------------------------------------------------------------------------------
% MFAT crack detection            
switch MFAT_TYPE
    case 'EigenFAT'
        % Proposed Method (Eign values based version)
        Ivessel = FractionalIstropicTensor(imageGray, MFAToptions);
        Ivessel = normalize(Ivessel);
    case 'ProbabilisticFAT'
        % Proposed Method (probability based version)
        % Ivessel = ProbabiliticMFATSpacing(imageGray, MFAToptions);
        Ivessel = ProbabiliticMFATSigmas(imageGray, MFAToptions);
        Ivessel = normalize(Ivessel);
end

% Binarize the image
mfatOutputImage = imbinarize(Ivessel, graythresh(Ivessel));

% Blob filtering
blobFilterImageMFAT = blobFilter(mfatOutputImage, blobFilterSigma);
        
%% Show crack detection results
fh = figure('WindowState', 'maximized');
t = tiledlayout(2, 3, TileSpacing="tight", Padding="compact");

% Plot input image
nexttile
imshow(inputImage)
title('Original', 'fontsize', 25)

% Plot ground-truth image
nexttile
imshow(labels)
title('Groundtruth', 'fontsize', 25)

% Plot mopho output image
nexttile
imshow(blobFilterImageMorpho)
title('Morpho', 'fontsize', 25)

% Plot Hessian output image
nexttile
imshow(blobFilterImageHessian)
title('Hessian', 'fontsize', 25)

% Plot MFAT output image
nexttile
imshow(blobFilterImageMFAT)
title('MFAT', 'fontsize', 25)

%% End parameters
%--------------------------------------------------------------------------
clcwaitbarz = findall(0,'type','figure','tag','TMWWaitbar');
delete(clcwaitbarz);
statusFclose = fclose('all');
if(statusFclose == 0)
    disp('All files are closed.')
end
Runtime = toc(Start);
disp(Runtime);