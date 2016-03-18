classdef QDimanServer < handle & hgsetget
    
    properties
        rhost = '127.0.0.1';    % '0.0.0.0' accepts any machine, 127.0.0.1 accepts only localhost connecitons etc...
        lport = 30001 ;         % Local port to listen to
        server;
        positions = struct();
        verbosity = 4;
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
            obj.server = tcpip( obj.rhost, obj.lport , 'NetworkRole', 'server');
            obj.visp(['Server up! Waiting for connection on port ' num2str(obj.lport) ' from ' obj.rhost '...'])
            fopen(obj.server);
            obj.visp(['Client ' obj.server.RemoteHost ' connected on port ' num2str(obj.server.RemotePort) '!']);
            obj.server.BytesAvailableFcn = @obj.bytesavcallback;
        end
        
        
        function setupNewPos(obj,pos, chan, filename)
            % Load script settings
            scriptsettings = load(filename);
            % If there is at least one positon, append. Otherwise create.
            if isempty(fieldnames(obj.positions))
                positions = struct('name',pos,'segchan',chan,'settings',scriptsettings,'displacement',[0 0],levels,struct());
            else
                positions(end+1) = struct('name',pos,'segchan',chan,'settings',scriptsettings,'displacement',[0 0],levels,struct());
            end
            obj.visp(['Set up new position: ' pos ', ref chan: ' chan])
        end
        
        function calculatedisplacement(obj,Icorr,ind1)
            obj.visp(['Computing displacement for position: ' pos ])
            sts = obj.positions(ind1).scriptsettings;
            % Compute cross corr
            crossComp = imcrop(Icorr,sts.CrossROI_P);
            motionXC = normxcorr2(sts.crossRef,crossComp);
            % Find peak and get displacement:
            [rowM, colM] = find(motionXC == max(motionXC(:)));
            obj.positions(ind1).displacement(end+1,:) = [(rowM - sts.CrossROI_P(3) - 1) (colM - sts.CrossROI_P(4) - 1) ];
            obj.visp(['displacement = ' num2str(obj.positions(ind1).displacement(end,:)) ],2);
        end
        
        function extractfluo(obj,I,ind1,chan)
            sts = obj.positions(ind1);
            
            obj.visp(['Extracting fluo for position: ' pos ', on channel: ' chan])
            % If we have a background:
            if ~isempty(sts.BKGD_P)
                fluo = imcrop(I, sts.BKGD_P + [fliplr(sts.displacement) 0 0 ]);
                bkgd = mean(fluo(:));
            else
                bkgd = 0;
            end
            
            % If we already have levels acquired in this channel, we append data. Otherwise ind1 = 1:
            if isfield(obj.positions(ind1).levels,chan) || isfield(obj.positions(ind1).levels.(chan),levelMean)
                ind0 = numel(obj.positions(ind1).levels.(chan).levelMean) + 1;
            else
                ind0 = 1;
            end
            
            % Save backgournd level:
            obj.positions(ind1).levels.(chan).bkgdlvl(ind0) = bkgd;
            
            % Then acquire fluo for each position and store it in the levels field: 
            for ind2 = 1:numel(sts.origROIS_P)
                fluo = imcrop(IR, sts.origROIS_P{ind2} + [fliplr(sts.displacement) 0 0 ]); % set the position to take into account the displacement
                if ~isempty(fluo)
                    obj.positions(ind1).levels.(chan).levelMean(ind0,ind2) = mean(fluo(:));
                    obj.positions(ind1).levels.(chan).levelMedian(ind0,ind2) = median(fluo(:));
                    obj.positions(ind1).levels.(chan).levelMax(ind0,ind2) = max(fluo(:));
                    sfl = sort(fluo(:));
                    obj.positions(ind1).levels.(chan).leveltop20(ind0,ind2) =  mean(sfl(round(numel(sfl)*.80):end));
                end
            end
            
            obj.visp(['Fluo levels: ' num2str(obj.positions(ind1).levels.(chan).levelMean(:,ind2)') ', on channel: ' chan])
            
            % Save to corresponding file:
            
            
        end
        
        function acqonPos(obj,pos, chan, filename)
            
            obj.visp(['New acquisition on pos: ' pos ' & channel: ' chan ', filename = ' filename])
            
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
            
            % According to channel, calculate displacement or extract fluo:
            switch chan
                case obj.positions(ind1).segchan
                    obj.calculatedisplacement(I,ind1);
                otherwise
                    obj.extractfluo(I,ind1,chan);
            end
        end
        
        function handles = plotlevelsofpos(obj,varargin)
            if nargin == 2
                pos = varargin{1}
            else
                pos = 1:numel(obj.positions)
            end
            
            for ind1 = 1:numel(pos) 
                if ~isfield(obj.positions(ind1),'fighandle') || ~isvalid(obj.positions(ind1).fighandle)
                    fh = figure();
                    set(fh,'Name',obj.positions(ind1).name);
                    obj.positions(ind1).fighandle = fh;
                else
                    fh = obj.positions(ind1).fighandle;
                end
                
                set(0,'CurrentFigure',fh)
                for ind1 = 1:numel(obj.positions)
                    plot(obj.positions(ind1).)
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
    

    end
    
    
end
            
                
    