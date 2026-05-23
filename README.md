# calenderbar

A lightweight macOS menu-bar calendar. Lives in the status bar, shows the date and time, and opens a custom Liquid Glass calendar popover with Maldives public holidays.

No Dock icon, no window — it runs as a menu-bar accessory (`LSUIElement`).

## Features

- **Status bar display** — choose Icon only, Date only, or Date & Time. Time is 24-hour, no seconds, and updates on the minute.
- **Custom calendar popover** — hand-built month grid (not the native `DatePicker`) styled with macOS Liquid Glass.
- **Holidays** — Maldives public holidays marked with a dot; the selected day's holiday name is shown below the grid.
- **Weekend shading** — Friday and Saturday columns are subtly shaded.
- **Today highlight**, previous/next month navigation, and a Today button.
- **Open at Login** toggle and Quit in the menu.
- Honors **Reduce Motion**; popover closes on any click outside.

## Holidays

> **Note:** The bundled holiday data covers **Maldives** for the **current calendar year only**.

Holidays are embedded in the app (`Holidays` in `ContentView.swift`), so the app needs no network access. Many Maldivian holidays are Hijri-based (Eid, Ramadan, etc.) and shift each year by moon sighting — so the list must be updated annually. To update: edit the `Holidays` dictionary (`yyyy-MM-dd` → name) and rebuild.

## Requirements

- macOS 26 (Tahoe) or later — uses the SwiftUI Liquid Glass APIs.
- Xcode 26+.

## Build & Install

```sh
xcodebuild -project calender-bar.xcodeproj -scheme calender-bar -configuration Release build
```

Copy the built `calender-bar.app` to `/Applications`. Installing to `/Applications` is recommended so **Open at Login** works reliably.

Or open the project in Xcode and run (⌘R).
