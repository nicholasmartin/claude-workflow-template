---
paths:
  - components/**
---

# Component Conventions

<!-- /init-project will expand this based on your codebase. These are sensible defaults for Next.js + TypeScript. -->

## File naming

- React components: PascalCase (e.g., `UserProfile.tsx`)
- Utilities and hooks: kebab-case (e.g., `use-auth.ts`)

## Patterns

- Use `cn()` from your utility lib for conditional class merging (if using Tailwind)
- Prefer server components by default, add `"use client"` only when needed
- Keep components focused on one responsibility
- Co-locate component-specific types in the same file

## Styling

- Use Tailwind utility classes directly
- Mobile-first responsive design
- Check for existing UI components before creating custom ones
