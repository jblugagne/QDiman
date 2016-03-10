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
% Get valves workspace if it exists:
if exist(fullfile(xpfolder,'../valves_workspace.mat'),'file')
    vlvwsp = load(fullfile(xpfolder,'../valves_workspace.mat'));
    for ind1 = 1:3
        disp(['media' num2str(ind1)])
        disp( [ 'label: ' vlvwsp.(['media' num2str(ind1) '_channelName'])])
        disp(vlvwsp.(['media' num2str(ind1)]))
    end
    answer = inputdlg({'What media percentage matrix should be used? (1 2 or 3)'})
    valvesmatrix = vlvwsp.(['media' num2str(answer{1})]);
end

% Do we make a video?
video = true;

if video 
    %%%%% VIDEO
    UlCornT = [20 20]; % Upper left corner of inserted text
    UlCornS = [20 500]; % Upper left corner of inserted scale
    ScSize = [80 4]; % Dimensions of the scale
    ScText = ['10 um'];

    RFPmM = [450 8000];
    GFPmM = [450 6000];
    
    vidObjU = VideoWriter(fullfile(xpfolder,'FilmUnc.avi'),'Uncompressed AVI');
    vidObjU.FrameRate = 7;
    open(vidObjU);
    
    vidObjJPG = VideoWriter(fullfile(xpfolder,'FilmJPEG.avi'),'Motion JPEG AVI');
    vidObjJPG.FrameRate = 7;
    
    open(vidObjJPG);
end




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
setResizable(CrossROI,true);
wait(CrossROI);
CrossROI_P = CrossROI.getPosition;
crossRef = imcrop(orI,CrossROI_P);

%%
% Loop da loop
% I'll loop sequentially on rfp and then gfp <- I don't do this anymore, I
% just loop on rfp and assume there is a corresponding gfp:
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
    displacement = [0 0];
    
    gfpfname = fullfile(gfpdir,gfplist(ind0).name);
    IG = imread(gfpfname);
    timegfp(ind0) = etime(datevec(gfplist(ind0).date),timezero);

    
    for ind1 = 1:numel(ROIS)
        
        % RFP
        fluo = imcrop(IR, ROIS(ind1).getPosition + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
        if ~isempty(fluo)
            rfplevelMean(ind0,ind1) = mean(fluo(:));
            rfplevelMedian(ind0,ind1) = median(fluo(:));
            rfplevelMax(ind0,ind1) = max(fluo(:));
            sfl = sort(fluo(:));
            rfpleveltop20(ind0,ind1) = mean(sfl(round(numel(sfl)*.95):end));
        end
        
        
        % GFP 
        fluo = imcrop(IG, ROIS(ind1).getPosition + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
        if ~isempty(fluo)
            gfplevelMean(ind0,ind1) = mean(fluo(:));
            gfplevelMedian(ind0,ind1) = median(fluo(:));
            gfplevelMax(ind0,ind1) = max(fluo(:));
            sfl = sort(fluo(:));
            gfpleveltop20(ind0,ind1) =  mean(sfl(round(numel(sfl)*.95):end));
        end
    end
    
    if video
        IG = imtranslate(IG,-fliplr(displacement),'OutputView', 'same');
        IR = imtranslate(IR,-fliplr(displacement),'OutputView', 'same');
        IG = imresize(IG,1/2);
        IR = imresize(IR,1/2);
        Icomp = cat(3,imadjust(double(IR)./2^16,RFPmM./2^16,[0 1]),imadjust(double(IG)./2^16,GFPmM./2^16,[0 1]),zeros(size(IR)));        ;
        valvestimes = cumsum(valvesmatrix(:,3));
        valveind = find(timerfp(ind0) < valvestimes,1,'first');
        curva = valvesmatrix(valveind,:);
        elapsed = secs2hms(timerfp(ind0));
        IPTGstr = ['IPTG   ' num2str(curva(1),'%03.f') '%'];
        ATCstr = ['ATC   ' num2str(curva(2),'%03.f') '%'];
        LBstr = ['LB      ' num2str(100-(curva(2)+curva(1)),'%03.f') '%' ];
        
        Icomp = insertText(Icomp,UlCornT + [-5 -5],elapsed,'BoxOpacity',0,'TextColor','w','FontSize',22);
        Icomp = insertText(Icomp,UlCornT + [-2 19],IPTGstr,'BoxOpacity',0,'TextColor','c','FontSize',15);
        Icomp = insertText(Icomp,UlCornT + [0 35],ATCstr,'BoxOpacity',0,'TextColor','m','FontSize',15);
        Icomp = insertText(Icomp,UlCornT + [0 51],LBstr,'BoxOpacity',0,'TextColor',[.8 .8 .8],'FontSize',15);
        
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 25] round(4*curva(1)) 12],'Color','c','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 41] round(4*curva(2)) 12],'Color','m','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 58] round(4*(100-curva(1)-curva(2))) 12],'Color',[.8 .8 .8],'Opacity',1);
        
                Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [500 25] 2 12],'Color','c','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [500 41] 2 12],'Color','m','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [500 58] 2 12],'Color',[.8 .8 .8],'Opacity',1);
        
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 25] 2 12],'Color','c','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 41] 2 12],'Color','m','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 58] 2 12],'Color',[.8 .8 .8],'Opacity',1);
                
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 35] 400 2],'Color','c','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 51] 400 2],'Color','m','Opacity',1);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornT + [100 68] 400 2],'Color',[.8 .8 .8],'Opacity',1);
        
        Icomp = insertText(Icomp,UlCornS + [-2 ScSize(2)-30 ],ScText,'BoxOpacity',0,'TextColor','w','FontSize',16);
        Icomp = insertShape(Icomp,'FilledRectangle',[UlCornS ScSize],'Color','w','Opacity',1);
         
        figure(2)
        imshow(Icomp)
        writeVideo(vidObjU,Icomp);
        writeVideo(vidObjJPG,Icomp);
    end
    
    
    disp(ind0)
end

if video
    close(vidObjU);
    close(vidObjJPG);
end
     

% for ind0 = 1:numel(gfplist)
%     gfpfname = fullfile(gfpdir,gfplist(ind0).name);
%     IR = imread(gfpfname);
%     timegfp(ind0) = etime(datevec(gfplist(ind0).date),timezero);
%     
%     % Compute crosscorr to get the x y displacement
%     % find the corresponding trans image first:
%     indCorr = find(~cellfun(@isempty, strfind({translist(:).name},gfplist(ind0).name)));
%     if ~isempty(indCorr)
%         Icorr = imread(fullfile(transdir,translist(indCorr).name));
%         crossComp = imcrop(Icorr,CrossROI_P);
%         motionXC = normxcorr2(crossRef,crossComp);
%         [rowM colM] = find(motionXC == max(motionXC(:)));
%         displacement = [(rowM - CrossROI_P(3) - 1) (colM - CrossROI_P(4) - 1) ];
%     else
%         displacement = [0 0];
%     end
%     
%     for ind1 = 1:numel(ROIS)
%         fluo = imcrop(IR, ROIS(ind1).getPosition + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
%         if ~isempty(fluo)
%             gfplevelMean(ind0,ind1) = mean(fluo(:));
%             gfplevelMedian(ind0,ind1) = median(fluo(:));
%             gfplevelMax(ind0,ind1) = max(fluo(:));
%             sfl = sort(fluo(:));
%             gfpleveltop20(ind0,ind1) =  mean(sfl(round(numel(sfl)*.95):end));
%         end
%     end
%     disp(ind0)
% end
%         
        
    
    
    
%% Final display

figure(3)
cla
for ind1 = 1:numel(origROIS_P)
    semilogy(timerfp/3600,smooth(rfplevelMean(:,ind1)-rfpbkgd'),'Color',[1 .6 .6])
    hold on
    semilogy(timegfp/3600,smooth(gfplevelMean(:,ind1)-gfpbkgd'),'Color',[.6 1 .6])
end

semilogy(timerfp/3600,smooth(mean(rfplevelMean,2)-rfpbkgd'),'r','LineWidth',3)
semilogy(timegfp/3600,smooth(mean(gfplevelMean,2)-gfpbkgd'),'g','LineWidth',3)

set(gcf,'Position',[10 10 750 450]);
set(gca,'Xcolor','w');
set(gca,'Ycolor','w');
set(gca,'XTick',[0 10 20 30 40 50 60 ]);
set(gca,'YTick',[20 200 5e2 20e2 5e3 15e3 ]);
set(gca,'Box','off');

xlim([0 24])
ylim([15 17e3])
% xlim([0 timerfp(end)/3600])

xlabel('time (h)')
ylabel('fluo a.u.')

save(fullfile(xpfolder,'QDiman'))
saveas(gcf,fullfile(xpfolder,'QDiman'),'fig')
saveas(gcf,fullfile(xpfolder,'QDiman'),'epsc')
saveas(gcf,fullfile(xpfolder,'QDiman'),'png')

figure(4)
cla
for ind1 = 1:numel(origROIS_P)
    semilogy(timerfp/3600,smooth(rfplevelMean(:,ind1)-rfpbkgd')./smooth(gfplevelMean(:,ind1)-gfpbkgd'),'Color','b')
    hold on
end
semilogy(timerfp/3600,smooth(mean(rfplevelMean,2)-rfpbkgd')./smooth(mean(gfplevelMean,2)-gfpbkgd'),'r','LineWidth',3)


xlim([0 24])
ylim([1e-2 1e2])
set(gcf,'Position',[10 10 750 450]);
set(gca,'Xcolor','w');
set(gca,'Ycolor','w');
set(gca,'XTick',[0 10 20 30 40 50 60 ]);
set(gca,'YTick',[1e-2 1e-1 1 1e1 1e2 ]);
set(gca,'YTickLabel',{'1/100' '1/10' '1/1' '10/1' '100/1' });
set(gca,'Box','off');

xlabel('time (h)')
ylabel('rfp/gfp')

saveas(gcf,fullfile(xpfolder,'QDiman-Ratio'),'fig')
saveas(gcf,fullfile(xpfolder,'QDiman-Ratio'),'epsc')
saveas(gcf,fullfile(xpfolder,'QDiman-Ratio'),'png')

% drawvalvesstates(valvesmatrix,[0 timerfp(end)/3600])

%% Load the valves workspace file first
media = media1;

figure(5)
cla
hold on
stairs(cumsum([0; media(1:(end-1),3)])/3600,media(:,1),'Color',[0 1 1],'LineWidth',3)
stairs(cumsum([0; media(1:(end-1),3)])/3600,media(:,2)+125,'Color',[1 0 1],'LineWidth',3)

set(gcf,'Position',[10 10 750 250]);
xlim([0 24])
ylim([-5 250])
line([xlim],[0     0],'Color',[0 1 1])
line([xlim],[100 100],'Color',[0 1 1])

line([xlim],[125 125],'Color',[1 0 1])
line([xlim],[225 225],'Color',[1 0 1])

set(gca,'XTick',[0 10 20 30 40 50 60 ]);
set(gca,'YTick',[0 100 125 225]);
set(gca,'YTickLabel',{'0%' '100%' '0%' '100%'});
set(gca,'Box','off');

xlabel('time (h)')
ylabel('IPTG             aTC')

saveas(gcf,fullfile(xpfolder,'Valves'),'fig')
saveas(gcf,fullfile(xpfolder,'Valves'),'epsc')
saveas(gcf,fullfile(xpfolder,'Valves'),'png')
