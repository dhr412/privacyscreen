# Privacy Screen

A lightweight, cross-platform utility that applies a subtle vignette effect to your displays. By dimming the edges of your screen while keeping the center clear, it enhances privacy in public spaces and helps improve focus by reducing peripheral distractions.

## Features

- **Multi-Monitor Support**: Automatically detects and covers all connected displays.
- **Click-Through**: The overlay is completely transparent to mouse input, so it won't interfere with your workflow.
- **Always On Top**: Stays above other windows to ensure the privacy effect is always active.
- **Performance Focused**: Minimal CPU and memory footprint.

## Installation

### From Releases

You can download the pre-compiled binaries for Windows and Linux from the [Releases](https://github.com/dhr412/privacyscreen/releases) page.

### From Source

#### Rust Implementation
Ensure you have the [Rust toolchain](https://rustup.rs/) installed.
```bash
cargo build --release
```
The binary will be located at `target/release/privscrn`.

#### Zig Implementation
Ensure you have [Zig](https://ziglang.org/download/) installed (tested with 0.15.0).
```bash
zig build -Doptimize=ReleaseFast
```
The binary will be located at `zig-out/bin/privscrn`.

## Usage

Simply run the executable:

```bash
# For the Rust version
./target/release/privscrn

# For the Zig version
./zig-out/bin/privscrn
```

To exit the application, press `Ctrl+C` in the terminal where it is running.

## How It Works

Privacy Screen creates a borderless, transparent, and layered window that spans the entire dimensions of each monitor.

- **On Windows**: It utilizes the Win32 API (`UpdateLayeredWindow`) and GDI to render a pre-computed vignette bitmap. The window style is set to `WS_EX_LAYERED | WS_EX_TRANSPARENT` to allow for per-pixel alpha blending and mouse click-through.
- **On Linux**: It uses X11 atoms (like `_NET_WM_STATE_ABOVE` and `_NET_WM_WINDOW_OPACITY`) along with the XShape extension to create an overlay that remains on top and ignores input events.

The vignette effect is calculated using a fall-off power function, creating a smooth transition from a clear center to dimmed edges.

## License

This project is licensed under the [MIT License](LICENSE).
