# CCost

## Build, Kill, Relaunch

From the `app/` directory:

```sh
./build.sh 2>&1 && pkill -x CCostBar; sleep 0.5; open .build/release/CCostBar.app
```

This builds the release app bundle, kills any running instance, and relaunches it.
