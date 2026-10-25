use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::{Arc, LazyLock, Mutex};

use base64::Engine;
use pdfcraft_automation::{Automation, Content};
use pdfcraft_cos::{Document, Object, SaveOptions, write_full};
use pdfcraft_create::{LETTER, blank, from_text, image_xobject};
use pdfcraft_crypt::{Algorithm, NewEncryption};
use pdfcraft_edit::{
    AddedImage, AddedText, Align, Content as AddedContent, Family, Watermark, add_content,
    add_watermark, delete_content, list_added, update_content,
};
use pdfcraft_render::{PageRenderer, RenderConfig, RenderRequest, RequestKind};
use pdfcraft_sign::graphic::Graphic;
use pdfcraft_sign::keys::{DigestAlg, PrivateKey};
use pdfcraft_sign::pkcs12::DigitalId;
use pdfcraft_sign::x509::{Certificate, Name as X509Name};
use pdfcraft_sign::{Appearance, SignOptions, Time, TrustStore, sign};
use serde_json::{Value, json};

static AUTOMATION: LazyLock<Mutex<Automation>> = LazyLock::new(|| Mutex::new(Automation::new()));

/// A rectangle in display space: `[l, b, r, t]`, bottom-left origin (as `pdfcraft-edit` wants).
fn norm_rect(r: [f64; 4]) -> [f64; 4] {
    [r[0].min(r[2]), r[1].min(r[3]), r[0].max(r[2]), r[1].max(r[3])]
}

/// A page's display size `(w, h)` from the document's page tree, without the renderer.
fn page_size(doc: &Document, page: usize) -> Option<(f64, f64)> {
    let root = doc.root()?;
    let pages = doc.get(root).as_dict().and_then(|d| d.reference(b"Pages"))?;
    let pages_dict = doc.get(pages);
    let kids = pages_dict.as_dict().and_then(|d| d.get(b"Kids")).and_then(|k| k.as_array())?;
    let page_ref = kids.get(page)?.as_ref()?;
    let page_dict = doc.get(page_ref);
    let media = page_dict
        .as_dict()
        .and_then(|d| d.get(b"MediaBox"))
        .and_then(|b| b.as_array())?;
    let nums: Vec<f64> = media.iter().filter_map(|x| x.as_f64()).collect();
    match nums.as_slice() {
        [_, _, w, h] => Some((*w, *h)),
        _ => None,
    }
}

/// A helper C-string argument, `None` when the pointer is null or not UTF-8.
fn cstr<'a>(ptr: *const c_char) -> Option<&'a str> {
    (!ptr.is_null()).then(|| unsafe { CStr::from_ptr(ptr) }).and_then(|c| c.to_str().ok())
}

/// Leak `bytes` to the caller, writing its length through `out_len`.
fn leak_bytes(bytes: Vec<u8>, out_len: *mut u32) -> *mut u8 {
    let len = bytes.len() as u32;
    unsafe {
        if !out_len.is_null() {
            *out_len = len;
        }
    }
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}

fn base64_encode(data: &[u8]) -> String {
    base64::engine::general_purpose::STANDARD.encode(data)
}

fn json_error(err: &str) -> *mut c_char {
    let resp = json!({
        "success": false,
        "error": err
    });
    CString::new(resp.to_string()).unwrap_or_default().into_raw()
}

fn json_success(data: Value) -> *mut c_char {
    let resp = json!({
        "success": true,
        "data": data
    });
    CString::new(resp.to_string()).unwrap_or_default().into_raw()
}

#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_version() -> *mut c_char {
    let s = CString::new("PdfCraft Mobile 0.14.0 (Engine: Hayro + RustCrypto + Cos)").unwrap_or_default();
    s.into_raw()
}

#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_free_bytes(ptr: *mut u8, len: u32) {
    if !ptr.is_null() && len > 0 {
        unsafe {
            drop(Vec::from_raw_parts(ptr, len as usize, len as usize));
        }
    }
}

/// Call any PdfCraft automation tool by name with JSON arguments.
/// Returns a JSON string with `{"success": true, "data": ...}` or `{"success": false, "error": ...}`.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_call_json(
    tool_name_ptr: *const c_char,
    args_json_ptr: *const c_char,
) -> *mut c_char {
    if tool_name_ptr.is_null() || args_json_ptr.is_null() {
        return json_error("Null pointer passed to pdfcraft_mobile_call_json");
    }

    let tool_name = match unsafe { CStr::from_ptr(tool_name_ptr) }.to_str() {
        Ok(s) => s,
        Err(e) => return json_error(&format!("Invalid tool name UTF-8: {e}")),
    };

    let args_str = match unsafe { CStr::from_ptr(args_json_ptr) }.to_str() {
        Ok(s) => s,
        Err(e) => return json_error(&format!("Invalid arguments UTF-8: {e}")),
    };

    let args_value: Value = match serde_json::from_str(args_str) {
        Ok(v) => v,
        Err(e) => return json_error(&format!("Failed to parse JSON arguments: {e}")),
    };

    let mut auto = match AUTOMATION.lock() {
        Ok(guard) => guard,
        Err(poison) => poison.into_inner(),
    };

    match auto.call(tool_name, &args_value) {
        Ok(contents) => {
            let mut items = Vec::new();
            for c in contents {
                match c {
                    Content::Json(val) => items.push(val),
                    Content::Png { width, height, data } => items.push(json!({
                        "type": "png",
                        "width": width,
                        "height": height,
                        "bytes_len": data.len(),
                        "base64": base64_encode(&data),
                    })),
                }
            }
            if items.len() == 1 {
                json_success(items.remove(0))
            } else {
                json_success(Value::Array(items))
            }
        }
        Err(e) => json_error(&e.to_string()),
    }
}

/// Directly creates a blank PDF in-memory using `pdfcraft-create`.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_create_blank(
    width: f64,
    height: f64,
    pages: u32,
    out_len: *mut u32,
) -> *mut u8 {
    let w = if width > 0.0 { width } else { LETTER.0 };
    let h = if height > 0.0 { height } else { LETTER.1 };
    let p = if pages > 0 { pages as usize } else { 1 };

    let doc = match blank(w, h, p) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    let len = bytes.len() as u32;
    unsafe {
        if !out_len.is_null() {
            *out_len = len;
        }
    }
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}

/// Directly creates a text PDF in-memory using `pdfcraft-create`.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_create_from_text(
    title_ptr: *const c_char,
    text_ptr: *const c_char,
    font_size: f64,
    out_len: *mut u32,
) -> *mut u8 {
    let title = if title_ptr.is_null() {
        "Document"
    } else {
        unsafe { CStr::from_ptr(title_ptr) }.to_str().unwrap_or("Document")
    };

    let text = if text_ptr.is_null() {
        ""
    } else {
        unsafe { CStr::from_ptr(text_ptr) }.to_str().unwrap_or("")
    };

    let size = if font_size > 4.0 && font_size < 72.0 { font_size } else { 12.0 };

    let doc = match from_text(title, text, LETTER, size) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    let len = bytes.len() as u32;
    unsafe {
        if !out_len.is_null() {
            *out_len = len;
        }
    }
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}

/// Renders a single PDF page directly to PNG bytes using `pdfcraft-render`.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_render_page_png(
    pdf_bytes: *const u8,
    pdf_len: u32,
    page_1_based: u32,
    dpi: f32,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 {
        return std::ptr::null_mut();
    }

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());

    let scale = if dpi > 10.0 && dpi <= 600.0 { dpi / 72.0 } else { 96.0 / 72.0 };
    let page_idx = if page_1_based >= 1 { (page_1_based - 1) as usize } else { 0 };

    let mut renderer = PageRenderer::new(data, RenderConfig::default());
    let res = renderer.render(RenderRequest {
        page: page_idx,
        kind: RequestKind::Pixels,
        tile: None,
        scale,
        tag: 0,
        preview: false,
    });

    if res.error.is_some() || res.width == 0 || res.height == 0 {
        return std::ptr::null_mut();
    }

    let png_bytes = match pdfcraft_engine::export::encode_png(res.width, res.height, &res.rgba) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    let len = png_bytes.len() as u32;
    unsafe {
        if !out_len.is_null() {
            *out_len = len;
        }
    }
    let mut boxed = png_bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}

/// Inspects a PDF and returns metadata + page info in JSON format.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_inspect(
    pdf_bytes: *const u8,
    pdf_len: u32,
) -> *mut c_char {
    if pdf_bytes.is_null() || pdf_len == 0 {
        return json_error("Empty or null PDF bytes");
    }

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());

    let doc = match Document::open(data.clone()) {
        Ok(d) => d,
        Err(e) => return json_error(&format!("Failed to open PDF: {e}")),
    };

    let doc_info = match pdfcraft_render::inspect(data.clone(), None) {
        Ok(i) => i,
        Err(e) => return json_error(&format!("Failed to inspect PDF: {e}")),
    };

    let trust = TrustStore::default();
    let signatures = pdfcraft_sign::signatures(&doc, &data, &trust);

    let pages: Vec<Value> = doc_info
        .pages
        .iter()
        .enumerate()
        .map(|(idx, p)| {
            json!({
                "page": idx + 1,
                "label": p.label,
                "width": p.width,
                "height": p.height,
                "rotation": p.rotation
            })
        })
        .collect();

    let sig_list: Vec<Value> = signatures
        .iter()
        .map(|s| {
            json!({
                "field": s.field,
                "signed": s.signed,
                "signer": s.signer,
                "reason": s.reason,
                "location": s.location,
                "date": s.date,
                "status": if !s.signed { "unsigned".to_string() } else { format!("{:?}", s.status).to_lowercase() }
            })
        })
        .collect();

    let result = json!({
        "page_count": doc_info.pages.len(),
        "title": doc_info.title,
        "author": doc_info.author,
        "subject": doc_info.subject,
        "creator": doc_info.creator,
        "producer": doc_info.producer,
        "pdf_version": doc_info.pdf_version,
        "is_encrypted": doc_info.encrypted,
        "is_tagged": doc_info.tagged,
        "pages": pages,
        "signatures": sig_list
    });

    json_success(result)
}

/// Adds a text watermark to the document.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_add_watermark(
    pdf_bytes: *const u8,
    pdf_len: u32,
    text_ptr: *const c_char,
    opacity: f64,
    rotation: f64,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 || text_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let text = match unsafe { CStr::from_ptr(text_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());

    let mut doc = match Document::open(data.clone()) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let doc_info = match pdfcraft_render::inspect(data, None) {
        Ok(i) => i,
        Err(_) => return std::ptr::null_mut(),
    };

    let page_count = doc_info.pages.len();
    let all_pages: Vec<usize> = (0..page_count).collect();

    let wm = Watermark {
        text: text.to_string(),
        opacity: if opacity > 0.0 && opacity <= 1.0 { opacity } else { 0.3 },
        rotation: if rotation.is_finite() { rotation } else { 45.0 },
        font_size: 48.0,
        behind: false,
        ..Default::default()
    };

    if add_watermark(&mut doc, &all_pages, &wm, true).is_err() {
        return std::ptr::null_mut();
    }

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    let len = bytes.len() as u32;
    unsafe {
        if !out_len.is_null() {
            *out_len = len;
        }
    }
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}

/// Rotates a page in degrees (must be 90, 180, 270, or -90).
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_rotate_page(
    pdf_bytes: *const u8,
    pdf_len: u32,
    page_1_based: u32,
    degrees: i32,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 || page_1_based < 1 {
        return std::ptr::null_mut();
    }

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());

    let mut doc = match Document::open(data) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let root_ref = match doc.root() {
        Some(r) => r,
        None => return std::ptr::null_mut(),
    };

    let pages_ref = match doc.get(root_ref).as_dict().and_then(|d| d.reference(b"Pages")) {
        Some(r) => r,
        None => return std::ptr::null_mut(),
    };

    let page_objs = match doc.get(pages_ref).as_dict().and_then(|d| d.get(b"Kids")).and_then(|k| k.as_array()) {
        Some(arr) => arr.iter().filter_map(|x| x.as_ref()).collect::<Vec<_>>(),
        None => return std::ptr::null_mut(),
    };

    let target_page_idx = (page_1_based - 1) as usize;
    if target_page_idx >= page_objs.len() {
        return std::ptr::null_mut();
    }

    let page_obj_ref = page_objs[target_page_idx];

    let _ = doc.update_dict(page_obj_ref, |d| {
        let current_rotate = d.int(b"Rotate").unwrap_or(0);
        let new_rotate = (current_rotate + degrees as i64).rem_euclid(360);
        d.set(b"Rotate".to_vec(), Object::Int(new_rotate));
    });

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    leak_bytes(bytes, out_len)
}

/// Adds editable text to a page (WYSIWYG item: kept as a PdfCraft `Added` mark, editable later).
/// `x, y` are the top-left of the text box in view space (points, y down from the page top).
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_add_text(
    pdf_bytes: *const u8,
    pdf_len: u32,
    page_1_based: u32,
    x: f64,
    y: f64,
    width: f64,
    text_ptr: *const c_char,
    font_ptr: *const c_char,
    size: f64,
    bold: bool,
    italic: bool,
    color_r: f64,
    color_g: f64,
    color_b: f64,
    align_ptr: *const c_char,
    out_len: *mut u32,
) -> *mut u8 {
    let Some(text) = cstr(text_ptr) else { return std::ptr::null_mut() };
    if pdf_bytes.is_null() || pdf_len == 0 || page_1_based == 0 || text.is_empty() {
        return std::ptr::null_mut();
    }
    let page = (page_1_based - 1) as usize;

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());
    let mut doc = match Document::open(data) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let (_, ph) = match page_size(&doc, page) {
        Some(s) => s,
        None => return std::ptr::null_mut(),
    };

    let family = match cstr(font_ptr).map(str::to_ascii_lowercase).as_deref() {
        Some("times" | "serif") => Family::Times,
        Some("courier" | "mono" | "monospace") => Family::Courier,
        _ => Family::Helvetica,
    };
    let align = match cstr(align_ptr) {
        Some("center" | "centre") => Align::Center,
        Some("right") => Align::Right,
        Some("justify") => Align::Justify,
        _ => Align::Left,
    };

    // View top-left → display box; the box's top is the first line's top.
    let w = if width > 8.0 { width } else { 200.0 };
    let x0 = x.max(0.0);
    let top = (ph - y).clamp(0.0, ph);
    let rect = [x0, (top - 20.0).max(0.0), x0 + w, top];

    let t = AddedText {
        rect,
        text: text.to_string(),
        family,
        bold,
        italic,
        size: if size > 2.0 && size < 400.0 { size } else { 12.0 },
        color: [color_r.clamp(0.0, 1.0), color_g.clamp(0.0, 1.0), color_b.clamp(0.0, 1.0)],
        align,
        char_spacing: 0.0,
    };

    if add_content(&mut doc, page, &AddedContent::Text(t)).is_err() {
        return std::ptr::null_mut();
    }

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    leak_bytes(bytes, out_len)
}

/// Adds an image to a page as an editable item. Pass `use_rect = true` to place it in
/// `rect` (display space `[l, b, r, t]`), else it is auto-scaled to ≤80% of the page, centered.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_add_image(
    pdf_bytes: *const u8,
    pdf_len: u32,
    page_1_based: u32,
    image_bytes: *const u8,
    image_len: u32,
    rect_l: f64,
    rect_b: f64,
    rect_r: f64,
    rect_t: f64,
    use_rect: bool,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 || page_1_based == 0 || image_bytes.is_null() || image_len == 0 {
        return std::ptr::null_mut();
    }
    let page = (page_1_based - 1) as usize;

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());
    let mut doc = match Document::open(data) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let img = unsafe { std::slice::from_raw_parts(image_bytes, image_len as usize) };
    let (image, natural) = match image_xobject(&mut doc, "image", img) {
        Ok(v) => v,
        Err(_) => return std::ptr::null_mut(),
    };

    let rect = if use_rect {
        norm_rect([rect_l, rect_b, rect_r, rect_t])
    } else {
        let Some((pw, ph)) = page_size(&doc, page) else { return std::ptr::null_mut() };
        let k = ((pw * 0.8) / natural.0).min((ph * 0.8) / natural.1).min(1.0);
        let (w, h) = (natural.0 * k, natural.1 * k);
        [(pw - w) / 2.0, (ph - h) / 2.0, (pw + w) / 2.0, (ph + h) / 2.0]
    };

    if add_content(&mut doc, page, &AddedContent::Image(AddedImage::new(rect, image))).is_err() {
        return std::ptr::null_mut();
    }

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    leak_bytes(bytes, out_len)
}

/// Lists the WYSIWYG-editable items (PdfCraft `Added` marks). View-space rects (y down).
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_list_content(pdf_bytes: *const u8, pdf_len: u32) -> *mut c_char {
    if pdf_bytes.is_null() || pdf_len == 0 {
        return json_error("Empty or null PDF bytes");
    }

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());
    let doc = match Document::open(data) {
        Ok(d) => d,
        Err(e) => return json_error(&format!("Failed to open PDF: {e}")),
    };

    let mut per_page: std::collections::HashMap<usize, usize> = Default::default();
    let mut items = Vec::new();
    for a in list_added(&doc) {
        let index = per_page.entry(a.page).or_default();
        let ph = page_size(&doc, a.page).map(|s| s.1).unwrap_or(0.0);
        let [l, b, r, t] = a.content.rect();
        // Display → view (y down).
        let rect = [l, ph - t, r, ph - b];
        let mut v = json!({ "page": a.page + 1, "index": *index, "rect": rect });
        *index += 1;
        match a.content {
            AddedContent::Text(t) => {
                v["type"] = json!("text");
                v["text"] = json!(t.text);
                v["font"] = json!(t.family.label());
                v["size"] = json!(t.size);
                v["bold"] = json!(t.bold);
                v["italic"] = json!(t.italic);
                v["color"] = json!(t.color);
                v["align"] = json!(match t.align {
                    Align::Left => "left",
                    Align::Center => "center",
                    Align::Right => "right",
                    Align::Justify => "justify",
                });
            }
            AddedContent::Image(_) => {
                v["type"] = json!("image");
            }
        }
        items.push(v);
    }

    json_success(json!({ "count": items.len(), "items": items }))
}

/// Updates item `index` (0-based, among its page's items): new text, new view-space rect, or both.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_update_content(
    pdf_bytes: *const u8,
    pdf_len: u32,
    page_1_based: u32,
    index: u32,
    text_ptr: *const c_char,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    use_rect: bool,
    font_ptr: *const c_char,
    size: f64,
    bold: i32,
    italic: i32,
    color_r: f64,
    color_g: f64,
    color_b: f64,
    align_ptr: *const c_char,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 || page_1_based == 0 {
        return std::ptr::null_mut();
    }
    let page = (page_1_based - 1) as usize;

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());
    let mut doc = match Document::open(data) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    let Some(item) = list_added(&doc).into_iter().filter(|a| a.page == page).nth(index as usize) else {
        return std::ptr::null_mut();
    };
    let ph = page_size(&doc, page).map(|s| s.1).unwrap_or(0.0);

    let mut content = item.content;
    if use_rect {
        let x0 = x.max(0.0);
        let h = if height > 2.0 { height } else { 20.0 };
        let w = if width > 8.0 { width } else { 200.0 };
        let top = (ph - y).clamp(0.0, ph);
        content = content.with_rect([x0, (top - h).max(0.0), x0 + w, top]);
    }
    if let AddedContent::Text(t) = &mut content {
        if let Some(s) = cstr(text_ptr) {
            t.text = s.to_string();
        }
        if let Some(f) = cstr(font_ptr).map(str::to_ascii_lowercase) {
            t.family = match f.as_str() {
                "times" | "serif" => Family::Times,
                "courier" | "mono" | "monospace" => Family::Courier,
                _ => Family::Helvetica,
            };
        }
        if size > 2.0 && size < 400.0 {
            t.size = size;
        }
        if bold >= 0 {
            t.bold = bold > 0;
        }
        if italic >= 0 {
            t.italic = italic > 0;
        }
        if color_r >= 0.0 {
            t.color = [color_r.clamp(0.0, 1.0), color_g.clamp(0.0, 1.0), color_b.clamp(0.0, 1.0)];
        }
        if let Some(a) = cstr(align_ptr) {
            t.align = match a {
                "center" | "centre" => Align::Center,
                "right" => Align::Right,
                "justify" => Align::Justify,
                _ => Align::Left,
            };
        }
    }

    if update_content(&mut doc, page, index as usize, &content).is_err() {
        return std::ptr::null_mut();
    }

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    leak_bytes(bytes, out_len)
}

/// Deletes item `index` (0-based) from `page` (1-based).
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_delete_content(
    pdf_bytes: *const u8,
    pdf_len: u32,
    page_1_based: u32,
    index: u32,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 || page_1_based == 0 {
        return std::ptr::null_mut();
    }

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());
    let mut doc = match Document::open(data) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    if delete_content(&mut doc, (page_1_based - 1) as usize, index as usize).is_err() {
        return std::ptr::null_mut();
    }

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    leak_bytes(bytes, out_len)
}

/// 32 bytes of entropy for new encryption keys (std `RandomState`, OS-seeded; no extra deps).
fn entropy() -> [u8; 32] {
    use std::hash::{BuildHasher, Hasher};
    let mut out = [0u8; 32];
    for (i, chunk) in out.chunks_mut(8).enumerate() {
        let mut h = std::collections::hash_map::RandomState::new().build_hasher();
        h.write_usize(i);
        chunk.copy_from_slice(&h.finish().to_le_bytes());
    }
    out
}

/// Encrypts the document. `open_password` may be null (opens freely, restrictions hold);
/// `owner_password` null means a random one. `changes_level`/`printing_level`: 0 none, 1 low,
/// 2 high (printing); changes: 0 none, 1 pages, 2 fill+sign, 3 comment+fill+sign, 4 any but extract.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_protect(
    pdf_bytes: *const u8,
    pdf_len: u32,
    open_password_ptr: *const c_char,
    owner_password_ptr: *const c_char,
    printing_level: i32,
    changes_level: i32,
    allow_copy: bool,
    algorithm_ptr: *const c_char,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 {
        return std::ptr::null_mut();
    }
    let open_pw = cstr(open_password_ptr).filter(|s| !s.is_empty());
    let owner_pw = cstr(owner_password_ptr).filter(|s| !s.is_empty());
    if open_pw.is_none() && owner_pw.is_none() {
        return std::ptr::null_mut(); // nothing to protect with
    }
    if let (Some(a), Some(b)) = (open_pw, owner_pw) && a == b {
        return std::ptr::null_mut(); // the two passwords must differ
    }

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());
    let mut doc = match Document::open(data) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    // Permission bits (ISO 32000-2 Table 22) as Acrobat maps its choices.
    let bit = |n: u32| 1i32 << (n - 1);
    let mut p = 0i32;
    match printing_level {
        1 => p |= bit(3),
        lvl if lvl >= 2 => p |= bit(3) | bit(12),
        _ => {}
    }
    match changes_level {
        1 => p |= bit(11),
        2 => p |= bit(9),
        3 => p |= bit(6) | bit(9),
        lvl if lvl >= 4 => p |= bit(4) | bit(6) | bit(9),
        _ => {}
    }
    if allow_copy {
        p |= bit(5) | bit(10);
    }
    if owner_pw.is_none() {
        p = -1; // nothing restricted without a permissions password
    }

    let algorithm = match cstr(algorithm_ptr).map(str::to_ascii_lowercase).as_deref() {
        Some("rc4-40" | "rc4_40") => Algorithm::Rc4_40,
        Some("rc4-128" | "rc4_128") => Algorithm::Rc4_128,
        Some("aes-128" | "aes128") => Algorithm::Aes128,
        _ => Algorithm::Aes256,
    };

    let seed = entropy();
    // Without a permissions password nothing is restricted, so the owner password is a
    // random one nobody needs (as the engine does).
    let random_owner: String = entropy().iter().map(|b| format!("{b:02x}")).collect();
    let params = NewEncryption {
        algorithm,
        user_password: open_pw.unwrap_or(""),
        owner_password: owner_pw.unwrap_or(&random_owner),
        permissions: p,
        encrypt_metadata: true,
        seed,
    };

    if doc.set_encryption(&params).is_err() {
        return std::ptr::null_mut();
    }

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    leak_bytes(bytes, out_len)
}

/// Removes encryption from a document opened with its owner (permissions) password.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_unprotect(
    pdf_bytes: *const u8,
    pdf_len: u32,
    password_ptr: *const c_char,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 {
        return std::ptr::null_mut();
    }

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());
    let pw = cstr(password_ptr);
    let mut doc = match Document::open_with_password(data, pw) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    if doc.output_handler().is_none() {
        return std::ptr::null_mut(); // not protected
    }
    doc.remove_encryption();

    let bytes = match write_full(&doc, &SaveOptions::default()) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    leak_bytes(bytes, out_len)
}

/// Digitally signs the PDF with a self-signed P-256 certificate and optional drawn signature strokes.
#[unsafe(no_mangle)]
pub extern "C" fn pdfcraft_mobile_sign_pdf(
    pdf_bytes: *const u8,
    pdf_len: u32,
    page_1_based: u32,
    rect_x: f64,
    rect_y: f64,
    rect_w: f64,
    rect_h: f64,
    signer_name_ptr: *const c_char,
    reason_ptr: *const c_char,
    location_ptr: *const c_char,
    strokes_json_ptr: *const c_char,
    out_len: *mut u32,
) -> *mut u8 {
    if pdf_bytes.is_null() || pdf_len == 0 {
        return std::ptr::null_mut();
    }

    let signer_name = if signer_name_ptr.is_null() {
        "PdfCraft Signer".to_string()
    } else {
        unsafe { CStr::from_ptr(signer_name_ptr) }.to_str().unwrap_or("PdfCraft Signer").to_string()
    };

    let reason = if reason_ptr.is_null() {
        None
    } else {
        Some(unsafe { CStr::from_ptr(reason_ptr) }.to_str().unwrap_or("Approved").to_string())
    };

    let location = if location_ptr.is_null() {
        None
    } else {
        Some(unsafe { CStr::from_ptr(location_ptr) }.to_str().unwrap_or("Mobile").to_string())
    };

    let slice = unsafe { std::slice::from_raw_parts(pdf_bytes, pdf_len as usize) };
    let data = Arc::new(slice.to_vec());

    let doc = match Document::open(data) {
        Ok(d) => d,
        Err(_) => return std::ptr::null_mut(),
    };

    // Generate self-signed key & certificate
    let now = chrono::Utc::now().timestamp();
    let key = match PrivateKey::generate_p256() {
        Ok(k) => k,
        Err(_) => return std::ptr::null_mut(),
    };

    let dn = X509Name::build(&signer_name, "Mobile Device", "PdfCraft", "", "US");
    let serial = DigestAlg::Sha256.digest(&[signer_name.as_bytes(), &now.to_be_bytes()])[..8].to_vec();
    let cert = match Certificate::self_signed(&dn, &key, Time::from_unix(now), 5, &serial) {
        Ok(c) => c,
        Err(_) => return std::ptr::null_mut(),
    };

    let id = DigitalId {
        key,
        certificate: cert,
        chain: Vec::new(),
        friendly_name: Some(signer_name.clone()),
    };

    // Parse strokes if present: [[[x, y], ...], ...] normalized 0..1
    let mut graphic = None;
    if !strokes_json_ptr.is_null() {
        if let Ok(json_str) = unsafe { CStr::from_ptr(strokes_json_ptr) }.to_str() {
            if let Ok(Value::Array(strokes_val)) = serde_json::from_str(json_str) {
                let mut stroke_paths = Vec::new();
                for stroke in strokes_val {
                    if let Value::Array(pts) = stroke {
                        let mut p_vec = Vec::new();
                        for p in pts {
                            if let Value::Array(coords) = p {
                                if coords.len() >= 2 {
                                    if let (Some(x), Some(y)) = (coords[0].as_f64(), coords[1].as_f64()) {
                                        p_vec.push([x, y]);
                                    }
                                }
                            }
                        }
                        if !p_vec.is_empty() {
                            stroke_paths.push(p_vec);
                        }
                    }
                }
                if !stroke_paths.is_empty() {
                    graphic = Some(Graphic::Strokes(stroke_paths));
                }
            }
        }
    }

    let page_0_based = if page_1_based >= 1 { (page_1_based - 1) as usize } else { 0 };
    let rect = if rect_w > 0.0 && rect_h > 0.0 {
        Some([rect_x, rect_y, rect_x + rect_w, rect_y + rect_h])
    } else {
        Some([50.0, 50.0, 250.0, 120.0])
    };

    let opts = SignOptions {
        page: page_0_based,
        rect,
        reason,
        location,
        contact: None,
        date: Time::from_unix(now).to_pdf(),
        certify: None,
        appearance: Appearance {
            name: true,
            date: true,
            reason: true,
            location: true,
            labels: true,
            distinguished_name: false,
        },
        graphic,
        ..Default::default()
    };

    let signed_bytes = match sign(&doc, &id, &opts) {
        Ok(b) => b,
        Err(_) => return std::ptr::null_mut(),
    };

    let len = signed_bytes.len() as u32;
    unsafe {
        if !out_len.is_null() {
            *out_len = len;
        }
    }
    let mut boxed = signed_bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}
