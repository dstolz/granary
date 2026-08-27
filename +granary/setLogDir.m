function d = setLogDir(p)
% d = granary.setLogDir(p)    write the daily logs to p from now on
% d = granary.setLogDir('')   clear the override, back to the built-in default
%
% Stores the choice as getpref(<PrefGroup>,'LogDir') so it survives MATLAB
% restarts, and re-points the live logger immediately: every file sink is
% closed and reopened against the new directory, so the next message lands
% there rather than at the next MATLAB session.
%
% A rig whose application sits on a read-only or synced share needs its logs
% elsewhere; this is what a host's "log directory" setting calls. The change is
% recorded in both the old log and the new one, so a reader of either can
% follow the trail.
%
% Unlike the rest of the package this DOES throw, because it is configuration
% rather than logging: a rejected setting must be visible to the operator
% typing it, not swallowed the way a bad log message is.
%
% Parameters:
%   p - absolute directory path, or '' to clear the override. A relative path
%       is refused: every cd would otherwise start a new log directory, and a
%       host offering to open "the current log" would point at whichever one
%       is current.
%
% Returns:
%   d - the directory now in effect (see granary.defaultLogDir)
%
% Example:
%   granary.setLogDir('D:\rig_logs')
%   granary.setLogDir('')          % back to the built-in default
%
% See also: granary.defaultLogDir, granary.isAbsolutePath, granary.config,
%           granary.sink.FileSink

arguments
    p {mustBeTextScalar} = ''
end

p = strtrim(char(p));
grp = granary.config().PrefGroup;

if ~isempty(p)
    if ~granary.isAbsolutePath(p)
        error('granary:setLogDir:RelativePath', ...
            ['The log directory must be an absolute path; "%s" is relative. ' ...
             'A relative path would follow the working directory.'],p);
    end

    if ~isfolder(p)
        [made,msg] = mkdir(p);
        if ~made
            error('granary:setLogDir:NotWritable', ...
                'Could not create the log directory "%s": %s',p,msg);
        end
    end
end

% Leave a marker in the log being left behind, and make sure it reaches disk
% before the handle moves.
L = granary.Logger.instance();
if ~isempty(p)
    granary.printf(1,'Log directory changing to: %s',p);
else
    granary.printf(1,'Log directory reverting to the built-in default');
end
L.flush();

if isempty(p)
    if ispref(grp,'LogDir')
        rmpref(grp,'LogDir');
    end
else
    setpref(grp,'LogDir',p);
end

d = granary.defaultLogDir();

% Re-point the live sinks. reset() also clears a latched open failure, so a
% logger that gave up on an unwritable directory starts working again here.
for k = 1:numel(L.Sinks)
    s = L.Sinks{k};
    if isa(s,'granary.sink.FileSink')
        s.reset();
        s.Dir = d;
    end
end

granary.printf(1,'Log directory: %s',d);
end
