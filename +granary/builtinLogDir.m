function d = builtinLogDir()
% d = granary.builtinLogDir()
% The log directory used when no override is configured:
% <LogRoot>/<LogDirName>, both from granary.config.
%
% By default LogRoot is tempdir, so a program that has configured nothing
% still logs somewhere predictable. A host normally points LogRoot at its own
% installation root during startup, which is what puts the log folder with the
% application instead of in the system temporary directory. Shipping that
% folder as a .gitignore stub that excludes every log written into it costs the
% host's working tree nothing.
%
% Separate from granary.defaultLogDir so callers can name the fallback while an
% override is in force -- a settings dialog showing it as placeholder text in
% an empty field is exactly the moment the override is about to be cleared.
%
% A configured root that has gone missing falls back to tempdir rather than
% being used anyway: fullfile('',name) is a RELATIVE path, which would scatter
% log directories through whatever folder happened to be the working
% directory. That is also why a relative override is refused rather than
% resolved against cd.
%
% Returns:
%   d - absolute path to the built-in log directory (not created here)
%
% See also: granary.defaultLogDir, granary.setLogDir, granary.config

C = granary.config();

root = C.LogRoot;
if isempty(root) || ~ischar(root) || ~isfolder(root)
    root = tempdir;
end

d = fullfile(root,C.LogDirName);
end
