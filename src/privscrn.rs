use std::sync::Arc;

use winit::raw_window_handle::HasWindowHandle;
use winit::{
    application::ApplicationHandler,
    dpi::PhysicalSize,
    event::WindowEvent,
    event_loop::{ActiveEventLoop, EventLoop},
    monitor::MonitorHandle,
    window::{Fullscreen, Window, WindowAttributes, WindowId, WindowLevel},
};

#[cfg(windows)]
use windows::Win32::Foundation::COLORREF;
#[cfg(windows)]
use windows::Win32::Foundation::*;
#[cfg(windows)]
use windows::Win32::Graphics::Gdi::*;
#[cfg(windows)]
use windows::Win32::UI::WindowsAndMessaging::*;

#[cfg(target_os = "linux")]
use winit::raw_window_handle::RawWindowHandle;
#[cfg(target_os = "linux")]
use x11::xlib::*;
#[cfg(target_os = "linux")]
use x11::xshape::*;

use clap::Parser;

#[derive(Parser)]
#[command(name = "privscrn")]
#[command(about = "Privacy screen vignette overlay")]
struct Cli {
    #[arg(short, long, default_value = "4.0")]
    falloff: f32,

    #[arg(short, long, default_value = "0.6")]
    opacity: f32,

    #[cfg(target_os = "linux")]
    #[arg(short = 'x', long, default_value = "0.4")]
    x11_opacity: f32,
}

struct App {
    windows: Vec<Arc<Window>>,
    monitors: Vec<MonitorHandle>,
    created: bool,
    falloff: f32,
    max_alpha: f32,
    #[cfg(target_os = "linux")]
    x11_opacity: f32,
}

impl Default for App {
    fn default() -> Self {
        Self {
            windows: Vec::new(),
            monitors: Vec::new(),
            created: false,
            falloff: 4.0,
            max_alpha: 0.6,
            #[cfg(target_os = "linux")]
            x11_opacity: 0.4,
        }
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if !self.created {
            self.created = true;
            self.monitors = event_loop.available_monitors().collect();

            for monitor in &self.monitors {
                let attributes = WindowAttributes::default()
                    .with_transparent(true)
                    .with_decorations(false)
                    .with_resizable(false)
                    .with_window_level(WindowLevel::AlwaysOnTop)
                    .with_fullscreen(Some(Fullscreen::Borderless(Some(monitor.clone()))));

                let window = event_loop.create_window(attributes).unwrap();
                self.windows.push(Arc::new(window));
            }

            for (i, window) in self.windows.iter().enumerate() {
                let monitor = &self.monitors[i];
                let size: PhysicalSize<u32> = window.inner_size();
                let width = size.width;
                let height = size.height;
                let center_x = width as f32 / 2.0;
                let center_y = height as f32 / 2.0;
                let max_dist = (center_x.powi(2) + center_y.powi(2)).sqrt().max(1.0);

                #[cfg(target_os = "linux")]
                {
                    let context = softbuffer::Context::new(window).unwrap();
                    let mut surface = softbuffer::Surface::new(&context, window).unwrap();
                    surface
                        .resize(width.try_into().unwrap(), height.try_into().unwrap())
                        .unwrap();
                    let mut buffer = surface.buffer_mut().unwrap();
                    for y in 0..height {
                        for x in 0..width {
                            buffer[(y * width + x) as usize] = 0;
                        }
                    }
                    buffer.present().unwrap();

                    unsafe {
                        let handle = window.window_handle().unwrap();
                        let (display, xwin) = match handle.as_raw() {
                            RawWindowHandle::Xlib(h) => (h.display as *mut Display, h.window),
                            _ => panic!("Not an X11 window"),
                        };

                        let net_state = XInternAtom(display, "_NET_WM_STATE\0".as_ptr() as _, 0);
                        let net_above =
                            XInternAtom(display, "_NET_WM_STATE_ABOVE\0".as_ptr() as _, 0);
                        let skip_taskbar =
                            XInternAtom(display, "_NET_WM_STATE_SKIP_TASKBAR\0".as_ptr() as _, 0);
                        let skip_pager =
                            XInternAtom(display, "_NET_WM_STATE_SKIP_PAGER\0".as_ptr() as _, 0);

                        let mut ev: XClientMessageEvent = std::mem::zeroed();
                        ev.type_ = ClientMessage;
                        ev.window = xwin;
                        ev.message_type = net_state;
                        ev.format = 32;

                        *ev.data.l_mut().offset(0) = 1;
                        *ev.data.l_mut().offset(1) = net_above as i64;
                        *ev.data.l_mut().offset(2) = skip_taskbar as i64;
                        *ev.data.l_mut().offset(3) = skip_pager as i64;

                        XSendEvent(
                            display,
                            XDefaultRootWindow(display),
                            0,
                            SubstructureRedirectMask | SubstructureNotifyMask,
                            &mut ev as *mut _ as _,
                        );

                        let net_opacity =
                            XInternAtom(display, "_NET_WM_WINDOW_OPACITY\0".as_ptr() as _, 0);
                        let opacity_val = (self.x11_opacity * 0xFFFFFFFFu64 as f32) as u32;
                        XChangeProperty(
                            display,
                            xwin,
                            net_opacity,
                            XA_CARDINAL,
                            32,
                            PropModeReplace,
                            &opacity_val as *const _ as _,
                            1,
                        );

                        let region = XCreateRegion();
                        let empty_rect = XRectangle {
                            x: 0,
                            y: 0,
                            width: 0,
                            height: 0,
                        };
                        XUnionRectWithRegion(&mut empty_rect, region, region);
                        XShapeCombineRegion(
                            display,
                            xwin,
                            ShapeInput as i32,
                            0,
                            0,
                            region,
                            ShapeSet as i32,
                        );
                        XDestroyRegion(region);

                        XSync(display, 0);
                    }
                }

                #[cfg(windows)]
                {
                    let window_handle = (**window).window_handle().unwrap();
                    let hwnd = match window_handle.as_raw() {
                        winit::raw_window_handle::RawWindowHandle::Win32(handle) => {
                            HWND(handle.hwnd.get() as *mut _)
                        }
                        _ => panic!("Expected Windows handle"),
                    };
                    unsafe {
                        let mut ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE) as u32;

                        const WS_EX_APPWINDOW: u32 = 0x00040000;

                        ex_style &= !WS_EX_APPWINDOW;
                        ex_style |= WS_EX_LAYERED.0 | WS_EX_TRANSPARENT.0 | WS_EX_TOOLWINDOW.0;

                        SetWindowLongPtrW(hwnd, GWL_EXSTYLE, ex_style as isize);

                        let _ = SetWindowPos(
                            hwnd,
                            None,
                            0,
                            0,
                            0,
                            0,
                            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED,
                        );

                        let screen_dc = GetDC(Some(HWND(std::ptr::null_mut())));
                        let mem_dc = CreateCompatibleDC(Some(screen_dc));

                        let bmi = BITMAPINFO {
                            bmiHeader: BITMAPINFOHEADER {
                                biSize: std::mem::size_of::<BITMAPINFOHEADER>() as u32,
                                biWidth: width as i32,
                                biHeight: -(height as i32),
                                biPlanes: 1,
                                biBitCount: 32,
                                biCompression: BI_RGB.0,
                                ..Default::default()
                            },
                            bmiColors: [RGBQUAD::default(); 1],
                        };
                        let mut bits_ptr: *mut std::ffi::c_void = std::ptr::null_mut();
                        let dib = CreateDIBSection(
                            Some(screen_dc),
                            &bmi,
                            DIB_RGB_COLORS,
                            &mut bits_ptr,
                            None,
                            0,
                        );

                        if dib.is_err() || dib.as_ref().unwrap().is_invalid() {
                            panic!("DIB failed");
                        }

                        let old_bmp = SelectObject(mem_dc, HGDIOBJ(dib.as_ref().unwrap().0));

                        let bits = std::slice::from_raw_parts_mut(
                            bits_ptr as *mut u32,
                            (width * height) as usize,
                        );
                        for y in 0..height {
                            for x in 0..width {
                                let dx = x as f32 - center_x;
                                let dy = y as f32 - center_y;
                                let dist = (dx.powi(2) + dy.powi(2)).sqrt();
                                let factor = (dist / max_dist).powf(self.falloff).min(1.0);
                                let alpha: u8 = (factor * self.max_alpha * 255.0) as u8;
                                let premul: u8 = 0;
                                let bgra = ((alpha as u32) << 24)
                                    | ((premul as u32) << 16)
                                    | ((premul as u32) << 8)
                                    | (premul as u32);
                                bits[(y * width + x) as usize] = bgra;
                            }
                        }

                        let pt_dst = POINT {
                            x: monitor.position().x,
                            y: monitor.position().y,
                        };
                        let sz = SIZE {
                            cx: width as i32,
                            cy: height as i32,
                        };
                        let pt_src = POINT { x: 0, y: 0 };
                        let blend = BLENDFUNCTION {
                            BlendOp: 0, // AC_SRC_OVER = 0u8
                            BlendFlags: 0,
                            SourceConstantAlpha: 255,
                            AlphaFormat: 1, // AC_SRC_ALPHA = 1u8
                        };
                        let _ = UpdateLayeredWindow(
                            hwnd,
                            Some(screen_dc),
                            Some(&pt_dst),
                            Some(&sz),
                            Some(mem_dc),
                            Some(&pt_src),
                            COLORREF(0),
                            Some(&blend),
                            ULW_ALPHA,
                        );

                        let _ = SelectObject(mem_dc, old_bmp);
                        let _ = DeleteObject(HGDIOBJ(dib.as_ref().unwrap().0));
                        let _ = DeleteDC(mem_dc);
                        ReleaseDC(Some(HWND(std::ptr::null_mut())), screen_dc);
                    }
                }
            }
        }
    }

    fn window_event(
        &mut self,
        event_loop: &ActiveEventLoop,
        _window_id: WindowId,
        event: WindowEvent,
    ) {
        if let WindowEvent::CloseRequested = event {
            event_loop.exit();
        }
    }
}

fn main() {
    let cli = Cli::parse();

    ctrlc::set_handler(|| std::process::exit(0)).expect("Failed to set Ctrl+C handler");

    let event_loop = EventLoop::new().unwrap();

    let mut app = App {
        falloff: cli.falloff,
        max_alpha: cli.opacity,
        #[cfg(target_os = "linux")]
        x11_opacity: cli.x11_opacity,
        ..Default::default()
    };
    event_loop.run_app(&mut app).unwrap();
}
