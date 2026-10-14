RED LANTERN
A small, free, native macOS menu-bar app for warmer or red-only screen colors.

FEATURES
Eight presets, from neutral daylight to red-only output.
Adjustable warmth (approximately 500–6500 K) and software brightness.
Manual, clock, and offline sunset-to-sunrise schedules.
Close the window to keep filtering from the menu bar. Quit restores colors.
Sleep restores original display colors; wake reapplies the active setting.
A small recovery helper restores captured color tables after a main-app crash.
Windows are bounded to their display's usable area, with scrolling when needed.

BUILD AND RUN
Requires macOS 14 or later and Apple Command Line Tools.
No package-manager dependencies or paid developer account are required.

    ./test.sh
    ./build.sh
    open "build/Red Lantern.app"

The build targets the current machine's architecture. It is signed locally
with an ad-hoc signature; it is not notarized by Apple for distribution.
Copy the resulting app to your Applications folder if desired. To pin a Dock
launcher, right-click its icon and choose Options > Keep in Dock.

USAGE
Click a preset and adjust the sliders. Sliders apply when released to avoid
repeated display writes while dragging. Use the horizon icon in the menu bar
for Quick Controls, or choose Settings to open the full window.
The red close button closes the window and hides the running Dock icon while
the filter and schedules continue. Quit fully exits and restores colors.
Emergency restore: Control + Option + Command + R. The Restore colors button
and application menu command provide additional ways to disable filtering.
Open at login is optional and uses macOS Login Items.

SCHEDULES
Manual stays active until switched off. Clock supports overnight intervals.
For Sunset, enter latitude and longitude and enable Use these coordinates.
North/east are positive; south/west are negative. Computation stays offline.
Enable the main filter switch to arm a schedule. Presets preserve the schedule.
Identical clock start/end times keep the filter off.

LOW RESOURCE USE
No repeating timer in manual mode, whether filtering or switched off.
Clock and solar schedules arm one timer for their next transition.
Unchanged settings do not rewrite gamma tables. Display, sleep/wake and clock
notifications handle system changes without polling. No animation timer runs.
Native AppKit controls are created when opened and released when closed.
The C recovery helper sleeps on a pipe and does not run for neutral daylight.

PRIVACY
No accounts, telemetry, tracking, network requests or third-party libraries.
Preferences, including any entered coordinates, stay in local user defaults.
Location permission is not needed. No credentials or signing keys are needed.
Diagnostic tools inspect only this app's window bounds or explicitly selected
process accounting; they do not capture screenshots or send anything online.

DISPLAY LIMITATIONS
Uses public Core Graphics display transfer tables. Some display drivers,
HDR/reference modes, Night Shift, True Tone or other color utilities may
override adjustments. Disable competing color adjustments for consistency.
Kelvin labels describe approximate visual warmth, not calibrated spectra.
At the deepest red setting, green and blue output tables are zeroed.
Brightness is software scaling; it does not change physical backlight PWM
or hardware temporal dithering. No medical benefits are claimed.
Crash recovery requires the helper and the display driver to remain usable;
it cannot recover from a simultaneous helper failure or a system/driver crash.

DEVELOPER CHECKS
Tests cover color mapping, settings, scheduling and screen bounds.
Tools/Guardian.c implements a bounded, private-stdin recovery protocol.
Tools/Icon.swift draws the icon; no third-party artwork is bundled.
Tools/ResourceProbe.c measures selected process CPU, footprint and wakeups.
Tools/WindowProbe.swift checks this app's window geometry.
The executable's --display-test option briefly changes display colors, checks
red output and crash-helper restoration, then restores the original tables.
Use it only when a brief display change will not interrupt your work.

SECURITY AND LICENSE
See SECURITY.txt for the pre-publication review scope and security reporting.
MIT licensed. See LICENSE.
