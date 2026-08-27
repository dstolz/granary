function rec = record(c,stamp,level,red,text,caller,line,file)
% rec = granary.record(c,stamp,level,red,text,caller,line,file)
% Build one log event.
%
% A plain struct, not a class. Sinks read six or seven fields per record, and
% classdef property access costs roughly 5-10 us per read against ~0.1 us for
% a struct field -- enough, across the console and file sinks, to dominate the
% whole logging path.
%
% Level is normalized here, so every sink can compare it against its own level
% with a scalar test. A malformed level -- granary.printf('oops','bad level') -- is
% recorded as 0 rather than passed through: as a char it made "rec.Level <= X"
% return an array and took the sink's whole && chain down with it. Critical is
% the loud end of the scale, which matches granary.isEnabled letting a malformed
% call site through rather than silencing it forever.
%
% Fields:
%   Clock      - clock vector [y mo d h mi s] the event was raised
%   Stamp      - 'HH:mm:ss.SSS' rendering of Clock, formatted once and shared
%                by every sink
%   Level      - verbosity level, always a scalar double (see granary.Level)
%   Red        - true to route console output to stderr
%   Text       - fully formatted message, no trailing newline
%   Caller     - name of the function that called granary.printf
%   Line       - line number within that function
%   File       - full path of that function's file
%   Identifier - error identifier when the event came from an exception
%   Stack      - exception stack, empty struct otherwise
%
% See also: granary.Logger, granary.sink.Sink, granary.stamp

% double(): an granary.Level is an int32 enumeration, which isnumeric rejects.
if isscalar(level) && (isnumeric(level) || isa(level,'granary.Level'))
    level = double(level);
else
    level = 0;
end

rec.Clock      = c;
rec.Stamp      = stamp;
rec.Level      = level;
rec.Red        = red;
rec.Text       = text;
rec.Caller     = caller;
rec.Line       = line;
rec.File       = file;
rec.Identifier = '';
rec.Stack      = struct('file',{},'name',{},'line',{});
end
