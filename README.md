# Aiwa AI PONT Google TV tuning

Make an Aiwa AI PONT Google TV (board `alimos`, MediaTek mt5896, Android 14) faster and ad-free, **with an automatic rollback for every change**. Built after a first attempt with a launcher swap left the TV on a black screen with no way back.

What you get on the test set: a home screen with only your apps (no suggestions or ads), about 20% faster boot, 13–35% faster app starts, about 100 MB more free memory, and a working Settings button on the remote. See [docs/FINDINGS.md](docs/FINDINGS.md).

> **Use at your own risk.** Tested on one TV. Nothing is uninstalled for good: system apps are disabled or removed only for your user, and can be restored. Read [docs/FINDINGS.md](docs/FINDINGS.md) before you start, especially the Home-screen section.

## How it stays safe

Every change is one small transaction:

1. `snapshot.sh` saves the TV's package states, HOME app and settings to your Mac.
2. `deadman.sh arm 5 <snapshot>` starts a 5-minute timer on your Mac.
3. You make one change and test it on the TV.
4. `deadman.sh confirm` keeps it. If you don't confirm in time, the timer runs `restore.sh` and puts the TV back. If the TV is unreachable at the deadline, it keeps retrying.

`check.sh` compares the TV with `config/` after any restart and lists anything that came back.

## Requirements

- macOS (the timer uses launchd; the scripts themselves are plain `sh`).
- [Android platform-tools](https://developer.android.com/tools/releases/platform-tools) (`adb`).
- On the TV: Settings → System → About → press **Build** 7 times → Developer options → **USB debugging** and **Wireless debugging** on.
- A fixed IP address for the TV on your router.

## Quick start

```sh
export TV_IP=192.168.1.50                      # your TV's address
TV_PORT=<port shown under Wireless debugging> sh scripts/connect.sh
sh scripts/install-timer.sh                    # once
sh scripts/check.sh                            # see what differs from config/
```

One change, the safe way (the runtime copy lives in `~/.android-tv-tuning/runtime`):

```sh
R=~/.android-tv-tuning/runtime
SNAP=$(sh $R/snapshot.sh before-change) && sh $R/deadman.sh arm 5 "$SNAP"
adb -s $TV_IP:<port> shell pm disable-user --user 0 com.homwee.store
# test on the TV, then:
sh $R/deadman.sh confirm
```

Work through `config/desired-disabled.txt` a few packages at a time, then `config/desired-uninstalled.txt`. Comment out anything you use.

## Replacing the home screen

The ad-free home screen is [CleanYourTV](https://github.com/Gathin23/cleanyourtv) (MIT). Build it from source, apply `patches/cleanyourtv-settings-key-240.patch` for this remote's gear button, and install it. Then, in **one guarded window**, with CleanYourTV holding the HOME role, disable `com.google.android.apps.tv.launcherx` and `com.google.android.tungsten.setupwraith` together. Check the setup app's saved Wi-Fi networks first. [docs/FINDINGS.md](docs/FINDINGS.md) explains why.

## After every restart

Wireless debugging turns itself off. Turn it on from Settings (CleanYourTV's Settings button, or the remote's gear button with the patch), then run `sh scripts/check.sh`.

## Credits

- [CleanYourTV](https://github.com/Gathin23/cleanyourtv) by Gathin, MIT: the launcher and the setup-app guidance.
- [TV Detox](https://github.com/Ansub/tv-detox) by Ansub, MIT: the idea, and the failure that shaped the rollback design.

## License

MIT, see [LICENSE](LICENSE).
