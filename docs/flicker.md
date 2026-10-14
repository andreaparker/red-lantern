# Screen flicker: what Red Lantern does and does not do

**Red Lantern does not stop screen flicker or provide a neurological safety mode.** It changes RGB transfer tables through Core Graphics. That changes colors and software brightness; it does not control the timing of emitted light.

| Mechanism | What this app does |
| --- | --- |
| Backlight pulse-width modulation (PWM) | No control of the backlight’s modulation frequency or duty cycle. |
| Temporal dithering / frame-rate control | No control that disables GPU or panel dithering. |
| Flashing video, websites, or animations | No detection, blocking, or suppression. Content still changes over time. |
| Color and software brightness | Scales the display’s red, green, and blue transfer tables. |

PWM brightness control is distinct from direct-current brightness control; display manufacturers can implement these differently. EIZO describes these hardware approaches in its [technical whitepaper on ergonomic displays](https://www.eizoglobal.com/support/db/files/technical_information/flexscan/WP15-002.pdf). Changing a software color table is not evidence that either hardware mechanism has changed.

## Red is not a safety guarantee

A red tint does not make flashing content safe. [W3C’s guidance on flashing content](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) specifically addresses saturated red flashes and photosensitive seizure risks. This concerns **flashing** red; it is not a claim that a steady red screen necessarily causes the same response.

## What has actually been checked

The implementation and regression tests cover color gains, schedules, restoration, and window placement. Live display tests checked whether gamma-table changes were accepted and restored on the development Mac. They did **not** measure emitted light over time.

There have been no optical flicker measurements or clinical evaluations of Red Lantern. Demonstrating an effect on flicker would require measurements of the actual display’s light output over time, across relevant brightness levels, modes, and content. Results would apply to the tested setup, not every Mac or monitor. This release makes no claim to prevent migraines, seizures, or other neurological symptoms.
