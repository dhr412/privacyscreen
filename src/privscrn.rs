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

use clap::Parser;

#[derive(Parser)]
#[command(name = "privscrn")]
#[command(about = "Privacy screen vignette overlay")]
struct Cli {
    #[arg(
        short,
        long,
        default_value = "4.0",
        help = "Fall-off power for the vignette curve"
    )]
    falloff: f32,

    #[arg(
        short,
        long,
        default_value = "0.3",
        help = "Maximum edge opacity (0.0–1.0)"
    )]
    opacity: f32,

    #[arg(
        short = 's',
        long,
        default_value = "elliptical",
        help = "Vignette shape"
    )]
    shape: Shape,

    #[arg(
        short = 't',
        long,
        default_value = "smootherstep",
        help = "Falloff function"
    )]
    falloff_type: FalloffType,

    #[arg(short = 'l', long, default_missing_value = "0.2", num_args = 0..=1, help = "Darken the left side more (optional strength, default: 0.2)")]
    left_bias: Option<f32>,
    #[arg(short = 'r', long, default_missing_value = "0.2", num_args = 0..=1, help = "Darken the right side more (optional strength, default: 0.2)")]
    right_bias: Option<f32>,

    #[arg(
        short = 'i',
        long,
        help = "Invert vignette (darken center instead of edges)"
    )]
    invert: bool,
}

#[derive(clap::ValueEnum, Clone, Copy, Debug)]
#[clap(rename_all = "lowercase")]
enum Shape {
    Circle,
    Rectangle,
    Diamond,
    Elliptical,
}

#[derive(clap::ValueEnum, Clone, Copy, Debug)]
#[clap(rename_all = "lowercase")]
enum FalloffType {
    Power,
    Exponential,
    Gaussian,
    Smootherstep,
}

struct App {
    windows: Vec<Arc<Window>>,
    monitors: Vec<MonitorHandle>,
    created: bool,
    falloff: f32,
    max_alpha: f32,
    shape: Shape,
    falloff_type: FalloffType,
    left_bias: Option<f32>,
    right_bias: Option<f32>,
    invert: bool,
}

impl Default for App {
    fn default() -> Self {
        Self {
            windows: Vec::new(),
            monitors: Vec::new(),
            created: false,
            falloff: 2.0,
            max_alpha: 0.6,
            shape: Shape::Rectangle,
            falloff_type: FalloffType::Smootherstep,
            left_bias: None,
            right_bias: None,
            invert: false,
        }
    }
}

fn calculate_vignette_factor(
    mut dx: f32,
    dy: f32,
    center_x: f32,
    center_y: f32,
    config: &App,
) -> f32 {
    dx = if let Some(bias) = config.left_bias {
        dx + center_x * bias
    } else if let Some(bias) = config.right_bias {
        dx - center_x * bias
    } else {
        dx
    };

    let mut normalized_dist = match config.shape {
        Shape::Circle => {
            let dist = (dx.powi(2) + dy.powi(2)).sqrt();
            let max_dist = (center_x.powi(2) + center_y.powi(2)).sqrt();
            dist / max_dist
        }
        Shape::Rectangle => {
            let dist_x = dx.abs() / center_x;
            let dist_y = dy.abs() / center_y;
            dist_x.max(dist_y)
        }
        Shape::Diamond => {
            let dist_x = dx.abs() / center_x;
            let dist_y = dy.abs() / center_y;
            (dist_x + dist_y) / 2.0
        }
        Shape::Elliptical => {
            let aspect = 1.7;
            let dist_x = dx / center_x;
            let dist_y = dy / center_y;
            let dist = ((dist_x.powi(2) * aspect) + dist_y.powi(2)).sqrt();
            let max_dist = (aspect + 1.0).sqrt();
            dist / max_dist
        }
    };

    if config.invert {
        normalized_dist = 1.0 - normalized_dist;
    }

    normalized_dist = normalized_dist.clamp(0.0, 1.0);

    match config.falloff_type {
        FalloffType::Power => normalized_dist.powf(config.falloff).min(1.0),
        FalloffType::Exponential => {
            let exp_max = config.falloff.exp() - 1.0;
            ((config.falloff * normalized_dist).exp() - 1.0) / exp_max
        }
        FalloffType::Gaussian => 1.0 - (-config.falloff * normalized_dist.powi(2)).exp(),
        FalloffType::Smootherstep => {
            let t = normalized_dist.min(1.0);
            let smootherstep = t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
            smootherstep.powf(config.falloff)
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
                                let factor =
                                    calculate_vignette_factor(dx, dy, center_x, center_y, self);
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
    #[cfg(not(windows))]
    {
        eprintln!("This application is only supported on Windows.");
        std::process::exit(0);
    }

    let cli = Cli::parse();

    let mut message = format!(
        "Running with opacity: {}, falloff power: {}, falloff function: {:?}, shape: {:?}",
        cli.opacity, cli.falloff, cli.falloff_type, cli.shape
    );
    if let Some(left_bias) = cli.left_bias {
        message.push_str(&format!(", left bias: {left_bias}"));
    }
    if let Some(right_bias) = cli.right_bias {
        message.push_str(&format!(", right bias: {right_bias}"));
    }
    if cli.invert {
        message.push_str(", invert: true");
    }
    println!("{message}");

    ctrlc::set_handler(|| {
        println!("Closing...");
        std::process::exit(0);
    })
    .expect("Failed to set Ctrl+C handler");

    let event_loop = EventLoop::new().unwrap();

    let mut app = App {
        falloff: cli.falloff,
        max_alpha: cli.opacity,
        shape: cli.shape,
        falloff_type: cli.falloff_type,
        left_bias: cli.left_bias,
        right_bias: cli.right_bias,
        invert: cli.invert,

        ..Default::default()
    };
    event_loop.run_app(&mut app).unwrap();
}
