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

douserinput = true;
if exist([ xpfolder '/QDiman.mat'])
    ret = questdlg('An older segmentation file alreday exists, do you want to reuse the segmentation information?',' ','Yes','No','Yes');
    if strcmp(ret,'Yes')
        % load previous crosses positions:
        ql = load([ xpfolder '/QDiman.mat'])
        BKGD_P = ql.BKGD_P
        CrossROI_P = ql.CrossROI_P
        timezero = ql.timezero
        origROIS_P = ql.origROIS_P;
        crossRef = ql.crossRef;
        douserinput = false;
    end
end


%% Ask user to place the ROIs
if douserinput
    ROISfig = figure(1);
    orI = imread(fullfile(transdir,translist(2).name));
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


    % Ask for background

    BKGD_P  = [];
    ret = input('Add background? [Y/n]: ','s');
    switch lower(ret)
        case 'y'
            numROI = numROI + 1;
            BKGD = imrect(gca, [10 10 30 20]);
        case 'n'
            break;
    end

    % Ask user for cross to compute cross-correlation
    disp('Please place the square on the cross for xcorr')
    CrossROI = imrect(gca, [10 10 150 150]);
    setResizable(CrossROI,false);
    wait(CrossROI);
    CrossROI_P = CrossROI.getPosition;
    crossRef = imcrop(orI,CrossROI_P);

    for ind1 = 1:numel(ROIS)
        origROIS_P{ind1} = ROIS(ind1).getPosition;
    end
    BKGD_P  = BKGD.getPosition;
    
end

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
    
    if ~isempty(BKGD_P)
        fluo = imcrop(IR, BKGD_P + [fliplr(displacement) 0 0 ]);
        rfpbkgd(ind0) = mean(fluo(:));
    else
        rfpbkgd(ind0) = 0;
    end
    
    for ind1 = 1:numel(origROIS_P)
%         For displaying the crosses position:
%         ROIS(ind1).setPosition(origROIS_P{ind1} + [fliplr(displacement) 0 0 ]);
%         drawnow
        fluo = imcrop(IR, origROIS_P{ind1} + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
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
    
    if ~isempty(BKGD_P)
        fluo = imcrop(IR, BKGD_P + [fliplr(displacement) 0 0 ]);
        gfpbkgd(ind0) = mean(fluo(:));
    else
        gfpbkgd(ind0) = 0;
    end
    
    for ind1 = 1:numel(origROIS_P)
        fluo = imcrop(IR, origROIS_P{ind1} + [fliplr(displacement) 0 0 ]); % set the position to take into account the displacement
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
        
        
    
    
    
%% Final display
figure(3)
for ind1 = 1:numel(origROIS_P)
    semilogy(timerfp/3600,smooth(rfplevelMean(:,ind1)-rfpbkgd'),'r')
    hold on
    semilogy(timegfp/3600,smooth(gfplevelMean(:,ind1)-gfpbkgd'),'g')
end

plot(timerfp/3600,smooth(mean(rfplevelMean,2)-rfpbkgd'),'r','LineWidth',3)
plot(timegfp/3600,smooth(mean(gfplevelMean,2)-gfpbkgd'),'g','LineWidth',3)

xlabel('time (h)')
ylabel('fluo a.u.')
yl = ylim;
ylim([20 yl(2)])

save(fullfile(xpfolder,'QDiman'))
saveas(gcf,fullfile(xpfolder,'QDiman'),'fig')
saveas(gcf,fullfile(xpfolder,'QDiman'),'png')

figure(5)
for ind1 = 1:numel(origROIS_P)
    semilogy(timerfp/3600,smooth(rfplevelMean(:,ind1)-rfpbkgd')./smooth(gfplevelMean(:,ind1)-gfpbkgd'))
    hold on
end
xlabel('time (h)')
ylabel('rfp/gfp ratio')

plot(timerfp/3600,smooth(mean(rfplevelMean,2)-rfpbkgd')./smooth(mean(gfplevelMean,2)-gfpbkgd'),'r','LineWidth',3)

saveas(gcf,fullfile(xpfolder,'QDimanRatio'),'fig')
saveas(gcf,fullfile(xpfolder,'QDimanRatio'),'png')

%% Fourier transform
X = smooth(mean(rfplevelMean,2)-rfpbkgd');
% X = smooth(mean(gfplevelMean,2)-gfpbkgd');

T = 4*60;            % Sampling frequency
Fs = 1/T;             % Sampling period
L = length(X);             % Length of signal
t = (0:L-1)*T;        % Time vector

% Compute the Fourier transform of the signal.
Y = fft(X);

% Compute the two-sided spectrum P2. Then compute the single-sided spectrum P1 based on P2 and the even-valued signal length L.
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);

ph = unwrap(angle(Y));
ph = ph(1:L/2+1);

f = Fs*(0:(L/2))/L;
p = (1./f)./3600;


figure(6)
semilogx(p,P1)
hold on
title('Single-Sided Amplitude Spectrum of X(t)')
xlabel('periode (h)')
ylabel('|P1|')

figure(7)
semilogx(p,ph)
hold on
xlabel 'periode (h)'
ylabel 'Phase (rad)'


