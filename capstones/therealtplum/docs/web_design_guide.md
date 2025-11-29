# Foundry90 Web Design Guide

**LLM-Friendly Design System Reference**

This guide provides comprehensive design system information for implementing visual components in the Foundry90 web application. All components use the `f90-` prefix for CSS classes.

---

## Design Tokens

### Color System

**Background Colors:**
- `--f90-bg`: `#050608` - Primary dark background
- `--f90-bg-soft`: `#0b0f14` - Softer dark background
- `--f90-bg-softer`: `#0f141b` - Lightest dark background

**Border Colors:**
- `--f90-border`: `#1b232e` - Primary border color
- `--f90-border-soft`: `#151b23` - Softer border color

**Text Colors:**
- `--f90-text`: `#e5f0ff` - Primary text color (high contrast)
- `--f90-text-soft`: `#8b9bb3` - Secondary text (hero/marketing)
- `--f90-text-soft-terminal`: `#a7f3c5` - Terminal/board text

**Accent Colors:**
- `--f90-accent`: `#43ff8a` - Primary neon green accent
- `--f90-accent-soft`: `rgba(67, 255, 138, 0.12)` - Soft accent background
- `--f90-accent-mint`: `#a7f3c5` - Mint green variant
- `--f90-accent-emerald`: `#10b981` - Emerald green variant

**State Colors:**
- `--f90-down-border`: `rgba(248, 113, 113, 0.9)` - Down/negative border
- `--f90-down-bg`: `rgba(239, 68, 68, 0.2)` - Down/negative background
- `--f90-down-text`: `#fecaca` - Down/negative text
- `--f90-flat-border`: `rgba(148, 163, 184, 0.5)` - Flat/neutral border
- `--f90-flat-bg`: `rgba(148, 163, 184, 0.16)` - Flat/neutral background
- `--f90-flat-text`: `#e5e7eb` - Flat/neutral text

### Typography

**Font Families:**
- `--f90-font-sans`: System UI stack (SF Pro, Segoe UI, etc.) - Default body text
- `--f90-font-mono`: Monospace stack (SF Mono, Menlo, Monaco) - Code/terminal text

**Usage:**
- Body text, buttons, navigation: `var(--f90-font-sans)`
- Headers, code, terminal displays: `var(--f90-font-mono)`
- Hero titles: `var(--f90-font-mono)` with uppercase and letter-spacing

### Spacing & Layout

**Border Radius:**
- `--f90-radius-lg`: `24px` - Large rounded corners (panels, cards)
- `--f90-radius-md`: `16px` - Medium rounded corners (cards, containers)
- `--f90-radius-sm`: `999px` - Pill shape (buttons, badges)

**Page Layout:**
- Max width: `1120px`
- Padding: `56px 20px 40px` (top, horizontal, bottom)
- Container class: `.f90-page`

---

## Component Patterns

### Buttons

**Primary Button** (`.f90-btn .f90-btn-primary`):
- Emerald gradient background with glow effect
- Black text (`#010203`)
- Pill shape (`border-radius: 999px`)
- Hover: Slight lift (`translateY(-1px)`) with enhanced glow
- Usage: Primary actions, CTAs, login buttons

**Ghost Button** (`.f90-btn .f90-btn-ghost`):
- Transparent with border
- Dark gradient background
- Soft text color
- Hover: Accent border and text color
- Usage: Secondary actions, logout buttons

**Base Button Structure:**
```tsx
<Link href="/path" className="f90-btn f90-btn-primary">
  Button Text
</Link>
```

### Navigation

**Top Navigation** (`.f90-nav`):
- Sticky header with backdrop blur
- Border bottom: `1px solid var(--f90-border)`
- Background: `rgba(5, 6, 8, 0.8)` with `backdrop-filter: blur(12px)`
- Max width container with padding: `16px 24px`
- Flexbox layout: space-between

**Navigation Brand** (`.f90-nav-brand`):
- Contains logo pill and title
- Flexbox with gap: `12px`
- Hover: `opacity: 0.8`

**Navigation Title** (`.f90-nav-title`):
- Font size: `15px`
- Font weight: `600`
- Color: `var(--f90-text)`
- Letter spacing: `0.02em`

**Example:**
```tsx
<header className="f90-nav">
  <div className="f90-nav-inner">
    <Link href="/" className="f90-nav-brand">
      <div className="f90-logo-pill">90</div>
      <span className="f90-nav-title">Foundry90</span>
    </Link>
    <AuthButton />
  </div>
</header>
```

### Logo & Branding

**Logo Pill** (`.f90-logo-pill`):
- Padding: `8px 14px`
- Border: `1px solid rgba(67, 255, 138, 0.6)`
- Border radius: `999px` (pill shape)
- Color: `var(--f90-accent)`
- Font: `var(--f90-font-mono)`
- Letter spacing: `0.22em`
- Text transform: `uppercase`
- Font size: `13px`

**Logo Caption** (`.f90-logo-caption`):
- Font size: `13px`
- Color: `var(--f90-text-soft)`

### Hero Section

**Hero Container** (`.f90-hero`):
- Grid layout: `3fr 2.4fr` (responsive to single column on mobile)
- Gap: `36px`
- Align items: center

**Hero Inner** (`.f90-hero-inner`):
- Flex column
- Gap: `20px`

**Hero Title** (`.f90-hero-title`):
- Font size: `clamp(42px, 5vw, 56px)`
- Letter spacing: `0.18em`
- Text transform: `uppercase`
- Font family: `var(--f90-font-mono)`

**Hero Subtitle** (`.f90-hero-subtitle`):
- Max width: `520px`
- Color: `var(--f90-text-soft)`
- Line height: `1.5`
- Font size: `15px`

**Hero Actions** (`.f90-hero-actions`):
- Flexbox with wrap
- Gap: `12px`
- Margin top: `4px`

**Hero Meta** (`.f90-hero-meta`):
- Flex column
- Gap: `8px`
- Align items: center
- Color: `var(--f90-text-soft)`
- Font size: `12px`
- Font family: `var(--f90-font-mono)`
- Letter spacing: `0.08em`
- Text transform: `uppercase`

**Hero Panel** (`.f90-hero-panel`):
- Border radius: `var(--f90-radius-lg)`
- Border: `1px solid var(--f90-border)`
- Background: Radial gradients with subtle accent
- Padding: `20px 20px 18px`

**Example:**
```tsx
<section className="f90-hero">
  <div className="f90-hero-inner">
    <h1 className="f90-hero-title">
      <span className="f90-type">Foundry90_</span>
    </h1>
    <p className="f90-hero-subtitle">
      Description text
    </p>
    <div className="f90-hero-actions">
      <Link href="/path" className="f90-btn f90-btn-primary">
        Action
      </Link>
    </div>
  </div>
  <div className="f90-hero-panel">
    {/* Panel content */}
  </div>
</section>
```

### Cards & Panels

**Card Structure:**
- Border radius: `var(--f90-radius-md)` or `var(--f90-radius-lg)`
- Border: `1px solid var(--f90-border)`
- Background: Dark gradients or `rgba(5, 6, 8, 0.9)`
- Padding: `14px 16px` (standard) or `20px` (larger)

**Hero Logo Card** (`.f90-hero-logo-card`):
- Background: `rgba(5, 6, 8, 0.9)`
- Border radius: `var(--f90-radius-md)`
- Padding: `14px 16px`
- Border: `1px solid var(--f90-border-soft)`
- Flexbox: space-between

### Metrics & Data Display

**Metric Container** (`.f90-metric`):
- Padding: `10px 12px`
- Border radius: `16px`
- Background: `rgba(5, 6, 8, 0.9)`
- Border: `1px solid var(--f90-border-soft)`

**Metric Label** (`.f90-metric-label`):
- Font size: `11px`
- Color: `var(--f90-text-soft)`
- Text transform: `uppercase`
- Letter spacing: `0.14em`
- Font family: `var(--f90-font-mono)`
- Margin bottom: `6px`

**Metric Value** (`.f90-metric-value`):
- Font size: `20px`
- Font weight: `600`

**Metric Note** (`.f90-metric-note`):
- Font size: `12px`
- Color: `var(--f90-text-soft)`

**Metrics Grid** (`.f90-hero-metrics`):
- Grid: `repeat(3, minmax(0, 1fr))`
- Gap: `14px`
- Responsive: Single column on mobile

### Sections

**Section Container** (`.f90-section`):
- Margin top: `80px`

**Section Title** (`.f90-section-title`):
- Font size: `28px`
- Font weight: `600`
- Margin bottom: `24px`
- Color: `var(--f90-text)`

### Footer

**Footer** (`.f90-footer`):
- Margin top: `120px`
- Padding: `40px 0`
- Border top: `1px solid var(--f90-border)`
- Text align: center
- Color: `var(--f90-text-soft)`
- Font size: `14px`

**Footer Link** (`.f90-footer-link`):
- Color: `var(--f90-text-soft)`
- Text decoration: none
- Hover: `var(--f90-accent)` with `opacity: 0.9`

### Authentication Components

**Auth Loading** (`.f90-auth-loading`):
- Padding: `10px 18px`
- Font size: `13px`
- Color: `var(--f90-text-soft)`

**Auth User Container** (`.f90-auth-user`):
- Flexbox with gap: `12px`
- Align items: center

**Auth User Info** (`.f90-auth-user-info`):
- Flexbox with gap: `10px`
- Align items: center

**Auth Avatar** (`.f90-auth-avatar`):
- Width/height: `28px`
- Border radius: `50%` (circle)
- Border: `1px solid var(--f90-border)`

**Auth Name** (`.f90-auth-name`):
- Font size: `13px`
- Color: `var(--f90-text-soft)`
- Hidden on mobile, visible on `sm` breakpoint and up

### Typewriter Effect

**Typewriter Text** (`.f90-type`):
- Display: `inline-block`
- Overflow: `hidden`
- White space: `nowrap`
- Border right: `2px solid var(--f90-accent)`
- Padding right: `4px`
- Animation: Typing effect with blinking caret

---

## Layout Patterns

### Page Container

All pages should use `.f90-page` as the main container:

```tsx
<main className="f90-page">
  {/* Page content */}
</main>
```

**Properties:**
- Max width: `1120px`
- Margin: `0 auto` (centered)
- Padding: `56px 20px 40px`

### Responsive Breakpoints

- Mobile: Default (single column layouts)
- Tablet: `@media (max-width: 900px)` - Hero switches to single column
- Small mobile: `@media (max-width: 600px)` - Metrics grid to single column

---

## Theme System

The design system supports two themes:

### Default Theme (Hacker/Finance)
- Dark background with emerald green accents
- High contrast, professional aesthetic
- Activated by default on `body.f90-body`

### Kawaii Theme (Strawberry Shortcake/Hello Kitty)
- Light pink/white background
- Pastel colors
- Activated by adding `f90-theme-kawaii` class to body: `body.f90-body.f90-theme-kawaii`

**Theme-Specific Overrides:**
- All components have kawaii theme variants
- Colors switch to pink/pastel palette
- Backgrounds become light gradients
- Borders use pink variants

**Implementation:**
- Use CSS variables for all colors (automatically theme-aware)
- Theme toggle component handles class switching
- All components should work in both themes

---

## Utility Classes

### Spacing
- `.f90-space-top`: `margin-top: 60px`
- `.f90-space-bottom`: `margin-bottom: 60px`

### Visual Effects
- `.f90-glow-green`: Green glow box shadow
- `.f90-text-glow`: Green text shadow

---

## Naming Conventions

### CSS Classes
- All classes use `f90-` prefix
- Component names: `f90-{component}` (e.g., `f90-nav`, `f90-btn`)
- Modifiers: `f90-{component}-{modifier}` (e.g., `f90-btn-primary`, `f90-btn-ghost`)
- Elements: `f90-{component}-{element}` (e.g., `f90-nav-title`, `f90-hero-inner`)

### Component Structure
- Use semantic HTML
- Prefer composition over deep nesting
- Keep class names descriptive and consistent

---

## Implementation Guidelines

### Color Usage
1. **Always use CSS variables** - Never hardcode colors
2. **Text hierarchy:**
   - Primary text: `var(--f90-text)`
   - Secondary text: `var(--f90-text-soft)`
   - Terminal/board text: `var(--f90-text-soft-terminal)`
3. **Accent usage:**
   - Primary actions: `var(--f90-accent)`
   - Softer accents: `var(--f90-accent-mint)`
   - Backgrounds: `var(--f90-accent-soft)`

### Typography
1. **Body text:** Always use `var(--f90-font-sans)`
2. **Code/terminal:** Use `var(--f90-font-mono)`
3. **Headers:** Typically use `var(--f90-font-mono)` with uppercase
4. **Letter spacing:** Use `0.08em` to `0.22em` for uppercase text

### Spacing
1. **Gaps:** Use `gap` property in flexbox/grid (typically `12px`, `16px`, `20px`)
2. **Padding:** Standard is `14px 16px` for cards, `10px 18px` for buttons
3. **Margins:** Use section margins (`80px` top) for major sections

### Borders & Radius
1. **Borders:** Always use `var(--f90-border)` or `var(--f90-border-soft)`
2. **Radius:** Use token values (`--f90-radius-lg`, `--f90-radius-md`, `--f90-radius-sm`)
3. **Pills:** Use `999px` (or `var(--f90-radius-sm)`) for buttons and badges

### Backgrounds
1. **Cards/panels:** Use `rgba(5, 6, 8, 0.9)` or dark gradients
2. **Body:** Use radial gradients with subtle accent colors
3. **Hover states:** Enhance borders/colors, add subtle transforms

### Buttons
1. **Primary actions:** Use `f90-btn f90-btn-primary`
2. **Secondary actions:** Use `f90-btn f90-btn-ghost`
3. **Always include hover states**
4. **Use Link component** for navigation buttons

### Responsive Design
1. **Mobile-first:** Default styles work on mobile
2. **Use CSS Grid/Flexbox** for responsive layouts
3. **Breakpoints:** `900px` (tablet), `600px` (mobile)
4. **Hide/show:** Use `hidden sm:inline` pattern for responsive visibility

---

## Common Patterns

### Card with Header
```tsx
<div className="f90-hero-panel">
  <div className="f90-hero-logo-card">
    <div className="f90-logo-pill">90</div>
    <div className="f90-logo-caption">Caption</div>
  </div>
</div>
```

### Button Group
```tsx
<div className="f90-hero-actions">
  <Link href="/primary" className="f90-btn f90-btn-primary">
    Primary
  </Link>
  <Link href="/secondary" className="f90-btn f90-btn-ghost">
    Secondary
  </Link>
</div>
```

### Metric Display
```tsx
<div className="f90-hero-metrics">
  <div className="f90-metric">
    <div className="f90-metric-label">Label</div>
    <div className="f90-metric-value">Value</div>
    <div className="f90-metric-note">Note</div>
  </div>
</div>
```

### Section Layout
```tsx
<section className="f90-section">
  <h2 className="f90-section-title">Section Title</h2>
  {/* Section content */}
</section>
```

---

## Accessibility

1. **Color contrast:** All text meets WCAG AA standards
2. **Focus states:** Buttons and links have visible focus indicators
3. **Semantic HTML:** Use proper heading hierarchy and landmarks
4. **Alt text:** Always include alt text for images
5. **Keyboard navigation:** All interactive elements are keyboard accessible

---

## Examples

### Complete Page Structure
```tsx
<main className="f90-page">
  <section className="f90-hero">
    <div className="f90-hero-inner">
      <h1 className="f90-hero-title">
        <span className="f90-type">Title_</span>
      </h1>
      <p className="f90-hero-subtitle">
        Subtitle text
      </p>
      <div className="f90-hero-actions">
        <Link href="/action" className="f90-btn f90-btn-primary">
          Action
        </Link>
      </div>
    </div>
  </section>
  
  <section className="f90-section">
    <h2 className="f90-section-title">Section</h2>
    {/* Content */}
  </section>
  
  <footer className="f90-footer">
    <a href="/link" className="f90-footer-link">
      Link text
    </a>
  </footer>
</main>
```

---

## Quick Reference

**Colors:**
- Primary text: `var(--f90-text)`
- Secondary text: `var(--f90-text-soft)`
- Accent: `var(--f90-accent)`
- Border: `var(--f90-border)`

**Typography:**
- Body: `var(--f90-font-sans)`
- Code/Header: `var(--f90-font-mono)`

**Spacing:**
- Button padding: `10px 18px`
- Card padding: `14px 16px`
- Section gap: `20px`

**Radius:**
- Large: `24px`
- Medium: `16px`
- Pill: `999px`

**Components:**
- Button: `.f90-btn .f90-btn-primary` or `.f90-btn .f90-btn-ghost`
- Nav: `.f90-nav` with `.f90-nav-inner`
- Hero: `.f90-hero` with `.f90-hero-inner`
- Card: `.f90-hero-panel` or custom with border/radius
- Footer: `.f90-footer` with `.f90-footer-link`

