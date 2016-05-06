classdef QDimanServer < handle & hgsetget
    
    properties (SetObservable)
        rhost = '127.0.0.1';    % '0.0.0.0' accepts any machine, 127.0.0.1 accepts only localhost connecitons etc...
        lport = 30001 ;         % Local port to listen to
        server;
        positions = struct();
        verbosity = 4;
        newvalue = 0;
        latestposition = '';
        latestchannel = '';
    end
    
    methods
        
        function obj = QDimanServer(varargin)
            
            obj.visp('Launching server...')

            switch nargin
                case 0 
                    % TODO (user 
                case 1
                    %TODO (user provides remote IP)
                case 2
                    %TODO (user provides IP and port)
                otherwise
                    error('Too many input arguments');
            end
            obj.launchserver()
        end
        
        
        function setupNewPos(obj,pos, chan, filename)
            % Load script settings
            scriptsettings = load(filename);
            % If there is at least one positon, append. Otherwise create.
            if isempty(fieldnames(obj.positions))
                obj.positions = struct('name',pos,'segchan',chan,'settings',scriptsettings.strct,'displacement',[0 0],'levels',struct());
            else
                obj.positions(end+1) = struct('name',pos,'segchan',chan,'settings',scriptsettings.strct,'displacement',[0 0],'levels',struct());
            end
            obj.visp(['Set up new position: ' pos ', reference channel: ' chan])
        end
        
        function calculatedisplacement(obj,Icorr,ind1)
            obj.visp(['Computing displacement for position ' obj.positions(ind1).name ])
            sts = obj.positions(ind1).settings;
            % Compute cross corr
            crossComp = imcrop(imadjust(Icorr),sts.CrossROI_P);
            motionXC = normxcorr2(sts.CrossRef,crossComp);
            % Find peak and get displacement:
            [rowM, colM] = find(motionXC == max(motionXC(:)));
            obj.positions(ind1).displacement(end+1,:) = [(rowM - sts.CrossROI_P(3) - 1) (colM - sts.CrossROI_P(4) - 1) ];
            obj.visp(['displacement = ' num2str(obj.positions(ind1).displacement(end,:)) ],2);
        end
        
        function extractfluo(obj,I,ind1,chan,dirStruct)
            sts = obj.positions(ind1).settings;
            displ = obj.positions(ind1).displacement(end,:);
            
            obj.latestposition = obj.positions(ind1).name;
            obj.latestchannel = chan;
            obj.visp(['Extracting fluo for position: ' obj.latestposition  ', on channel: ' chan])
            
            % If we have a background:
            if ~isempty(sts.BKGD_P)
                fluo = imcrop(I, sts.BKGD_P + [fliplr(displ) 0 0 ]);
                bkgd = mean(fluo(:));
            else
                bkgd = 0;
            end
            
            % If we already have levels acquired in this channel, we append data. Otherwise ind1 = 1:
            if ~isfield(obj.positions(ind1).levels,chan) || ~isfield(obj.positions(ind1).levels.(chan),'levelMean')
                ind0 = 1;
            else
                ind0 = size(obj.positions(ind1).levels.(chan).levelMean,1) + 1;
            end
            
            % First of all, store the time value:
            obj.positions(ind1).levels.(chan).datenums(ind0) = dirStruct.datenum;
            obj.positions(ind1).levels.(chan).timepoints(ind0) = etime(datevec(dirStruct.datenum),datevec(obj.positions(ind1).levels.(chan).datenums(1)));
            
            
            % Save backgournd level:
            obj.positions(ind1).levels.(chan).bkgdlvl(ind0) = bkgd;
            
            % Then acquire fluo for each position and store it in the levels field: 
            for ind2 = 1:numel(sts.ROIS_P)
                fluo = imcrop(I, sts.ROIS_P{ind2} + [fliplr(displ) 0 0 ]); % set the position to take into account the displacement
                if ~isempty(fluo)
                    obj.positions(ind1).levels.(chan).levelMean(ind0,ind2) = mean(fluo(:))-bkgd;
                    obj.positions(ind1).levels.(chan).levelMedian(ind0,ind2) = median(fluo(:))-bkgd;
                    obj.positions(ind1).levels.(chan).levelMax(ind0,ind2) = max(fluo(:))-bkgd;
                    sfl = sort(fluo(:));
                    obj.positions(ind1).levels.(chan).leveltop20(ind0,ind2) =  mean(sfl(round(numel(sfl)*.80):end))-bkgd;
                end
            end
            
            try
                obj.visp(['Fluo levels: ' num2str(round(obj.positions(ind1).levels.(chan).levelMean(ind0,:))) ', on channel: ' chan])
            catch
            end
            
            % Save to corresponding file:
            
            obj.newvalue = ind1;
        end
        
        function acqonPos(obj,pos, chan, filename)
            
            obj.visp(['New acquisition on pos: ' pos ' & channel: ' chan ', filename = ' regexprep(filename,'\\','\\\\')])
            
            % Get the value of ind1 for the name of the position pos
            for ind1 = 1:numel(obj.positions)
                if strcmp(pos,obj.positions(ind1).name)
                    found = true;
                    break; 
                else
                    found = false;
                end
            end
            if ~found
                obj.visp(['Unknown position ' pos ]-1)
            end
            
            % Read the image
            I = imread(filename);
            dirStruct = dir(filename);
            
            % According to channel, calculate displacement or extract fluo:
            switch chan
                case obj.positions(ind1).segchan
%                     obj.calculatedisplacement(I,ind1);
                    dispL = fgetl(obj.server);
                    obj.positions(ind1).displacement(end+1,:) = str2num(dispL);
                    obj.visp(['displacement = ' num2str(obj.positions(ind1).displacement(end,:)) ],2);
                    
                otherwise
                    obj.extractfluo(I,ind1,chan,dirStruct);
            end
        end
        
        function handles = plotlevelsofpos(obj,varargin)
            if nargin >= 2 && varargin{1} ~= ':'
                pos = varargin{1};
            else
                pos = 1:numel(obj.positions);
            end
            if nargin >= 4 && strcmp(varargin{3},'hold on')
                clearPlots = false;
            else
                clearPlots = true;
            end
            
            plottype = 1; % levels
            
            if nargin >= 5 
                switch varargin{4}
                    case 'lvls'
                        plottype = 1;
                    case 'ratio'
                        plottype = 2;
                    case 'traj'
                        plottype = 3;
                end
            end
            
            
            
            
            handles = [];
            
            for ind1 = pos
                if ~isfield(obj.positions(ind1),'fighandle') || isempty(obj.positions(ind1).fighandle) || ~ishandle(obj.positions(ind1).fighandle)
                    fh = figure();
                    set(fh,'Name',obj.positions(ind1).name);
                    obj.positions(ind1).fighandle = fh;
                else
                    fh = obj.positions(ind1).fighandle;
                end
                
                handles(end+1) = fh;
                set(0,'CurrentFigure',fh)
                if clearPlots
                    cla
                else
                    hold on
                end
                
                fields = fieldnames(obj.positions(ind1).levels);
                colors = {'r','g','b','c','y','m','k'};
                
                
                if nargin >= 3 && (~ischar(varargin{2}) || varargin{2} ~= ':')
                    curves = varargin{2};
                else
                    curves = 1:size(obj.positions(ind1).levels.(fields{1}).levelMean,2);
                end
                
                switch plottype
                    case 1 % levels
                        for ind2 = 1:numel(fields)
                            for ind3 = 1:numel(curves)
                                plot(obj.positions(ind1).levels.(fields{ind2}).timepoints./3600,smooth(obj.positions(ind1).levels.(fields{ind2}).levelMean(:,curves(ind3)),20),'Color',colors{ind2})
                                hold on;
                            end
                        end
                    case 2 % ratio
                        for ind3 = 1:numel(curves)
                            semilogy(obj.positions(ind1).levels.(fields{1}).timepoints./3600,smooth(obj.positions(ind1).levels.(fields{1}).levelMean(:,curves(ind3)),20)./smooth(obj.positions(ind1).levels.(fields{2}).levelMean(:,curves(ind3)),20))
                            hold on
                        end
                    case 3 % traj
                        for ind3 = 1:numel(curves)
                            plot(smooth(obj.positions(ind1).levels.(fields{1}).levelMean(:,curves(ind3)),20),smooth(obj.positions(ind1).levels.(fields{2}).levelMean(:,curves(ind3)),20))
                            hold on
                        end
                end
            end
        end
            
        
        
        %Utilities
        function bytesavcallback(obj, ~,~)
            
            if obj.server.BytesAvailable % For some reason the callback is triggered even when there are no bytes availble?
                obj.visp(['Received data! (' num2str(obj.server.BytesAvailable) ' B)'],4);
                
                ret = fgetl(obj.server);
                if strcmp(ret,'<CMD>')
                    switch fgetl(obj.server)
                        case 'SETUP'
                            pos = fgetl(obj.server);
                            chn = fgetl(obj.server);
                            fname = fgetl(obj.server);
                            obj.setupNewPos(pos,chn,fname);
                        case 'ACQ'
                            pos = fgetl(obj.server);
                            chn = fgetl(obj.server);
                            fname = fgetl(obj.server);
                            obj.acqonPos(pos,chn,fname);
                        otherwise
                            return;
                    end
                end
            end
        end
        
        function visp(obj,msg,varargin)

            % If no verbosity specified, verbosity is one
            if nargin == 2
                verbosity = 1;
            else
                verbosity = varargin{1};
            end
            
            % Get level of verbosity of object:
            verb = obj.verbosity;
            
            % Cat message and output:
            msg = ['[' class(obj) '] ' datestr(now) ' - '   msg '\n'];
            if verbosity < 0
                error(msg);
            end
            if verb >= verbosity
                fprintf(msg);
            end
           
        end
        
        function delete(obj)
            fclose(obj.server);
        end
        
        function reboot(obj)
            obj.visp('Rebooting...')
            fclose(obj.server);
            pause(1)
            obj.launchserver();
        end
    
        function launchserver(obj)
            obj.server = tcpip( obj.rhost, obj.lport , 'NetworkRole', 'server');
            obj.visp(['Server up! Waiting for connection on port ' num2str(obj.lport) ' from ' obj.rhost '...'])
            fopen(obj.server);
            obj.visp(['Client ' obj.server.RemoteHost ' connected on port ' num2str(obj.server.RemotePort) '!']);
            obj.server.BytesAvailableFcn = @obj.bytesavcallback;
        end

    end
    
    
end
            
                
    