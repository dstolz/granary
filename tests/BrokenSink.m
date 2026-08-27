classdef BrokenSink < granary.sink.Sink
% BrokenSink  A sink that always throws.
%
% Used by smoke_test_logging to prove that a failing destination is contained by
% granary.Logger and never propagates into the caller -- which matters because
% callers log from inside catch blocks.

    methods
        function write(~,~)
            error('granary:smoke:brokenSink','this sink always fails');
        end
    end
end
