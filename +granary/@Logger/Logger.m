classdef Logger < handle
% granary.Logger  Session-wide log dispatcher.
%
% Owns the list of sinks and turns a call into a log record (see granary.record).
% There is one logger per MATLAB session, reached through
% granary.Logger.instance().
%
% Verbosity filtering is NOT done here -- granary.isEnabled gates before a
% logger is even fetched, so a message no destination wants costs a global read
% and a comparison and nothing else. That gate answers for the session as a
% whole; the console and the file have separate levels (GVerbosity and
% GLogVerbosity), so each sink applies its own in accepts().
%
% Nothing in this class is allowed to throw. Logging routinely runs inside
% catch blocks, and an exception raised while reporting an exception replaces
% the failure the operator actually needed to see.
%
% Properties:
%   Enabled - master switch (default true)
%   Sinks   - cell array of granary.sink.Sink
%   LogFile - path of the first file sink's current file (read-only)
%
% Methods:
%   instance()                 - (Static) the session logger
%   emit(level,red,msg,args)   - format and dispatch one message
%   log(rec)                   - dispatch an already-built record
%   flush() / close()          - durability and teardown
%   addSink(s) / removeSink(s) - reconfigure destinations
%   sinkOfType(cls)            - first sink of a given class, or empty
%
% Example:
%   L = granary.Logger.instance();
%   L.addSink(granary.sink.JsonLines());   % structured log alongside the text one
%   disp(L.LogFile)
%
% See also: granary.printf, granary.isEnabled, granary.sink.Sink, granary.record

    properties
        Enabled (1,1) logical = true
    end

    properties (SetAccess = protected)
        Sinks (1,:) cell = {}
    end

    properties (Dependent, SetAccess = private)
        LogFile
    end

    methods (Static)
        function L = instance(cmd)
            % L = granary.Logger.instance()
            % L = granary.Logger.instance('-reset')   discard and rebuild
            persistent theLogger

            if nargin > 0 && (ischar(cmd) || isstring(cmd)) && strcmp(cmd,'-reset')
                if ~isempty(theLogger) && isvalid(theLogger)
                    theLogger.close();
                    delete(theLogger);
                end
                theLogger = [];
            end

            if isempty(theLogger) || ~isvalid(theLogger)
                theLogger = granary.Logger();
            end

            L = theLogger;
        end
    end

    methods
        function obj = Logger(sinks)
            % obj = granary.Logger()        console + daily text file
            % obj = granary.Logger(sinks)   cell array of granary.sink.Sink
            if nargin < 1 || isempty(sinks)
                sinks = {granary.sink.Console(), granary.sink.TextFile()};
            end
            obj.Sinks = sinks;
        end

        function emit(obj,level,red,msg,args)
            % emit(obj,level,red,msg,args)
            % Build one record from a granary.printf-style call and dispatch it.
            if ~obj.Enabled, return; end
            if nargin < 5, args = {}; end

            try
                % clock, not datetime('now'): the Code Analyzer prefers
                % datetime, but rendering one to 'HH:mm:ss.SSS' costs ~275 us
                % against ~1 us for granary.stamp on a clock vector, and this
                % runs on every emitted message. See granary.stamp.
                c = clock;

                if isa(msg,'MException') || (isstruct(msg) && isfield(msg,'message'))
                    [txt,ident,stk] = granary.formatException(msg);
                else
                    txt   = granary.format(msg,args);
                    ident = '';
                    stk   = struct('file',{},'name',{},'line',{});
                end

                [nm,ln,fl] = granary.callerFrame();

                rec = granary.record(c,granary.stamp(c),level,red,txt,nm,ln,fl);
                rec.Identifier = ident;
                rec.Stack      = stk;

                obj.log(rec);
            catch emitErr
                % Last resort: say so on stderr and carry on.
                fprintf(2,'granary: dropped a log message (%s)\n',emitErr.message);
            end
        end

        function log(obj,rec)
            % log(obj,rec)  Dispatch a record to every sink.
            for k = 1:numel(obj.Sinks)
                try
                    obj.Sinks{k}.write(rec);
                catch sinkErr
                    % One broken sink must not stop the others, and must not
                    % propagate into the caller's catch block.
                    fprintf(2,'granary: sink %s failed: %s\n', ...
                        class(obj.Sinks{k}),sinkErr.message);
                end
            end
        end

        function flush(obj)
            for k = 1:numel(obj.Sinks)
                try
                    obj.Sinks{k}.flush();
                catch
                    % nothing useful to do while flushing
                end
            end
        end

        function close(obj)
            for k = 1:numel(obj.Sinks)
                try
                    obj.Sinks{k}.close();
                catch
                    % nothing useful to do while closing
                end
            end
        end

        function addSink(obj,s)
            arguments
                obj
                s (1,1) granary.sink.Sink
            end
            obj.Sinks{end+1} = s;
        end

        function removeSink(obj,s)
            keep = true(1,numel(obj.Sinks));
            for k = 1:numel(obj.Sinks)
                keep(k) = obj.Sinks{k} ~= s;
            end
            dropped = obj.Sinks(~keep);
            for k = 1:numel(dropped)
                try
                    dropped{k}.close();
                catch
                    % already closed
                end
            end
            obj.Sinks = obj.Sinks(keep);
        end

        function s = sinkOfType(obj,cls)
            % s = sinkOfType(obj,'granary.sink.TextFile')
            s = [];
            for k = 1:numel(obj.Sinks)
                if isa(obj.Sinks{k},cls)
                    s = obj.Sinks{k};
                    return
                end
            end
        end

        function p = get.LogFile(obj)
            % Where the next record will land, not where the last one went:
            % callers use this to open "the current log", which must name a
            % file even before anything has been written today.
            p = '';
            fs = obj.sinkOfType('granary.sink.FileSink');
            if ~isempty(fs)
                p = fs.expectedPath();
            end
        end

        function delete(obj)
            obj.close();
        end
    end
end
