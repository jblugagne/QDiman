classdef valvesclient < handle
    properties
        rhost = '127.0.0.1';
        rport = 30000;
        socket;
    end
    
    methods
        function obj = valvesclient(varargin)
            if nargin >= 1
                obj.rhost = varargin{1};
            end
            if nargin >= 2
                obj.rport = varargin{2};
            end
            
            obj.socket = tcpip(obj.rhost,obj.rport,'NetworkRole','Client');
            fopen(obj.socket);
            disp(['[valvesclient](' datestr(now) ') Connected to valves server on host ' obj.rhost ' & port ' num2str(obj.rport)])
        end
        
        function setVal(obj,posname,valname,value)
            msg = ['\n<CMD>\n' posname '\n' valname '\n' num2str(value) '\n</CMD>\n'];
            disp(['[valvesclient](' datestr(now) ') Pushing ' num2str(numel(sprintf(msg))) ' bytes of cmd to valves server'])
            fprintf(obj.socket,msg);
        end
    end
end