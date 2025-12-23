---
applyTo: '**/index.html'
description: 'Create landing pages that serve as table of contents for documentation sites'
---

## Purpose & Structure
- Landing pages serve as the primary entry point and table of contents for documentation sites.
- Organize all linked pages into logical, hierarchical groups with clear categorization.
- Use a single `<main>` element containing section groups, each with a heading and description list.
- Display all groups at once (avoid tabs or accordions) for accessibility and search engine optimization.

## Content Organization
- Group pages by functional area or topic (e.g., "Getting Started", "Configuration", "API Reference", "Troubleshooting").
- Use consistent, descriptive group headings that clearly communicate the category purpose.
- Order groups by user journey (e.g., Getting Started first, then Advanced topics).
- Ensure each group contains 2-8 related pages; split or merge groups if imbalanced.
- Use a `<section>` element for each group with a `<h2>` heading and a `<ul>` or `<dl>` for page links.
- **Reference only HTML files** in the landing page; convert or link to HTML versions of documentation (not Markdown files).

## Page Descriptions
- Include a brief, single-line description (40-60 characters) for each linked page.
- Descriptions should use active language and specify what the user will learn or accomplish.
- Examples: "Install and configure the application", "Reference guide for API endpoints", "Troubleshoot common setup issues".
- Avoid generic descriptions like "Documentation" or "More information"; be specific about content.
- Do not include the page title in the description; assume the title and description together provide context.

## Navigation Structure
- Use semantic HTML: `<section>` for groups, `<h2>` for group titles, `<h3>` for page titles within groups.
- **Link only to HTML files**; do not reference Markdown files. All linked pages must be `.html` files.
- Link structure: Each page should be in a list item with a link (`<a>`) and descriptive text.
- Example structure:
  ```html
  <section>
    <h2>Getting Started</h2>
    <ul>
      <li><a href="quickstart.html">Quick Start</a> – Install and run in 5 minutes</li>
      <li><a href="installation.html">Installation</a> – Detailed setup instructions</li>
    </ul>
  </section>
  ```
- Include a table of contents (`<nav>` with anchor links) at the top if more than 5 groups exist.

## Visual Hierarchy & Layout
- Use consistent spacing and typography to distinguish group headings from page links.
- Apply subtle background colors or borders to group sections for visual separation.
- Ensure page links are visually distinct from descriptive text (e.g., bold or different color).
- Align descriptions below or beside links for readability; maintain consistent alignment across all groups.
- Use CSS Grid or Flexbox for responsive group layout (2-column on desktop, 1-column on mobile).

## Search & Discoverability
- Use descriptive `<title>` and meta description tags (e.g., "Documentation Index – All guides and references").
- Include hidden metadata (in comments) listing all page titles for search engine crawlers if beneficial.
- Use heading tags (`<h1>`, `<h2>`) properly so search engines understand structure.
- Ensure all page links use relative or absolute URLs correctly; test all links before deployment.

## Accessibility
- Use semantic HTML structure so screen readers understand the hierarchy and grouping.
- Provide descriptive link text that makes sense when read out of context (e.g., avoid "Click here" or "More").
- Ensure color is not the only visual distinction between groups; use headings, spacing, or borders.
- Maintain sufficient contrast between text and background (WCAG AA: 4.5:1 for text, 3:1 for graphics).
- Test with screen readers to ensure group structure and page descriptions are clear.

## Performance & Maintenance
- Load all page links on the initial page load (no lazy loading or dynamic loading of links).
- Use static HTML lists rather than JavaScript to populate links; ensure link data is in HTML source.
- Keep the landing page lightweight; descriptions and links are the primary content.
- Validate all links regularly using automated tools; update or remove broken links immediately.
- If pages are added or removed, update the landing page within 24 hours to maintain accuracy.

## Example Structure
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Documentation – All Guides and References</title>
  <meta name="description" content="Complete documentation with guides, configuration, API reference, and troubleshooting." />
</head>
<body>
  <header>
    <h1>Documentation</h1>
    <p>Learn how to install, configure, and use the application.</p>
  </header>
  
  <nav>
    <h2>Quick Links</h2>
    <ul>
      <li><a href="#getting-started">Getting Started</a></li>
      <li><a href="#configuration">Configuration</a></li>
      <li><a href="#reference">API Reference</a></li>
    </ul>
  </nav>

  <main>
    <section id="getting-started">
      <h2>Getting Started</h2>
      <ul>
        <li><a href="quickstart.html">Quick Start</a> – Install and run in 5 minutes</li>
        <li><a href="installation.html">Installation</a> – Detailed setup and system requirements</li>
      </ul>
    </section>

    <section id="configuration">
      <h2>Configuration</h2>
      <ul>
        <li><a href="config-basics.html">Configuration Basics</a> – Essential settings explained</li>
        <li><a href="advanced-config.html">Advanced Configuration</a> – Custom options and optimization</li>
      </ul>
    </section>

    <section id="reference">
      <h2>API Reference</h2>
      <ul>
        <li><a href="api-overview.html">API Overview</a> – Authentication and core concepts</li>
        <li><a href="api-endpoints.html">API Endpoints</a> – Complete endpoint reference</li>
      </ul>
    </section>
  </main>

  <footer>
    <p>&copy; 2025 SolidWorks Consulting LLC. All rights reserved.</p>
  </footer>
</body>
</html>
```
