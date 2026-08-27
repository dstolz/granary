function d = defaultLogDir()
% d = granary.defaultLogDir()
% Directory the daily log files are written to.
%
% Resolves in this order:
%   1. The operator's override, getpref(<PrefGroup>,'LogDir') -- set through
%      granary.setLogDir, or by whatever settings dialog the host puts in
%      front of it. A rig whose application lives on a read-only or synced
%      share needs its logs somewhere else.
%   2. granary.builtinLogDir, <LogRoot>/<LogDirName>.
%
% The preference group is granary.config's PrefGroup, so each host owns its own
% override and two applications embedding granary cannot fight over one log
% directory.
%
% Returns:
%   d - absolute path to the log directory (not created here)
%
% See also: granary.builtinLogDir, granary.setLogDir, granary.config,
%           granary.sink.FileSink

d = '';
grp = granary.config().PrefGroup;

try
    % ispref first: the three-argument getpref CREATES the preference when it
    % is missing, so querying with a default would write an empty LogDir into
    % the preferences file on every sink construction and leave "is there an
    % override?" unanswerable.
    if ispref(grp,'LogDir')
        d = char(getpref(grp,'LogDir'));
    end
catch
    % Preferences unreadable (rare, but getpref touches the file system);
    % fall through to the built-in default rather than losing logging.
end

% A stored relative path is worse than no override at all: it would follow the
% working directory, so it is discarded rather than resolved against cd.
if ~isempty(d) && granary.isAbsolutePath(d)
    return
end

d = granary.builtinLogDir();
end
