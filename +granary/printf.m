function printf(verbose_level,varargin)
% granary.printf(level,msg)
% granary.printf(level,red,msg)
% granary.printf(level,msg,value1,value2,...)
% granary.printf(level,red,msg,value1,value2,...)
% granary.printf(level,[red],exception)
%
% Verbosity-gated console and log printing, and the front door to the whole
% package: it parses the calling convention and hands the result to
% granary.Logger, which formats the record once and dispatches it to every
% configured sink (console, daily text file, optional JSON Lines).
%
% Levels are integers normally between -1 and 4:
%  -1 log message, but do not print to screen
%   0 critical; suppresses nearly all other text
%   1 low, information that may be generally useful to the user
%   2 medium, information that can be helpful for debugging
%   3 high, lots of information about nearly all processes (debugging)
%   4 trace, per-iteration detail
% See granary.Level for the named form.
%
% The two destinations are filtered separately:
%   GVerbosity    - command window. Default 1.
%   GLogVerbosity - log file. Default Inf, so EVERY message is written no
%                   matter how quiet the console is.
% Lowering GVerbosity therefore hides output; it does not discard it. Set
% GLogVerbosity to a finite level where per-iteration level-4 traces are too
% expensive to write.
%
% Format policy (granary.format):
%   With values, msg is a printf format string, exactly as documented.
%   With no values, msg is LITERAL text -- nothing is interpreted -- so a
%   runtime-built message such as ME.message or 'C:\new\data.mat' survives
%   intact instead of being mangled by '\n' and '%' conversions.
% A trailing newline is never needed and is stripped if present; the sinks add
% their own line ending.
%
% The msg input may also be an MException, or any struct carrying .message
% (a lasterror-style struct or a timer ErrorFcn event). The identifier,
% message, stack and any nested causes are written as a SINGLE log record,
% attributed to the catch site rather than to the logger.
%
% Nothing here throws. Callers log from inside catch blocks, and an exception
% raised while reporting an exception destroys the report.
%
% A host application that prefers its own spelling may wrap this function --
% see granary.config's FacadeFiles, which keeps the caller column pointing at
% the code that logged rather than at the wrapper.
%
% ex:
%      global GVerbosity
%      GVerbosity = 2;
%      granary.printf(2,'This is a level %d message: %s',2,'medium verbosity')
%      18:51:35.958: This is a level 2 message: medium verbosity
%
%      granary.printf(3,'Not printed because GVerbosity = %d, but still logged',GVerbosity)
%
%      granary.printf(1,1,'This is a red level %d message: %s',1,'low verbosity')
%      18:51:35.958: This is a red level 1 message: low verbosity
%
% See also: granary.isEnabled, granary.Logger, granary.Level, granary.format,
%           granary.config

% The gate comes first and is the only cost a suppressed message pays: no
% timestamp, no dbstack, no formatting. In a 100 Hz timer callback that is the
% difference between level-4 traces being free and being a timing hazard --
% which is also a reason to lower GLogVerbosity there, since the default asks
% for everything and only a message no destination wants stops here. Each sink
% applies its own level once the record is built.
if ~granary.isEnabled(verbose_level,'any'), return; end

if isempty(varargin)
    % Nothing to say. Returning here rather than further in: this historically
    % errored on an undefined variable inside the logger, which is the worst
    % possible place to raise.
    return
end

% Calling convention: an optional red flag sits between the level and the
% message. It is only a flag when something follows it, and only when it is
% numeric or logical -- testing ~ischar instead reads a string scalar message
% as the flag and then fails on it.
if numel(varargin) >= 2 && (isnumeric(varargin{1}) || islogical(varargin{1})) ...
        && isscalar(varargin{1})
    red    = logical(varargin{1});
    msg    = varargin{2};
    values = varargin(3:end);
else
    red    = false;
    msg    = varargin{1};
    values = varargin(2:end);
end

granary.Logger.instance().emit(verbose_level,red,msg,values);
