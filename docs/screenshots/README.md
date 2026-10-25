# macOS screenshots

Captured on 25 October 2026 from the running Universal macOS app, using live local metrics. These are window screenshots, not sample-data renders. No file scan or cleanup was performed.

| File | Palette | Mode | Language |
| --- | --- | --- | --- |
| `overview-visual-studio-code.png` | Visual Studio Code | Dark | English |
| `overview-command-line.png` | Command Line | Dark | English |
| `overview-dracula.png` | Dracula | Dark | English |

To reproduce, build with `bash scripts/build-app.sh --universal`, open `dist/MacPulse.app`, choose **Settings → General → Language → English**, and return to **Overview**. Use the palette menu to select **Dark** and the desired theme. Enlarge the window and let the live chart collect samples before capturing the app window. Actual resource values vary with the Mac and current activity.

All seven palettes support Light, Dark, and System default. Screenshots show only the three new developer themes in Dark mode.
