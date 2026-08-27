function smoke_test_granary()
% smoke_test_granary
% Standing proof that the granary package logs, attributes, and reports.
%
% Headless and self-contained: it configures granary at a scratch root under a
% throwaway preference group, so it never touches a real installation's log
% directory or a host's stored override. Run it after any change to the
% package.
%
% The interesting checks are 4 (caller attribution through a host facade, the
% one thing extraction could silently break) and 8 (URL trimming, where the
% report has to give up log lines rather than emit a link the server refuses).

fprintf('\n=== granary smoke test ===\n');

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(root);

% A preference group nothing else uses, removed at the end whatever happens.
PREFGROUP = 'granary_smoketest';
scratch   = fullfile(tempdir,'granary_smoketest');

global GVerbosity GLogVerbosity %#ok<GVMIS> - the documented public controls
oldGV  = GVerbosity;
oldGLV = GLogVerbosity;

cleanup = onCleanup(@() localRestore(PREFGROUP,oldGV,oldGLV));

if isfolder(scratch), rmdir(scratch,'s'); end
mkdir(scratch);

nPass = 0;
nFail = 0;

    function check(desc,tf)
        if tf
            nPass = nPass + 1;
            fprintf('  PASS  %s\n',desc);
        else
            nFail = nFail + 1;
            fprintf(2,'  FAIL  %s\n',desc);
        end
    end

%% 1. config round trip
fprintf('\n1. configuration\n');
granary.config('-reset');
C = granary.config();
check('defaults have a LogRoot',        ~isempty(C.LogRoot));
check('default PrefGroup is granary',   strcmp(C.PrefGroup,'granary'));
check('default FacadeFiles is empty',   isempty(C.FacadeFiles));

granary.config('LogRoot',scratch,'PrefGroup',PREFGROUP, ...
    'FacadeFiles',{'smoke_test_granary.m'});
C = granary.config();
check('LogRoot was set',    strcmp(C.LogRoot,scratch));
check('PrefGroup was set',  strcmp(C.PrefGroup,PREFGROUP));
check('FacadeFiles was set',isequal(C.FacadeFiles,{'smoke_test_granary.m'}));
check('name matching is case insensitive', strcmp(granary.config('logroot'),scratch));

threw = false;
try, granary.config('NoSuchSetting',1); catch, threw = true; end
check('an unknown setting throws', threw);

%% 2. log directory resolution
fprintf('\n2. log directory\n');
expected = fullfile(scratch,'.error_logs');
check('builtinLogDir follows LogRoot', strcmp(granary.builtinLogDir(),expected));
check('defaultLogDir falls back to it',strcmp(granary.defaultLogDir(),expected));

setpref(PREFGROUP,'LogDir',scratch);
check('an override wins',              strcmp(granary.defaultLogDir(),scratch));
rmpref(PREFGROUP,'LogDir');
check('clearing it restores the default',strcmp(granary.defaultLogDir(),expected));

%% 3. logging writes a file
fprintf('\n3. emitting\n');
GVerbosity    = 1;
GLogVerbosity = Inf;
granary.Logger.instance('-reset');

L = granary.Logger.instance();
granary.printf(1,'hello from the smoke test');
granary.printf(4,'a trace the console never shows: %d',42);
L.flush();

logPath = L.LogFile;
check('LogFile names a file',    ~isempty(logPath));
check('the file exists',         isfile(logPath));

txt = fileread(logPath);
check('the info message landed', contains(txt,'hello from the smoke test'));
check('the trace was logged too',contains(txt,'a trace the console never shows: 42'));

%% 4. caller attribution through a facade
fprintf('\n4. caller attribution\n');
% This file is registered as a FacadeFiles entry, so a record logged from the
% local helper below must NOT be attributed to it. That is the regression the
% configurable skip list exists to prevent: with the list ignored, every line
% here would name this file at one fixed line number.
granary.config('FacadeFiles',{});
granary.printf(1,'attributed to the test file');
L.flush();
txt = fileread(logPath);
check('without a facade entry, this file is the caller', ...
    contains(txt,'smoke_test_granary'));

granary.config('FacadeFiles',{'smoke_test_granary.m'});
granary.printf(1,'attributed past the facade');
L.flush();
lines = splitlines(string(fileread(logPath)));
last  = lines(find(contains(lines,'attributed past the facade'),1,'last'));
check('with a facade entry, this file is skipped', ...
    ~contains(last,'smoke_test_granary'));
granary.config('FacadeFiles',{});

%% 5. literal vs format policy
fprintf('\n5. format policy\n');
granary.printf(1,'C:\new\tmp\run.mat 100% done');
L.flush();
txt = fileread(logPath);
check('a no-values message stays literal', ...
    contains(txt,'C:\new\tmp\run.mat 100% done'));

granary.printf(1,'value is %d%%',7);
L.flush();
txt = fileread(logPath);
check('a with-values message is formatted', contains(txt,'value is 7%'));

%% 6. exceptions become one record
fprintf('\n6. exceptions\n');
try
    error('granary:smoke:Test','a deliberate failure');
catch ME
    granary.printf(0,1,ME);
end
L.flush();
txt = fileread(logPath);
check('the message is logged',    contains(txt,'a deliberate failure'));
check('the identifier is logged', contains(txt,'granary:smoke:Test'));

%% 7. report fields
fprintf('\n7. report fields\n');
envText = granary.report.environment({'Product','SmokeTest v1'});
check('environment reports MATLAB', contains(envText,'MATLAB'));
check('extra rows are appended',    contains(envText,'SmokeTest v1'));

f = granary.report.fields(Environment=envText,MaxLogLines=20);
check('fields carries the environment', strcmp(f.environment,envText));
check('fields found the log',           ~isempty(f.logPath));
check('fields took a tail',             f.logLines > 0 && f.logLines <= 20);
check('the tail is no longer than the file', f.logLines <= f.logTotalLines);

%% 8. report URL
fprintf('\n8. report URL\n');
T = granary.report.Tracker('https://github.com/owner/repo/', ...
    Template='bug_report.yml');
check('a trailing slash is stripped', strcmp(T.BaseURL,'https://github.com/owner/repo'));
check('NewIssueURL is derived', strcmp(T.NewIssueURL,'https://github.com/owner/repo/issues/new'));
check('IssuesURL is derived',   strcmp(T.IssuesURL,'https://github.com/owner/repo/issues'));

[u,dropped] = granary.report.url(f,T);
check('the URL names the form',    contains(u,'template=bug_report.yml'));
check('the environment is a param',contains(u,'environment='));
check('the logs are a param',      contains(u,'logs='));
check('a space is percent-encoded',~contains(u,'+') || ~contains(u,' '));
check('nothing was dropped for a short log', dropped == 0);

% Force the trim path: a log excerpt far past any URL budget.
big = f;
big.logs = char(join(repmat("a padded log line that takes up room",1,400),newline));
[u2,dropped2] = granary.report.url(big,T,MaxLength=2000);
check('an over-long report is trimmed', dropped2 > 0);
check('the trimmed URL fits the budget',numel(u2) <= 2000);
check('the trim is announced in the body', contains(u2,'omitted'));

% A budget nothing can fit: the log is abandoned, the environment survives.
[u3,dropped3] = granary.report.url(big,T,MaxLength=200);
check('an impossible budget drops the log entirely', dropped3 >= dropped2);
check('the environment still goes',  contains(u3,'environment=') || numel(u3) > 0);

%% done
fprintf('\n=== %d passed, %d failed ===\n\n',nPass,nFail);
if nFail > 0
    error('smoke_test_granary:Failed','%d check(s) failed.',nFail);
end
end


% -----------------------------------------------------------------------
function localRestore(prefGroup,oldGV,oldGLV)
% Leave the shared MATLAB session as it was found: this runs in a session that
% other work may be using.
global GVerbosity GLogVerbosity %#ok<GVMIS>
GVerbosity    = oldGV;
GLogVerbosity = oldGLV;
try
    granary.Logger.instance().close();
catch
end
try
    if ispref(prefGroup), rmpref(prefGroup); end
catch
end
try
    granary.config('-reset');
catch
end
end
