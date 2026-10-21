---
name: aiwa-tv-tuning
description: Guide the user step by step through speeding up and de-cluttering an Aiwa AI PONT (or similar MediaTek Google TV 14) over ADB, with a snapshot and 5-minute automatic rollback for every change. Interviews the user one question at a time. Use when the user wants to clean up, debloat, speed up, remove ads from, or replace the home screen of their Android or Google TV with this repo.
---

# Aiwa AI PONT tuning, guided

You are helping someone who may not be technical. Interview them **one question at a time** and wait for each answer. Never batch questions. Explain each step in one or two plain sentences before doing it. Read `docs/FINDINGS.md` before starting: it records what broke on the test TV and why.

## Rules that are never skipped

1. **One change per window.** Before any change: take a snapshot (`scripts/snapshot.sh <label>`), arm the timer (`deadman.sh arm 5 <snapshot>`, plus a scope file for settings keys), make the change, then ask the user to test. Only `deadman.sh confirm` after the user explicitly says **keep**. Silence is not a keep.
2. **If the snapshot fails, stop.** An empty snapshot means the TV dropped off. A restore from it would re-enable everything. `snapshot.sh` refuses empty data. Respect its exit code.
3. **A keep that arrives after the deadline doesn't count.** The timer has already restored. Offer a new window.
4. **Never uninstall a package for all users without the user's explicit request.** Prefer `pm disable-user --user 0` (undo: `pm enable --user 0`). Use `pm uninstall -k --user 0` only for preinstalled apps that come back after a restart. Undo: `cmd package install-existing --user 0`.
5. **Never disable Google TV Home (`com.google.android.apps.tv.launcherx`) on its own.** It drops Home to a blank setup screen. Only disable it together with `com.google.android.tungsten.setupwraith`, only after a replacement launcher holds the HOME role (`cmd role get-role-holders android.app.role.HOME`), and only after checking the setup app's saved Wi-Fi networks (`dumpsys wifi | grep -o 'cname=[^ ]*'`). If it owns the network the TV uses, stop and have the user forget and re-join that network first.
6. **Never touch** packages marked PERSISTENT, Google Play services, the Play Store, Settings, System UI, the keyboard in use, Bluetooth (the remote), the TV input framework or HDMI.
7. If a command is refused (component disables, Wi-Fi country override), say so and move on. Don't look for workarounds.
8. Keep a record. Append each kept or rolled-back change to `docs/CHANGES-LOCAL.md` in the user's copy.

## The interview, in order

Ask, wait, act, then move to the next question.

1. **Setup.** "Is your TV an Aiwa AI PONT? What does Settings → System → About show for model and Android version?" If it's a different model, warn that the lists were tested only on board `alimos`, and get them read-only from the TV: `getprop ro.product.board`.
2. **Tools.** Check `adb` (`command -v adb`, or `~/Library/Android/sdk/platform-tools/adb`). If it's missing, guide the user to install Android platform-tools. Don't install system software without asking.
3. **TV address.** "What is the TV's IP address? (Settings → Network)" Suggest a fixed address on their router. `export TV_IP=...`.
4. **Debugging.** Walk them through: About → press Build 7 times → Developer options → USB debugging and Wireless debugging on. "What port does Wireless debugging show?" Then `TV_PORT=<port> sh scripts/connect.sh`. On first connection the TV asks to allow debugging: tell them to tick **Always allow**.
5. **Timer.** `sh scripts/install-timer.sh` (macOS). Prove it works with a 1-minute no-change window: arm, wait, confirm in `~/.android-tv-tuning/deadman.log` that it restored.
6. **Baseline.** Read-only: `snapshot.sh baseline`, free memory, and cold starts (`am start -W`) of the apps they use most. Ask: "Which apps do you use most?" Record the answers. These are their keep-list.
7. **Restart test.** "Can you restart the TV now and time how long it takes to reach the home screen?" After the restart, Wireless debugging is off. Ask them to turn it on and send the new port.
8. **Settings.** Offer animations off, screensaver off, and timers. Ask: "Do you want the TV to stay on until you turn it off?" One window for the group.
9. **Debloat.** Go through `config/desired-disabled.txt` a small group at a time, naming each app in plain words. For anything that sounds like something they might use (voice search, casting, Live TV), ask first. Skip their keep-list apps.
10. **Uninstall.** Ask which of `config/desired-uninstalled.txt` they never use. Uninstall those for user 0, one window.
11. **Home screen (optional, highest risk).** Ask: "Do you want a home screen with only your apps, no suggestions or ads?" If yes:
    - Build [CleanYourTV](https://github.com/Gathin23/cleanyourtv) (needs Java 17 and the Android SDK; ask before installing either). Apply `patches/cleanyourtv-settings-key-240.patch`. Install it.
    - Make it the HOME role holder, and check by pressing Home that it opens.
    - Then do rule 5 in one window, press Home, and confirm Home resolves to CleanYourTV before asking for keep.
    - Restart test with the user at the TV.
12. **Remote.** "Does the remote's Settings (gear) button work?" If not, and the patched CleanYourTV is installed, check its `HomeKeyService` is enabled. If the remote differs, capture the code with `getevent -lt` while the user presses the button.
13. **After every restart.** Teach them to turn Wireless debugging on and run `sh scripts/check.sh`. Anything listed as re-enabled gets its own window.
14. **Finish.** Measure again (same commands as the baseline), show a before/after table, and suggest turning Wireless debugging off. Keep Developer options on, since turning it off can reset animation settings.

## If something goes wrong

- Blank Home after a change: the timer restores within 5 minutes while ADB is up. If the TV restarted, the user unplugs it for 30 seconds. If Home is still blank, they use the Settings tile or gear to turn Wireless debugging on, then run `restore.sh <last snapshot>`.
- TV unreachable mid-window: don't retry changes. Wait for it, check `deadman.sh status`, and let the timer restore when it's back.
