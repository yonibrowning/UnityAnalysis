classdef UnitySession
    %This is my way of loading a unity
    
    properties
        % File names used to build the object. Just for reference later.
        % Probably would be best to build in other usefull info, but not
        % for now.
        behaviorFile = '';
        neuralFile = '';
        task = ''; %Either W for W maze or F for foraing.
        % Behavior Data
        tme = []; % Time
        frm = []; % Frame
        posdat = []; % Position
        dirdat = []; % Direction
        beep = []; % Beep times
        banpos = []; % Banana locations
        baneat = []; % Banana eat times.
        % Eye Data
        eyepos = []; % Eye position.
        % Neural Data
        spikes = [];
        lfp = [];
        
        
    end
    
    methods
        % Class constructor. This is a monster of a Method that will
        % eventually take data from any behavioral data and pair it with
        % neural data in a usable way.
        
        % Right now, it just puts the behavioral data in a usable form!
        function S = UnitySession(varargin)
            if nargin == 0||nargin == 1;
                % Constructor can't do much without data
                error('Constructor requires input!!');
            elseif nargin == 2;
                % One input: behavior file only!
                S.task = varargin{1};
                S.behaviorFile = varargin{2};
            elseif nargin == 3;
                % Two inputs: now we have a blackrock file! This will need
                % to be expanded to handel the different types of blackrock
                % files. For starters, lets just look at the .NEV
                S.task = varargin{1};
                S.behaviorFile = varargin{2};
                S.neuralFile = varargin{3};
            end
            
            % start with the first trial.
            trl = 0;newtrl = 0;
            
            % Read behavioral data
            fileID = fopen(S.behaviorFile,'r');
            % Fencepost
            line = fgetl(fileID);
            while ischar(line);
                % Split Data on line. These are seperated by cols
                elmts = strsplit(line,',');
                % Figure out if line has usefull data by checking that it
                % begins with a number. This number should be the time
                % stamp.
                if ~isnan(str2double(elmts{1}))
                    % start a new trial when banana 0 is spawned.
                    if isequal(S.task,'F')
                        if isequal(elmts{4},'SPAWNED')&&isequal(elmts{3},'banana_0');
                            trl = trl+1
                            newtrl = 1;
                        end
                    elseif isequal(S.task,'W')
                        % start a new trial each time the monkey goes to
                        % the center
                        if isequal(elmts{4},'SPAWNED')&&...
                                (isequal(elmts{3},'SimpleBanana_0')||isequal(elmts{3},'Training_Center_Banana'));
                            trl = trl+1
                            newtrl = 1;
                        end
                    end
                    if newtrl == 1;
                        S.banpos{trl} = [];
                        S.baneat{trl} = [];
                        S.tme{trl} = [];
                        S.posdat{trl} = [];
                        S.dirdat{trl} = [];
                        S.beep{trl} = [];
                        S.frm{trl} = [];
                        newtrl = 0;
                    end
                    if trl>=1;
                        % if entry is position. Here, we can log frame and
                        % time. B.C. the next entry will always be rotation,
                        % these will NOT be loged. This is the same for all
                        % tasks (Foraging, W, Etc.);
                        if isequal(elmts{3},'Player')&&isequal(elmts{4},'POSITION')&&(trl~=0);
                            % Time stamp.
                            S.tme{trl} = [S.tme{trl} str2double(elmts{1})];
                            % Frame.
                            S.frm{trl} = [S.frm{trl} str2double(elmts{2})];
                            % Position; X,Z.
                            S.posdat{trl} = [S.posdat{trl} [str2double(elmts{5});str2double(elmts{7})]];
                            
                            % Entries for rotation.
                        elseif isequal(elmts{3},'Main Camera')&&isequal(elmts{4},'ROTATION');
                            S.dirdat{trl} = [S.dirdat{trl} str2double(elmts{6})];
                            % Entries for beeps
                        elseif isequal(elmts{3},'BEEP');
                            S.beep{trl} = [S.beep{trl}; str2double(elmts{1}), str2double(elmts{2})];
                            % Entires for bananas being created or distroyed.
                        end
                        
                        % Note Banana Locations, eat times for the Foraging Task; 
                        if isequal(S.task,'F')
                            if ~isempty(strfind(elmts{3},'banana'));
                                brk = strsplit(elmts{3},'_'); bannum = str2double(brk{2}); %number of the banana.
                                if isequal(elmts{4},'POSITION')
                                    % bananaID, X, Z
                                    S.banpos{trl} = [S.banpos{trl}; [bannum, str2double(elmts{5}),str2double(elmts{7})]];
                                elseif isequal(elmts{4},'EATEN')
                                    % Timestamp, frame, and bananaID
                                    S.baneat{trl} = [S.baneat{trl}; [str2double(elmts{1}), str2double(elmts{2}), str2double(elmts{3})]];
                                end
                            end
                        end
                        
                        % Note Banana Appearing, Eating for the W Task
                        if isequal(S.task,'W')
                            % Identify Training Banana
                            if ~isempty(strfind(elmts{3},'Training'));
                                brk = strsplit(elmts{3},'_');
                                if isequal(brk{2},'Right');
                                    ban = 'r';
                                elseif isequal(brk{2},'Left');
                                    ban = 'c';
                                elseif isequal(brk{2},'Center');
                                    ban = 'l';
                                end
                                
                            % idenfity Full Banana
                            elseif ~isempty(strfind(elmts{3},'SimpleBanana'));
                                brk = strsplit(elmts{3},'_');
                                if isequal(brk{2},'0');
                                    ban = 'r';
                                elseif isequal(brk{2},'2');
                                    ban = 'c';
                                elseif isequal(brk{2},'1');
                                    ban = 'l';
                                end
                            end
                            
                            % Not Spawning, Eating.
                            if isequal(elmts{4},'SPAWNED');
                                S.banpos{trl} = [S.banpos{trl}; [str2double(elmts{1}), ban]];
                            elseif isequal(elmts{4},'EATEN');
                                S.baneat{trl} = [S.baneat{trl}; [str2double(elmts{1}), ban]];
                            end
                            
                        end
                    end
                end
                % grab the next line. Will be processed on the next
                % iteration of the loop.
                line = fgetl(fileID);
            end
            
        end
        
        
    end
    
    %Static Methods.
    methods (Static);
        function plotTrial(S,trlnum)
            plot(S.posdat{trlnum}(1,:),S.posdat{trlnum}(2,:),'LineWidth',2); hold on;
            for bn = 1:length(S.banpos{trlnum}(:,1));
                plot(S.banpos{trlnum}(bn,2),S.banpos{trlnum}(bn,3),'*r','MarkerSize',5);
            end
        end
    end
    
end

