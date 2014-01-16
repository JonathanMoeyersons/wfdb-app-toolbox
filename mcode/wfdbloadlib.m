function [varargout]=wfdbloadlib(varargin)
%
% [isloaded,config]=wfdbloadlib(debugLevel,networkWaitTime)
%
% Loads the WDFDB libarary if it has not been loaded already into the
% MATLAB classpath. And optionally prints configuration environment and debug information
% regarding the settings used by the classes in the JAR file.
%
% Inputs:
%
% debugLevel
%       (Optional) 1x1 integer between 0 and 5 represeting the level of debug information to output from
%       Java class when output configuration information. Level 0 (no debug information),
%       level =5 is maximum level of information output by the class (logger set to finest). Default is level 0.
%
% networkWaitTime
%       (Optional) 1x1 interger representing the longest time in
%       milliseconds  for which the JVM should wait for a data stream from
%       PhysioNet (default is =1000  , ie one second). If you need to change this time to a
%       longer value across the entire toolbox, it is better modify to default value in the source
%       code below and restart MATLAB.
%
%
% Written by Ikaro Silva, 2013
%         Last Modified: January 16, 2014
% Since 0.0.1
%
%
mlock
persistent isloaded wfdb_path;

%%%%% SYSTEM WIDE CONFIGURATION PARAMETERS %%%%%%%
%%% Change these values for system wide configuration of the WFDB binaries

WFDB_CUSTOMLIB=0; %If you are using your own custom version of the WFDB binaries, set this to true
WFDB_PATH=[]; %If empty, will use the default giveng confing.WFDB_PATH
WFDBCAL=[]; %If empty, will use the default giveng confing.WFDBCAL
debugLevel=0;
networkWaitTime=1000;

%%%% END OF SYSTEM WIDE CONFIGURATION PARAMETERS

inputs={'debugLevel','networkWaitTime'};
for n=1:nargin
    if(~isempty(varargin{n}))
        eval([inputs{n} '=varargin{n};'])
    end
end


inOctave=is_octave;
if(isempty(isloaded))
    jar_path=which('wfdbloadlib');
    cut=strfind(jar_path,'wfdbloadlib.m');
    wfdb_path=jar_path(1:cut-1);
    
    if(~inOctave)
        ml_jar_version=version('-java');
    else
        %In Octave
        ml_jar_version=javaMethod('getProperty','java.lang.System','java.version');
        ml_jar_version=['Java ' ml_jar_version];
    end
    %Check if path has not been added yet
    if(~isempty(strfind(ml_jar_version,'Java 1.6')))
        wfdb_path=[wfdb_path 'wfdb-app-JVM6-0-9-6.jar'];
    elseif(~isempty(strfind(ml_jar_version,'Java 1.7')))
        wfdb_path=[wfdb_path 'wfdb-app-JVM7-0-9-6.jar'];
    else
        error(['Cannot load on unsupported JVM: ' ml_jar_version])
    end
    javaaddpath(wfdb_path)
    isloaded=1;
end

outputs={'isloaded','config'};
for n=1:nargout
    if(n>1)
        config.MATLAB_VERSION=version;
        config.inOctave=inOctave;
        if(inOctave)
            javaWfdbExec=javaObject('org.physionet.wfdb.Wfdbexec','wfdb-config',WFDB_CUSTOMLIB);
            javaWfdbExec.setLogLevel(debugLevel);
            config.WFDB_VERSION=char(javaMethod('execToStringList',javaWfdbExec,{'--version'}));
        else
            javaWfdbExec=org.physionet.wfdb.Wfdbexec('wfdb-config',WFDB_CUSTOMLIB);
            javaWfdbExec.setLogLevel(debugLevel);
            config.WFDB_VERSION=char(javaWfdbExec.execToStringList('--version'));
        end
        env=regexp(char(javaWfdbExec.getEnvironment),',','split');
        for e=1:length(env)
            tmpstr=regexp(env{e},'=','split');
            varname=strrep(tmpstr{1},'[','');
            varname=strrep(varname,' ','');
            varname=strrep(varname,']','');
            eval(['config.' varname '=''' tmpstr{2} ''';'])
        end
        config.MATLAB_PATH=strrep(which('wfdbloadlib'),'wfdbloadlib.m','');
        config.SUPPORT_EMAIL='wfdb-matlab-support@physionet.org';
        wver=regexp(wfdb_path,filesep,'split');
        config.WFDB_JAVA_VERSION=wver{end};
        config.DEBUG_LEVEL=debugLevel;
        config.NETWORK_WAIT_TIME=networkWaitTime;
        
        %Remove empty spaces from arch name
        del=strfind(config.osName,' ');
        config.osName(del)=[];
        
        %Define WFDB Environment variables
        if(isempty(WFDB_PATH))
            WFDB_PATH=['. http://physionet.org/physiobank/database'];
        end
        if(isempty(WFDBCAL))
            WFDBCAL=[config.WFDB_JAVA_HOME filesep 'database' filesep 'wfdbcal'];
        end
        config.WFDB_PATH=WFDB_PATH;
        config.WFDBCAL=WFDBCAL;
        config.WFDB_CUSTOMLIB=WFDB_CUSTOMLIB;
    end
    eval(['varargout{n}=' outputs{n} ';'])
end


%% subfunction that checks if we are in octave
function r = is_octave ()
    r = exist ('OCTAVE_VERSION', 'builtin')>0;
