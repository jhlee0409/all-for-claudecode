# Ecommerce Domain Adapter

> Guardrails for ecommerce and retail projects. Auto-loaded when project-profile domain is `ecommerce`.

## Compliance Requirements

- Payment processing: PCI-DSS compliance via third-party (Stripe, PayPal) — never process cards directly
- Cookie consent: GDPR/ePrivacy for EU customers (tracking, analytics, marketing cookies)
- Consumer protection: clear return/refund policy, accurate product descriptions

## Data Handling Rules

- Prices: store in smallest currency unit (cents), display with locale formatting
- Product variants: normalize SKU structure early (size/color/material)
- Inventory: eventual consistency is acceptable for display, strong consistency for checkout
- Tax calculation: use external service (TaxJar, Avalara) — tax rules change frequently
- Discount/coupon stacking rules: define clearly before building

## Domain-Specific Guardrails

- **Core Flows**: Cart → Checkout → Payment → Fulfillment — each transition must be atomic
- **Inventory management**: prevent overselling (stock reservation on add-to-cart or checkout)
- **Order state machine**: clear state transitions (pending → paid → shipped → delivered → returned)
- **SEO**: unique title + meta description + JSON-LD Product schema per product page
- **URLs**: human-readable slugs (`/products/blue-widget` not `/products/12345`)
- **Sitemap**: include all product pages, update frequency based on price/stock changes
- **Performance**: paginate product listings, lazy-load images (WebP/AVIF), cache category pages

## Security Heightened Checks

- User accounts: password reset flow, account lockout after failed attempts
- Admin panel: separate authentication, audit logging for price/inventory changes
- CSRF protection on all form submissions
- Cart tampering: server-side price validation (never trust client-side price)

## Testing Requirements

- Cart edge cases: empty cart checkout, single item, max items, out-of-stock during checkout
- Price consistency: price at add-to-cart vs price at checkout (stale cart)
- Concurrent purchases: last-item-in-stock race condition
- Discount stacking: multiple coupons, coupon + sale price, minimum order value

## Scale Considerations

- Flash sales / traffic spikes: queue-based checkout for burst traffic
- International: multi-currency, multi-language, shipping zones
- Catalog size thresholds: < 100 products (simple DB), 100-10K (indexed search), 10K+ (dedicated search service)
