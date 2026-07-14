---
paths:
  - app/api/**
---

# API Route Conventions

<!-- /init-project will expand this based on your codebase. These are sensible defaults for Next.js App Router. -->

## Location

API routes live under `app/api/`. Use versioned paths (e.g., `app/api/v1/`) if the API is consumed by external clients.

## Pattern

```typescript
import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
  // 1. Validate auth/input
  // 2. Perform operation
  // 3. Return response
  return NextResponse.json({ data });
}
```

## Rules

- Always validate input before database operations
- Return consistent error shapes: `{ error: { code, message } }`
- Use appropriate HTTP status codes
- Handle errors explicitly, don't let them bubble as 500s
