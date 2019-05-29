function EyelinkExample

% Short MATLAB example program that uses the Eyelink and Psychophysics
% Toolboxes to create a real-time gaze-dependent display.
%
% This is the example as shown in the EyelinkToolbox article in BRMIC
% Cornelissen, Peters and Palmer (2002), but updated to use new routines
% and functionality.
%
% History
% ~2006     fwc    created it, to use updated functions
% 15-06-10  fwc    updated to enable eye image display
% 17-06-10  fwc    made colour of the gaze dot change, just for fun

% ####################################################################################
% ####################################################################################
clear all;
commandwindow;
PsychDefaultSetup(1);

% ####################################################################################
% ####################################################################################
% Uncomment next lines if you want to send some triggers 
%ioObj   = io64;
%status  = io64(ioObj);
%address = hex2dec('fff8'); 

%io64(ioObj,address,255);
%WaitSecs(0.010);                    
%io64(ioObj,address,0);
%WaitSecs(2);      

% #######################################################################################
% #######################################################################################
try
    
    % Set to 1 to initialize in dummymode (rather pointless for this example though)
    fprintf('EyelinkToolbox Example\n\n\t');
    dummymode=0;       
    
    % ####################################################################################
    % ####################################################################################
    % STEP 1
    % Open a graphics window on the main screen using the PsychToolbox's Screen function.
    screenNumber = max(Screen('Screens'));
    window = Screen('OpenWindow', screenNumber);
     
    % Provide Eyelink with details about the graphics environment, and perform some initializations. 
    % The information is returned in a structure that also contains useful defaults
    % and control codes (e.g. tracker state bit and Eyelink key values).
    el = EyelinkInitDefaults(window);
    
    % Disable key output to Matlab window:
    ListenChar(2);
        
    % #################################################################################### 
    % ####################################################################################
    % STEP 2
    % Dummy Check: Initialization of the connection with the Eyelink Gazetracker.
    
    % exit program if this fails.
    if ~EyelinkInit(dummymode, 1)
        fprintf('Eyelink Init aborted.\n');
        cleanup;  % cleanup function
        return;
    end
    
    [v vs]=Eyelink('GetTrackerVersion');
    fprintf('Running experiment on a ''%s'' tracker.\n', vs );
    
    % #################################################################################### 
    % ####################################################################################
    % Set calibration tones!
    % You can also just omitt this part of the code. 
    % 
    % 
    % Parameters are in frequency, volume, and duration
    % set the second value in each line to 0 to turn off the sound
    calib_vol =                        0.01;
    el.cal_target_beep =               [600 calib_vol 0.05];
    el.drift_correction_target_beep =  [600 calib_vol 0.05];
    el.calibration_failed_beep =       [400 calib_vol 0.25];
    el.calibration_success_beep =      [800 calib_vol 0.25];
    el.drift_correction_failed_beep =  [400 calib_vol 0.25];
    el.drift_correction_success_beep = [800 calib_vol 0.25];
    
    % You must call this function to apply the changes from above
    EyelinkUpdateDefaults(el);    % parameters are in frequency, volume, and duration
 
    
    Eyelink('getnextdatatype')
    
    % Make sure that we get gaze data from the Eyelink
    Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA,INPUT');
    
    %Eyelink('Command', 'input_data_mask = 0xFF');
    
    % ####################################################################################
    % ####################################################################################
    % Strep 3
    % Open file to record data to
    edfFile = 'demo.edf';
    Eyelink('Openfile', edfFile);
    
    % ####################################################################################
    % ####################################################################################
    % STEP 4
    % Calibration
    EyelinkDoTrackerSetup(el);

    % Do a final check of calibration using driftcorrection
    % EyelinkDoDriftCorrection(el);
        
    % ####################################################################################
    % ####################################################################################
    % STEP 5
    % start recording eye position
    Eyelink('StartRecording');
    % record a few samples before we actually start displaying
    WaitSecs(0.1);
    
    % Mark zero-plot time in data file
    Eyelink('Message', 'SYNCTIME');
    stopkey = KbName('space');
    eye_used = -1;

    Screen('FillRect', el.window, el.backgroundcolour);
    Screen('TextFont', el.window, el.msgfont);
    Screen('TextSize', el.window, el.msgfontsize);
    [width, height]=Screen('WindowSize', el.window);
    message='Press space to stop.';
    Screen('DrawText', el.window, message, 200, height-el.msgfontsize-20, el.msgfontcolour);
    Screen('Flip',  el.window, [], 1);
    
    % #################################################################################### 
    % ####################################################################################
    % Show gaze-dependent display
    while 1 % loop till error or space bar is pressed
        
        % Check recording status, stop display if error
        error=Eyelink('CheckRecording');
        if(error~=0)
            break;
        end
        
        % Check for keyboard press
        [keyIsDown, secs, keyCode] = KbCheck;
        % if spacebar was pressed stop display
        if keyCode(stopkey)
            break;
        end

        % Check for presence of a new sample update
        if Eyelink( 'NewFloatSampleAvailable') > 0
            % get the sample in the form of an event structure
            evt = Eyelink( 'NewestFloatSample');
            if eye_used ~= -1 % do we know which eye to use yet?
                
                % if we do, get current gaze position from sample
                x = evt.gx(eye_used+1); % +1 as we're accessing MATLAB array
                y = evt.gy(eye_used+1);
                
                % do we have valid data and is the pupil visible?
                if x~=el.MISSING_DATA && y~=el.MISSING_DATA && evt.pa(eye_used+1)>0
                    % if data is valid, draw a circle on the screen at current gaze position
                    % using PsychToolbox's Screen function
                    gazeRect=[ x-9 y-9 x+10 y+10];
                    colour=round(rand(3,1)*255); % coloured dot
                    Screen('FillOval', window, colour, gazeRect);
                    Screen('Flip',  el.window, [], 1); % don't erase
                    
                else
                    % If data is invalid (e.g. during a blink), clear display
                    Eyelink('message', 'You are blinking!!');
                    io64(ioObj,address,255);
                    WaitSecs(0.010);                    
                    io64(ioObj,address,0);
                    WaitSecs(0.010);

                    Screen('FillRect', window, el.backgroundcolour);
                    Screen('DrawText', window, message, 200, height-el.msgfontsize-20, el.msgfontcolour);
                    Screen('Flip',  el.window, [], 1); % don't erase
                end
            
            else % If we don't, first find eye that's being tracked
                eye_used = Eyelink('EyeAvailable'); % get eye that's tracked
                if eye_used == el.BINOCULAR; % if both eyes are tracked
                    eye_used = el.LEFT_EYE; % use left eye
                end
            end
        end % If sample available
    end % Main loop
    % Wait a while to record a few more samples
    WaitSecs(0.1);
    
    % ####################################################################################
    % ####################################################################################
    % STEP 6
    % Finish up: Stop recording eye-movements,
    Eyelink('StopRecording');
    Eyelink('CloseFile');
    
    % ####################################################################################
    % ####################################################################################
    % Step 7
    % Download data file
    try
        fprintf('Receiving data file ''%s''\n', edfFile );
        status=Eyelink('ReceiveFile');
        if status > 0
            fprintf('ReceiveFile status %d\n', status);
        end
        if 2==exist(edfFile, 'file')
            fprintf('Data file ''%s'' can be found in ''%s''\n', edfFile, pwd );
        end
    catch rdf
        fprintf('Problem receiving data file ''%s''\n', edfFile );
        rdf;
    end
    
    cleanup;
    
catch myerr
    %this "catch" section executes in case of an error in the "try" section
    %above.  Importantly, it closes the onscreen window if its open.
    cleanup;
    commandwindow;
    myerr;
    myerr.message
    myerr.stack.line

end %try..catch.

% Cleanup routine:
function cleanup

% ####################################################################################
% ####################################################################################
% Close graphics window, close data file and shut down tracker	
% Shutdown Eyelink:
Eyelink('Shutdown');

% Close window:
sca;

% Restore keyboard output to Matlab:
ListenChar(0);
