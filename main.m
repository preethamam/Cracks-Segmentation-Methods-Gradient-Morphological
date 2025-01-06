%% Start parameters
%--------------------------------------------------------------------------
clear; close all; clc;
clcwaitbarz = findall(0,'type','figure','tag','TMWWaitbar');
delete(clcwaitbarz);
Start = tic;

%% Inputs
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
crackMaps = cell(length(imFiles), totalMethods+1);

fh = figure('WindowState', 'maximized');
t = tiledlayout(length(imFiles), totalMethods+2, TileSpacing="tight", Padding="tight");
cnt = 1;
titleShow = true(1, totalMethods+2);

for i = 1:length(imFiles)
    % Image read
    inputImage = imread(fullfile(imFiles(i).folder, imFiles(i).name));

    % Labels
    labels = imread(fullfile(labelsimFiles(i).folder, labelsimFiles(i).name));

    % Convert to grayscale
    imageGray = double(rgb2gray(inputImage));
        
    for m = 1:totalMethods+2        
        % Crack detection morphological
        if m == 1
            % Morphological crack detection
            morphoOutputImage = crackDetectSalembierSinhaJahan(imageGray, crackLEN, anglebetween);
        
            % Blob filtering
            blobFilterImage = blobFilter(morphoOutputImage, blobFilterSigma);
        elseif m == 2        
            % Hessian/Frangi vessel filter crack detection
            [Ivessel,Scale,Direction] = FrangiFilter2D(imageGray, frangiOptions);

            % Binarize the image
            hessianOutputImage = imbinarize(Ivessel, graythresh(Ivessel));

            % Blob filtering
            blobFilterImage = blobFilter(hessianOutputImage, blobFilterSigma);
        else
            % Hessian/Frangi vessel filter crack detection            
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
            blobFilterImage = blobFilter(mfatOutputImage, blobFilterSigma);
        end

        % Save crackmaps
        if m == 1
            crackMaps{i,m} = labels;
        elseif m <= totalMethods+1
            crackMaps{i,m} = blobFilterImage;
        end
    
        % Image show
        if mod(cnt, totalMethods+2) == 1
            nexttile
            imshow(inputImage)
            if titleShow(1) == true
                title('Original')
            end
            titleShow(1) = false;
        elseif mod(cnt, totalMethods+2) == 2   
            nexttile
            imshow(crackMaps{i,1})
            if titleShow(2) == true
                title('Groundtruth')
            end
            titleShow(2) = false;            
        elseif mod(cnt, totalMethods+2) == 3 
            nexttile
            imshow(crackMaps{i,2})
            if titleShow(3) == true
                title('Morpho')
            end
            titleShow(3) = false;            
        elseif mod(cnt, totalMethods+2) == 4   
            nexttile
            imshow(crackMaps{i,3})
            if titleShow(4) == true
                title('Hessian')
            end
            titleShow(4) = false;             
        else
            nexttile
            imshow(crackMaps{i,4})            
            if titleShow(5) == true
                title('MFAT')
            end
            titleShow(5) = false;
        end
        cnt = cnt + 1;
    end
end
exportgraphics(fh, 'crack_segmentation.png')


%% Show single crack image
figure;
ax = gca;
imshow(crackMaps{3,4})
exportgraphics(ax, 'crack_output.png')

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