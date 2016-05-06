%% Channel 1

ha1 = ImagingServer.plotlevelsofpos(1,1);
t = get(get(ha1,'Children'),'Children');
set(t,'LineWidth',2)
ImagingServer.plotlevelsofpos(1,2:size(ImagingServer.positions(1).levels.rfp.levelMean,2),'hold on');

line([xlim],[ch1RFPcntrlwrpr.controller.objective(1) ch1RFPcntrlwrpr.controller.objective(1)],'Color','r');
line([xlim],[ch1GFPcntrlwrpr.controller.objective(1) ch1GFPcntrlwrpr.controller.objective(1)],'Color','g');

figure()
set(gcf,'Name','Chan01 decisions')
subplot(2,1,1)
plot(ch1RFPcntrlwrpr.decisions,'m','LineWidth',2)
ylabel('aTC')
ylim([0 1e2]);
subplot(2,1,2)
plot(ch1GFPcntrlwrpr.decisions,'c','LineWidth',2)
ylabel('IPTG')
ylim([0 1e2]);

%% Channel 2

ha2 = ImagingServer.plotlevelsofpos(2,1);
t = get(get(ha2,'Children'),'Children');
set(t,'LineWidth',2)
ImagingServer.plotlevelsofpos(2,2:size(ImagingServer.positions(2).levels.rfp.levelMean,2),'hold on');

line([xlim],[ch2RFPcntrlwrpr.controller.objective(1) ch2RFPcntrlwrpr.controller.objective(1)],'Color','r');
line([xlim],[ch2GFPcntrlwrpr.controller.objective(1) ch2GFPcntrlwrpr.controller.objective(1)],'Color','g');

shift = 1;
tpsR = ImagingServer.positions(2).levels.rfp.timepoints((1+shift):end)/3600;
tpsG = ImagingServer.positions(2).levels.gfp.timepoints((1+shift):end)/3600;
figure()
set(gcf,'Name','Chan02 decisions')
subplot(2,1,1)
stairs(tpsR-1,ch2RFPcntrlwrpr.decisions,'m','LineWidth',1)
xl = xlim;
bar(tpsR,ch2RFPcntrlwrpr.decisions,'EdgeColor','m','FaceColor','m')
xlim(xl)
ylabel('aTC')
ylim([0 1e2]);
subplot(2,1,2)
% stairs(tpsG,ch3GFPcntrlwrpr.decisions,'c','LineWidth',1)
bar(tpsG-1,ch2GFPcntrlwrpr.decisions,'EdgeColor','c','FaceColor','c')
xlim(xl)
ylabel('IPTG')
ylim([0 1e2]);

%% Channel 3

ha3 = ImagingServer.plotlevelsofpos(3,1);
t = get(get(ha3,'Children'),'Children');
set(t,'LineWidth',3)
ImagingServer.plotlevelsofpos(3,2:size(ImagingServer.positions(3).levels.rfp.levelMean,2),'hold on');

line([xlim],[ch3RFPcntrlwrpr.controller.objective(1) ch3RFPcntrlwrpr.controller.objective(1)],'Color','r','LineWidth',3,'LineStyle','--');
line([xlim],[ch3GFPcntrlwrpr.controller.objective(1) ch3GFPcntrlwrpr.controller.objective(1)],'Color','g','LineWidth',3,'LineStyle','--');

shift = 1;
tpsR = ImagingServer.positions(3).levels.rfp.timepoints((1+shift):end)/3600;
tpsG = ImagingServer.positions(3).levels.gfp.timepoints((1+shift):end)/3600;
figure()
set(gcf,'Name','Chan03 decisions')
subplot(2,1,1)
stairs(tpsR-1,ch3RFPcntrlwrpr.decisions,'m','LineWidth',1)
xl = xlim;
bar(tpsR-1,ch3RFPcntrlwrpr.decisions,'EdgeColor','m','FaceColor','m')
xlim(xl)
ylabel('aTC')
ylim([0 1e2]);
subplot(2,1,2)
% stairs(tpsG,ch3GFPcntrlwrpr.decisions,'c','LineWidth',1)
bar(tpsR-1,ch3GFPcntrlwrpr.decisions,'EdgeColor','c','FaceColor','c')
xlim(xl)
ylabel('IPTG')
ylim([0 1e2]);