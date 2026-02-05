const std = @import("std");
const builtin = @import("builtin");

const Config = struct {
    falloff: f32 = 2.0,
    max_alpha: f32 = 0.6,
    shape: Shape = .rectangle,
    falloff_type: FalloffType = .smootherstep,
};

const Shape = enum {
    circle,
    rectangle,
    diamond,
    elliptical,
};

const FalloffType = enum {
    power,
    exponential,
    gaussian,
    smootherstep,
};

const windows = if (builtin.os.tag == .windows) struct {
    const HWND = std.os.windows.HWND;
    const HDC = std.os.windows.HDC;
    const HINSTANCE = std.os.windows.HINSTANCE;
    const WPARAM = std.os.windows.WPARAM;
    const LPARAM = std.os.windows.LPARAM;
    const LRESULT = std.os.windows.LRESULT;
    const UINT = std.os.windows.UINT;
    const BOOL = std.os.windows.BOOL;
    const TRUE = std.os.windows.TRUE;
    const FALSE = std.os.windows.FALSE;
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    const PM_REMOVE: UINT = 0x0001;

    extern "kernel32" fn SetConsoleCtrlHandler(
        HandlerRoutine: ?*const fn (dwCtrlType: u32) callconv(.winapi) i32,
        Add: i32,
    ) callconv(.winapi) i32;

    fn windowsCtrlHandler(dwCtrlType: u32) callconv(.winapi) i32 {
        _ = dwCtrlType;
        should_quit.store(true, .monotonic);
        return 1;
    }

    extern "user32" fn CreateWindowExW(
        dwExStyle: u32,
        lpClassName: [*:0]const u16,
        lpWindowName: [*:0]const u16,
        dwStyle: u32,
        X: i32,
        Y: i32,
        nWidth: i32,
        nHeight: i32,
        hWndParent: ?HWND,
        hMenu: ?*anyopaque,
        hInstance: ?HINSTANCE,
        lpParam: ?*anyopaque,
    ) callconv(.winapi) ?HWND;

    extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.winapi) u16;
    extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.winapi) BOOL;
    extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
    extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
    extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;
    extern "user32" fn GetDC(hWnd: ?HWND) callconv(.winapi) ?HDC;
    extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.winapi) i32;
    extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: i32) callconv(.winapi) isize;
    extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: isize) callconv(.winapi) isize;
    extern "user32" fn UpdateLayeredWindow(
        hWnd: HWND,
        hdcDst: ?HDC,
        pptDst: ?*const POINT,
        psize: ?*const SIZE,
        hdcSrc: ?HDC,
        pptSrc: ?*const POINT,
        crKey: u32,
        pblend: ?*const BLENDFUNCTION,
        dwFlags: u32,
    ) callconv(.winapi) BOOL;
    extern "user32" fn EnumDisplayMonitors(
        hdc: ?HDC,
        lprcClip: ?*const RECT,
        lpfnEnum: *const fn (HMONITOR, HDC, *RECT, LPARAM) callconv(.winapi) BOOL,
        dwData: LPARAM,
    ) callconv(.winapi) BOOL;
    extern "user32" fn GetMonitorInfoW(hMonitor: HMONITOR, lpmi: *MONITORINFO) callconv(.winapi) BOOL;

    extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.winapi) ?HDC;
    extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.winapi) BOOL;
    extern "gdi32" fn CreateDIBSection(
        hdc: ?HDC,
        pbmi: *const BITMAPINFO,
        usage: u32,
        ppvBits: *?*anyopaque,
        hSection: ?*anyopaque,
        offset: u32,
    ) callconv(.winapi) ?*anyopaque;
    extern "gdi32" fn SelectObject(hdc: HDC, h: *anyopaque) callconv(.winapi) ?*anyopaque;
    extern "gdi32" fn DeleteObject(ho: *anyopaque) callconv(.winapi) BOOL;

    const WNDCLASSEXW = extern struct {
        cbSize: UINT = @sizeOf(WNDCLASSEXW),
        style: UINT,
        lpfnWndProc: *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT,
        cbClsExtra: i32 = 0,
        cbWndExtra: i32 = 0,
        hInstance: ?HINSTANCE,
        hIcon: ?*anyopaque = null,
        hCursor: ?*anyopaque = null,
        hbrBackground: ?*anyopaque = null,
        lpszMenuName: ?[*:0]const u16 = null,
        lpszClassName: [*:0]const u16,
        hIconSm: ?*anyopaque = null,
    };

    const MSG = extern struct {
        hWnd: ?HWND,
        message: UINT,
        wParam: WPARAM,
        lParam: LPARAM,
        time: u32,
        pt: POINT,
        lPrivate: u32,
    };

    const POINT = extern struct {
        x: i32,
        y: i32,
    };

    const SIZE = extern struct {
        cx: i32,
        cy: i32,
    };

    const RECT = extern struct {
        left: i32,
        top: i32,
        right: i32,
        bottom: i32,
    };

    const BLENDFUNCTION = extern struct {
        BlendOp: u8,
        BlendFlags: u8,
        SourceConstantAlpha: u8,
        AlphaFormat: u8,
    };

    const BITMAPINFOHEADER = extern struct {
        biSize: u32,
        biWidth: i32,
        biHeight: i32,
        biPlanes: u16,
        biBitCount: u16,
        biCompression: u32,
        biSizeImage: u32,
        biXPelsPerMeter: i32,
        biYPelsPerMeter: i32,
        biClrUsed: u32,
        biClrImportant: u32,
    };

    const RGBQUAD = extern struct {
        rgbBlue: u8,
        rgbGreen: u8,
        rgbRed: u8,
        rgbReserved: u8,
    };

    const BITMAPINFO = extern struct {
        bmiHeader: BITMAPINFOHEADER,
        bmiColors: [1]RGBQUAD,
    };

    const HMONITOR = *opaque {};

    const MONITORINFO = extern struct {
        cbSize: u32,
        rcMonitor: RECT,
        rcWork: RECT,
        dwFlags: u32,
    };

    const WS_POPUP: u32 = 0x80000000;
    const WS_VISIBLE: u32 = 0x10000000;
    const WS_EX_LAYERED: u32 = 0x00080000;
    const WS_EX_TRANSPARENT: u32 = 0x00000020;
    const WS_EX_TOOLWINDOW: u32 = 0x00000080;
    const WS_EX_TOPMOST: u32 = 0x00000008;
    const GWL_EXSTYLE: i32 = -20;
    const WM_DESTROY: UINT = 0x0002;
    const BI_RGB: u32 = 0;
    const DIB_RGB_COLORS: u32 = 0;
    const ULW_ALPHA: u32 = 0x00000002;
} else struct {};

fn windowProc(hWnd: windows.HWND, uMsg: windows.UINT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.winapi) windows.LRESULT {
    if (uMsg == windows.WM_DESTROY) {
        windows.PostQuitMessage(0);
        return 0;
    }
    return windows.DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

const MonitorData = struct {
    monitors: std.ArrayList(MonitorInfo),
    allocator: std.mem.Allocator,
};

const MonitorInfo = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

fn monitorEnumProc(hMonitor: windows.HMONITOR, _: windows.HDC, _: *windows.RECT, dwData: windows.LPARAM) callconv(.winapi) windows.BOOL {
    const data: *MonitorData = @ptrFromInt(@as(usize, @intCast(dwData)));

    var mi = std.mem.zeroes(windows.MONITORINFO);
    mi.cbSize = @sizeOf(windows.MONITORINFO);

    if (windows.GetMonitorInfoW(hMonitor, &mi) == windows.TRUE) {
        const info = MonitorInfo{
            .x = mi.rcMonitor.left,
            .y = mi.rcMonitor.top,
            .width = mi.rcMonitor.right - mi.rcMonitor.left,
            .height = mi.rcMonitor.bottom - mi.rcMonitor.top,
        };
        data.monitors.append(data.allocator, info) catch {};
    }

    return windows.TRUE;
}

fn createVignetteWindows(allocator: std.mem.Allocator, config: Config) !void {
    if (builtin.os.tag != .windows) {
        @compileError("Only Windows is supported");
    }

    const hInstance: ?windows.HINSTANCE = @ptrCast(std.os.windows.kernel32.GetModuleHandleW(null));

    const wc = windows.WNDCLASSEXW{
        .style = 0,
        .lpfnWndProc = windowProc,
        .hInstance = hInstance,
        .lpszClassName = windows.L("VignetteWindow"),
    };

    _ = windows.RegisterClassExW(&wc);

    var monitor_data = MonitorData{
        .monitors = std.ArrayList(MonitorInfo).empty,
        .allocator = allocator,
    };
    defer monitor_data.monitors.deinit(monitor_data.allocator);

    _ = windows.EnumDisplayMonitors(null, null, monitorEnumProc, @intCast(@intFromPtr(&monitor_data)));

    for (monitor_data.monitors.items) |mon| {
        const hwnd = windows.CreateWindowExW(
            windows.WS_EX_LAYERED | windows.WS_EX_TRANSPARENT | windows.WS_EX_TOOLWINDOW | windows.WS_EX_TOPMOST,
            windows.L("VignetteWindow"),
            windows.L("Vignette"),
            windows.WS_POPUP | windows.WS_VISIBLE,
            mon.x,
            mon.y,
            mon.width,
            mon.height,
            null,
            null,
            hInstance,
            null,
        ) orelse continue;

        try drawVignetteWindows(hwnd, @intCast(mon.width), @intCast(mon.height), mon.x, mon.y, config);
    }

    var msg: windows.MSG = undefined;
    while (!should_quit.load(.monotonic)) {
        while (windows.PeekMessageW(&msg, null, 0, 0, windows.PM_REMOVE) != 0) {
            if (msg.message == windows.WM_DESTROY) break;
            _ = windows.TranslateMessage(&msg);
            _ = windows.DispatchMessageW(&msg);
        }
        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}

fn calculateVignetteFactor(dx: f32, dy: f32, center_x: f32, center_y: f32, config: Config) f32 {
    const normalized_dist = switch (config.shape) {
        .circle => blk: {
            const dist = @sqrt(dx * dx + dy * dy);
            const max_dist = @sqrt(center_x * center_x + center_y * center_y);
            break :blk dist / max_dist;
        },
        .rectangle => blk: {
            const dist_x = @abs(dx) / center_x;
            const dist_y = @abs(dy) / center_y;
            break :blk @max(dist_x, dist_y);
        },
        .diamond => blk: {
            const dist_x = @abs(dx) / center_x;
            const dist_y = @abs(dy) / center_y;
            break :blk (dist_x + dist_y) / 2.0;
        },
        .elliptical => blk: {
            const aspect = 1.7;
            const dist_x = dx / center_x;
            const dist_y = dy / center_y;
            const dist = @sqrt((dist_x * dist_x * aspect) + (dist_y * dist_y));
            const max_dist = @sqrt(aspect + 1.0);
            break :blk dist / max_dist;
        },
    };

    return switch (config.falloff_type) {
        .power => @min(1.0, std.math.pow(f32, normalized_dist, config.falloff)),
        .exponential => blk: {
            const exp_max = @exp(config.falloff) - 1.0;
            break :blk (@exp(config.falloff * normalized_dist) - 1.0) / exp_max;
        },
        .gaussian => 1.0 - @exp(-config.falloff * normalized_dist * normalized_dist),
        .smootherstep => blk: {
            const t = @min(1.0, normalized_dist);
            const smootherstep = t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
            break :blk std.math.pow(f32, smootherstep, config.falloff);
        },
    };
}

fn drawVignetteWindows(hwnd: windows.HWND, width: u32, height: u32, xpos: i32, ypos: i32, config: Config) !void {
    const center_x = @as(f32, @floatFromInt(width)) / 2.0;
    const center_y = @as(f32, @floatFromInt(height)) / 2.0;

    const screen_dc = windows.GetDC(null) orelse return error.GetDCFailed;
    defer _ = windows.ReleaseDC(null, screen_dc);

    const mem_dc = windows.CreateCompatibleDC(screen_dc) orelse return error.CreateDCFailed;
    defer _ = windows.DeleteDC(mem_dc);

    var bmi = std.mem.zeroes(windows.BITMAPINFO);
    bmi.bmiHeader.biSize = @sizeOf(windows.BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = @intCast(width);
    bmi.bmiHeader.biHeight = -@as(i32, @intCast(height));
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = windows.BI_RGB;

    var bits_ptr: ?*anyopaque = null;
    const dib = windows.CreateDIBSection(screen_dc, &bmi, windows.DIB_RGB_COLORS, &bits_ptr, null, 0) orelse return error.CreateDIBFailed;
    defer _ = windows.DeleteObject(dib);

    const old_bmp = windows.SelectObject(mem_dc, dib);
    defer _ = windows.SelectObject(mem_dc, old_bmp.?);

    const bits = @as([*]u32, @ptrCast(@alignCast(bits_ptr)))[0..(width * height)];

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const dx = @as(f32, @floatFromInt(x)) - center_x;
            const dy = @as(f32, @floatFromInt(y)) - center_y;
            const factor = calculateVignetteFactor(dx, dy, center_x, center_y, config);
            const alpha: u8 = @intFromFloat(factor * config.max_alpha * 255.0);
            const premul: u8 = 0;
            const bgra = (@as(u32, alpha) << 24) | (@as(u32, premul) << 16) |
                (@as(u32, premul) << 8) | premul;
            bits[y * width + x] = bgra;
        }
    }

    const pt_dst = windows.POINT{ .x = xpos, .y = ypos };
    const sz = windows.SIZE{ .cx = @intCast(width), .cy = @intCast(height) };
    const pt_src = windows.POINT{ .x = 0, .y = 0 };
    const blend = windows.BLENDFUNCTION{
        .BlendOp = 0,
        .BlendFlags = 0,
        .SourceConstantAlpha = 255,
        .AlphaFormat = 1,
    };

    _ = windows.UpdateLayeredWindow(hwnd, screen_dc, &pt_dst, &sz, mem_dc, &pt_src, 0, &blend, windows.ULW_ALPHA);
}

var should_quit = std.atomic.Value(bool).init(false);

fn handleSignal(_: c_int) callconv(.C) void {
    should_quit.store(true, .monotonic);
}

fn printHelp() void {
    std.debug.print(
        \\Usage: privscrn [OPTIONS]
        \\
        \\Options:
        \\  -f, --falloff <VALUE>       Fall-off power for vignette curve (default: 4.0)
        \\  -o, --opacity <VALUE>       Maximum edge opacity, 0.0-1.0 (default: 0.6)
        \\  -s, --shape <VALUE>         Shape: circle, rectangle, diamond, elliptical (default: rectangle)
        \\  -t, --type <VALUE>          Falloff: power, exponential, gaussian, smoothers
        \\
    , .{});
}

fn parseArgs(allocator: std.mem.Allocator) !Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var config = Config{};

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp();
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--falloff")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --falloff requires a value\n", .{});
                std.process.exit(1);
            }
            config.falloff = std.fmt.parseFloat(f32, args[i]) catch {
                std.debug.print("Error: invalid falloff value: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--opacity")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --opacity requires a value\n", .{});
                std.process.exit(1);
            }
            config.max_alpha = std.fmt.parseFloat(f32, args[i]) catch {
                std.debug.print("Error: invalid opacity value: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--shape")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --shape requires a value\n", .{});
                std.process.exit(1);
            }
            config.shape = std.meta.stringToEnum(Shape, args[i]) orelse {
                std.debug.print("Error: invalid shape: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--type")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --type requires a value\n", .{});
                std.process.exit(1);
            }
            config.falloff_type = std.meta.stringToEnum(FalloffType, args[i]) orelse {
                std.debug.print("Error: invalid falloff type: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else {
            std.debug.print("Error: unknown argument: {s}\n", .{arg});
            printHelp();
            std.process.exit(1);
        }
    }

    return config;
}

pub fn main() !void {
    if (builtin.os.tag != .windows) {
        std.debug.print("This application is only supported on Windows.\n", .{});
        std.process.exit(0);
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = try parseArgs(allocator);

    _ = windows.SetConsoleCtrlHandler(windows.windowsCtrlHandler, 1);

    try createVignetteWindows(allocator, config);
}
