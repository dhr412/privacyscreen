# Privacy Screen

A lightweight utility for Windows that applies a customizable vignette effect to your displays. By dimming the edges of your screen while keeping the center clear, it enhances privacy in public spaces and helps improve focus by reducing peripheral distractions.

## Features

- **Multi-Monitor Support**: Automatically detects and covers all connected displays.
- **Configurable Effects**: Choose from multiple shapes and fall-off functions to suit your preference.
- **Click-Through**: The overlay is completely transparent to mouse input, so it won't interfere with your workflow.
- **Always On Top**: Stays above other windows to ensure the privacy effect is always active.
- **Performance Focused**: Minimal CPU and memory footprint.

## Installation

### From Releases

You can download the pre-compiled binaries for Windows from the [Releases](https://github.com/dhr412/privacyscreen/releases) page.

### From Source

Ensure you have one of the following toolchains installed:

#### Rust Implementation
```bash
cargo build --release
```
The binary will be located at `target/release/privscrn.exe`.

#### Zig Implementation
Tested with Zig 0.15.2.
```bash
zig build -Doptimize=ReleaseSafe
```
The binary will be located at `zig-out/bin/privscrn.exe`.

## Usage

Run the executable with optional flags to customize the effect:

```bash
# Example: circular vignette with higher falloff
./privscrn.exe --shape circle --opacity 0.5 --falloff 3.0
```

### CLI Options

| Flag | Description | Default | Values |
|------|-------------|---------|--------|
| `-s, --shape` | The shape of the clear area | `elliptical` | `circle`, `rectangle`, `diamond`, `elliptical` |
| `-t, --type` | The mathematical function for the fall-off | `smootherstep` | `power`, `exponential`, `gaussian`, `smootherstep` |
| `-o, --opacity` | Maximum opacity at the edges (0.0 to 1.0) | `0.3` | Any float |
| `-f, --falloff` | Intensity/steepness of the fall-off curve | `4.0` | Any float |
| `-r, --reverse` | Reverse the vignette effect (darken from center instead of edges) | `false` | `true`, `false` |

To exit the application, press `Ctrl+C` in the terminal or close the terminal window.

## How It Works

Privacy Screen creates a borderless, transparent, and layered window that spans the entire dimensions of each monitor on Windows.

It utilizes the Win32 API (`UpdateLayeredWindow`) and GDI to render a pre-computed vignette bitmap. The window style is set to `WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW` to allow for per-pixel alpha blending, mouse click-through, and to keep it hidden from the taskbar.

The vignette effect is calculated using various mathematical functions (like Smootherstep or Gaussian), creating a smooth transition from a clear center to dimmed edges based on the selected shape.

## License

This project is licensed under the [MIT License](LICENSE).
