function out = ProbabiliticMFATSpacing(I,options)
% calculates the vesselness Probabilitic Fractional anisotropy tensor of a 2D
%    Reference :
%    1- Hansen, Charles D., and Chris R. Johnson. Visualization handbook. Academic Press, 2011.�? APA    
%    2- Prados, Ferran, et al. "Analysis of new diffusion tensor imaging anisotropy measures in the three�?phase plot." Journal of Magnetic Resonance Imaging 31.6 (2010): 1435-1444.�?    
% inputs,
%   I : 2D image
%   sigmas : vector of scales on which the vesselness is computed
%   spacing : input image spacing resolution - during hessian matrix 
%       computation, the gaussian filter kernel size in each dimension can 
%       be adjusted to account for different image spacing for different
%       dimensions            
%   tau,tau 2: cutoff thresholding related to eignvlaues.
%   D  : the step size of soultion evolution.
%
% outputs,
%   out: final vesselness response over scales sigmas
%
% Example:

% out = ProbabiliticFractionalIstropicTensor(I, sigmas,spacing,tau ,tau2,D)
% sigmas = [1:1:3];
% out = ProbabiliticFractionalIstropicTensor(I, sigmas, 1,0.03,0.3,0.27)
%
% Function written by Haifa F. Alhasson , Durham University (Dec 2017)
% Based on code by T. Jerman, University of Ljubljana (October 2014)

%% Use the parameters by struct
sigmas      = options.sigmas1 : options.sigmasScaleRatio : options.sigmas2;        
spacing     = options.spacing;
whiteondark = options.whiteondark;
tau         = options.tau;
tau2        = options.tau2; 
D           = options.D;

%%
spacing = [spacing(1) spacing(1)]; 
verbose = 1;

%% preprocessing 
I = single(I);
%% Enhancement 
vesselness = zeros(size(I));
for j = 1:length(sigmas)
    if verbose
        %disp(['Current filter scale (sigma): ' num2str(sigmas(j)) ]);
    end
    %% (1) Eigen-values
    [~, Lambda2] = imageEigenvalues(I,sigmas(j),spacing,whiteondark); 
    %% filter response at current scale from RVR
    Lambda3 = Lambda2;
    Lambda3(Lambda3<0 & Lambda3 >= tau .* min(Lambda3(:)))=  tau.* min(Lambda3(:));
    %% New filter response
    Lambda4 = Lambda2;
    Lambda4(Lambda4<0 & Lambda4 >= tau2 .* min(Lambda4(:)))= tau2.* min(Lambda4(:));
    %% (2) Fractional Anisotropy Tensor equation: 
    % Mean Eigen-value (LambdaMD):
    Trace = (abs(Lambda2)+ abs(Lambda3) +abs(Lambda4));
    LambdaMD = 1./3;
    %%
    p2= abs(Lambda2./Trace);
    p3= abs(Lambda3./Trace);
    p4= abs(Lambda4./Trace);
    
    % response at current scale 
    response = sqrt((((abs(p2))-abs(LambdaMD)).^2+(abs((p3))-abs(LambdaMD)).^2+(abs(p4)-abs(LambdaMD)).^2)) ./sqrt((p2).^2+((p3)).^2+(p4).^2);    
    response = sqrt(3./2).*(response);
    response  = (imcomplement(response));
    
    %% (3) Post-processing: targeting gaussian noise in the background
     x = Lambda3 - Lambda2;
    response(x == min(x(:))) = 1;
    response(x < max(x(:))) = 0; 
    response(Lambda2 > x) = 0;
% %     response(Lambda2 > x) = 0;
%     response(~isfinite(response)) = 0;
% %     response(Lambda3 > x) = 0;
%     response(~isfinite(response)) = 0;
%     response(x > max(x(:))) = 1; 
    response(Lambda3 > x) = 0;
    response(Lambda2>=0) = 0;
    response(Lambda3>=0) = 0;   
    response(~isfinite(response)) = 0;   
    %% (4) Update vesselness & I
    if(j==1)
        vesselness = response;
    else  
        vesselness = vesselness + D .* ( response - D);
        vesselness = max(vesselness,response);
    end
    % Normalize vessleness
     vesselness = min(max(vesselness, 0), 1);

    clear Lambda2 Lambda3 Lambda4 LambdaMD
end
out = vesselness ./ max(vesselness(:));  
out(out < 1e-2) = 0;

function [Lambda1, Lambda2] = imageEigenvalues(I,sigma,spacing,whiteondark)
% calculates the two eigenvalues for each voxel in a volume

% Calculate the 2D hessian
[Hxx, Hyy, Hxy] = Hessian2D(I,sigma,spacing);

% Correct for scaling
c=sigma.^2;
Hxx = c*Hxx; 
Hxy = c*Hxy;
Hyy = c*Hyy;

% correct sign based on brightness of structuress
if whiteondark == false
    c=-1;
    Hxx = c*Hxx; 
    Hxy = c*Hxy;
    Hyy = c*Hyy;   
end

% reduce computation by computing vesselness only where needed
% S.-F. Yang and C.-H. Cheng, �Fast computation of Hessian-based
% enhancement filters for medical images,� Comput. Meth. Prog. Bio., vol.
% 116, no. 3, pp. 215�225, 2014.
B1 = - (Hxx+Hyy);
B2 = Hxx .* Hyy - Hxy.^2;


T = ones(size(B1));
T(B1<0) = 0;
T(B2==0 & B1 == 0) = 0;

clear B1 B2;

indeces = find(T==1);

Hxx = Hxx(indeces);
Hyy = Hyy(indeces);
Hxy = Hxy(indeces);

% Calculate eigen values
[Lambda1i,Lambda2i]=eigvalOfHessian2D(Hxx,Hxy,Hyy);

clear Hxx Hyy Hxy;

Lambda1 = zeros(size(T));
Lambda2 = zeros(size(T));

Lambda1(indeces) = Lambda1i;
Lambda2(indeces) = Lambda2i;

% some noise removal
Lambda1(~isfinite(Lambda1)) = 0;
Lambda2(~isfinite(Lambda2)) = 0;

Lambda1(abs(Lambda1) < 1e-4) = 0;
Lambda2(abs(Lambda2) < 1e-4) = 0;


function [Dxx, Dyy, Dxy] = Hessian2D(I,Sigma,spacing)
%  filters the image with an Gaussian kernel
%  followed by calculation of 2nd order gradients, which aprroximates the
%  2nd order derivatives of the image.
% 
% [Dxx, Dyy, Dxy] = Hessian2D(I,Sigma,spacing)
% 
% inputs,
%   I : The image, class preferable double or single
%   Sigma : The sigma of the gaussian kernel used. If sigma is zero
%           no gaussian filtering.
%   spacing : input image spacing
%
% outputs,
%   Dxx, Dyy, Dxy: The 2nd derivatives

if nargin < 3, Sigma = 1; end

if(Sigma>0)
    F = imgaussian(I,Sigma,spacing);
else
    F=I;
end

% figure; imshow(uint8(F))

% Create first and second order diferentiations
Dy=gradient2(F,'y');
Dyy=(gradient2(Dy,'y'));
clear Dy;

Dx=gradient2(F,'x');
Dxx=(gradient2(Dx,'x'));
Dxy=(gradient2(Dx,'y'));
clear Dx;

function D = gradient2(F,option)
% Example:
%
% Fx = gradient2(F,'x');

[k,l] = size(F);
D  = zeros(size(F),class(F)); 

switch lower(option)
case 'x'
    % Take forward differences on left and right edges
    D(1,:) = (F(2,:) - F(1,:));
    D(k,:) = (F(k,:) - F(k-1,:));
    % Take centered differences on interior points
    D(2:k-1,:) = (F(3:k,:)-F(1:k-2,:))/2;
case 'y'
    D(:,1) = (F(:,2) - F(:,1));
    D(:,l) = (F(:,l) - F(:,l-1));
    D(:,2:l-1) = (F(:,3:l)-F(:,1:l-2))/2;
otherwise
    disp('Unknown option')
end
        
function I=imgaussian(I,sigma,spacing,siz)
% IMGAUSSIAN filters an 1D, 2D color/greyscale or 3D image with an 
% Gaussian filter. This function uses for filtering IMFILTER or if 
% compiled the fast  mex code imgaussian.c . Instead of using a 
% multidimensional gaussian kernel, it uses the fact that a Gaussian 
% filter can be separated in 1D gaussian kernels.
%
% J=IMGAUSSIAN(I,SIGMA,SIZE)
%
% inputs,
%   I: 2D input image
%   SIGMA: The sigma used for the Gaussian kernel
%   SPACING: input image spacing
%   SIZ: Kernel size (single value) (default: sigma*6)
% 
% outputs,
%   I: The gaussian filtered image
%

if(~exist('siz','var')), siz=sigma*6; end

if(sigma>0)
    % Filter each dimension with the 1D Gaussian kernels\
    x=-ceil(siz/spacing(1)/2):ceil(siz/spacing(1)/2);
    H = exp(-(x.^2/(2*(sigma/spacing(1))^2)));
    H = H/sum(H(:));    
    Hx=reshape(H,[length(H) 1]);
    
    x=-ceil(siz/spacing(2)/2):ceil(siz/spacing(2)/2);
    H = exp(-(x.^2/(2*(sigma/spacing(2))^2)));
    H = H/sum(H(:));    
    Hy=reshape(H,[1 length(H)]);
    
    I=imfilter(imfilter(I,Hx, 'same' ,'replicate'),Hy, 'same' ,'replicate');
end

function [Lambda1,Lambda2]=eigvalOfHessian2D(Dxx,Dxy,Dyy)
% This function calculates the eigen values from the
% hessian matrix, sorted by abs value

% Compute the eigenvectors of J, v1 and v2
tmp = sqrt((Dxx - Dyy).^2 + 4*Dxy.^2);

% Compute the eigenvalues
mu1 = 0.5*(Dxx + Dyy + tmp);
mu2 = 0.5*(Dxx + Dyy - tmp);

% Sort eigen values by absolute value abs(Lambda1)<abs(Lambda2)
check=abs(mu1)>abs(mu2);

Lambda1=mu1; Lambda1(check)=mu2(check);
Lambda2=mu2; Lambda2(check)=mu1(check);

