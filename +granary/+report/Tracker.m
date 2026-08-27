classdef Tracker
% granary.report.Tracker  Where a bug report is filed, and under what field names.
%
% A value class naming the issue tracker a host reports to. It exists so
% granary.report.url can build a prefilled link without knowing anything about
% the application embedding it.
%
% GitHub issue FORMS are prefilled by query parameters named for the field ids
% in the repository's .github/ISSUE_TEMPLATE/<template> file, so the field
% names are part of the tracker's configuration rather than something this
% package can assume. The defaults match the conventional ids used by the
% reference templates shipped alongside this package.
%
% Properties:
%   BaseURL          - Repository URL, e.g. 'https://github.com/owner/repo'
%   Template         - Issue-form file name, e.g. 'bug_report.yml'. '' opens a
%                      plain issue with no form.
%   EnvironmentField - Query parameter for the environment block
%                      (default 'environment')
%   LogsField        - Query parameter for the log excerpt (default 'logs')
%
% Dependent:
%   NewIssueURL      - <BaseURL>/issues/new
%   IssuesURL        - <BaseURL>/issues, for the "report it here instead"
%                      fallback when a browser will not open
%
% Example:
%   T = granary.report.Tracker('https://github.com/owner/repo', ...
%                              Template='bug_report.yml');
%
% See also: granary.report.url, granary.report.fields

    properties
        BaseURL          (1,:) char = ''
        Template         (1,:) char = ''
        EnvironmentField (1,:) char = 'environment'
        LogsField        (1,:) char = 'logs'
    end

    properties (Dependent, SetAccess = private)
        NewIssueURL
        IssuesURL
    end

    methods
        function obj = Tracker(baseURL,opts)
            arguments
                baseURL {mustBeTextScalar} = ''
                opts.Template         {mustBeTextScalar} = ''
                opts.EnvironmentField {mustBeTextScalar} = 'environment'
                opts.LogsField        {mustBeTextScalar} = 'logs'
            end

            % Trailing separators are stripped once here rather than guarded
            % at each use, so '.../repo/' and '.../repo' cannot produce two
            % different URLs.
            b = char(string(baseURL));
            while ~isempty(b) && (b(end) == '/' || b(end) == '\')
                b(end) = [];
            end

            obj.BaseURL          = b;
            obj.Template         = char(string(opts.Template));
            obj.EnvironmentField = char(string(opts.EnvironmentField));
            obj.LogsField        = char(string(opts.LogsField));
        end

        function u = get.NewIssueURL(obj)
            u = '';
            if ~isempty(obj.BaseURL)
                u = [obj.BaseURL '/issues/new'];
            end
        end

        function u = get.IssuesURL(obj)
            u = '';
            if ~isempty(obj.BaseURL)
                u = [obj.BaseURL '/issues'];
            end
        end
    end
end
