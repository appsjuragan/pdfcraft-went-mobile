# PdfCraft Mobile (`MobilePDFCraft`)

A high-performance Flutter mobile application targeting Android (with desktop testing support), designed with a clean, authentic Facebook-like aesthetic and powered by the core Rust engine of **PdfCraft**.

---

## 🌟 Key Highlights & Philosophy

- **No Login Wall:** Instant access. Users can immediately open, inspect, create, edit, and cryptographically sign PDFs without any authentication friction.
- **Clean Facebook-like Aesthetic:**
  - Meta Blue primary color (`#1877F2`) and subtle light-blue accents (`#E7F3FF`).
  - Off-white card feed background (`#F0F2F5`) with crisp, rounded card surfaces.
  - "What's on your mind?" composer box for instant PDF actions (Open, Blank, Text to PDF, Sign).
  - Social-style feed cards displaying document details, page thumbnails, metadata chips, and action rows.
  - Top tab icon navigation bar with notification badges for unsigned contracts.
- **Powered by `pdfcraft` Core Engine:**
  - **Open & Inspect:** Extracts structural metadata, page counts, encryption status, and validates existing digital signatures conforming to ISO 32000-2.
  - **High-Speed Rendering:** Renders PDF pages to crisp PNGs directly from memory.
  - **Edit & Transform:** Applies diagonal translucent watermarks and rotates individual or document pages without quality loss.
  - **P-256 Cryptographic Signing:** Generates NIST P-256 Elliptic Curve keypairs and self-signed X.509 certificates on-device. Embeds `ETSI.CAdES.detached` digital signatures with interactive vector stroke appearance contours from the touch/stylus signature pad.
  - **Zero-Crash Architecture:** Dual-engine architecture featuring the native Rust `cdylib` via Dart FFI and a fallback ISO 32000-2 pure-Dart engine to ensure zero crashes under all testing and execution environments.

---

## 📱 Application Modules & Views

1. **Documents Feed (`FeedView`):**
   - Facebook-style composer box:
     - Avatar pill with user initials.
     - "What PDF would you like to craft today?" interactive trigger.
     - Quick action buttons: **Open PDF**, **New Blank**, **Sign PDF**.
   - Quick action story carousel: **Open Document**, **Create Blank**, **Text to PDF**, **Sign Contract**, **Watermark**.
   - Feed cards with author, timestamp, page preview, cryptographic badge, and action bar.
2. **Viewer & Studio (`ViewerEditorView`):**
   - High-fidelity interactive page viewer with pinch-to-zoom and pan.
   - Multi-page floating pagination pill (`Page X of Y`).
   - Bottom edit toolbar:
     - **Watermark:** Customizable text preset, opacity slider, and rotation angle.
     - **Rotate:** 90°, 180°, or 270° clockwise page orientation transform.
     - **Sign PDF:** Direct jump to cryptographic signing studio.
     - **Inspect:** Detailed internal PDF tree and metadata analysis.
     - **Share:** Export and share PDF through native system sharesheet.
3. **Signature Studio (`SignView`):**
   - Signer metadata form (Full Name, Purpose/Reason, Location).
   - Vector touch/stylus drawing canvas with bezier smoothing, stroke normalization, undo, and clear controls.
   - Signature placement selector (Bottom Right, Bottom Left, Center).
   - Execution button: Signs PDF with P-256 ECDSA and embeds vector stroke contours.
4. **Audit & Inspection (`InspectView`):**
   - Digital signatures validator (Signer Name, Reason, Location, Algorithm, Digest status).
   - Technical PDF attributes (Page dimensions, rotation, byte size, engine status).
   - Raw JSON inspector modal for developers and power users.

---

## 🏗️ Architecture & Directory Layout

```
MobilePDFCraft/
├── android/                         # Android application project
│   ├── app/
│   │   ├── build.gradle.kts         # Configured with minSdk 21 and jniLibs
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Storage permissions and PdfCraft label
│   │       └── jniLibs/             # Native library binaries (arm64-v8a, x86_64)
│   └── local.properties             # SDK and Flutter paths
├── rust/                            # Native C-ABI bridge crate (pdfcraft-mobile)
│   ├── Cargo.toml                   # cdylib target and repo vendored patches
│   └── src/lib.rs                   # C-ABI export functions:
│       ├── pdfcraft_mobile_version
│       ├── pdfcraft_mobile_call_json
│       ├── pdfcraft_mobile_create_blank
│       ├── pdfcraft_mobile_create_from_text
│       ├── pdfcraft_mobile_render_page_png
│       ├── pdfcraft_mobile_inspect
│       ├── pdfcraft_mobile_add_watermark
│       ├── pdfcraft_mobile_rotate_page
│       ├── pdfcraft_mobile_sign_pdf
│       └── pdfcraft_mobile_free_bytes / free_string
├── lib/                             # Flutter Dart codebase
│   ├── main.dart                    # Application root, theme binding & navigation
│   ├── core/
│   │   └── pdfcraft_bridge.dart     # DynamicLibrary FFI loader & pure-Dart fallback
│   ├── models/
│   │   └── pdf_document_item.dart   # Document model with metadata & preview cache
│   ├── state/
│   │   └── pdf_state.dart           # Reactive state management (Listenable)
│   └── ui/
│       ├── theme/
│       │   └── facebook_theme.dart  # Meta/Facebook design tokens & palette
│       ├── dialogs/
│       │   └── create_dialog.dart   # Blank PDF, Text-to-PDF, Watermark & Rotate dialogs
│       ├── widgets/
│       │   ├── fb_app_bar.dart      # Facebook top bar with engine status indicator
│       │   ├── fb_tab_bar.dart      # Icon tab navigation with badge counts
│       │   ├── fb_post_card.dart    # Feed card displaying document details
│       │   └── signature_pad.dart   # Vector touch/stylus drawing canvas
│       └── views/
│           ├── feed_view.dart       # Composer box + document feed
│           ├── viewer_editor_view.dart # Page viewer & edit toolbar
│           ├── sign_view.dart       # Signature Studio
│           └── inspect_view.dart    # Document audit & metadata
└── test/
    ├── widget_test.dart             # UI smoke test
    └── pdfcraft_state_test.dart     # Comprehensive unit tests for state, bridge & models
```

---

## 🚀 Running & Verification

### Running Analysis & Tests
```powershell
cd d:\source_code\pdfcraft-went-mobile\MobilePDFCraft
D:\flutter\bin\flutter.bat analyze
D:\flutter\bin\flutter.bat test
```

### Running on Android
Connect an Android device or start an emulator with ADB (`D:\Android\android-sdk\platform-tools\adb.exe`):
```powershell
D:\flutter\bin\flutter.bat run -d android
```

### Running on Windows Desktop
```powershell
D:\flutter\bin\flutter.bat run -d windows
```
