# tmux active-tab highlight stall — investigation handoff

Status: **UNRESOLVED, DO NOT MERGE**. Last updated: 2026-10-20 JST.
Repository: `sawa2d2/dotfiles`
Working branch: `fix/tmux-live-active-tab-highlight`, created from `main` at `359fac77072e241ad586591f0873bf4ddce2884e`.
No pull request was opened. The user has NOT approved `gfinish`.
This note is intentionally committed on the working branch for a future maintainer or assistant with no access to the original chat.

## User-visible failure and scope

The custom tmux status bar shows 1–5 rows of windows. The active tab's colors stop tracking actual window selection for about eight seconds while authenticated IBM Bob Shell is running/initializing. Window switching still works; pane rendering continues (a counter printed every 0.1s keeps moving). When the delay ends, highlight catches up. Normal usage restores correct colors.

Reproduction confirmed **on a workplace Mac with iTerm2 and an authenticated Bob Shell**, typically beginning approximately **five seconds AFTER Bob startup**, not immediately upon launch. A home Mac with Bob not logged in (stuck before authentication) does NOT reproduce; Ubuntu also did not reproduce. Therefore do not treat a negative test on an unauthenticated/home machine as conclusive. iTerm restart and `tmux kill-server` did not fix the workplace issue.

Preferred reproduction sequence, executed outside tmux in iTerm2:

```sh
cd ~/dotfiles
git fetch origin
git switch fix/tmux-live-active-tab-highlight
git pull --ff-only
bash -n bin/tmux-bin/tmux-status-windows || exit 1
tmux kill-server
tmux -u new-session
```

Inside tmux, use the user's existing `tload` utility to restore the `tsave`d session, launch **authenticated Bob Shell afresh**, wait roughly five seconds and switch windows repeatedly. The user expressly permits killing all active tmux sessions for this experiment: snapshots are saved with `tsave`. Execute kill-server from an *outside-tmux* shell because it terminates tmux panes. No PR. Do not squash/merge unless explicitly approved, at which point suggest the local `gfinish -y -m "<message>"` command.

## Confirmed observations

- `bash ~/bin/tmux-bin/tmux-status-windows --sync` is near-instant in normal circumstances, but takes about **8.5 seconds wall-clock** in the failure window. File timestamp instrumentation recorded an approximately 8.5-second span, even when a shell `time` readout seemed misleading.
- During Bob startup, simple `tmux list-clients`, `tmux list-windows`, `tmux display-message -p '#{window_id}'`, and `tmux show-options -v status` each return immediately when invoked individually.
- The **outer** `--sync` invocation stalls around `rows=$("$0" --rows "$session" "$width")`. Time-stamped opt-in trace showed **8.458 s** between `rows_call_begin` and `rows_call_end` (an earlier version of the script). No other >=0.5 s gap was reported in that run. Important: not evidence that parsing itself takes 8.458 s; possible child-process completion/wait.
- Invoking `--rows` alone outside `--sync`, given the same session ID/width, returns immediately.
- Disabling only `after-select-window` via `tmux set-hook -gu after-select-window` did **not** eliminate the delay. Other hooks remained enabled. Restore normal hooks with `tmux source-file ~/.tmux.conf`.
- `ps` during the stall showed at least two concurrent `--sync` / `--rows` pairs with `S` (sleeping/waiting) status. Cause of the waiting and whether concurrent invocations are causal are **not proven**.
- The first attempt to avoid outer command substitution (temporary file for `--rows` output) did **not** eliminate the delay: still `rows_call_begin -> rows_call_end`.
- A second change avoided the inner process substitution `done < <(tmux list-windows ...)` in `--rows`. **This latter change has NOT been tested on the authenticated workplace Mac.** Home Mac cannot reproduce.

## Branch history / current changes

The branch was originally intended to resolve focus colors dynamically in tmux format evaluation. **Both attempts failed**: one permanently removed active highlighting, the other removed the tab bar. These format changes were **reverted**. Do not assume the format approach works without an isolated tmux format test.

Subsequently added opt-in trace instrumentation in `bin/tmux-bin/tmux-status-windows` and changed two output transports:

1. In `--sync`, `--rows` output now goes to a `mktemp` file instead of `rows=$("$0" ...)`.
2. In `--rows`, `tmux list-windows` output now goes to a `mktemp` file, read with `done < "$rows_input"` instead of process substitution.
3. `TMUX_STATUS_TRACE_FILE` enables `_trace_event`: timestamp via Perl `Time::HiRes`, PID/PPID/event, appended to a file. No full window/command names in the structured trace. The instrumentation itself invokes Perl for each event and may affect timing; always compare trace-disabled behavior too.

**These are experiments, not accepted fixes.** Review and likely revert unsuccessful tmpfile changes and instrumentation before finalizing a fix. There are no intentional changes to `home/.tmux.conf` on the branch; the `main` tmux config has many `run-shell -b "... --sync"` hooks. Status row strings are stored in `@tmux_window_row0` through `@tmux_window_row4`, and the focus style is precomputed, not automatically re-evaluated on redraw.

One instrumentation update accidentally corrupted Bash syntax and generated `--sync returned 2` errors. It was replaced with a fresh version in commit `0a37b40`. **Before any restart/test, always run `bash -n bin/tmux-bin/tmux-status-windows` and stop if nonzero.** Branch has not been runtime-tested here on macOS.

## Recommended next investigation

**Avoid another sequence of speculative changes.** On authenticated workplace Mac, obtain a *single* paired trace from parent `--sync` and its `--rows` child in the same failure interval, preferably adding an explicit trace marker before/after `tmux list-windows`, process exit, and parent wait. Need determine whether (a) command execution is actually blocked, (b) stdout/stderr file descriptor ownership causes the parent to wait for EOF, (c) multiple background `--sync` instances/process substitution leak or interfere, or (d) Bob environment/processes interfere with this setup. The current trace uses PID and can associate outer `rows_call_begin` with inner `rows_start` / `rows_list_done` / `rows_parse_done` / `rows_end`; the previous report included only one delayed parent interval, but the complete event order was not investigated.

To generate a trace while the focus is stuck:

```sh
rm -f /tmp/tmux-status-trace.log
TMUX_STATUS_TRACE_FILE=/tmp/tmux-status-trace.log \
  bash ~/bin/tmux-bin/tmux-status-windows --sync
```

Use this sanitizer/summarizer; it prints only elapsed seconds and event names, not workspace/session/window names:

```sh
python3 - <<'PY'
from collections import defaultdict
events = defaultdict(list)
with open('/tmp/tmux-status-trace.log') as f:
    for line in f:
        parts = line.split()
        if not parts:
            continue
        fields = dict(item.split('=', 1) for item in parts[1:])
        events[fields['pid']].append((float(parts[0]), fields['event']))
for pid, records in events.items():
    for (start, a), (end, b) in zip(records, records[1:]):
        if end - start >= 0.5:
            print(f'{end-start:.3f}s: {a} -> {b}')
PY
```

Inspect full trace locally if necessary; raw debug outputs from `ps -axo ... command` and shell traces can contain sensitive workplace paths or window titles. The user prefers to share only redacted results.

Look closely at Bash process substitution and asynchronous `run-shell -b` hooks. The stall occurring **~5s into authenticated Bob startup** raises the possibility of a Bob-specific child process, resource contention or inherited descriptor, but no cause has been proven. Avoid incorrectly asserting that Bob, Bash, tmux, or iTerm2 is definitely at fault.

## Communication and working agreements

Japanese, concise plain style (常体). User fatigued after many manual iterative tests. Minimize test cycles; add robust and automated verification to branch before requesting workplace testing. Must create a branch for new work; currently use existing unfinished branch. No PR without request. User manually `tsave`s and `tload`s. Before proposing more fixes, clearly state hypotheses and pass/fail criteria. On explicit `approved`, provide the command `gfinish -y -m "<commit-message>"` for user to run after fetching/switching the branch. Do **not** merge now.
