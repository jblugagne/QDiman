
%% Setup the valves client: (MUST START VALVES SERVER FIRST!)
actuatorclient = valvesclient();

%% Setup the imaging server (BLOCKS UNTIL CONNECTED TO!)
ImagingServer = QDimanServer();

%% Setup the controllers:

% PI controller:
    posN = 'Chan03';
    cell_to_control = 1;
    pstn_index = 3;

    % RFP-laci-atc branch:
    mediaN = 'pcm2'; % atc
    channel = 'rfp';
    % Actual controller:
    lacirfpPIctrlr3 = PIcontroller(1/100,1/12e3,[1000, Inf],[0,50],6);
    % Set it up!
    ch3RFPcntrlwrpr = ControlWrapper(lacirfpPIctrlr3, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    % GFP-tetr-iptg branch:
    mediaN = 'pcm1'; % iptg
    channel = 'gfp';
    % Actual controller:
    tetrgfpPIctrlr3 = PIcontroller(1/20,1/6e3,[1000, Inf],[0,50],19);
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
    lacirfpPIctrlr2 = PIcontroller(1/70,1/12e3,[2000, Inf],[0,50],6);
    % Set it up!
    ch2RFPcntrlwrpr = ControlWrapper(lacirfpPIctrlr2, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    % GFP-tetr-iptg branch:
    mediaN = 'pcm1'; % iptg
    channel = 'gfp';
    % Actual controller:
    tetrgfpPIctrlr2 = PIcontroller(1/20,1/6e3,[1000, Inf],[0,50],19);
    % Set it up!
    ch2GFPcntrlwrpr = ControlWrapper(tetrgfpPIctrlr2, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    
    
    
% Bang Bang controller:
    posN = 'Chan01';
    cell_to_control = 1;
    pstn_index = 1;

    % RFP-laci-atc branch:
    mediaN = 'pcm2'; % atc
    channel = 'rfp';
    % Actual controller:
    lacirfpPIctrlr1 = PIcontroller(1e6,0,[2000, Inf],[0,50],0);
    % Set it up!
    ch1RFPcntrlwrpr = ControlWrapper(lacirfpPIctrlr1, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

    % GFP-tetr-iptg branch:
    mediaN = 'pcm1'; % iptg
    channel = 'gfp';
    % Actual controller:
    tetrgfpPIctrlr1 = PIcontroller(1e6,0,[1000, Inf],[0,50],0);
    % Set it up!
    ch1GFPcntrlwrpr = ControlWrapper(tetrgfpPIctrlr1, ImagingServer, actuatorclient, posN, mediaN,cell_to_control,pstn_index,channel);

%% Reboot controllers:

% clearvars -except ImagingServer actuatorclient