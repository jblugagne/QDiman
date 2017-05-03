
%% Setup the valves client: (MUST START VALVES SERVER FIRST!)
actuatorclient = valvesclient();

%% Setup the imaging server (BLOCKS UNTIL CONNECTED TO!)
ImagingServer = QDimanServer();

%% Setup the controllers:

% BB controller:
    posN = 'Chan03'; % This needs to be changed back to chan03
    cell_to_control = 1;
    pstn_index = 3; 

    % RFP-laci-atc branch:
    mediaN = 'pcm2'; % atc
    channel = 'rfp';
    % Actual controller:
    lacirfpPIctrlr3 = PIcontrollerNew(1/20,1/4800,[900, Inf],[0,50],20,120);
    % Set it up!
    ch3RFPcntrlwrpr = ControlWrapper(lacirfpPIctrlr3, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    % GFP-tetr-iptg branch:
    mediaN = 'pcm1'; % iptg
    channel = 'gfp';
    % Actual controller:
    tetrgfpPIctrlr3 = PIcontrollerNew(1/40,1/1440,[420, Inf],[0,50],25,120);
    % Set it up!
    ch3GFPcntrlwrpr = ControlWrapper(tetrgfpPIctrlr3, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

%%    
    
    
% PI controller:
    posN = 'Chan02';
    cell_to_control = 1;
    pstn_index = 2;

    % RFP-laci-atc branch:
    mediaN = 'pcm2'; % atc
    channel = 'rfp';
    % Actual controller:
    lacirfpPIctrlr2 = PIcontrollerNew(1/20,1/4800,[750, Inf],[0,50],20,120);
    % Set it up!
    ch2RFPcntrlwrpr = ControlWrapper(lacirfpPIctrlr2, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    % GFP-tetr-iptg branch:
    mediaN = 'pcm1'; % iptg
    channel = 'gfp';
    % Actual controller:
    tetrgfpPIctrlr2 = PIcontrollerNew(1/40,1/1440,[350, Inf],[0,50],25,120);
    % Set it up!
    ch2GFPcntrlwrpr = ControlWrapper(tetrgfpPIctrlr2, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    
    
    
%% PI controller:
    posN = 'Chan01';
    cell_to_control = 1; %%% CELL TO CONTROL !!!!!!!!!
    pstn_index = 1;

    % RFP-laci-atc branch:
    mediaN = 'pcm2'; % atc
    channel = 'rfp';
    % Actual controller:
    lacirfpPIctrlr1 = PIcontrollerNew(1/20,1/4800,[900, Inf],[0,50],20,120);
    % Set it up!
    ch1RFPcntrlwrpr = ControlWrapper(lacirfpPIctrlr1, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    % GFP-tetr-iptg branch:
    mediaN = 'pcm1'; % iptg
    channel = 'gfp';
    % Actual controller:
    tetrgfpPIctrlr1 = PIcontrollerNew(1/40,1/1440,[420, Inf],[0,50],25,120);
    % Set it up!
    ch1GFPcntrlwrpr = ControlWrapper(tetrgfpPIctrlr1, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    
%% Test delay

%     posN = 'ChanTT';
%     cell_to_control = 1; %%% CELL TO CONTROL !!!!!!!!!
%     pstn_index = 1;
% 
%     % RFP-laci-atc branch:
%     mediaN = 'pcm2'; % atc
%     channel = 'rfp';
%     % Actual controller:
%     lacirfpPIctrlr1 = PIcontrollerNew(1/20,0,[750, Inf],[0,50],0,5);
%     % Set it up!
%     ch1RFPcntrlwrpr = ControlWrapper(lacirfpPIctrlr1, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);
% 
%     % GFP-tetr-iptg branch:
%     mediaN = 'pcm1'; % iptg
%     channel = 'gfp';
%     % Actual controller:
%     tetrgfpPIctrlr1 = PIcontrollerNew(1/20,0,[350, Inf],[0,50],0,10);
%     % Set it up!
%     ch1GFPcntrlwrpr = ControlWrapper(tetrgfpPIctrlr1, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);
% 
%     

%% Reboot controllers:

% clearvars -except ImagingServer actuatorclient