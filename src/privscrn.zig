const std = @import("std");
const builtin = @import("builtin");

const FALL_OFF_POWER: f32 = 1.0;
const MAX_ALPHA: f32 = 0.35;
const X11_WINDOW_OPACITY: f32 = 0.4;

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
    extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(.winapi) BOOL;
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

const linux = if (builtin.os.tag == .linux) struct {
    const Display = opaque {};
    const Window = c_ulong;
    const Atom = c_ulong;
    const XID = c_ulong;
    const Region = *opaque {};

    const XClientMessageEvent = extern struct {
        type: i32,
        serial: c_ulong,
        send_event: i32,
        display: *Display,
        window: Window,
        message_type: Atom,
        format: i32,
        data: extern union {
            b: [20]u8,
            s: [10]i16,
            l: [5]i64,
        },
    };

    const XRectangle = extern struct {
        x: i16,
        y: i16,
        width: u16,
        height: u16,
    };

    extern "X11" fn XOpenDisplay(display_name: ?[*:0]const u8) ?*Display;
    extern "X11" fn XDefaultRootWindow(display: *Display) Window;
    extern "X11" fn XInternAtom(display: *Display, atom_name: [*:0]const u8, only_if_exists: i32) Atom;
    extern "X11" fn XSendEvent(display: *Display, w: Window, propagate: i32, event_mask: i64, event: *XClientMessageEvent) i32;
    extern "X11" fn XChangeProperty(display: *Display, w: Window, property: Atom, type: Atom, format: i32, mode: i32, data: *const u32, nelements: i32) i32;
    extern "X11" fn XSync(display: *Display, discard: i32) i32;
    extern "X11" fn XCreateRegion() Region;
    extern "X11" fn XUnionRectWithRegion(rect: *const XRectangle, src: Region, dest: Region) i32;
    extern "X11" fn XDestroyRegion(r: Region) i32;
    extern "Xext" fn XShapeCombineRegion(display: *Display, dest: Window, dest_kind: i32, x_off: i32, y_off: i32, region: Region, op: i32) void;

    const XA_CARDINAL: Atom = 6;
    const ClientMessage: i32 = 33;
    const SubstructureRedirectMask: i64 = 1 << 20;
    const SubstructureNotifyMask: i64 = 1 << 19;
    const PropModeReplace: i32 = 0;
    const ShapeInput: i32 = 2;
    const ShapeSet: i32 = 0;
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

fn createVignetteWindows(allocator: std.mem.Allocator) !void {
    if (builtin.os.tag == .windows) {
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

            try drawVignetteWindows(hwnd, @intCast(mon.width), @intCast(mon.height), mon.x, mon.y);
        }

        var msg: windows.MSG = undefined;
        while (windows.GetMessageW(&msg, null, 0, 0) > 0) {
            _ = windows.TranslateMessage(&msg);
            _ = windows.DispatchMessageW(&msg);
        }
    }
}

fn drawVignetteWindows(hwnd: windows.HWND, width: u32, height: u32, xpos: i32, ypos: i32) !void {
    const center_x = @as(f32, @floatFromInt(width)) / 2.0;
    const center_y = @as(f32, @floatFromInt(height)) / 2.0;
    const max_dist = @max(1.0, @sqrt(center_x * center_x + center_y * center_y));

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
            const dist = @sqrt(dx * dx + dy * dy);
            const factor = @min(1.0, std.math.pow(f32, dist / max_dist, FALL_OFF_POWER));
            const alpha: u8 = @intFromFloat(factor * MAX_ALPHA * 255.0);
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try createVignetteWindows(allocator);
}
