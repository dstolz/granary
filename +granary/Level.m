classdef Level < int32
% granary.Level  Named verbosity levels.
%
% A Level may be passed anywhere a numeric level is accepted, since the
% enumeration derives from int32:
%
%   granary.printf(granary.Level.Debug, 'connected to %s', name)
%   double(granary.Level.Debug)   % 2
%
% Levels outside this set remain legal -- pass a plain number. Level 4 has a
% member here because per-iteration traces in a tight loop are common enough
% to deserve a name.
%
% See also: granary.printf, granary.Logger, granary.isEnabled

    enumeration
        LogOnly  (-1)   % written to the log only, never echoed to the console
        Critical ( 0)
        Info     ( 1)
        Debug    ( 2)
        Verbose  ( 3)
        Trace    ( 4)
    end

    methods (Static)
        function s = label(value)
            % s = granary.Level.label(value)
            % Short name for any numeric level, including levels with no
            % enumeration member. Never errors -- it is used while logging.
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                s = "L?";
                return
            end
            switch double(value)
                case -1, s = "LogOnly";
                case  0, s = "Critical";
                case  1, s = "Info";
                case  2, s = "Debug";
                case  3, s = "Verbose";
                case  4, s = "Trace";
                otherwise, s = "L" + string(double(value));
            end
        end
    end
end
