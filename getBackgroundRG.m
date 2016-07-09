function bkgd = getBackgroundRG(max_lacI, max_tetR, varargin)
% This function creates a simple red/green gradient background image based on the
% maximum laci and tetR levels provided

lts = [max_lacI max_tetR]; 

if nargin == 4
    minmaxRED = varargin{1};
    minmaxGRN = varargin{2};
else
    minmaxRED = [0 lts(1)];
    minmaxGRN = [0 lts(2)];
end

curveRED = [zeros(1,minmaxRED(1)) linspace(0,1,minmaxRED(2)-minmaxRED(1)+1) ones(1,lts(1)-minmaxRED(2))];
curveGRN = [zeros(1,minmaxGRN(1)) linspace(0,1,minmaxGRN(2)-minmaxGRN(1)+1) ones(1,lts(2)-minmaxGRN(2))];

bkgd = zeros(lts(2)+1,lts(1)+1,3);
bkgd(:,:,1) = repmat(curveRED,lts(2)+1,1);
bkgd(:,:,2) = repmat(curveGRN',1,lts(1)+1);