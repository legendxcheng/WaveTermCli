# Development Plan: External Workspace Switch via CLI (Single-Instance)

## Summary
Add a `wave.exe --switch-workspace "<name>"` entrypoint that can be called from external scripts to switch (or create) a workspace by name. The implementation uses Electron single-instance forwarding and existing window/workspace logic to minimize changes.

## Confirmed Decisions
- Workspace name matching is case-insensitive.
- Force switch: bypass the "unsaved workspace opens in new window" behavior for CLI-triggered switches.
- Non-zero exit code on errors (best-effort; see "Exit Code Behavior").

## Scope
- CLI parameter parsing in the Electron main process.
- Single-instance forwarding via `second-instance` event.
- Resolve workspace by name (case-insensitive) using existing workspace list RPC.
- Create workspace if missing and switch to it.
- Force the switch to avoid new-window diversion.
- Set exit code to non-zero for detectable errors in the invoking process.

## Out of Scope
- New IPC channel (Named Pipe) or external server.
- Multi-instance orchestration.
- UI or toast changes unless required for error visibility.

## Implementation Approach (High Level)
1. Parse `--switch-workspace` (and optionally `-s`) from `process.argv` in the main process.
2. On second instance, forward the request to the primary instance using `app.on("second-instance")` and exit.
3. On primary instance, queue the request until WSH RPC and windows are ready, then execute the switch.
4. Resolve workspace by name (case-insensitive); if not found, create it with defaults.
5. Force switch on a target window (focused window preferred).
6. Handle errors with logs and non-zero exit codes where possible.

## Detailed Checklist

### 1) Add argument parsing (main process)
- Implement a small parser for `--switch-workspace <name>` and `--switch-workspace="<name>"`.
- Validate that the name is non-empty after trimming.
- Location: `waveterm/emain/emain.ts`.

### 2) Single-instance forwarding
- Register `app.on("second-instance")` to receive argv from the second instance.
- Parse argv; if invalid, exit the second instance with code 1.
- If valid, send the request to the primary instance handler (in-memory queue).
- Location: `waveterm/emain/emain.ts`.

### 3) Startup request queue
- Maintain a queue (or a single pending request) for `switch-workspace` requests.
- Drain after WSH RPC is initialized and windows are reloaded (`relaunchBrowserWindows` complete).
- Ensure this runs both for first-start and for `second-instance` events.
- Location: `waveterm/emain/emain.ts`.

### 4) Resolve workspace by name
- Call `RpcApi.WorkspaceListCommand(ElectronWshClient)` to get `WorkspaceData` including name.
- Normalize names to lowercase for comparison.
- If multiple matches (same name ignoring case), treat as error.
- If no match, call `WorkspaceService.CreateWorkspace(name, "", "", true)`.
- Location: `waveterm/emain/emain-menu.ts` (reference), new helper in `waveterm/emain/*`.

### 5) Force switch behavior
- Ensure CLI uses a force path that does NOT open a new window when the current workspace is "unsaved".
- Option A: extend `WaveBrowserWindow.switchWorkspace` to accept `{ force: true }` and bypass the unsaved check.
- Option B: add a dedicated method used only by external switch requests.
- Still use the action queue so the tab view is rebuilt correctly.
- Location: `waveterm/emain/emain-window.ts`.

### 6) Target window selection
- Prefer `focusedWaveWindow` if available.
- Else use the first window in `getAllWaveWindows()`.
- If no windows exist, create one and then perform the switch.
- Location: `waveterm/emain/emain-window.ts` and/or `waveterm/emain/emain.ts`.

### 7) Exit code behavior
- If argv invalid in the invoking process, exit code = 1.
- If forwarding fails (no primary instance / app not ready), exit code = 1.
- If switching fails in the primary instance, log the error; exit code is best-effort for the invoking process (cannot always be propagated from the primary).
- Location: `waveterm/emain/emain.ts`.

## Validation Checklist
1. With Wave running, `wave.exe --switch-workspace "WorkA"` switches to WorkA.
2. If WorkA does not exist, it is created and switched to.
3. Case-insensitive matching works (e.g., `worka` matches `WorkA`).
4. For a workspace with unsaved content, CLI switch still switches in the same window (no new window).
5. Invalid argv (missing name) exits with non-zero code.

## Risks and Mitigations
- **Switch fails because UI not ready**: queue requests until after WSH RPC and windows are initialized.
- **Duplicate names ignoring case**: treat as error and return non-zero exit code in the invoking process.
- **Exit code propagation**: best-effort; document that only parse/dispatch errors are guaranteed in the invoking process.

## Upstream Update Strategy (Rebase)
Use a dedicated `custom` branch that rebases onto upstream to keep history linear and reduce merge noise.

1. Add upstream (one-time):
   - `git remote add upstream <WaveTerm repo URL>`
2. Update and rebase:
   - `git fetch upstream`
   - `git checkout custom`
   - `git rebase upstream/main`
3. Resolve conflicts, then run build/test as needed.

## Files Expected to Change
- `waveterm/emain/emain.ts`
- `waveterm/emain/emain-window.ts`
- (New helper file if needed under `waveterm/emain/`)

## Notes
- This plan intentionally avoids Named Pipes to minimize change scope while still meeting the core requirement.
