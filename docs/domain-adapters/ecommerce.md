# Ecommerce Domain Adapter

> Guardrails for ecommerce and retail projects. Auto-loaded when project-profile domain is `ecommerce`.

## Core Flows to Protect

- **Cart → Checkout → Payment → Fulfillment**: each transition must be atomic
- **Inventory management**: prevent overselling (stock reservation on add-to-cart or checkout)
- **Order state machine**: clear state transitions (pending → paid → shipped → delivered → returned)

## Data Handling Rules

- Prices: store in smallest currency unit (cents), display with locale formatting
- Product variants: normalize SKU structure early (size/color/material)
- Inventory: eventual consistency is acceptable for display, strong consistency for checkout
- Tax calculation: use external service (TaxJar, Avalara) — tax rules change frequently
- Discount/coupon stacking rules: define clearly before building

## Performance Guardrails

- Product listing pages: paginate, never load all products
- Search: use dedicated search service (Algolia, Elasticsearch, Meilisearch) for > 1K products
- Image optimization: WebP/AVIF with responsive sizes, lazy loading
- Cart: client-side optimistic updates + server validation
- Category pages: cache aggressively (product data changes infrequently)

## SEO Requirements

- Product pages: unique title, meta description, structured data (JSON-LD Product schema)
- Category pages: canonical URLs, proper pagination (rel=next/prev or infinite scroll with SEO fallback)
- Sitemap: include all product pages, update frequency based on price/stock changes
- URL structure: human-readable slugs (`/products/blue-widget` not `/products/12345`)

## Security Considerations

- Payment: always server-side (Stripe, PayPal) — never process cards directly
- User accounts: password reset flow, account lockout after failed attempts
- Admin panel: separate authentication, audit logging for price/inventory changes
- CSRF protection on all form submissions

## Testing Requirements

- Cart edge cases: empty cart checkout, single item, max items, out-of-stock during checkout
- Price consistency: price at add-to-cart vs price at checkout (stale cart)
- Concurrent purchases: last-item-in-stock race condition
- Discount stacking: multiple coupons, coupon + sale price, minimum order value

## Scale Considerations

- Flash sales / traffic spikes: queue-based checkout for burst traffic
- International: multi-currency, multi-language, shipping zones
- Catalog size thresholds: < 100 products (simple DB), 100-10K (indexed search), 10K+ (dedicated search service)
