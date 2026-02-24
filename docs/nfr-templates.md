# NFR Templates by Project Type

This document provides Non-Functional Requirement (NFR) templates organized by project type. The `/afc:spec` command references this document to auto-suggest NFRs based on the detected project type, helping teams establish quality baselines early in the specification phase.

## Web Application (React, Next.js, Vue, Svelte)
- Accessibility (WCAG 2.1 AA compliance for interactive elements)
- SEO (meta tags, structured data, semantic HTML)
- Performance (LCP < 2.5s, FID < 100ms, CLS < 0.1)
- Bundle size (JS bundle < 200KB gzipped for initial load)
- Responsive design (mobile-first, breakpoints: 320px, 768px, 1024px, 1440px)

## API / Backend (Express, Fastify, NestJS)
- Latency (p95 response time < 200ms for read, < 500ms for write)
- Rate limiting (per-user and per-IP)
- Error response format (consistent JSON error schema)
- Authentication/Authorization (JWT validation, RBAC)
- Logging (structured JSON logs, request tracing)

## CLI / Plugin (Bash, Node CLI)
- Startup latency (< 200ms for hook scripts, < 1s for CLI commands)
- Backward compatibility (existing behavior unchanged)
- Error handling (non-zero exit codes, stderr for errors, stdout for data)
- Idempotency (re-running produces same result)
- Graceful degradation (optional dependencies warn, don't block)

## Mobile (React Native, Flutter)
- Offline capability (core features available without network)
- Battery efficiency (background tasks minimized)
- Startup time (< 2s cold start)
- Touch targets (minimum 44x44pt)

## Monorepo
- Build isolation (package changes don't trigger unrelated builds)
- Dependency consistency (shared versions for common packages)
- CI parallelization (independent packages test in parallel)

## Usage Notes
- Tag auto-suggested NFRs with `[AUTO-SUGGESTED]` in spec.md
- Users may accept, modify, or remove suggestions
- Not all NFRs apply to every project — select the most relevant 3-5
