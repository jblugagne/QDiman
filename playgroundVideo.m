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
% valvesmatrix = cat(2,vhs.timeseries.tschan3.Data, vhs.timeseries.tschan3.Time)
% vlvstT = vhs.timeseries.tschan3.UserData.starttime;
%% Do we make a video?
video = true;

if video 
    %%%%% VIDEO
    UlCornT = [20 20]; % Upper left corner of inserted text
    UlCornS = [20 500]; % Upper left corner of inserted scale
    ScSize = [80 4]; % Dimensions of the scale
    ScText = ['10 um'];
    uselogscale = true;

    RFPmM = [450 5000];
    GFPmM = [550 6000];
    
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
% disp('Please place the square on the cross for xcorr')
% CrossROI = imrect(gca, [10 10 150 150]);
% setResizable(CrossROI,true);
% wait(CrossROI);
% CrossROI_P = CrossROI.getPosition;
% crossRef = imcrop(orI,CrossROI_P);

rotangle = 0;

for ind1 = 1:numel(ROIS)
    ROIS_P{ind1} = ROIS(ind1).getPosition;
end

% ROIS_P = [];
%%
% Loop da loop
% I'll loop sequentially on rfp and then gfp <- I don't do this anymore, I
% just loop on rfp and assume there is a corresponding gfp:
% for ind0 = 1:numel(rfplist)
for ind0 = 1:1:300
    rfpfname = fullfile(rfpdir,rfplist(ind0).name);
    IR = imread(rfpfname);
    timerfp(ind0) = etime(datevec(rfplist(ind0).date),timezero);
    
    % Compute crosscorr to get the x y displacement
    % find the corresponding trans image first:
%     indCorr = find(~cellfun(@isempty, strfind({translist(:).name},rfplist(ind0).name)));
%     if ~isempty(indCorr)
%         Icorr = imread(fullfile(transdir,translist(indCorr).name));
% %         crossComp = imcrop(Icorr,CrossROI_P);
% %         motionXC = normxcorr2(crossRef,crossComp);
%         motionXC = normxcorr2(orI,Icorr);
%         [rowM colM] = find(motionXC == max(motionXC(:)));
%         displacement = [(rowM - size(orI,1) - 1) (colM - size(orI,2) - 1) ];
%     else
%         displacement = [0 0];
%     end
    displacement = [0 0];
    
    gfpfname = fullfile(gfpdir,gfplist(ind0).name);
    IG = imread(gfpfname);
    timegfp(ind0) = etime(datevec(gfplist(ind0).date),timezero);

    
    for ind1 = 1:numel(ROIS_P)
        
        try
            ROIS(ind1).setPosition(ROIS_P{ind1} + [fliplr(displacement) 0 0 ]);
        catch
        end
        % RFP
        fluo = imcrop(IR, ROIS_P{ind1} + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
        if ~isempty(fluo)
            rfplevelMean(ind0,ind1) = mean(fluo(:));
            rfplevelMedian(ind0,ind1) = median(fluo(:));
            rfplevelMax(ind0,ind1) = max(fluo(:));
            sfl = sort(fluo(:));
            rfpleveltop20(ind0,ind1) = mean(sfl(round(numel(sfl)*.95):end));
        end
        
        
        % GFP 
        fluo = imcrop(IG, ROIS_P{ind1} + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
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
        IR = imadjust(double(IR)./2^16,RFPmM./2^16,[0 1]);
        IG = imadjust(double(IG)./2^16,GFPmM./2^16,[0 1]);
        
        if uselogscale
            IR(:) = log(IR(:)+1)./log(2);
            IG(:) = log(IG(:)+1)./log(2);
        end
        
        Icomp = cat(3,IR,IG,zeros(size(IR)));       

        
        Icomp = imrotate(Icomp,rotangle,'bilinear','crop');
%         valvestimes = cumsum(valvesmatrix(:,3));
        valvestimes = valvesmatrix(:,3);
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

% save(fullfile(xpfolder,'QDiman'))
% saveas(gcf,fullfile(xpfolder,'QDiman'),'fig')
% saveas(gcf,fullfile(xpfolder,'QDiman'),'epsc')
% saveas(gcf,fullfile(xpfolder,'QDiman'),'png')

figure(4)
cla
for ind1 = 1:numel(origROIS_P)
    semilogy(timerfp/3600,smooth(rfplevelMean(:,ind1)-rfpbkgd')./smooth(gfplevelMean(:,ind1)-gfpbkgd'),'Color','b')
    hold on
end
semilogy(timerfp/3600,smooth(mean(rfplevelMean,2)-rfpbkgd')./smooth(mean(gfplevelMean,2)-gfpbkgd'),'r','LineWidth',3)


xlim([0 16])
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
% 
% saveas(gcf,fullfile(xpfolder,'QDiman-Ratio'),'fig')
% saveas(gcf,fullfile(xpfolder,'QDiman-Ratio'),'epsc')
% saveas(gcf,fullfile(xpfolder,'QDiman-Ratio'),'png')

% drawvalvesstates(valvesmatrix,[0 timerfp(end)/3600])

%% Reconstruct from control decisions
init = [80 20];
init_nb = 1;
interv = 5*60;
final = [25 20];

atc = [repmat(init(2),1,init_nb) ch3RFPcntrlwrpr.decisions final(2)];
iptg = [repmat(init(1),1,init_nb) ch3GFPcntrlwrpr.decisions repmat(25,1,8) final(1)];

timevalves = cumsum([repmat(interv,1,init_nb) repmat(interv,1,numel(ch3RFPcntrlwrpr.decisions)) 12*3600]);

media = [ iptg; atc; timevalves]';

%% Load and Extract the data from the valves variable
posV = '3';

valvesmatrix = cat(2,vhs.timeseries.(['tschan' posV]).Data, vhs.timeseries.(['tschan' posV]).Time)
vlvstT = vhs.timeseries.(['tschan' posV]).UserData.starttime;

% media = media3;
media = valvesmatrix;

%% Load and extract the data from the control variable
posV = '1';

%% Show the mixing levels

figure(5)
cla
hold on

% Plot the iptg and atc stairs as areas:
[iptgstrX, iptgstrY] = stairs([0; media(:,3)]/3600,[media(:,1); media(end,1)]);
[atcstrX, atcstrY] = stairs([0; media(:,3)]/3600,[media(:,2); media(end,2)]+125);

h = area(iptgstrX, iptgstrY, 0);
set(h(1),'FaceColor',[0 1 1]);
set(h(1),'EdgeColor',[0 1 1]);
h = area(atcstrX, atcstrY, 125);
set(h(1),'FaceColor',[1 0 1]);
set(h(1),'EdgeColor',[1 0 1]);


% Plot max and min lines:
line([xlim],[0     0],'Color','k')
line([xlim],[100 100],'Color','k')
line([xlim],[125 125],'Color','k')
line([xlim],[225 225],'Color','k')

% Re-set position
set(gcf,'Position',[10 10 750 250]);
xlim([0 24])
ylim([-5 250])

set(gca,'XTick',[0 10 20 30 40 50 60 ]);
set(gca,'YTick',[0 100 125 225]);
set(gca,'YTickLabel',{'0%' '100%' '0%' '100%'});
set(gca,'Box','off');

xlabel('time (h)')
ylabel('IPTG             aTC')


%% Save it:
saveas(gcf,'Valves','fig')
saveas(gcf,'Valves','epsc')
saveas(gcf,'Valves','png')

%% Create valves data for the fitting
% timerfp = ImagingServer.positions(3).levels.rfp.timepoints

for ind1 = 1:(timerfp(end)/60)
    indx = find(media(:,3)/60>ind1,1,'first');
    if isempty(indx), indx = size(media,1); end
    inputsatc(ind1) = media( indx,2);
    inputsiptg(ind1) = media( indx,1);
end

inputsiptg = inputsiptg/100;

inputs = [inputsatc;inputsiptg]

% save('inputs','inputs')

%% Extract traces from imaging server
pos = 2;
gfpMothers = ImagingServer.positions(pos).levels.gfp.levelMean;
rfpMothers = ImagingServer.positions(pos).levels.rfp.levelMean;
timerfp = ImagingServer.positions(pos).levels.rfp.timepoints;
timegfp = ImagingServer.positions(pos).levels.gfp.timepoints;

%% Plot it

figure(2)
semilogy(timerfp/3600,rfpMothers./gfpMothers)
title('ratio')
saveas(gcf,'Fig_Ratio','fig')
saveas(gcf,'Fig_Ratio','epsc')
saveas(gcf,'Fig_Ratio','png')


figure(3)
plot(timerfp/3600,rfpMothers)
title('rfp')
saveas(gcf,'Fig_rfp','fig') 
saveas(gcf,'Fig_rfp','epsc')
saveas(gcf,'Fig_rfp','png')


figure(4)
plot(timegfp/3600,gfpMothers)
title('gfp')
saveas(gcf,'Fig_gfp','fig')
saveas(gcf,'Fig_gfp','epsc')
saveas(gcf,'Fig_gfp','png')


figure(6)
plot(rfpMothers,gfpMothers)
title('trajs')
xlabel('rfp')
ylabel('gfp')
xlim([0 8e3])
ylim([0 4e3])

%% Remove useless tpoints:
% find(timerfp/3600 > 16, 1, 'first')
firstpoint = 1; % It is better to do with firstpoint =1, then do the smoothing, than use another value for firstpoint if necessary
lastpoint = 272;
% lastpoint = size(rfpMothers,1);
rfpMothers = rfpMothers(firstpoint:lastpoint,:);
gfpMothers = gfpMothers(firstpoint:lastpoint,:);
timerfp = timerfp(firstpoint:lastpoint) - timerfp(firstpoint);
timegfp = timegfp(firstpoint:lastpoint) - timerfp(firstpoint);
media(:,3) = media(:,3) - timerfp(firstpoint);
% The difference between the acquisition starttime and the valves
% starttime:
lag = etime(...
    datevec(vhs.timeseries.tschan2.UserData.starttime), ...
    datevec(ImagingServer.positions(pos).levels.rfp.datenums(1)));
media(:,3) = media(:,3) + lag;
disp(['Valves: added ' num2str(lag) ' seconds, substracted ' num2str(timerfp(firstpoint)) ' seconds'])

%% For older versions of the media time variable
fld =  '/run/media/jeanbaptiste/58D4-C258/2016-03-02_TS-26v1_higherconC_therealdeal/ch1_1500_Switch/rfp_hf/';
a = dir([fld '*.tif']);
media(:,3) = cumsum(media(:,3));
% media(:,3) = media(:,3) + etime(...
%     datevec(tstart),...
%     datevec(a(1).datenum));
%% smooth traces

ncells = size(gfpMothers,2);

for ind1 = 1:ncells
    gfpMothers(:,ind1) = smooth(gfpMothers(:,ind1),20);
    rfpMothers(:,ind1) = smooth(rfpMothers(:,ind1),20);
end

%%
ncells = size(gfpMothers,2);
exclude = [2 5 12];
gfpMothers = gfpMothers(:,setdiff(1:ncells,exclude));
rfpMothers = rfpMothers(:,setdiff(1:ncells,exclude));

% save('2016-06-20_KapitzaPos3','gfpMothers','rfpMothers','media','timerfp','timegfp')
% save('2016-06-18_TS-26v1_Control_PI_idelay_2Pos2Nomedia','gfpMothers','rfpMothers','timerfp','timegfp')
% save('DATA','gfpMothers','rfpMothers','timerfp','timegfp','celltocontrol')

%% Show position of control cell

crPos = ImagingServer.positions(pos).settings.ROIS_P{celltocontrol};
figure(13)
imshow(imadjust(IMG_0001));
imrect(gca,crPos)

%% Trajs/time

% vidObjU = VideoWriter('FilmSpace.avi','Uncompressed AVI');
% vidObjU.FrameRate = 7;
% open(vidObjU);

saveframes = true;

if exist('Frames')
    rmdir('Frames','s')
end
mkdir('Frames')
    
obj = [750 350];

bkgd = getBackgroundRG(4e3, 2.5e3);


% celltocontrol = 1;
if ~exist('celltocontrol')
    celltocontrol = [];
end
greycells = setdiff(1:size(rfpMothers,2),celltocontrol);

hg = [];
hc = [];

figure(5)
xlim([0 4e3])
ylim([0 2.5e3])
imagesc(bkgd)
set(gca,'YDir','normal')
hold on

plot(50,1750,'o','MarkerSize',20,'Color','w');
plot(3500,250,'o','MarkerSize',20,'Color','w');
plot(obj(1),obj(2),'x','MarkerSize',20,'Color','w');

%     plot(rfpMothers(ind1,1),gfpMothers(ind1,1),'.','MarkerSize',25,'Color','k');
title('trajs')
xlabel('RFP')
ylabel('GFP')
drawnow

for ind1 = 1:size(rfpMothers,1)
% for ind1 = 1:199
    figure(5)
    delete(hg)
    delete(hc)
    
    hg = plot(rfpMothers(ind1,greycells),gfpMothers(ind1,greycells),'o','MarkerSize',10,'MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[.5 .5 .5]);
    hc = plot(rfpMothers(ind1,celltocontrol),gfpMothers(ind1,celltocontrol),'o','MarkerSize',10,'MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[0 0 1]);

    drawnow
%     pause(.05)

%     Icomp = getimage(gcf);
    if saveframes
        saveas(gcf,['Frames/frame_' num2str(ind1,'%05.f') '.png'])
    end
    
    
end
