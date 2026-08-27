# granary

A verbosity-gated logging package for MATLAB, and the headless core of a
"report this bug" flow that attaches the log to a prefilled issue form.

Named for the acorn woodpecker (*Melanerpes formicivorus*), which caches acorns
in a **granary**: a storage tree drilled with thousands of holes, one acorn per
hole, reused year after year and maintained by the whole group. That is what a
log is — many small records appended to one durable store, kept because someone
will need them later. The metaphor even covers rotation: as acorns dry out, the
birds move them to smaller holes.

*(The species epithet `formicivorus`, "ant-eating", is a famous misnomer — the
bird lives on acorns. The behavior, not the binomial, is what the name draws
on.)*

## What it is

Two halves that belong together:

- **Logging** — one session logger, a severity level per message, and pluggable
  sinks (console, daily text file, optional JSON Lines). The console and the
  file are filtered **separately**, so turning the command window quiet does not
  throw away the record that explains a failure.
- **Reporting** — `granary.report` takes the tail of the current log and builds
  a prefilled issue-form URL. Nothing is uploaded and no credentials are
  involved: the report travels as text in a link, which the host opens in a
  browser after the operator has reviewed it.

`granary` is **headless**. It contains no UI and claims no unqualified names on
the MATLAB path, so it drops into an existing program without colliding with it.
The preview dialog, the menu item and the host's own front-door function all
stay in the application.

## Install

Put the repository root on the MATLAB path:

```matlab
addpath('C:\src\granary')
```

The package is `+granary`, so everything is reached as `granary.*`.

## Quick start

```matlab
granary.printf(1,'Starting %s', name)          % info
granary.printf(0,1,'Could not reach the pump') % critical, red
granary.printf(4,'raw = %s', mat2str(v))       % trace: logged, not shown

try
    ...
catch ME
    granary.printf(0,1,ME);                    % one record, attributed to here
end
```

Two globals gate output, and they are independent:

| Global | Controls | Default |
|---|---|---|
| `GVerbosity` | command window | `1` |
| `GLogVerbosity` | log file | `Inf` (log everything) |

Levels: `-1` log only, `0` critical, `1` info, `2` debug, `3` verbose, `4` trace.
`granary.Level` gives them names.

## Configuring a host

A library cannot discover where its host lives, which preferences belong to it,
or what wraps it. Tell it once, at startup:

```matlab
granary.config( ...
    'LogRoot',     myAppRoot, ...      % logs land with the app, not in tempdir
    'PrefGroup',   'myapp', ...        % this app's own log-directory override
    'FacadeFiles', {'mylog.m'});       % see below
granary.Logger.instance('-reset');     % rebuild against the new settings
```

**`FacadeFiles` is the one that bites.** If your application wraps
`granary.printf` in a front door of its own, that wrapper sits between the call
site and the logger — and `granary.callerFrame` would then report the wrapper,
at one fixed line, as the origin of every message in the log. Naming the file
here restores the attribution the log exists for. The same applies to any bridge
forwarding a third-party library's messages in.

## Where logs go

1. The operator's override, `getpref(<PrefGroup>,'LogDir')`, set through
   `granary.setLogDir` or whatever settings UI the host puts in front of it.
2. Otherwise `<LogRoot>/<LogDirName>`, by default `<tempdir>/.error_logs`.

Files are `error_log_<ddmmmyyyy>.txt`, one per day. The name is part of the
contract: anything offering to open "the current log" rebuilds it.
`granary.Logger.instance().LogFile` names the current file — call `flush()`
first if something is about to read it.

## Reporting an issue

```matlab
T = granary.report.Tracker('https://github.com/owner/repo', ...
                           Template='bug_report.yml');

f = granary.report.fields(Environment=granary.report.environment());
[url,dropped] = granary.report.url(f,T);

web(url,'-browser')
```

`fields` flushes the logger and takes the **tail** of the log — the end is the
part describing the failure. `url` fences both sections and trims the excerpt
from its *start* until the whole thing fits in a request line, reporting how
many lines it dropped so the caller can offer the rest another way (the
clipboard, or revealing the file to drag onto the issue).

The environment block is the host's to build, because only the application
knows what about its own state is worth reporting. `granary.report.environment`
is a convenience for hosts that have nothing of their own; it reports MATLAB
version, platform, host, memory and toolboxes, and appends any extra rows given
to it.

Prefill works by query parameters named for the field ids in the repository's
`.github/ISSUE_TEMPLATE/<template>` file — see `templates/` for reference copies,
and `granary.report.Tracker` for the field names.

**A log routinely contains file paths, user names and data that should not be
published.** A tracker is usually public. Show the operator the text and let
them edit it before anything opens.

## Layout

```
+granary/
  printf.m  isEnabled.m  config.m  Level.m
  format.m  formatException.m  callerFrame.m  record.m  stamp.m  dateTag.m
  builtinLogDir.m  defaultLogDir.m  setLogDir.m  isAbsolutePath.m
  @Logger/
  +sink/     Sink  Console  FileSink  TextFile  JsonLines
  +report/   fields.m  url.m  Tracker.m  environment.m
```

Nothing in the package throws — callers log from inside catch blocks, and an
exception raised while reporting an exception destroys the report. The two
exceptions are deliberate: `granary.setLogDir` and `granary.config` are
configuration, and a rejected setting must be visible to whoever typed it.

## Origin

Extracted from [EPsych v2](https://github.com/dstolz/epsych2), where it was the
`eplog` package. Some comments still explain a decision by reference to the
problem it originally fixed; that history is the reason the code is shaped the
way it is.

## License

GNU GPL v3.0. See `LICENSE`.
