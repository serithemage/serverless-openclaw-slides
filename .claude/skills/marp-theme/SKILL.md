---
name: marp-theme
description: Generate a Marp CSS theme from a PowerPoint (.pptx) template file. Extracts background images, analyzes typography/colors/layout, and produces a complete theme.css with slide class variants.
argument-hint: <path-to-template.pptx>
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# PPTX to Marp Theme Generator

Generate a Marp-compatible CSS theme from a PowerPoint template (.pptx) file.

## Overview

This skill converts a branded PowerPoint template into a Marp presentation theme by:
1. Analyzing the PPTX structure (layouts, placeholders, fonts, colors)
2. Extracting background images from slide layouts
3. Mapping layout types to Marp CSS classes
4. Generating a complete `theme.css` with all variants

## Prerequisites

- `python3` available on the system
- `python-pptx` library (will be installed automatically via `uv` or `pip`)

## Process

### Step 1: Install python-pptx

```bash
# Prefer uv, fallback to pip
uv pip install --system python-pptx 2>/dev/null || \
uv venv /tmp/pptx-env && source /tmp/pptx-env/bin/activate && uv pip install python-pptx 2>/dev/null || \
pip3 install python-pptx
```

### Step 2: Analyze PPTX Template Structure

Run an inline Python script to extract the template's design system:

```python
"""Analyze PPTX template: layouts, placeholders, fonts, colors, backgrounds."""
from pptx import Presentation
from pptx.util import Inches, Pt, Emu

TEMPLATE = "<user-provided-path>"
prs = Presentation(TEMPLATE)

print(f"Slide dimensions: {Emu(prs.slide_width).inches:.2f} x {Emu(prs.slide_height).inches:.2f} inches")

# Enumerate slide layouts — each becomes a Marp CSS class
for i, layout in enumerate(prs.slide_layouts):
    print(f"\nLayout {i}: \"{layout.name}\"")
    for ph in layout.placeholders:
        print(f"  PH idx={ph.placeholder_format.idx} type={ph.placeholder_format.type} "
              f"name=\"{ph.name}\" pos=({ph.left},{ph.top}) size=({ph.width},{ph.height})")

# Analyze each slide for fonts, colors, text styles
for idx, slide in enumerate(prs.slides):
    print(f"\n--- Slide {idx+1} (layout: \"{slide.slide_layout.name}\") ---")
    for shape in slide.shapes:
        if shape.has_text_frame:
            for para in shape.text_frame.paragraphs:
                for run in para.runs:
                    font = run.font
                    print(f"  Font: name={font.name} size={font.size} "
                          f"bold={font.bold} color={font.color.rgb if font.color and font.color.rgb else 'theme'}")
```

**Key outputs to capture:**
- Slide aspect ratio (16:9 standard = 13.33 x 7.5 inches)
- Layout names → map to Marp class names (e.g., title, lead, speaker, closing)
- Font families → `font-family` in CSS
- Color palette → text color, accent color, background color
- Placeholder positions → padding and alignment in CSS

### Step 3: Extract Background Images

Run an inline Python script to extract all images from the template:

```python
"""Extract all images from PPTX: slide master, layouts, and slides."""
from pptx import Presentation
from pptx.opc.constants import RELATIONSHIP_TYPE as RT
import os, hashlib

TEMPLATE = "<user-provided-path>"
OUT_DIR = "./assets"
os.makedirs(OUT_DIR, exist_ok=True)

prs = Presentation(TEMPLATE)
saved = set()

def save_image(blob, content_type, prefix, name):
    ext_map = {"image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif",
               "image/svg+xml": ".svg", "image/x-emf": ".emf"}
    ext = ext_map.get(content_type, ".bin")
    h = hashlib.md5(blob).hexdigest()[:8]
    if h in saved:
        return
    saved.add(h)
    fname = f"{prefix}_{name}{ext}".replace(" ", "_")
    with open(os.path.join(OUT_DIR, fname), "wb") as f:
        f.write(blob)
    print(f"  Saved: {fname} ({len(blob):,} bytes)")

# Slide master images
for rel in prs.slide_masters[0].part.rels.values():
    if "image" in rel.reltype:
        save_image(rel.target_part.blob, rel.target_part.content_type,
                   "master", rel.target_ref.split("/")[-1].split(".")[0])

# Layout images (most important — these are the background images)
for i, layout in enumerate(prs.slide_layouts):
    for rel in layout.part.rels.values():
        if "image" in rel.reltype:
            save_image(rel.target_part.blob, rel.target_part.content_type,
                       f"layout{i}_{layout.name}", rel.target_ref.split("/")[-1].split(".")[0])
    for shape in layout.shapes:
        if shape.shape_type == 13:  # Picture
            save_image(shape.image.blob, shape.image.content_type,
                       f"layout{i}_{layout.name}", shape.name)

# Slide images
for idx, slide in enumerate(prs.slides):
    for shape in slide.shapes:
        if shape.shape_type == 13:
            save_image(shape.image.blob, shape.image.content_type,
                       f"slide{idx}", shape.name)
```

After extraction, rename the background images to semantic names:

```bash
cd assets/
cp "layout0_<cover-layout-name>_<image>.jpg" bg_cover.jpg
cp "layout1_<content-layout-name>_<image>.jpg" bg_content.jpg
cp "layout3_<section-layout-name>_<image>.jpg" bg_section.jpg
cp "layout12_<closing-layout-name>_<image>.jpg" bg_closing.jpg
```

**Important:** Examine each extracted image visually (using Read tool on the image file) to identify which layout image corresponds to which slide type (cover, content, section divider, closing).

### Step 4: Build the Marp CSS Theme

Create `theme.css` with this structure:

```css
/* @theme <theme-name> */
@import 'default';

/* Google Fonts matching the template's font family */
@import url('https://fonts.googleapis.com/css2?family=...');

/* ── Base section (content slides) ── */
section {
  background-color: <from-analysis>;
  color: <from-analysis>;
  font-family: '<matched-font>', sans-serif;
  font-size: 24px;
  padding: 50px 60px;
  line-height: 1.6;
}

/* Typography: h1, h2, h3, p, li, strong, a */
/* Match font sizes, weights, and colors from Step 2 */

/* ── Title/Cover slide ── */
section.title {
  background-image:
    linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.65) 100%),
    url('./assets/bg_cover.jpg');
  background-size: cover;
  background-position: center;
  justify-content: flex-end !important;
  /* Adjust padding based on placeholder positions from Step 2 */
}

/* ── Speaker intro slide ── */
section.speaker {
  background-image:
    linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.65) 100%),
    url('./assets/bg_content.jpg');
  background-size: cover;
}

/* ── Section divider (lead) ── */
section.lead {
  justify-content: center;
  text-align: center;
}

/* ── Closing slide ── */
section.closing {
  background-image:
    linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.65) 100%),
    url('./assets/bg_closing.jpg');
  background-size: cover;
}

/* ── Tables ── */
/* Match border colors, header bg, text colors */

/* ── Code blocks ── */
/* Semi-transparent background matching the theme */

/* ── Blockquotes ── */
/* Accent color for left border */

/* ── Lists ── */
/* ── Columns layout (.columns grid) — requires --html flag ── */
/* ── Footer & page numbers ── */
```

**Key design decisions:**
- Use `linear-gradient()` overlay on background images for text readability
- `background-size: cover` for full-bleed backgrounds
- Match the template's accent color for `strong`, blockquote borders, table headers
- Use `justify-content` for vertical positioning (flex-end for title, center for lead)
- Add `.columns` class with CSS Grid for two-column layouts (requires `--html` flag)

### Step 5: Create slides.md with Frontmatter

```markdown
---
marp: true
theme: <theme-name>
paginate: true
header: ''
footer: ''
---

<!-- _class: title -->

# Presentation Title
## Subtitle

**Speaker Name**
Job Title
Company

---

<!-- _class: lead -->

# Section Title

---

# Content Slide

- Bullet point 1
- Bullet point 2

---

<!-- _class: closing -->

# Thank You!
### contact@example.com
```

### Step 6: Preview and Iterate

```bash
# HTML preview (fast)
npx @marp-team/marp-cli slides.md --theme theme.css --html --allow-local-files -o preview.html

# PNG preview (for visual verification)
npx @marp-team/marp-cli slides.md --theme theme.css --html --allow-local-files --images png -o preview.png

# PDF export
npx @marp-team/marp-cli slides.md --theme theme.css --html --allow-local-files --pdf -o slides.pdf
```

Review each preview image using the Read tool and iterate on CSS until the output matches the original template's look and feel.

## Slide Class Reference

| Marp Class | Usage | Background |
|-----------|-------|-----------|
| `title` | Cover/title slide | bg_cover.jpg with gradient overlay |
| `speaker` | Speaker introduction | bg_content.jpg with gradient overlay |
| `lead` | Section dividers | Solid background, centered text |
| `closing` | Final/thank you slide | bg_closing.jpg with gradient overlay |
| _(default)_ | Content slides | Solid background color |

## Tips

- **Dark templates:** Use white text (`#ffffff`) and semi-transparent backgrounds for code/tables (`rgba(255,255,255,0.08)`)
- **Light templates:** Use dark text and light overlays
- **Gradient overlays:** `linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.65) 100%)` improves text readability over busy backgrounds
- **Font matching:** If the template uses a proprietary font, find the closest Google Fonts alternative
- **`--allow-local-files`:** Required for Marp to load local background images in `url()`
- **`--html` flag:** Required for custom HTML like `<div class="columns">` or `<br>` tags

## Cleanup

After the theme is finalized, delete the intermediate files:
- `analyze_template.py`
- `extract_images.py`
- `assets/layout*_*` (keep only `bg_*.jpg` and other final assets)
