function [url, trimmedLines] = url(f, tracker, opts)
% url = granary.report.url(fields, tracker)
% [url, trimmedLines] = granary.report.url(fields, tracker, MaxLength=n)
% Build the prefilled URL of a repository's bug-report issue form.
%
% GitHub's issue forms are prefilled by query parameters named for the field
% ids in the template (see granary.report.Tracker), so a report travels as TEXT
% IN A URL: nothing is uploaded, no credentials are needed, and equally, no
% file can be attached this way and the whole report must fit in a request
% line. Over-long URLs are answered with 414, so the log excerpt is trimmed
% from its START -- the end of a log is the part describing the failure --
% until it fits, and the caller is left to offer the rest by another route.
%
% Parameters:
%   fields    - Struct from granary.report.fields; only .environment and .logs
%               are read, so a caller may pass text the operator has edited.
%   tracker   - granary.report.Tracker naming the repository and field ids.
%   MaxLength - Character budget for the whole URL (default 6000).
%               Conservative: GitHub itself accepts more, but proxies and the
%               shell hand-off in web() are the narrower limits.
%
% Returns:
%   url          - Full https URL to open in a browser.
%   trimmedLines - Lines dropped from the head of the excerpt to fit; 0 when
%                  the whole excerpt survived.
%
% Both sections are wrapped in a fenced code block here rather than by the
% caller, so what an operator reviews in a preview is the text itself.
%
% See also: granary.report.fields, granary.report.Tracker

arguments
    f       (1,1) struct
    tracker (1,1) granary.report.Tracker
    opts.MaxLength (1,1) double {mustBeInteger, mustBePositive} = 6000
end

base = tracker.NewIssueURL;
if ~isempty(tracker.Template)
    base = [base '?template=' localEncode(tracker.Template)];
end

envText = char(string(f.environment));
logText = char(string(f.logs));

trimmedLines = 0;
if isempty(strtrim(logText))
    url = localAssemble(base, tracker, envText, '');
    return
end

logLines = splitlines(string(logText));
url = localAssemble(base, tracker, envText, localFence(char(join(logLines, newline))));

% Drop a tenth of what remains per pass: one line at a time is thousands of
% encode calls on a long log, and the exact cut point does not matter.
while numel(url) > opts.MaxLength && numel(logLines) > 1
    drop = max(1, floor(numel(logLines)/10));
    logLines(1:drop) = [];
    trimmedLines = trimmedLines + drop;
    marker = sprintf('[... %d earlier line(s) omitted so the report fits in a URL ...]', trimmedLines);
    url = localAssemble(base, tracker, envText, localFence(char(join([string(marker); logLines], newline))));
end

% Nothing left to drop but still too long: the environment block alone is over
% budget, which means something very large was pasted into it. Send it without
% the log rather than send a URL the server will refuse.
if numel(url) > opts.MaxLength
    trimmedLines = trimmedLines + numel(logLines);
    url = localAssemble(base, tracker, envText, '');
end
end


% -----------------------------------------------------------------------
function u = localAssemble(base, tracker, envText, fencedLog)
% Join the query parameters, omitting an empty section entirely so the form
% shows its own placeholder instead of an empty code fence.
u = base;
sep = '&';
if ~contains(base,'?'), sep = '?'; end

if ~isempty(strtrim(envText)) && ~isempty(tracker.EnvironmentField)
    u = [u sep tracker.EnvironmentField '=' localEncode(localFence(envText))];
    sep = '&';
end
if ~isempty(fencedLog) && ~isempty(tracker.LogsField)
    u = [u sep tracker.LogsField '=' localEncode(fencedLog)];
end
end


% -----------------------------------------------------------------------
function s = localFence(text)
% Wrap in a plain code fence. The form's textareas are unrendered on purpose:
% a log line's backslashes and underscores would otherwise be read as markdown.
s = sprintf('```text\n%s\n```', text);
end


% -----------------------------------------------------------------------
function out = localEncode(txt)
% Percent-encode one query-parameter value, keeping the RFC 3986 unreserved
% set. Written here rather than reaching for urlencode, which maps a space to
% '+': correct inside a form body, but ambiguous in an issue body where a
% literal '+' is ordinary text.
bytes = double(unicode2native(char(txt),'UTF-8'));

persistent unreserved
if isempty(unreserved)
    unreserved = false(1,256);
    unreserved(double(['A':'Z' 'a':'z' '0':'9' '-' '_' '.' '~']) + 1) = true;
end

parts = cell(1,numel(bytes));
for k = 1:numel(bytes)
    b = bytes(k);
    if unreserved(b+1)
        parts{k} = char(b);
    else
        parts{k} = sprintf('%%%02X',b);
    end
end
out = [parts{:}];
end
