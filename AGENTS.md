# AGENTS.md

## Build Policy

- Use `app/build.sh` for packaging and launch flow.
- Do not use `swift build` as the main user-facing rebuild/relaunch path.
- If quick compile validation is needed, `swift build` is optional, but final relaunch must still use `app/build.sh`.

## Kill, Rebuild, Relaunch

From repo root:

```bash
pkill -f CCostBar || true
cd /Users/brennan/code/ccost/app
./build.sh
open /Users/brennan/code/ccost/app/.build/release/CCostBar.app
pgrep -fl CCostBar
```

## Notes

- The app bundle used for manual launch is:
  `/Users/brennan/code/ccost/app/.build/release/CCostBar.app`
- Always relaunch this bundle after UI changes.
