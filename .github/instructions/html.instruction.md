---
applyTo: '**/*.html'
description: 'Create html pages to support technical documentation'
---

## HTML5 Structure
- Use HTML5 doctype: `<!DOCTYPE html>`.
- Include `<html lang="en">` attribute for language declaration.
- Include required meta tags in `<head>`:
  - `<meta charset="utf-8" />`
  - `<meta name="viewport" content="width=device-width, initial-scale=1" />`
  - `<meta name="description" content="..." />` with concise page description.
  - `<meta name="color-scheme" content="light dark" />` to support dark mode.
- Include favicon with multiple formats for broad compatibility:
  - `<link rel="icon" type="image/x-icon" href="/favicon.ico" />`
  - `<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png" />`
  - `<link rel="apple-touch-icon" href="/apple-touch-icon.png" />`
  - Recommended sizes: favicon.ico (16×16, 32×32), favicon-32x32.png, apple-touch-icon (180×180).
- Include OpenGraph meta tags for social media sharing (use specific, descriptive values):
  - `<meta property="og:title" content="Page Title" />`
  - `<meta property="og:description" content="Concise page description" />`
  - `<meta property="og:image" content="/path/to/image.png" />`
  - `<meta property="og:url" content="https://example.com/page" />`
  - `<meta property="og:type" content="website" />`
- Use semantic HTML elements (`<header>`, `<nav>`, `<main>`, `<section>`, `<article>`, `<footer>`, etc.) to structure content.

## General
- Reference https://oracle-base.com/ for design inspiration and use similar style for professional technical documentation.
- Base CSS styling on oracle-base.com aesthetic: clean typography, generous whitespace, subtle borders, muted colors.
- Use 2 spaces for indentation.
- Use lowercase for element names, attribute names, and attribute values.
- Use double quotes for attribute values.
- Self-close void elements with a single space before closing slash (e.g., `<br />`, `<img />`, `<input />`, etc.).
- Place each attribute on a new line if there are more than 2 attributes.
- Place the closing bracket of a multi-line element on a new line.
- **Dark Mode Support:**
  - Implement dark mode using CSS media query: `@media (prefers-color-scheme: dark)`.
  - Provide CSS custom properties (variables) for colors: `--text-color`, `--bg-color`, `--border-color`, `--code-bg`, etc.
  - Support both light and dark modes simultaneously; users' system preference determines default.
  - Ensure sufficient contrast in both light and dark modes (WCAG AA minimum 4.5:1).
  - Use colors that reduce eye strain in dark mode (avoid pure white text on pure black).
- Maintain consistent formatting across all pages.
- Use existing external CSS when possible.
- **Code Block Enhancements:**
  - Add a "Copy" button to each `<code>` block for clipboard functionality.
  - Button should appear on hover (desktop) or always visible (mobile).
  - Use JavaScript to copy code content to clipboard with visual feedback (e.g., "Copied!" message).
  - Preserve indentation and formatting when copying.
- **Navigation & Structure:**
  - Include a table of contents (TOC) at the top of each page listing all major sections.
  - TOC should use smooth scrolling links to each section.
  - Add a "Back to Top" link at the end of each major section for easier navigation.
  - Use consistent anchor links for all sections (lowercase, hyphenated).

## Accessibility
- Always include meaningful alt text for images.
- Alt text should be helpful for screen readers and people who are blind or have visual impairment.
- Never start alt text with "Image of..." or "Picture of...".
- Clearly identify the primary subject or subjects of the image.
- Describe what the subject is doing, if applicable.
- Add a short description of the wider environment.
- If there is text in the image, transcribe and include it.
- Describe the emotional tone of the image, if applicable.
- Do not use single or double quotes in the alt text.
- Avoid using "logo" in the alt text; instead, describe the logo (e.g., "Company Name logo").
- For decorative images that do not add meaningful content, use an empty alt attribute (e.g., `alt=""`).
- Ensure sufficient color contrast between text and background in both light and dark modes.
- Use semantic HTML elements (e.g., `<header>`, `<nav>`, `<main>`, `<footer>`, etc.) to improve accessibility and SEO.
- Ensure all interactive elements are keyboard accessible.
- Code copy buttons must be accessible via keyboard (Tab and Enter keys).
- Ensure TOC links are properly announced by screen readers.

## Accessibility
- Always include meaningful alt text for images.
- Alt text should be helpful for screen readers and people who are blind or have visual impairment.
- Never start alt text with "Image of..." or "Picture of...".
- Clearly identify the primary subject or subjects of the image.
- Describe what the subject is doing, if applicable.
- Add a short description of the wider environment.
- If there is text in the image, transcribe and include it.
- Describe the emotional tone of the image, if applicable.
- Do not use single or double quotes in the alt text.
- Avoid using "logo" in the alt text; instead, describe the logo (e.g., "Company Name logo").
- For decorative images that do not add meaningful content, use an empty alt attribute (e.g., `alt=""`).
- Ensure sufficient color contrast between text and background.
- Use semantic HTML elements (e.g., `<header>`, `<nav>`, `<main>`, `<footer>`, etc.) to improve accessibility and SEO.
- Ensure all interactive elements are keyboard accessible.

## SEO
- Use descriptive and unique title tags for each page.
- Include meta description tags with relevant keywords.
- Use heading tags (`<h1>`, `<h2>`, etc.) to structure content and include relevant keywords.
- Use descriptive and keyword-rich URLs.
- Include alt text for images with relevant keywords.
- Use internal linking to connect related pages within the website.
- Ensure fast page load times by optimizing images and minimizing code.
- Implement responsive design to ensure the website is mobile-friendly.
- Use structured data (Schema.org) to enhance search engine understanding of the content.
- Create and submit an XML sitemap to search engines.
- Regularly update content to keep it fresh and relevant.

## Performance

### Image Optimization
- Optimize images for web use (compress and resize as necessary).
- Use modern image formats like WebP or AVIF for better compression and quality.
- Implement efficient image loading techniques such as responsive images and srcset to serve appropriately sized images based on device capabilities and viewport width.
- Use lazy loading for images and videos to improve performance.

### JavaScript Optimization
- Defer loading of non-essential JavaScript to improve initial page load times.
- Use asynchronous loading for third-party scripts to prevent blocking page rendering.
- Implement code splitting to load only the necessary code for each page.
- Use tree shaking to eliminate unused code from JavaScript bundles.
- Ensure efficient use of web workers to offload heavy computations from the main thread.
- Implement lazy loading for non-critical JavaScript to improve initial load times.

### CSS Optimization
- Eliminate render-blocking resources by inlining critical CSS and deferring non-critical CSS.
- Ensure efficient use of CSS selectors to minimize rendering time.
- Ensure efficient use of CSS animations and transitions to avoid performance bottlenecks.
- Use font-display: swap; for web fonts to improve text rendering performance.
- Minimize the use of web fonts and ensure they are optimized for performance.
- Implement lazy loading for non-critical CSS to improve initial load times.

### Caching & Compression
- Leverage browser caching by setting appropriate cache headers.
- Implement gzip or Brotli compression for text-based resources.
- Implement efficient caching strategies for dynamic content.
- Use service workers to enable offline capabilities and improve load times for repeat visitors.
- Implement HTTP/2 to improve loading times through multiplexing and header compression.

### General Performance Strategies
- Minimize the use of inline CSS and JavaScript.
- Reduce the number of HTTP requests by combining files where possible.
- Use a content delivery network (CDN) to serve static assets.
- Reduce the use of heavy frameworks and libraries; prefer lightweight alternatives when possible.
- Avoid excessive DOM size by keeping the number of elements on a page manageable.
- Monitor and optimize server response times.
- Optimize server-side rendering (SSR) to improve initial load times and SEO.
- Use preconnect and dns-prefetch to establish early connections to important third-party origins.
- Implement resource hints like preload and prefetch to prioritize loading of important assets.

### Performance Monitoring & Testing
- Regularly audit website performance using tools like Google PageSpeed Insights or Lighthouse.
- Monitor performance metrics such as Time to First Byte (TTFB), First Contentful Paint (FCP), and Largest Contentful Paint (LCP) to identify areas for improvement.
- Monitor and optimize Cumulative Layout Shift (CLS) to improve visual stability during page load.
- Monitor and optimize Time to Interactive (TTI) to ensure the website becomes fully interactive quickly.
- Regularly test website performance across different devices and network conditions to ensure a consistent user experience.
- Use performance budgeting to set and maintain performance goals for the website.
- Utilize browser developer tools to identify and fix performance issues.
- Regularly review and update dependencies to ensure optimal performance.
- Regularly review and update performance optimization strategies to keep up with best practices and evolving web technologies.

## CSS & Framework Guidelines
- Prefer lightweight CSS frameworks (e.g., Tailwind CSS, Bootstrap) over heavy solutions.
- Minimize custom CSS by leveraging existing framework utilities when available.
- Use CSS preprocessors (SASS/SCSS) for variables, mixins, and nested rules to improve maintainability.
- Organize CSS by component or page section for better organization.
- Use CSS variables (custom properties) for themes and dark mode support.
- Implement responsive design with mobile-first approach using appropriate breakpoints (e.g., 640px, 768px, 1024px, 1280px).
- Test layout across common device sizes: mobile (375px), tablet (768px), desktop (1280px+).
- Avoid inline styles; use external stylesheets or utility classes instead.

## Testing & Validation
- Validate HTML using W3C Markup Validator (https://validator.w3.org/).
- Validate CSS using W3C CSS Validator (https://jigsaw.w3.org/css-validator/).
- Test accessibility with WAVE (Web Accessibility Evaluation Tool).
- Test accessibility with axe DevTools browser extension.
- Run Lighthouse audit in Chrome DevTools to check performance, accessibility, best practices, and SEO.
- Test responsive design at multiple viewport sizes using browser DevTools.
- Verify color contrast meets WCAG AA standards (4.5:1 for text, 3:1 for graphics).
- Test keyboard navigation to ensure all interactive elements are accessible.
- Verify OpenGraph tags render correctly using Open Graph Debugger (https://developers.facebook.com/tools/debug/).
- Test page with screen readers (NVDA, JAWS) for accessibility.
- Verify favicon displays correctly across browsers and devices.
- Check HTML5 semantic structure with browser DevTools inspector.
- Test cross-browser compatibility (Chrome, Firefox, Safari, Edge).
- Verify page loads and renders correctly on slow network conditions.
- Test print styles if applicable.
- Validate meta tags are properly formatted and contain appropriate content.

## Landing Pages
- For pages serving as table of contents or documentation indexes, use [landing-page.instruction.md](landing-page.instruction.md) for specialized guidance on structure, organization, and content hierarchy.
- Landing pages organize related content into logical groups with brief descriptions for discoverability.
- Apply general HTML5 standards (favicon, meta tags, semantic structure, accessibility) in addition to landing page specific requirements.
