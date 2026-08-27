function varargout = config(varargin)
% s = granary.config()                 read the whole configuration
% v = granary.config(name)             read one setting
% granary.config(name,value,...)       set one or more settings
% granary.config('-reset')             restore the defaults
%
% Host-supplied settings for the logger.
%
% granary ships usable defaults, so a program that calls granary.printf without
% configuring anything still logs -- to <tempdir>/.error_logs. But a library
% cannot discover where its host lives, which preferences belong to it, or what
% wraps it, so those are told to it by the application that embeds granary,
% normally once during startup.
%
% Settings:
%   LogRoot     - Directory the built-in log folder is created under. Default
%                 tempdir. Point this at the application's own root so logs
%                 land with the program instead of in the system temporary
%                 directory. See granary.builtinLogDir.
%   LogDirName  - Name of that folder. Default '.error_logs'.
%   PrefGroup   - Preference group holding the operator's log-directory
%                 override. Default 'granary'. Give each host its own group:
%                 two programs sharing one would fight over a single log
%                 directory, and a host migrating INTO granary can name the
%                 group it already uses and keep every existing setting
%                 working untouched.
%   FacadeFiles - Filenames that wrap granary.printf and so must never be
%                 reported as the origin of a message. A host with its own
%                 logging front door names that file here, or the caller
%                 column of every record points at the wrapper rather than at
%                 the code that logged. See granary.callerFrame.
%
% Settings live for the MATLAB session and are deliberately NOT persisted:
% they describe how this program is wired, which is decided by the code that
% starts it, not by whoever last ran it. The operator's log-directory choice
% IS persisted, separately, by granary.setLogDir.
%
% Reading never throws. Setting an unknown name does, because it is a
% programming error in the host and silently ignoring it would leave the host
% believing it had configured something.
%
% Example:
%   granary.config('LogRoot',myAppRoot, ...
%                  'PrefGroup','myapp', ...
%                  'FacadeFiles',{'mylog.m'});
%
% See also: granary.builtinLogDir, granary.defaultLogDir, granary.callerFrame,
%           granary.setLogDir

persistent S

if isempty(S)
    S = localDefaults();
end

% --- reset -------------------------------------------------------------
if nargin == 1 && (ischar(varargin{1}) || isstring(varargin{1})) ...
        && strcmp(char(varargin{1}),'-reset')
    S = localDefaults();
    if nargout > 0, varargout{1} = S; end
    return
end

% --- read the whole struct ---------------------------------------------
if nargin == 0
    varargout{1} = S;
    return
end

% --- read one setting ---------------------------------------------------
if nargin == 1
    name = localResolve(char(string(varargin{1})),S);
    varargout{1} = S.(name);
    return
end

% --- set ----------------------------------------------------------------
if mod(nargin,2) ~= 0
    error('granary:config:PairsExpected', ...
        'Settings must be given as name/value pairs.');
end

for k = 1:2:nargin
    name = localResolve(char(string(varargin{k})),S);
    S.(name) = localValidate(name,varargin{k+1});
end

if nargout > 0, varargout{1} = S; end
end


% -----------------------------------------------------------------------
function S = localDefaults()
% tempdir rather than pwd: a relative or working-directory-dependent root
% would scatter log folders through wherever the session happened to be.
S = struct( ...
    'LogRoot',     tempdir, ...
    'LogDirName',  '.error_logs', ...
    'PrefGroup',   'granary', ...
    'FacadeFiles', {{}});
end


% -----------------------------------------------------------------------
function name = localResolve(name,S)
% Match a setting name case-insensitively, so a host may write 'logroot'.
f = fieldnames(S);
i = strcmpi(f,name);
if ~any(i)
    error('granary:config:UnknownSetting', ...
        'Unknown setting "%s". Valid settings: %s.',name,strjoin(f,', '));
end
name = f{find(i,1)};
end


% -----------------------------------------------------------------------
function v = localValidate(name,v)
switch name
    case 'FacadeFiles'
        if isempty(v)
            v = {};
            return
        end
        if ischar(v) || isstring(v)
            v = cellstr(v);
        end
        if ~iscellstr(v) %#ok<ISCLSTR> - cellstr is exactly what is wanted here
            error('granary:config:BadFacadeFiles', ...
                'FacadeFiles must be a filename or a cell array of filenames.');
        end
        v = v(:).';

    otherwise
        if ~(ischar(v) || isstring(v)) || ~isscalar(string(v))
            error('granary:config:BadValue', ...
                '%s must be a single text value.',name);
        end
        v = char(string(v));
end
end
