function [ strct ] = ZstackSegment_batchprocess( StrCommand , strct ) % A class would be a cleaner implementation of this whole thing. Maybe later...

% Here we should have the dispatcher (Run, stop, settings...)
visp('Starting script...',1, strct);

switch lower(StrCommand)
    case 'settings'
        strct = changesettings(strct);
    case 'initialize'
        strct = changesettings(strct); % Same thing...
    case 'run'
        visp('Starting run sequence...',1, strct);
        strct = runZstackSegment(strct);
    case 'stop'
        visp('Stopping script...',1, strct);
    otherwise
        visp([ 'Unknown string command: ' StrCommand],-1,strct);
end
visp('Exiting script...',1, strct);


% And then the core functions
function strct = changesettings(strct)
% I chose to use inputdlg here to change my settings; but you can do pretty
% much whatever you want, design your own gui or use cmd line input, it's
% up to you, as long as you can use your own settings afterwards. And If
% you don't want to set anything, simply don't bother.


    global mmc guihs

    width=mmc.getImageWidth();
    height=mmc.getImageHeight();

    % You CANNOT name a field 'name' or 'value'
    visp('Opening settings dialog...',2, strct);
    strct.settings.name{1} = 'verbosity';
    strct.settings.name{2} = 'range_in_microns';
    strct.settings.name{3} = 'nb_of_stacks';
    strct.settings.name{4} = 'clusterprofile';
    defaultval{1} = '4';
    defaultval{2} = '10';
    defaultval{3} = '100';
    defaultval{4} = 'Default';

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
    visp('File selection of SVM and feat basis file dialog...',2, strct);
    [svmfname,svmpath,~] = uigetfile('*.mat','SVM and featurebasis MAT file');
    strct.svmfile = fullfile(svmpath,svmfname);

    visp('Starting image manipulation figure...',2, strct);

    % Start the image/mask manipulation interface...
    % Intializing...
    visp('Acquiring image on current settings...',3, strct);
    mmc.snapImage();
    imgC = mmc.getImage();
    imgC=reshape(imgC,[width,height])';
    UD.orig = imgC;
    visp('Loading chambers mask file...',3, strct);
    % For now I will hard-code it, I'll look for a better solution later:
    stload = load('C:\Users\lab 513\JB\ZstackSegmentation\onlinesegmentation\maskfile.mat');
    UD.mask = stload.Im;
    UD.oldmask = UD.mask;
    os = size(UD.orig);
    ms = size(UD.mask);
    mask = UD.mask((floor((ms(1)-os(1))/2) + (1:os(1))),(floor((ms(2)-os(2))/2) + (1:os(2))));
    %Starting 
    visp('Launching figure...',3, strct);
    handlemanip = figure();
    imagesc(colorizeandcombine(UD.orig,mask));
    visp('Setting userdata...',4, strct);
    set(handlemanip,'UserData',UD);
    visp('Setting keypressfcn...',4, strct);
    set(handlemanip,'keypressfcn',@manipulateimagecallback);
    visp('... Ready to use!',4, strct);
    % Give the instructions:
    msg = ['Mask/Image manipulation interface. Use the arrow keys to move the \n' ...
    'mask around, brackets ([,]) keys to rotate, and ''1'' and ''2'' to \n' ...
    'erode / dilate the mask. To reset the mask, press ctrl+shift+r.\n' ...
    'To validate mask press ctrl+enter (DO NOT CLOSE FIGURE).\n' ...
    ' ctrl and ctrl+shift will increase the range in pixel of each operation'];
    visp(msg,1,strct);

    % Wait for user to press control+enter when done (We should have the field 'Final' then)
    while true
        waitfor(handlemanip,'UserData');
        UD = get(handlemanip,'UserData');
        if isfield(UD,'Final')
            visp('User pressed ctrl+enter, mask positioned',4, strct);
            close(handlemanip);
            break;
        end
    end
    visp('Exiting image manipulation interface...',2, strct);
    visp('Processing ROIs...',2, strct);
    % Get Chambers mask:
    strct.settings.chambersROI = UD.Final;
    visp(['Evaluation ROI: ' num2str(numel(find(strct.settings.chambersROI(:)))) ' pixels' ] ,3, strct);
    % Create the acquisition mask (basically a bounding box)
    dim1 = sum(UD.Final,1);
    dim2 = sum(UD.Final,2);
    strct.settings.globalROI = [find(dim1(:),1, 'first') ... % xmin?
        find(dim2(:),1, 'first') ...                         % ymin?
        (find(dim2(:),1,'last')-find(dim2(:),1, 'first')+1) ...     %height? I'm not sure this is the right format...
        (find(dim1(:),1,'last')-find(dim1(:),1, 'first')+1) ];   % width?
    visp(['Acquisition ROI: ' num2str(strct.settings.globalROI) '(' num2str(strct.settings.globalROI(3)*strct.settings.globalROI(4)) ') pixels'] ,3, strct);
    strct.settings.imgsize = size(UD.orig);
    strct.settings.chambersInd = FulltoROI(find(strct.settings.chambersROI(:)),strct.settings.globalROI,strct.settings.imgsize);


    % Cluster
    visp('Processing cluster configuration...',2, strct);
    if ~isfield(guihs,'cluster') || ~isempty(guihs.cluster)
        if strcmp(strct.settings.clusterprofile, 'Default')
            visp('Starting default cluster profile ...',1, strct);
            guihs.cluster = parcluster();
        else
            visp(['Starting cluster profile: ' strct.settings.clusterprofile ' ...'],1, strct);
            guihs.cluster = parcluster(strct.settings.clusterprofile);
        end
    else
        visp('Another cluster is already set up',1, strct);
    end


    % Features and models
    visp('Loading feature extraction and SVM models...',2, strct);
    st2 = load(strct.svmfile);
    strct.svmmodels = st2.SVMmodels;
    strct.featbasis = st2.Featbasis;

    strct.executions = 0;

    visp('Creating acquisition directory...',2, strct);

    % Check whether we are initializing, and choose the filepath accordingly
    if guihs.timeLapseSetUp.settingup
        cc = guihs.timeLapseSetUp.CurrentChannel; 
        pp = guihs.timeLapseSetUp.CurrentPosition;
        acqfolder = fullfile(guihs.timeLapseSetUp.mainFolder, [guihs.timeLapseSetUp.positionNames{pp} filesep], [guihs.timeLapseSetUp.Channels.Data{cc,1} filesep]);
        strct.filespath = fullfile(acqfolder, ['ZstackSegment' filesep]);
    else
        strct.filespath = fullfile('./', ['ZstackSegment' filesep]);
    end
    mkdir(strct.filespath)

    visp('Saving settings structure in acquisition directory...',2, strct);
    save(fullfile(strct.filespath,'strctsettings.mat'),'strct');

    visp('Closing settings...',2, strct);

function strct = runZstackSegment(strct)

    global guihs mmc
    visp('Starting Zstack acquisition...',1, strct);

    % Compute the positions to acquire:
    pos0 = mmc.getPosition('PIZStage');
    Zobj = linspace(pos0-(str2num(strct.settings.range_in_microns)/2),pos0+(str2num(strct.settings.range_in_microns)/2),str2num(strct.settings.nb_of_stacks));
    visp( [num2str(numel(Zobj)) ' frames to be acquired between z= ' num2str(Zobj(1)) 'um and z= ' num2str(Zobj(end)) 'um'],3, strct);
    drawnow
    % Acquire Stack
    predictFeat = acqandprocessStack(Zobj,strct);
    mmc.setPosition('PIZStage',pos0);

    strct.executions = strct.executions + 1;

    visp('Cleaning old jobs...',2, strct);
    % Check for already existing jobs and remove those that are over
    finishedindX= [];
    if isfield(strct,'jobs')
        for ind1 = 1:numel(strct.jobs)
            if strcmp(strct.jobs{ind1}.State,'finished') % Identify those that are finished
                delete(strct.jobs{ind1}); % Erase them from memory
                finishedindX = [finishedindX ind1]; % Store index
            end
        end
        strct.jobs = strct.jobs(~ismember(1:numel(strct.jobs),finishedindX)); % Delete their handles
    else
        strct.jobs = {};
    end
    visp([ num2str(numel(finishedindX)) ' jobs deleted, ' num2str(numel(strct.jobs)) ' jobs still running'] ,2, strct);

    % Off-load to new batch job
    visp('Launching segmentation job...',2, strct);
    strct.jobs{end+1} = batch(guihs.cluster,@ZstackSegment_batchjob,1,{predictFeat,strct});
    visp([ ' SVM Segmentation job (id #' num2str(strct.jobs{end}.ID) ') launched - ' strct.jobs{end}.StartTime ] ,1, strct);

function predictFeat = acqandprocessStack(Zobj,strct)

    global mmc

    % Get the relevant settings:
    roi = strct.settings.globalROI;
    chambR = strct.settings.chambersInd;

    % Initialize the acquisition
    oldroi = mmc.getROI;
    mmc.setROI(roi(1),roi(2),roi(3),roi(4));
    mmc.setProperty('Camera-1','ClearMode','Clear Never');
    width=mmc.getImageWidth();
    height=mmc.getImageHeight();
    mmc.setAutoShutter(false);
    mmc.setProperty('Light shutter (Vincent-D1)','Command','Open')
    mmc.setPosition('PIZStage',Zobj(1));
    mmc.waitForDevice('PIZStage');
    mmc.setPosition('PIZStage',Zobj(1)); % It's always messy the first time
    mmc.waitForDevice('PIZStage');

    htic = tic();
    visp('Starting now...',3, strct);
    drawnow;
    % Acquisition:
    for ind1 = 2:numel(Zobj);
        mmc.waitForDevice('PIZStage');
        mmc.snapImage();
        mmc.setPosition('PIZStage',Zobj(ind1)); % I'm already setting position for the next step!
        imgC = mmc.getImage(); 
        imgC = reshape(imgC,[width,height]);
        imgD = imgradient(imgC);
        predictMatpart1(:,ind1) = imgC(chambR);
        predictMatpart2(:,ind1) = imgD(chambR);
    end

    % Reset to original settings
    mmc.setProperty('Light shutter (Vincent-D1)','Command','Close');
    mmc.setROI(oldroi.x,oldroi.y,oldroi.width,oldroi.height)
    mmc.setProperty('Camera-1','ClearMode','Clear Pre-Exposure')
    mmc.setAutoShutter(true);

    etimesecs = toc(htic);
    visp(['Done! (' num2str(round(etimesecs)) ' seconds)'],2, strct);

    visp('Converting signatures to features basis',3, strct);
    % concatenate & extract features (I should group the two)
    predictFeat = strct.featbasis*((double(uint16(cat(2,predictMatpart1,predictMatpart2))))');



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

function manipulateimagecallback(obj, evt)

    UD = get(obj,'UserData');

    % Manipulate teh mask depending on the key stroke:
    switch evt.Key
        case 'leftarrow'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imtranslate(UD.mask,[-30, 0],'FillValues',0);
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imtranslate(UD.mask,[-10, 0],'FillValues',0);
            else
                UD.mask = imtranslate(UD.mask,[-1, 0],'FillValues',0);
            end
        case 'rightarrow'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imtranslate(UD.mask,[30, 0],'FillValues',0);
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imtranslate(UD.mask,[10, 0],'FillValues',0);
            else
                UD.mask = imtranslate(UD.mask,[1, 0],'FillValues',0);
            end
        case 'uparrow'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imtranslate(UD.mask,[0, -30],'FillValues',0);
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imtranslate(UD.mask,[0, -10],'FillValues',0);
            else
                UD.mask = imtranslate(UD.mask,[0, -1],'FillValues',0);
            end
        case 'downarrow'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imtranslate(UD.mask,[0, 30],'FillValues',0);
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imtranslate(UD.mask,[0, 10],'FillValues',0);
            else
                UD.mask = imtranslate(UD.mask,[0, 1],'FillValues',0);
            end
        case 'leftbracket'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imrotate(UD.mask,30,'nearest','crop');
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imrotate(UD.mask,10,'nearest','crop');
            else
                UD.mask = imrotate(UD.mask,1,'nearest','crop');
            end
        case 'rightbracket'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imrotate(UD.mask,-30,'nearest','crop');
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imrotate(UD.mask,-10,'nearest','crop');
            else
                UD.mask = imrotate(UD.mask,-1,'nearest','crop');
            end
        case '1'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imerode(UD.mask,strel('Disk',30));
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imerode(UD.mask,strel('Disk',10));
            else
                UD.mask = imerode(UD.mask,strel('Disk',1));
            end
        case '2'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = imdilate(UD.mask,strel('Disk',30));
            elseif find(strcmp('control', evt.Modifier))
                UD.mask = imdilate(UD.mask,strel('Disk',10));
            else
                UD.mask = imdilate(UD.mask,strel('Disk',1));
            end
        case 'r'
            if ~isempty(find(strcmp('control', evt.Modifier))) && ~isempty(find(strcmp('shift', evt.Modifier)))
                UD.mask = UD.oldmask;
            end
        case 'return'
            if ~isempty(find(strcmp('control', evt.Modifier)))
                os = size(UD.orig);
                ms = size(UD.mask);
                mask = UD.mask((floor((ms(1)-os(1))/2) + (1:os(1))),(floor((ms(2)-os(2))/2) + (1:os(2))));
                UD.Final = mask;
            end
        otherwise
            % Nothing happens
            return
    end

    % Reconstruct image:
    % First the mask must be the right size:
    os = size(UD.orig);
    ms = size(UD.mask);
    mask = UD.mask((floor((ms(1)-os(1))/2) + (1:os(1))),(floor((ms(2)-os(2))/2) + (1:os(2))));
    % Then we apply it to the image:
    % Display:
    imagesc(colorizeandcombine(UD.orig,mask));
    set(obj,'UserData',UD)

function Imout = colorizeandcombine(Im, mask)
    cmap = colormap('gray');
    mask = grs2rgb(uint8(mask).*255,cmap);
    mask(:,:,1) = zeros(size(mask(:,:,1)));
    mask(:,:,2) = zeros(size(mask(:,:,2)));
    Imout = 0.8*grs2rgb(Im,cmap) + 0.2*mask;
    
function output = ROItoFull(input,ROI,imgsize)
    [s1,s2] = ind2sub(ROI(3:4),input);
    s1 = s1 + ROI(2) - 1;
    s2 = s2 + ROI(1) - 1;
    output = sub2ind(imgsize,s1,s2);

function output = FulltoROI(input,ROI,imgsize)
    [s1,s2] = ind2sub(imgsize,input);
    s1 = s1 - ROI(2) + 1;
    s2 = s2 - ROI(1) + 1;
    output = sub2ind(ROI(3:4),s1,s2);

function [scores] = ZstackSegment_batchjob( predictFeat, strct)

    % Run the prediction:
    scores = SVMclassificationMultiClass(strct.svmmodels, predictFeat);
    % Save it to a mat file:
    fname = fullfile(strct.filespath,['segmentation_' num2str(strct.executions,'%06.f') '.mat']);
    save(fname,'scores','-v7.3');

% Below is just a copy of the classification function in /prediction.
% CHanges to this function should also be applied to the original function
function [Scores] = SVMclassificationMultiClass(SVMmodels,predictFeat)

    % Run the models on the modified stack:
    Scores = [];
    for j = 1:numel(SVMmodels);
        [~,scoreSVM] = predict(SVMmodels{j},predictFeat');
        Scores(:,j) = scoreSVM(:,2); % Second column contains positive-class scores
    end
    
% Below is just a copy of the classification function in /utilities/misc.
% CHanges to this function should also be applied to the original function
function fullpath = relative2full(relativepath,rootfoldername)
    %relative2full Transform a relative path in a full path relative to an
    %arbitrary root
    %
    % fullpath = relative2full(relativepath,rootfoldername) returns global path
    % of relative path relativepath. relativepath must start with a '/' symbol, 
    % the path is relative to transposed root rootfoldername, and
    % is transformed by this function into the 'actual' global path.
    %
    % example :
    % >>pwd
    % 
    % ans =
    % 
    % /home/jeanbaptiste/phd/imageanalysis/ZstackSegmentation/training_set_construction
    %
    % >> fullpath = relative2full('/google_drive/zstacks/','ZstackSegmentation')
    % 
    % ans = 
    % 
    % /home/jeanbaptiste/phd/imageanalysis/ZstackSegmentation/google_drive/zstacks/
    % 
    %
    % Of course, if the working directory is not under the transposed root
    % directory (here ZstackSegmentation) this does not work.

    if relativepath(1) ~= '/'
        error('The relative path must start with ''/''')
    end

    pwdstr = pwd();
    pos = strfind(pwdstr,rootfoldername);
    if isempty(pos)
        error('You must be under the rootfoldername directory  or one of its subdirectories to run this function');
    end

    fullpath = fullfile(pwdstr(1:(pos+numel(rootfoldername)-1)),relativepath(2:end));

% A copy of grs2rgb...
function res = grs2rgb(img, map)

    %%Convert grayscale images to RGB using specified colormap.
    %	IMG is the grayscale image. Must be specified as a name of the image 
    %	including the directory, or the matrix.
    %	MAP is the M-by-3 matrix of colors.
    %
    %	RES = GRS2RGB(IMG) produces the RGB image RES from the grayscale image IMG 
    %	using the colormap HOT with 64 colors.
    %
    %	RES = GRS2RGB(IMG,MAP) produces the RGB image RES from the grayscale image 
    %	IMG using the colormap matrix MAP. MAP must contain 3 columns for Red, 
    %	Green, and Blue components.  
    %
    %	Example 1:
    %	open 'image.tif';	
    %	res = grs2rgb(image);
    %
    %	Example 2:
    %	cmap = colormap(summer);
    % 	res = grs2rgb('image.tif',cmap);
    %
    % 	See also COLORMAP, HOT
    %
    %	Written by 
    %	Valeriy R. Korostyshevskiy, PhD
    %	Georgetown University Medical Center
    %	Washington, D.C.
    %	December 2006
    %
    % 	vrk@georgetown.edu

    % Check the arguments
    if nargin<1
        error('grs2rgb:missingImage','Specify the name or the matrix of the image');
    end;

    if ~exist('map','var') || isempty(map)
        map = hot(64);
    end;

    [l,w] = size(map);

    if w~=3
        error('grs2rgb:wrongColormap','Colormap matrix must contain 3 columns');
    end;

    if ischar(img)
        a = imread(img);
    elseif isnumeric(img)
        a = img;
    else
        error('grs2rgb:wrongImageFormat','Image format: must be name or matrix');
    end;

    % Calculate the indices of the colormap matrix
    a = double(a);
    a(a==0) = 1; % Needed to produce nonzero index of the colormap matrix
    ci = ceil(l*a/max(a(:))); 

    % Colors in the new image
    [il,iw] = size(a);
    r = zeros(il,iw); 
    g = zeros(il,iw);
    b = zeros(il,iw);
    r(:) = map(ci,1);
    g(:) = map(ci,2);
    b(:) = map(ci,3);

    % New image
    res = zeros(il,iw,3);
    res(:,:,1) = r; 
    res(:,:,2) = g; 
    res(:,:,3) = b;
