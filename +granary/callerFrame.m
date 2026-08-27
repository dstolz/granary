function [name,line,file] = callerFrame()
% [name,line,file] = granary.callerFrame()
% Identify the function that raised a log message.
%
% Walks dbstack and returns the first frame belonging to neither the granary
% package nor any front door the host registered. An earlier version of this
% logger hardcoded frame index 3, which assumed exactly
% "caller -> printf -> logmessage". That assumption broke in three real cases:
%
%   * exception logging, which recursed through the front door and so recorded
%     its line number instead of the catch site
%   * call sites inside anonymous functions or cellfun bodies
%   * calls typed at the command window, where the stack is shorter
%
% Scanning by file makes the depth irrelevant, so wrappers added later cannot
% silently mis-attribute every line in the log.
%
% That last point is why the skip list is configurable rather than fixed.
% A host application typically wraps granary.printf in a front door of its own
% -- and may add a bridge that forwards a third-party library's messages in,
% which puts further frames between the call site and this function. Every such
% wrapper must be named in granary.config's FacadeFiles, or the caller column
% of every record it carries points at the wrapper at one fixed line, and the
% attribution the log exists for is silently lost.
%
% Returns:
%   name - calling function name, 'base' when called from the command window
%   line - line number within that function, 0 when unknown
%   file - full path of that function's file, '' when unknown
%
% See also: granary.Logger, granary.printf, granary.config

name = 'base';
line = 0;
file = '';

st = dbstack('-completenames');

% Read once per call rather than caching in a persistent: a host may configure
% granary after the first message has already been logged, and a stale cache
% would then mis-attribute every record for the rest of the session. The whole
% configuration is fetched in one call, which costs far less than the
% dbstack above.
facades = granary.config().FacadeFiles;

% st(1) is callerFrame itself.
for k = 2:numel(st)
    if localIsLoggerFile(st(k).file,facades), continue; end
    name = st(k).name;
    line = st(k).line;
    file = st(k).file;
    return
end

% Every frame belonged to the logger: the call came straight from the command
% window or from a script the stack does not name. Fall back to the outermost
% logger frame rather than reporting nothing.
if numel(st) >= 2
    name = st(end).name;
    line = st(end).line;
    file = st(end).file;
end
end


function tf = localIsLoggerFile(f,facades)
persistent pkgMark
if isempty(pkgMark)
    pkgMark = [filesep '+granary' filesep];
end

tf = false;
if isempty(f), return; end

% The package folder covers granary.printf and every internal frame at once,
% so only the host's own wrappers need naming.
if contains(f,pkgMark)
    tf = true;
    return
end

for k = 1:numel(facades)
    if endsWith(f,[filesep facades{k}])
        tf = true;
        return
    end
end
end
