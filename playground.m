% Get main folder
xpfolder = uigetdir();
% Get trans images list
transname = dir([xpfolder '/*trans*']);
transdir = [xpfolder '/' transname.name ];
translist = dir(fullfile(transdir,'*.tif'));
% Get rfp images list
rfpname = dir([xpfolder '/*rfp*']);
rfpdir = [xpfolder '/' rfpname.name ];
rfplist = dir(fullfile(rfpdir,'*.tif'));
% Get gfp images list
gfpname = dir([xpfolder '/*gfp*']);
gfpdir = [xpfolder '/' gfpname.name ];
gfplist = dir(fullfile(gfpdir,'*.tif'));



%% Ask user to place the ROIs
ROISfig = figure(1);
orI = imread(fullfile(transdir,translist(1).name));
imshow(imadjust(orI));
timezero = datevec(translist(1).date);

numROI = 0;
while true
    ret = input('Add ROI? [Y/n]: ','s');
    switch lower(ret)
        case 'y'
            numROI = numROI + 1;
                ROIS(numROI) = imrect(gca, [10 10 30 20]);
            setResizable(ROIS(numROI),false);
        case 'n'
            break;
    end
end

% Ask user for cross to compute cross-correlation
disp('Please place the square on the cross for xcorr')
CrossROI = imrect(gca, [10 10 150 150]);
setResizable(CrossROI,false);
wait(CrossROI);
CrossROI_P = CrossROI.getPosition;
crossRef = imcrop(orI,CrossROI_P);

%%
% Loop da loop
% I'll loop sequentially on rfp and then gfp
for ind0 = 1:numel(rfplist)
    rfpfname = fullfile(rfpdir,rfplist(ind0).name);
    IR = imread(rfpfname);
    timerfp(ind0) = etime(datevec(rfplist(ind0).date),timezero);
    
    % Compute crosscorr to get the x y displacement
    % find the corresponding trans image first:
    indCorr = find(~cellfun(@isempty, strfind({translist(:).name},rfplist(ind0).name)));
    if ~isempty(indCorr)
        Icorr = imread(fullfile(transdir,translist(indCorr).name));
        crossComp = imcrop(Icorr,CrossROI_P);
        motionXC = normxcorr2(crossRef,crossComp);
        [rowM colM] = find(motionXC == max(motionXC(:)));
        displacement = [(rowM - CrossROI_P(3) - 1) (colM - CrossROI_P(4) - 1) ];
    else
        displacement = [0 0];
    end
    
    for ind1 = 1:numel(ROIS)
        fluo = imcrop(IR, ROIS(ind1).getPosition + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
        if ~isempty(fluo)
            rfplevelMean(ind0,ind1) = mean(fluo(:));
            rfplevelMedian(ind0,ind1) = median(fluo(:));
            rfplevelMax(ind0,ind1) = max(fluo(:));
            sfl = sort(fluo(:));
            rfpleveltop20(ind0,ind1) = mean(sfl(round(numel(sfl)*.95):end));
        end
    end
    disp(ind0)
end
     

for ind0 = 1:numel(gfplist)
    gfpfname = fullfile(gfpdir,gfplist(ind0).name);
    IR = imread(gfpfname);
    timegfp(ind0) = etime(datevec(gfplist(ind0).date),timezero);
    
    % Compute crosscorr to get the x y displacement
    % find the corresponding trans image first:
    indCorr = find(~cellfun(@isempty, strfind({translist(:).name},gfplist(ind0).name)));
    if ~isempty(indCorr)
        Icorr = imread(fullfile(transdir,translist(indCorr).name));
        crossComp = imcrop(Icorr,CrossROI_P);
        motionXC = normxcorr2(crossRef,crossComp);
        [rowM colM] = find(motionXC == max(motionXC(:)));
        displacement = [(rowM - CrossROI_P(3) - 1) (colM - CrossROI_P(4) - 1) ];
    else
        displacement = [0 0];
    end
    
    for ind1 = 1:numel(ROIS)
        fluo = imcrop(IR, ROIS(ind1).getPosition + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
        if ~isempty(fluo)
            gfplevelMean(ind0,ind1) = mean(fluo(:));
            gfplevelMedian(ind0,ind1) = median(fluo(:));
            gfplevelMax(ind0,ind1) = max(fluo(:));
            sfl = sort(fluo(:));
            gfpleveltop20(ind0,ind1) =  mean(sfl(round(numel(sfl)*.95):end));
        end
    end
    disp(ind0)
end
        
        
    
    
    
% Final display
figure(3)
hold on
for ind1 = 1:numel(ROIS)
    plot(timerfp/3600,smooth(rfplevelMean(:,ind1)),'r')
    plot(timegfp/3600,smooth(gfplevelMean(:,ind1)),'g')
end

plot(timerfp/3600,smooth(mean(rfplevelMean,2)),'r','LineWidth',3)
plot(timegfp/3600,smooth(mean(gfplevelMean,2)),'g','LineWidth',3)

xlabel('time (h)')
ylabel('fluo a.u.')

save(fullfile(xpfolder,'QDiman'))
saveas(gcf,fullfile(xpfolder,'QDiman'),'fig')
saveas(gcf,fullfile(xpfolder,'QDiman'),'png')

