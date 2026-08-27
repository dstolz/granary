classdef TextFile < granary.sink.FileSink
% granary.sink.TextFile  Daily human-readable log file.
%
% Writes one comma-delimited header per record, so a log stays greppable by
% time, by caller, and by line:
%
%   09:14:26.435,myapp_startup,80: MyApp version 2
%
% Multi-line records -- an exception with its stack -- keep the header line in
% that shape and indent their continuation lines, so one event stays visually
% one event instead of repeating the timestamp per stack frame.
%
% The filename shape is part of the contract rather than a private detail:
% anything offering to open "the current log" rebuilds the same name to find
% it, at <logdir>/error_log_<ddmmmyyyy>.txt.
%
% See also: granary.sink.FileSink, granary.sink.JsonLines

    methods
        function obj = TextFile(logDir)
            if nargin < 1, logDir = ''; end
            obj@granary.sink.FileSink(logDir);
        end
    end

    methods (Access = protected)
        function s = formatLine(~,rec)
            % Concatenation rather than sprintf: this runs on every message
            % and sprintf costs roughly 18 us here against 13 us for a concat.
            head = [rec.Stamp ',' rec.Caller ',' localInt(rec.Line) ': '];

            if contains(rec.Text,newline)
                parts = strsplit(rec.Text,newline);
                body  = strjoin([parts(1) strcat({'    '},parts(2:end))],newline);
                s = [head body newline];
            else
                s = [head rec.Text newline];
            end
        end

        function e = extension(~)
            e = '.txt';
        end
    end
end


function s = localInt(v)
% Line numbers are almost always small; skip sprintf for the common case.
if v >= 0 && v < 10
    s = char(48+v);
else
    s = sprintf('%d',v);
end
end
