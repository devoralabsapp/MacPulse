# iPhone/iPad battery reports over USB

[Tiếng Việt](USB-battery.vi.md) · [iOS guide](iOS.md)

MacPulse on Mac can query a connected iPhone/iPad through the diagnostics service used by the open-source [libimobiledevice tools](https://github.com/libimobiledevice/libimobiledevice/blob/master/tools/idevicediagnostics.c). This host-side path is different from the public battery API available to a sandboxed iOS app. This feature does not inspect or depend on 3uTools.

## Capture on Mac

1. Install the optional command-line tools with [Homebrew](https://formulae.brew.sh/formula/libimobiledevice):

   ```sh
   brew install libimobiledevice
   ```

2. Connect your iPhone/iPad by USB. Unlock it and approve **Trust This Computer** on the device if prompted.
3. Open MacPulse → **Battery & Power** → **iPhone / iPad battery via USB**.
4. Select **Find devices**, choose the correct device, and select **Read battery via USB**. With multiple devices, the menu distinguishes them using the final six characters of their USB identifier; the full identifier stays in memory and is passed only to the tool.
5. Enter a recognizable device label and select **Export battery report** to save JSON. Labels are user supplied, so avoid personal information if sharing a report.

The app resolves `idevice_id` and `idevicediagnostics` at `/opt/homebrew/bin` or `/usr/local/bin`, without invoking a shell or installing anything automatically. Listing is USB-only (`idevice_id -l`); every diagnostic command explicitly selects that device. Each command has a 10-second timeout and a 2 MB output limit. A full read can take approximately 30 seconds across three queries. It does not restart, shut down, change settings, or read file contents on the phone.

libimobiledevice is an optional, separately installed LGPL-2.1-or-later tool; its binaries and libraries are not included in MacPulse's MIT-licensed app or linked into iOS. Installation is currently manual. Nonstandard prefixes are not detected automatically.

## View on iPhone or iPad

Transfer the JSON through AirDrop, iCloud Drive, or another location in Files. In MacPulse **Overview**, scroll to **Battery details from your Mac**, select **Import battery report**, and choose the file. The last valid report persists locally across launches; **Remove imported report** removes that copy. Import errors preserve the previous report.

The report shows its label, capture time, source, and individual query/field provenance. It is a **historical snapshot**, displayed separately from live percentage/charging status. MacPulse does not automatically establish that the report belongs to the device on which it is imported. There is no live USB tunnel, network server, background sync, or connection to 3uTools.

## Fields and units

Queries are attempted in this order: `ioregentry AppleSmartBattery`, `ioregentry AppleARMPMUCharger`, and `diagnostics GasGauge`. Missing fields can fall back to later responses for the same explicitly selected device. Firmware availability varies by model and OS version; successful communication does not guarantee every field.

| Display | Accepted fields |
| --- | --- |
| Design capacity, mAh | `BatteryData.DesignCapacity` or `DesignCapacity` |
| Full-charge capacity, mAh | `AppleRawMaxCapacity`, `BatteryData.NominalChargeCapacity`, `NominalChargeCapacity`; `FullChargeCapacity` only from GasGauge and only above 100 |
| Remaining charge, mAh | `AppleRawCurrentCapacity`, including a valid zero |
| Cycle count | `CycleCount`, including zero |

Generic `MaxCapacity` and `CurrentCapacity` are ignored because they can be percentages. GasGauge's `FullChargeCapacity = 100` is also ignored; upstream reports document this normalized result on some devices. No mAh is inferred by multiplying percentage by a nominal capacity. `Qmax` is never substituted for design capacity.

Capacity readings are firmware references rather than an independent physical measurement. When full-charge capacity exceeds design capacity, or remaining charge exceeds full-charge capacity, raw values stay visible with a warning and no health ratio. A consistent full-charge/design ratio is only an estimate, separate from Apple's Battery Health assessment. Unavailable readings show **—**. New firmware formats should be checked against the device before expanding the accepted field list.

## Report format and privacy

The version-1 JSON contains `schemaVersion`, `deviceLabel`, an ISO-8601 `capturedAt`, and optional `design`, `maximum`, `current`, and `cycles` readings. Each reading has an integer `value`, a known `query`, and a known `field`. See the clearly labeled [synthetic example](examples/battery-report.example.json).

Only this allowlist is serialized. UDID, battery/device serials, raw diagnostic output, lockdown pairing records, and device names from lockdown are excluded. Imported reports are unverified documents, not cryptographically authenticated hardware attestations. Unknown JSON properties are discarded when storing/re-exporting the parsed model. The importer checks version, field/unit combinations, ranges, label, timestamp, and a 64 KB size limit, using a coordinated, bounded read of a regular file. Future timestamps beyond five minutes are rejected; verify the Mac/device clock if needed.

MacPulse itself uploads no report. A transfer location such as iCloud Drive has its own sync behavior.

## Verification limits

Automated checks use synthetic plist/JSON fixtures, injected USB responses, process timeout/output tests, and Simulator file imports. Physical iPhone/iPad firmware responses, trust dialogs, unplugging during a query, and multi-device identity should still be checked on real hardware. Lack of a supported field remains **—**, rather than a claimed universal battery readout.
