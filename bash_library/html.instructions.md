# HTML Instruction Files - Documentation

## Overview
All bash_library scripts now have comprehensive HTML instruction files with a shared CSS stylesheet for consistent styling and maintainability. Files feature a sticky Table of Contents in a dedicated right column and responsive dark/light mode support.

## Files Structure

### HTML Instruction Files (6 total)
1. **sqlToJson.sh.instructions.html** - SQL to JSON converter documentation
2. **loggy.sh.instructions.html** - Structured logging utility documentation
3. **ssh.sh.instructions.html** - Remote SSH command executor documentation
4. **findOracleDatabases.sh.instructions.html** - Oracle database discovery documentation
5. **relocateRacOneNode.sh.instructions.html** - RAC One Node relocation documentation
6. **updateOratab.sh.instructions.html** - Oracle database monitoring documentation

### Shared Resources
- **styles.css** - External stylesheet containing all shared CSS (~4 KB)

## CSS Architecture

### Shared CSS (styles.css)
Contains all styling for instruction files with consistent theming:

**Color Scheme (CSS Variables)**
- Light Mode:
  - Text: #333
  - Background: #ffffff
  - Secondary: #f5f5f5
  - Code: #f4f4f4
  - Accent: #0066cc

- Dark Mode:
  - Text: #e0e0e0
  - Background: #1e1e1e
  - Secondary: #2d2d2d
  - Code: #282c34
  - Accent: #5ba3d0

**Layout System**
- `main` uses CSS Grid with 2 columns: `grid-template-columns: 1fr 300px`
- Left column (1fr): Content sections
- Right column (300px): Sticky Table of Contents
- Mobile responsive: Single column below 768px

**Core Components Styled**
- `html` - Smooth scroll behavior
- `body` - Font, line-height, colors, backgrounds
- `header` - Sticky positioning, accent border
- `h1`, `h2`, `h3`, `h4` - Heading styles with accent colors
- `main` - Grid layout with 2-column design
- `code` - Inline code with background and monospace font
- `pre` - Code blocks with left border and relative positioning
- `.copy-btn` - Copy-to-clipboard button styling
- `.toc` - Sticky right-column navigation
- `.note` - Dark grey (#333333) callout boxes with orange border
- `.section` - Content section containers
- `table` - Striped rows with borders
- `footer` - Footer with top border
- Dark mode overrides - Consistent dark grey palette

### TOC (Table of Contents) Features
- **Position**: Sticky (top: 90px, z-index: 50)
- **Layout**: Grid column 2 (right side), spans all rows
- **Responsive**: Full-width on mobile (< 768px)
- **Styling**: Bordered box with accent color links
- **Sections**: 14-16 section links per file with smooth scroll anchors

### Dark Mode Implementation
- Auto-detects via `prefers-color-scheme` media query
- All blocks use consistent dark grey backgrounds (#2d2d2d, #252525, #333333)
- Light grey text (#e0e0e0) for readability
- Orange/blue accent colors for visual hierarchy
- Seamless dark/light mode switching

## HTML Structure

Each instruction file follows this structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <!-- Meta tags (charset, viewport, description, og:tags) -->
  <link rel="stylesheet" href="styles.css" />
  <title>[Script Name] - Script Creation Instructions</title>
</head>
<body>
  <header>
    <main style="padding: 0 20px;">
      <h1>[Script Name] - Script Creation Instructions</h1>
    </main>
  </header>
  
  <main>
    <!-- Table of Contents (sticky right column) -->
    <nav class="toc">
      <h3>Table of Contents</h3>
      <ul>
        <li><a href="#section-id">Section Name</a></li>
      </ul>
    </nav>
    
    <!-- Content sections with ID anchors -->
    <section class="section">
      <h2 id="section-id">Section Name</h2>
      <div class="note">Content with dark grey background</div>
    </section>
  </main>
  
  <footer>
    <p>Footer content</p>
  </footer>
  
  <script>
    <!-- Copy-to-clipboard functionality -->
  </script>
</body>
</html>
```

## Features

### Dark Mode Support
- Automatic detection via `prefers-color-scheme` media query
- CSS custom properties for easy theme switching
- Dark grey backgrounds (#2d2d2d, #252525, #333333) for all content blocks
- Light grey text (#e0e0e0) on dark backgrounds
- Dark/light colors for code, borders, and accents

### Two-Column Responsive Layout
- Desktop: Content on left, sticky TOC on right (300px fixed width)
- Mobile (< 768px): Single column, TOC stacks above content
- CSS Grid for clean, maintainable layout
- 30px gap between columns on desktop, 20px on mobile

### Navigation
- Sticky header with accent border stays visible while scrolling
- Sticky TOC in right sidebar with section anchors
- Smooth scroll behavior on all elements
- Deep linking via anchor URLs (#section-id)

### Code Blocks
- Syntax highlighting with custom colors
- Copy-to-clipboard buttons on hover
- Monospace font with proper spacing
- Left accent border
- Responsive overflow handling

### Accessibility
- Semantic HTML5 structure
- Proper heading hierarchy (h1, h2, h3, h4)
- Color-independent visual design
- Readable font sizes (16px base) and line heights
- Section anchors for deep linking
- Keyboard navigation fully supported

## Recent Changes (Latest Update)

### CSS Grid Layout (2-Column Design)
- Converted from float-based layout to CSS Grid
- TOC now in dedicated right column (300px wide)
- Content sections in left column (flexible width)
- Prevents TOC from overlapping text content
- Mobile responsive: single column < 768px

### Dark Mode Consistency
- All content blocks use dark grey backgrounds in dark mode
- Added explicit dark mode styles for .note, table, blockquote elements
- Consistent palette: #2d2d2d (primary), #252525 (alternates)
- Light text (#e0e0e0) ensures readability

### Light Mode Block Colors
- Changed .note background from light yellow (#fff3cd) to dark grey (#333333)
- Added light text color (#e0e0e0) for contrast
- Maintains orange left border (#ffc107) for visual accent
- Consistent appearance across light and dark modes

### Removed Features
- Back-to-Top buttons removed from all files (not needed with sticky TOC)
- Inline back-to-top links removed from updateOratab.sh
- Simplified user experience focused on navigation via TOC

## File Sizes

After CSS extraction and optimization:
- sqlToJson.sh.instructions.html: ~18 KB
- loggy.sh.instructions.html: ~20 KB
- ssh.sh.instructions.html: ~21 KB
- findOracleDatabases.sh.instructions.html: ~19 KB
- relocateRacOneNode.sh.instructions.html: ~22 KB
- updateOratab.sh.instructions.html: ~30 KB
- styles.css: ~4 KB

**Total size**: ~134 KB (optimized from ~180 KB with inline CSS)

## Maintenance

### Adding New Instruction Files
1. Create HTML file with structure above
2. Add `<link rel="stylesheet" href="styles.css" />` in head
3. Include table of contents with section anchors
4. Use semantic HTML5 tags (header, main, section, footer)
5. Apply class names: `section`, `note`, `toc` as needed

### Updating Shared CSS
- Edit `styles.css` to change styling for all files
- Use CSS custom properties (--text-color, --bg-color, etc.) for themes
- Test in both light and dark modes
- Mobile responsive testing at 768px breakpoint

### Custom Styles (per file)
- Keep custom/script-specific styles in HTML `<style>` tags
- Examples: updateOratab.sh has additional classes (.metadata, .phase, .success)
- Do not duplicate shared CSS in file-specific styles

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- CSS Grid support required
- Custom properties (CSS variables) required
- Smooth scroll behavior supported
- Dark mode (prefers-color-scheme) supported
- Tested on Windows, macOS, Linux, mobile browsers

## Accessibility Features

- Semantic HTML5 structure with proper element usage
- Heading hierarchy (h1 > h2 > h3 > h4)
- Color contrast meets WCAG AA standards
- Light mode: Dark text on light/grey backgrounds
- Dark mode: Light text on dark backgrounds
- Responsive design supports all screen sizes
- Keyboard navigation fully supported
- Focus indicators visible on interactive elements
- Links underlined on hover for clarity
- Code blocks clearly distinguished with borders and background
- Proper skip navigation via anchors
