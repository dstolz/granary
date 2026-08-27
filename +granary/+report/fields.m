function f = fields(opts)
% f = granary.report.fields()
% f = granary.report.fields(Environment=txt, MaxLogLines=n)
% Gather the prefilled sections of a bug report.
%
% The log excerpt is this package's contribution: the logger is flushed, the
% current log file is located, and its TAIL is taken -- the end of a log is the
% part describing the failure. The environment block is the host's, because
% only the application knows what about its own state is worth reporting; pass
% it in as text, optionally built on granary.report.environment.
%
% Flushing first is load-bearing rather than tidy. The file sink buffers, so
% without it the excerpt ends several messages before the failure the operator
% is reporting -- which is the one message they opened the report about.
%
% Parameters:
%   Environment - Host-supplied environment block. Default ''.
%   MaxLogLines - Lines to take from the end of the log (default 120). A first
%                 pass only: granary.report.url trims further when the encoded
%                 URL would be too long.
%
% Returns:
%   f - Struct with fields:
%       environment   - char. The Environment text, unchanged.
%       logs          - char. Tail of the current log; '' when there is none.
%       logPath       - char. Full path of that log file; '' when file logging
%                       is disabled, which is what a caller tests to decide
%                       whether a log can be offered at all.
%       logLines      - Lines taken.
%       logTotalLines - Lines the file holds, so the excerpt can say what it
%                       omits.
%
% Read defensively throughout: this runs when something has already gone
% wrong, so a failure here must cost one line of the report rather than the
% report.
%
% See also: granary.report.url, granary.report.environment,
%           granary.report.Tracker

arguments
    opts.Environment {mustBeTextScalar} = ''
    opts.MaxLogLines (1,1) double {mustBeInteger, mustBePositive} = 120
end

f = struct('environment','','logs','','logPath','', ...
    'logLines',0,'logTotalLines',0);

f.environment = char(string(opts.Environment));

L = granary.Logger.instance();
L.flush();
logPath = char(string(L.LogFile));
if isempty(logPath) || ~isfile(logPath)
    return
end
f.logPath = logPath;

try
    txt = fileread(logPath);
catch ME
    granary.printf(0,1,ME);
    return
end

lines = splitlines(string(txt));
if strlength(lines(end)) == 0
    lines(end) = [];
end
f.logTotalLines = numel(lines);

n = min(opts.MaxLogLines, numel(lines));
f.logLines = n;
f.logs = char(join(lines(end-n+1:end), newline));
end
