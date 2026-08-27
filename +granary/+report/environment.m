function txt = environment(extraRows)
% txt = granary.report.environment()
% txt = granary.report.environment(rows)
% Build a generic environment block for a bug report.
%
% Reports what can be known about any MATLAB installation: version, release,
% platform, host, memory and installed toolboxes. This is a CONVENIENCE for
% hosts that have no introspection of their own -- an application that already
% knows its version, commit and session state should build its own block, or
% pass those rows in here to be appended, since the half a version string
% cannot give is usually the half that explains the report.
%
% Parameters:
%   rows - Optional N-by-2 cell or string array of label/value pairs appended
%          after the standard rows.
%
% Returns:
%   txt - char. Label-aligned block, one row per line, ready to be fenced.
%
% Every value is fetched inside its own try. This runs when something has
% already gone wrong, so a failing probe must cost one line of the report
% rather than the report.
%
% See also: granary.report.fields, granary.report.url

arguments
    extraRows = {}
end

rows = strings(0,2);

rows = localRow(rows,'MATLAB',   localTry(@() sprintf('%s (%s)',version,version('-release'))));
rows = localRow(rows,'Platform', localTry(@() computer));
rows = localRow(rows,'Host',     localTry(@localHostname));
rows = localRow(rows,'Memory',   localTry(@localMemory));
rows = localRow(rows,'Toolboxes',localTry(@localToolboxes));

if ~isempty(extraRows)
    e = string(extraRows);
    for i = 1:size(e,1)
        rows = localRow(rows,e(i,1),e(i,2));
    end
end

% Left-aligned key column so the block stays readable inside a code fence,
% where GitHub renders it in a monospaced font.
w = max(strlength(rows(:,1)));
txt = char(join(pad(rows(:,1), w) + " : " + rows(:,2), newline));
end


% -----------------------------------------------------------------------
function rows = localRow(rows,label,value)
% Append one label/value row, normalizing whatever the getter produced.
value = strtrim(string(value));
if isempty(value) || ismissing(value) || strlength(value) == 0
    value = "(none)";
end
rows(end+1,:) = [string(label) value];
end


% -----------------------------------------------------------------------
function v = localTry(fcn)
% Evaluate one report line, reporting failure in place of the value.
try
    v = fcn();
catch
    v = '(unavailable)';
end
end


% -----------------------------------------------------------------------
function s = localHostname()
% Environment variables rather than a shell call: this runs during a failure
% report, where spawning a process is the last thing wanted.
s = getenv('COMPUTERNAME');
if isempty(s), s = getenv('HOSTNAME'); end
end


% -----------------------------------------------------------------------
function s = localMemory()
% "memory" exists only on Windows, so elsewhere this row is simply absent
% rather than wrong.
if ~ispc
    s = '';
    return
end
m = memory;
s = sprintf('%.1f GB total, %.1f GB available', ...
    m.MemAvailableAllArrays/2^30, m.MaxPossibleArrayBytes/2^30);
end


% -----------------------------------------------------------------------
function s = localToolboxes()
v = ver;
s = strjoin(sort({v.Name}), ', ');
end
