# What we learned on the Aiwa AI PONT

Tested on one set over two days in October 2026. These are observations from that TV, not guarantees for every unit.

## The device

- `ro.product.model` AI PONT, board `alimos`, MediaTek mt5896, Google TV on Android 14 (SDK 34), build UKN2.241219.067.
- About 1.74 GB RAM (MemTotal 1,827,452 kB) and 1 GB zram swap.
- CleanYourTV's existing `aiwa-ai-pont-sa` list is for a different board (`osaka`, mt5867, 2026 firmware). Don't apply it blindly to `alimos`.

## Home screen and launcher

- **Disabling Google TV Home on its own breaks Home.** HOME falls back to `com.google.android.tungsten.setupwraith/.RecoveryActivity`, a blank setup screen. After a restart, Wireless debugging is off, so there is no way back over ADB. This is how the first attempt (with TV Detox) left the TV on a black screen.
- `cmd package set-home-activity` reported success but did not change what Home opened. Third-party "set as default" settings inside other launchers didn't either.
- What worked: the replacement launcher (CleanYourTV) holds the HOME role, **then** Google TV Home and the setup app are disabled together. Home then resolves to CleanYourTV, and it survived restarts.
- **Before disabling the setup app**, check which saved Wi-Fi networks it created: `dumpsys wifi | grep -o 'cname=[^ ]*'`. Android deletes those networks when the app is disabled. On the test set the setup app owned only an old, unused network; the network the TV used was owned by the system (`android.uid.system`).
- Keep a Settings tile on the new home screen. It's the way back to Wireless debugging after a restart.

## Things that don't stick, and things that can't be done

- Netflix and Live TV (`com.mediatek.tv.oneworld.tvcenter`) came back **enabled after every restart** when only disabled. `pm uninstall -k --user 0` kept them off across restarts.
- Disabling one component of an app (for example YouTube's recommendations receiver) is refused: "Shell cannot change component state". It needs root.
- `cmd wifi force-country-code` is refused to the ADB shell.
- Packages marked PERSISTENT (ACR `tv.anoki.acr.controller`, `com.homwee.factory`, `com.mediatek.browservice`) were left alone; disabling them risks boot problems.

## Wi-Fi

- With the region set to Iran (IR), the TV's driver allows 5 GHz only on channels 149–165, while a router using IR rules allows 36–64. With no shared channel the TV stays on 2.4 GHz. Check yours with `dumpsys wifi | grep SupportedChannelListIn5g`.
- With the screen-off timer at 5 minutes, the TV cut its network shortly after the screen went off, which dropped ADB mid-change. Setting the timers to never (`screen_off_timeout`, `sleep_timeout`, `attentive_timeout`) fixed that.

## The remote

- The Bluetooth remote ("TVC0GWBT") sends the Settings/gear button as HID usage 0x0c009f, which Linux reports as `KEY_UNKNOWN` (scancode 240). Without Google TV Home it does nothing. Rebuilding CleanYourTV with `settings_key_scancodes` = 240 (`patches/cleanyourtv-settings-key-240.patch`) and enabling its `HomeKeyService` made it open Settings.

## Tooling pitfalls

- `adb shell` reads standard input. Inside `while read` loops it swallows the rest of the list, so a restore silently handled only the first item. Always redirect `</dev/null`.
- A dropped connection produces empty snapshot files. A restore from an empty snapshot would re-enable every disabled app, launchers included. `snapshot.sh` refuses to save empty data.
- On macOS, launchd can't run scripts from `~/Documents`. `install-timer.sh` copies them to a runtime folder.
- Wireless debugging uses a new port after every restart, and mDNS discovery is intermittent. `connect.sh` falls back to the last port that worked.
- Disabled apps can keep their icons on the old Google TV Home until removed by hand.

## Results on the test set

Measured once each, before (20 Oct, Google TV Home) and after (21 Oct, CleanYourTV), same commands:

| Metric | Before | After |
|---|---|---|
| Boot to home screen | ~50 s | ~40 s |
| YouTube cold start (avg) | 737 ms | 537 ms |
| Telewebion cold start (avg) | 1155 ms | 751 ms |
| Free memory | 556–596 MB | ~695 MB |
| Running processes | 452 | 419 |

The "before" boot was measured after the first cleanup steps, so the original was probably slower.
