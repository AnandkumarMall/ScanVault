# ScanVault Design System & Product Specification

## 1. Design Philosophy

ScanVault is built on the premise that a utility application should be invisible. The interface exists solely to support the document. The app must convey trustworthiness, reliability, and absolute privacy. 

**Core Principles:**
*   **Simplicity Before Decoration:** Every visual element must serve a functional purpose. If removing a border, a shadow, or a color improves clarity, it must be removed.
*   **Calm Interface:** The user should focus entirely on their documents (passports, legal contracts, tax forms), not on the interface. The UI must recede into the background.
*   **Absolute Consistency:** Spacing, typography, motion, and elevation must follow strict, mathematically sound scales. There is no room for arbitrary values.
*   **Professional Trust:** As an offline vault storing sensitive documents, the app must feel as secure as a physical safe. It must never feel playful, trendy, or experimental. We design for longevity, ensuring the product looks just as modern five years from now.

---

## 2. Visual Language

Our visual style is defined by **Modern Minimalism** and **Quiet Confidence**. 
We rely on soft depth, subtle elevation, and high readability. We explicitly avoid visual clutter and common UI clichés (e.g., pervasive glassmorphism, glowing neon borders, excessive blur, and oversized border radii). The interface must feel handcrafted, grounded, and native to the device.

---

## 3. Color System

Color is used intentionally to communicate hierarchy and state, never for mere decoration.

### Dark Mode (Primary Focus for Privacy/Security Contexts)
*   **Background:** `#0F172A` (Slate 900) — The base app background.
*   **Canvas:** `#020617` (Slate 950) — Behind document previews for maximum contrast.
*   **Surface/Cards:** `#1E293B` (Slate 800) — Elevated elements (cards, bottom sheets).
*   **Primary Accent:** `#4F46E5` (Indigo 600) — Primary buttons, active states, selections.
*   **Success:** `#10B981` (Emerald 500) — Confirmations, saved states.
*   **Warning:** `#F59E0B` (Amber 500) — Destructive actions that can be undone.
*   **Danger:** `#EF4444` (Red 500) — Permanent deletions.
*   **Text Primary:** `#F8FAFC` (Slate 50) — Headings, body text.
*   **Text Secondary:** `#94A3B8` (Slate 400) — Metadata, timestamps, placeholders.
*   **Border/Divider:** `#334155` (Slate 700) — Subtle separation of content.

### Light Mode
*   **Background:** `#F8FAFC` (Slate 50)
*   **Surface/Cards:** `#FFFFFF` (Pure White)
*   **Primary Accent:** `#4F46E5` (Indigo 600)
*   **Text Primary:** `#0F172A` (Slate 900)
*   **Text Secondary:** `#64748B` (Slate 500)
*   **Border/Divider:** `#E2E8F0` (Slate 200)

---

## 4. Typography

**Primary Font:** `Plus Jakarta Sans` (Fallback: `Inter`)
Typography establishes hierarchy through weight, size, and color.

| Role | Size | Weight | Line Height | Letter Spacing | Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Display** | 32sp | Bold (700) | 1.2 | -0.5px | Empty states, major onboarding steps. |
| **H1** | 24sp | SemiBold (600)| 1.3 | -0.3px | Screen titles, Large app bar headers. |
| **H2** | 18sp | SemiBold (600)| 1.4 | -0.2px | Section headers, Bottom sheet titles. |
| **Body** | 16sp | Regular (400) | 1.5 | 0px | Main text, document descriptions. |
| **Label** | 14sp | Medium (500) | 1.4 | 0.1px | Form labels, settings list items. |
| **Button** | 14sp | SemiBold (600)| 1.0 | 0.2px | Text inside buttons (Primary/Secondary). |
| **Caption** | 12sp | Regular (400) | 1.3 | 0.2px | Timestamps, page counts, secondary metadata. |

---

## 5. Spacing System

All spacing (margins, padding, gaps) must strictly adhere to this scale. Do not invent values.

*   `4dp` — Micro adjustments (e.g., between an icon and its label).
*   `8dp` — Tight relationship (e.g., between title and subtitle).
*   `12dp` — Standard component padding (inner).
*   `16dp` — Default screen margin; standard gutter.
*   `20dp` — Loose component relationship.
*   `24dp` — Distinct section separation.
*   `32dp` — Major grouping separation.
*   `40dp` — Large whitespace block.
*   `48dp` — Minimum accessible touch target size.
*   `64dp` — Bottom padding to clear FABs or bottom navigation.

---

## 6. Border Radius

Geometry must be consistent to maintain a professional feel. Avoid oversized, pill-shaped aesthetics unless it is a specific primary action button.

*   **Small Components (Chips, Tags, Checkboxes):** `8dp`
*   **Buttons (Standard & Primary):** `12dp`
*   **Document Thumbnails:** `12dp`
*   **Cards & List Items:** `16dp`
*   **Dialogs:** `24dp`
*   **Bottom Sheets:** `28dp` (Top corners only)

---

## 7. Elevation

Elevation relies on subtle contrast and shadow, avoiding heavy, dramatic, or colored drop shadows. In Dark Mode, elevation is achieved entirely through background lightness (Surface color), not shadows.

*   **Level 0 (Flat):** Main background, standard text.
*   **Level 1 (Cards):** Document cards, list items. (Light mode: 2px blur shadow, 4% opacity).
*   **Level 2 (Floating):** FABs, Dialogs, Bottom Sheets, Snackbars. (Light mode: 8px blur shadow, 8% opacity).

---

## 8. Motion System

Motion is structural. It exists to explain spatial relationships and acknowledge user input, not to entertain. All curves should be standard `easeOut` or `fastOutSlowIn`.

*   **Button Press (Scale):** Scale down to `0.97`, duration `100ms`.
*   **Card Selection/Highlight:** `120ms` color fade.
*   **Screen Navigation (Push/Pop):** `250ms` subtle slide + fade.
*   **Bottom Sheet (Slide up):** `300ms` with a very subtle, dampened spring.
*   **Hero Transition (Thumbnail to Preview):** `300ms` ease-out.

---

## 9. Haptics

Haptics provide physical confirmation of digital actions. They must be used sparingly.

*   **Light Impact:** Button taps, crop corner adjustments, slider stops/detents, page reordering drop.
*   **Medium Impact:** Successful document capture, document saved to vault, success snackbars.
*   **Heavy Impact:** Never used.

---

## 10. Iconography

*   **Family:** Consistent rounded outline style (e.g., Phosphor Icons or standard Material Symbols Rounded).
*   **Size:** Standard `24dp`.
*   **Stroke:** Consistent `1.5px` or `2px` stroke weight across all icons. 
*   **Rule:** Never mix filled and outline styles arbitrarily (use filled only to denote an active/selected state in bottom navigation).

---

## 11. Component Library

*All components must meet the 48dp minimum touch target requirement.*

1.  **PrimaryButton:** Solid `#4F46E5` background, white text. Radius `12dp`. Uses `ScaleTransition` on press. 
2.  **SecondaryButton:** Transparent background, `1.5px` border of `#334155` (Dark) / `#E2E8F0` (Light). 
3.  **IconButton:** `48x48dp` touch target, icon centered. Transparent background until pressed.
4.  **FloatingActionButton:** `56x56dp` circle, solid Primary Accent, Level 2 elevation.
5.  **SearchBar:** Radius `12dp`, Surface background color, leading search icon, placeholder text in `Text Secondary`.
6.  **SegmentedControl:** Used for view toggles. Tight padding, active state uses Surface color on Background.
7.  **BottomSheet:** Top radius `28dp`, drag handle indicator (`4x32dp` pill).
8.  **DocumentCard:** Radius `16dp`, Level 1 elevation. Contains `DocumentThumbnail` (`12dp` radius).
9.  **FilterChip:** Radius `8dp`, Surface background, Primary Accent when selected.
10. **CropHandle:** `24dp` circular touch target, transparent center with a solid white border, precise crosshair in the middle.
11. **Magnifier:** Appears exactly `48dp` above the touch point during crop adjustment. Shows 2x zoom of pixels underneath the finger.

*Flutter Implementation Note:* Prefer stateless widgets with implicit animation wrappers (`AnimatedContainer`, `AnimatedScale`) over heavy `AnimationController` boilerplate where possible.

---

## 12. Screen-by-Screen Design

### 1. Splash & 2. Onboarding
*   **Purpose:** Instant loading, establish trust immediately.
*   **Layout:** Centered discrete logo. Onboarding emphasizes "Offline, Secure, Yours" using H1 typography. No paginated carousels if possible; a single concise welcome screen is preferred.

### 3. Permissions
*   **Purpose:** Explain *why* camera and storage access is needed before prompting the OS dialog.
*   **Layout:** H1 header, simple Body text. Two prominent Primary/Secondary buttons.

### 4. Home Vault
*   **Purpose:** Quick access to all scans. 
*   **Layout:** Large Title ("Vault"). SearchBar underneath. Grid or List view of `DocumentCard`s. FAB in the bottom right for capturing.
*   **States:** Scroll triggers subtle elevation on the AppBar.

### 6. Camera & 7. Auto Detection
*   **Purpose:** Fast, frictionless document capture.
*   **Layout:** Immersive edge-to-edge camera preview. 
*   **Detection:** Subtle, thin blue (`#4F46E5`) polygon overlays the detected document. NO neon glowing borders.
*   **Controls:** Bottom safe area contains a circular shutter button, flash toggle, and a thumbnail to enter the review stack.

### 8. Crop Editor
*   **Purpose:** Pixel-perfect manual adjustments.
*   **Layout:** Canvas background (`#020617`). The document is elevated. 
*   **Interactions:** Dragging a `CropHandle` triggers the `Magnifier` and Light haptic feedback.

### 9. Enhancement
*   **Purpose:** Filter and adjust legibility.
*   **Layout:** Document preview top 70%. Bottom sheet contains `FilterChip`s (B&W, Grayscale, Color). Sliders for contrast/brightness if advanced mode is toggled.

### 10. Multi-page Reordering
*   **Purpose:** Manage document structure.
*   **Interactions:** Long-press to lift a page (Level 2 elevation, Light haptic). Drag and drop into place. Handled natively via Flutter's `ReorderableGridView`.

### 12. PDF Preview & 13. Document Details
*   **Purpose:** Review the final artifact before export.
*   **Layout:** Document is the absolute hero. Minimal app bar with an "Export/Share" `IconButton`.
*   **Metadata:** Bottom panel shows file size, page count, and created date in `Text Secondary`.

*(Screens 14-25 follow the identical philosophy: ruthless minimization of UI, reliance on the typographic hierarchy, and strict adherence to the spacing scale. Error and Empty states must be descriptive, calm, and provide a clear primary action to recover.)*

---

## 13. Accessibility & Performance

### Accessibility
*   **Touch Targets:** Strictly `48dp` minimum.
*   **Contrast:** All text must meet WCAG AA standards (4.5:1). Dark mode relies on stark white text on Slate backgrounds.
*   **Semantics:** Use Flutter's `Semantics` widget wrapping custom interactive elements (Crop handles, Document Cards).

### Performance (Flutter Specifics)
*   **Zero Blur:** `BackdropFilter` and `ImageFilter.blur` are completely banned to guarantee 60 FPS on low-end Android devices. Use solid Surface colors with opacity (e.g., `#1E293B` at 95% opacity) to achieve layered hierarchy without the GPU cost of blurring.
*   **Isolates:** Image processing (OpenCV thresholds, cropping) must be heavily offloaded to Dart Isolates. The UI thread must remain untouched during image saves.
*   **List Views:** Always use `ListView.builder` or `GridView.builder` for the Vault to ensure lazy loading and constant memory footprints.

---

## 14. Brand Personality Summary
ScanVault is **Professional, Dependable, Fast, Private, and Quiet.** It is not trendy, and it is not flashy. It is a timeless utility designed to do one thing perfectly, forever.
