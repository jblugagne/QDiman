function [ strct ] = QDiman_batchprocess( StrCommand , strct ) % A class would be a cleaner implementation of this whole thing. Maybe later...

% Here we should have the dispatcher (Run, stop, settings...)
visp('Starting script...',1, strct);

switch lower(StrCommand)
    case 'settings'
        strct = changesettings(strct);
    case 'initialize'
        strct = changesettings(strct); % Same thing...
    case 'run'
        visp('Starting run sequence...',1, strct);
        strct = runQDimanSegment(strct);
    case 'stop'
        visp('Stopping script...',1, strct);
    otherwise
        visp([ 'Unknown string command: ' StrCommand],-1,strct);
end
visp('Exiting script...',1, strct);


% And then the core functions
function strct = changesettings(strct)

    global mmc guihs
    
    cc = guihs.timeLapseSetUp.CurrentChannel; 
    pp = guihs.timeLapseSetUp.CurrentPosition;

    width=mmc.getImageWidth();
    height=mmc.getImageHeight();
    
    if ~strfind(guihs.timeLapseSetUp.Channels.Data{cc,1},'trans')
        return;
    end

    % You CANNOT name a field 'name' or 'value'
    visp('Opening settings dialog...',2, strct);
    strct.settings.name{1} = 'verbosity';
    defaultval{1} = '4';

    if isfield(strct.settings,'value')
        for ind1 = 1:numel(defaultval)
            if isempty(strct.settings.value{ind1}) || ~ischar(strct.settings.value{ind1})
                strct.settings.value{ind1} = defaultval{ind1};
            end
        end
    else
        strct.settings.value = defaultval;
    end

    strct.settings.value = inputdlg(strct.settings.name,strct.pathtofile,1,strct.settings.value);

    for ind1 = 1:numel(strct.settings.name)
        strct.settings.(strct.settings.name{ind1}) =  strct.settings.value{ind1};
    end

    visp('Closing settings dialog...',2, strct);
    
    visp('Starting selection interface...',2, strct);

    % Start the image/mask manipulation interface...
    % Intializing...
    visp('Acquiring image on current settings...',3, strct);
    mmc.snapImage();
    imgC = mmc.getImage();
    imgC=reshape(imgC,[width,height])';
    UD.orig = imgC;
    visp('Loading chambers mask file...',3, strct);
    
    % Starting 
    visp('Launching figure...',3, strct);
    handlemanip = figure();
    imshow(imadjust(UD.orig));
    [strct.ROIS_P,strct.BKGD_P,strct.CrossROI_P,strct.CrossRef] = ROIselection();
    

    % Check whether we are initializing, and choose the filepath accordingly
    if guihs.timeLapseSetUp.settingup
        acqfolder = fullfile(guihs.timeLapseSetUp.mainFolder, [guihs.timeLapseSetUp.positionNames{pp} filesep], [guihs.timeLapseSetUp.Channels.Data{cc,1} filesep]);
        strct.filespath = fullfile(acqfolder, ['QDimanSegment' filesep]);
    else
        strct.filespath = fullfile('./', ['QDimanSegment' filesep]);
    end
    mkdir(strct.filespath)

    visp('Saving settings structure in acquisition directory...',2, strct);
    save(fullfile(strct.filespath,'strctsettings.mat'),'strct');

    if ~isfield(guihs,'imagingserver')
        guihs.imagingserver = tcpip('localhost',30001,'NetworkRole','client');
        visp('Connecting to imaging server...',1, strct);
        fopen(guihs.imagingserver);
        visp('Connected...',1, strct);
    end
    
    visp('Sending setup message to server...',2, strct);
    fprintf(guihs.imagingserver,    [ ...
                                    '<CMD>\n' ...
                                    'SETUP\n' ...
                                    guihs.timeLapseSetUp.positionNames{pp} '\n' ...
                                    guihs.timeLapseSetUp.Channels.Data{cc,1}  '\n' ...
                                    fullfile(strct.filespath,'strctsettings.mat') '\n' ...
                                    '</CMD>\n' ...
                                    ]);
    
    visp('Closing settings...',2, strct);
    
    
fprintf(t,    [ ...
                                '<CMD>\n' ...
                                'ACQ\n' ...
                                'chan01' '\n' ...
                                'trans'  '\n' ...
                                'thisisatest '\n' ...
                                '</CMD>\n' ...
                                ]);

function strct = runQDimanSegment(strct)

    global guihs mmc
    visp('Sending signal to server...',1, strct);

    fprintf(guihs.imagingserver,    [ ...
                                '<CMD>\n' ...
                                'ACQ\n' ...
                                guihs.timeLapseSetUp.positionNames{pp} '\n' ...
                                guihs.timeLapseSetUp.Channels.Data{cc,1}  '\n' ...
                                guihs.timeLapseSetUp.lastIMGfile '\n' ...
                                '</CMD>\n' ...
                                ]);

% Utilities
function visp(msg,verbosity,strct)

    if isfield(strct.settings,'verbosity')
        verb = str2num(strct.settings.verbosity);
    else
        verb = 0;
    end
    if verbosity < 0
        msg = ['[' strct.Name '] ' msg '\n'];
        error(msg);
    end
    if verb >= verbosity
        msg = ['[' strct.Name '] ' msg '\n'];
        fprintf(msg);
    end
    
function [ROIS_P,BKGD_P,CrossROI_P,CrossRef] = ROIselection()
%% Ask user to place the ROIs

    % Ask for ROIS
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
    for ind1 = 1:numel(ROIS)
        ROIS_P{ind1} = ROIS(ind1).getPosition;
    end


    % Ask for background
    BKGD_P  = [];
    ret = input('Add background? [Y/n]: ','s');
    switch lower(ret)
        case 'y'
            BKGD = imrect(gca, [10 10 30 20]);
            wait(BKGD)
            BKGD_P  = BKGD.getPosition;
        case 'n'
            % Nothing to do
    end

    
    % Ask user for cross to compute cross-correlation
    disp('Please place the square on the cross for xcorr')
    CrossROI = imrect(gca, [10 10 150 150]);
    setResizable(CrossROI,false);
    wait(CrossROI);
    CrossROI_P = CrossROI.getPosition;
    CrossRef = imcrop(orI,CrossROI_P);
