classdef ControlWrapper < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetObservable)
        controller;
        sensor;
        actuator;
        posname = '';
        media = 'pcm1'; % Media percentage to modify depending on the decision result. (1 =iptg, 2=aTC)
        sensorlistener;
        decisions = [];
        decisiontimes = [];
        decisionslistener;
        celltocontrol = 1;
        positionnb = 1;
        channel = 'rfp';
    end
    
    methods
        function obj = ControlWrapper(varargin)
            if nargin >= 1
                obj.controller = varargin{1};
            end
            if nargin >= 2
                obj.sensor = varargin{2};
            end
            if nargin >= 3
                obj.actuator = varargin{3};
            end
            if nargin >= 4
                obj.posname = varargin{4};
            end
            if nargin >= 5
                obj.media = varargin{5};
            end
            if nargin >= 6
                obj.celltocontrol = varargin{6};
            end
            if nargin >= 7
                obj.positionnb = varargin{7};
            end
            if nargin >= 8
                obj.channel = varargin{8};
            end
            
            obj.decisionslistener = addlistener(obj,'decisions','PostSet',@obj.decisioncallback);
            obj.sensorlistener = addlistener(obj.sensor, 'newvalue','PostSet',@obj.newsensorvaluecallback);
        end
        
        function decisioncallback(obj,~,~)
            obj.actuator.setVal(obj.posname,obj.media,obj.decisions(end));
        end
        
        
        function newsensorvaluecallback(obj,src,evt)
            if evt.AffectedObject.newvalue == obj.positionnb && strcmp(evt.AffectedObject.latestchannel,obj.channel);
                evt.AffectedObject.newvalue = 0;
                levels = evt.AffectedObject.positions(obj.positionnb).levels.(obj.channel).levelMean(:,obj.celltocontrol);
                tpoints = evt.AffectedObject.positions(obj.positionnb).levels.(obj.channel).timepoints;
                if numel(tpoints) <= 21
                levels = smooth(levels,20);
                else
                    levels = smooth(levels,20,'sgolay',3);
                end
                levels(end) = evt.AffectedObject.positions(obj.positionnb).levels.(obj.channel).levelMean(end,obj.celltocontrol);
                
                obj.decisions(end+1) = obj.controller.decide(levels,tpoints);
                obj.decisiontimes(end+1) = now;
            end
        end
        
    end
    
end