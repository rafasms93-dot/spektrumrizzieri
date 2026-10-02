# CODEX TASK — Wireless Workbench CSV Export

## Repository and branch

Repository: `rafasms93-dot/spektrumrizzieri`

Work only on branch:

`feat/wwb-export`

Do not modify `master` directly.

## Objective

Add a small, isolated feature to Spektrum that exports the current RF scan as a CSV file importable by Shure Wireless Workbench (WWB).

The existing scan/display behavior must remain unchanged.

## Confirmed existing data path

The application is Processing/Java.

In `spektrum.pde`, `draw()` currently obtains the raw scan values with:

`double[] buffer = spektrumReader.getDbmBuffer();`

For each raw buffer index `i`, the corresponding tuner frequency is already derived by the application as:

`startFreq + i * binStep`

The repository also already contains:

`ifCorrectedFreq(int inFreq)`

This must be used when producing the exported frequency so that IF/up-down converter behavior matches the frequency shown to the user.

The scanner library does not need to be modified for this feature.

## WWB file requirements

Create a plain CSV scan file with exactly two values per line:

`frequency_in_MHz,amplitude_in_dBm`

Example:

```text
470.000,-109.0
470.025,-103.7
470.050,-101.2
```

Requirements:

- extension: `.csv`
- no header
- no metadata lines
- decimal separator must be `.`
- field separator must be comma
- frequency must be written in MHz
- amplitude must be written in dBm
- rows must be sorted by ascending frequency
- minimum spacing between exported frequencies must be 25 kHz (0.025 MHz)
- skip invalid samples: `NaN`, positive infinity, negative infinity

Shure's current WWB documentation states that imported scan files must contain only frequency/signal-strength pairs, with no header, and that the minimum step size is 25 kHz.

## Important downsampling rule

Spektrum can scan with `binStep` values smaller than 25 kHz. Do not simply export every raw bin in that case.

If the source spacing is below 25 kHz:

1. Convert all valid raw points into corrected frequency + dBm pairs.
2. Sort the pairs by corrected frequency.
3. Group them into sequential 25 kHz windows.
4. For each 25 kHz window, export the strongest signal in that window (highest dBm value).

Using the maximum value is intentional: it preserves interference peaks instead of averaging them away.

If the source spacing is already 25 kHz or greater, preserve the valid points, after sorting.

After conversion, assert logically that adjacent exported rows are at least 25,000 Hz apart.

## UI

Add one button to the existing General tab:

Label:

`Export to WWB`

Place it in the lower controls area near the existing Pause/Exit controls without overlapping existing controls.

The button must not pause, stop, restart, or reconfigure the SDR scan.

On click:

1. obtain a snapshot using `spektrumReader.getDbmBuffer()`
2. validate that the buffer exists and contains usable samples
3. convert it to WWB rows
4. open a normal save-file dialog
5. save as CSV

Suggested default filename:

`spektrum_wwb_YYYYMMDD_HHmmss.csv`

Use Processing/Java-native file selection where practical (for example `selectOutput`) rather than adding a new dependency.

If the user cancels the dialog, do nothing destructive.

## Branding / logo support

Prepare this customized build to carry the owner's visual identity in addition to the WWB export feature.

Add branding in a way that is isolated from RF/scanning logic.

Requirements:

- create a dedicated branding asset location, preferably `assets/branding/` or the Processing-compatible equivalent used by the project
- support a primary logo image named `logo.png`
- display the logo inside the application UI in a non-intrusive area that does not cover the spectrum graph, controls, values, or cursor information
- where the Processing/runtime packaging mechanism allows it reliably, use a matching application/window icon derived from the provided branding asset
- keep the original Spektrum attribution and BSD license information intact
- do not remove or obscure upstream credits
- if the final logo asset is not yet present, implement a safe fallback so the application still compiles and runs without crashing
- do not invent a final logo or generate substitute artwork inside the codebase
- document exactly where the final logo file must be placed and any pixel-size / file-format requirements
- do not add external UI or image-processing dependencies solely for branding

The customized build may use the working product label `Spektrum Rizzieri` in the window title or a small UI label, provided this does not replace required upstream attribution.

The final visual asset itself will be supplied separately by the owner. The implementation should make replacing `logo.png` straightforward without code changes.

## Code organization

Prefer keeping the feature isolated.

Recommended structure:

- minimal UI/button addition in `spektrum.pde`
- new Processing tab/file: `wwb_export.pde`

Suggested responsibilities inside `wwb_export.pde`:

- capture/validate the current dBm buffer
- construct corrected frequency + amplitude pairs
- sort pairs
- perform 25 kHz peak-preserving downsampling when required
- format output using `Locale.US`
- write the CSV
- handle the save dialog callback
- report success/failure cleanly

Keep branding concerns separate from the WWB export functions where practical.

Do not add third-party dependencies.

Do not change the rtl-sdr / rtlspektrum library.

Do not refactor unrelated parts of the application.

## Frequency conversion

For each input sample:

`rawFrequencyHz = startFreq + i * binStep`

Then:

`correctedFrequencyHz = ifCorrectedFreq(rawFrequencyHz)`

Then convert to MHz only for final text serialization:

`frequencyMHz = correctedFrequencyHz / 1000000.0`

Because `IF_TYPE_BELOW` can reverse the frequency direction, sorting by corrected frequency before export is mandatory.

## Number formatting

Use `Locale.US` explicitly so machines configured for locales that use decimal commas still produce WWB-compatible output.

Recommended serialization:

- frequency: at least 3 decimal places; preferably enough precision to preserve 25 kHz steps (for example `%.6f`)
- amplitude: one or two decimal places (for example `%.1f` or `%.2f`)

Do not emit spaces around the comma.

## Error handling

Handle at least:

- `spektrumReader == null`
- null or zero-length dBm buffer
- all samples invalid
- save dialog cancelled
- file write exception
- missing optional branding asset

Do not crash the application.

Use existing UI/error conventions where possible; otherwise use a concise message plus `println`.

## Acceptance criteria

The task is complete only when all of the following are true:

1. Spektrum still launches and scans as before.
2. Existing controls continue to behave as before.
3. A visible `Export to WWB` button exists.
4. Clicking it can save a `.csv` file.
5. The CSV contains no header.
6. Every line contains only `MHz,dBm`.
7. Decimal output uses a period regardless of OS locale.
8. Exported frequencies are ascending.
9. No adjacent output frequencies are closer than 25 kHz.
10. Invalid floating-point samples are excluded.
11. Scans with a source `binStep < 25 kHz` are reduced using peak-preserving 25 kHz windows.
12. IF-corrected scans export the corrected/display frequency, not the uncorrected tuner frequency.
13. No unrelated code or dependency is changed.
14. The result is committed only to `feat/wwb-export`.
15. The customized build supports a replaceable `logo.png` without requiring code edits.
16. The application remains functional if the optional branding asset is temporarily absent.
17. The logo does not obstruct the spectrum graph or operational controls.
18. Upstream Spektrum attribution and BSD license information remain intact.

## Verification artifact

Along with the implementation, add a small sample output file under:

`test-data/sample_wwb_scan.csv`

It should contain a short valid scan (about 10–20 rows) with 25 kHz spacing and no header.

Do not fabricate this file from live hardware; it is only a deterministic format fixture.

## Final Codex report

When finished, report:

- files changed
- implementation summary
- how the 25 kHz conversion works
- branding/logo integration points and the required final asset path/specification
- any assumptions
- build/compile result
- manual test steps
- commit SHA

Do not merge the branch into `master`.
