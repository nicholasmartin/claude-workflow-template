# Example Reference Doc

**Purpose:** This is a template showing the scout-friendly header format. Delete this file and create real docs as your project grows.

**When to use:** When you have complex subsystems that need detailed documentation (database schema, API design, queue architecture, etc.) but you don't want to load all of it into every conversation.

**Size:** ~30 lines (this is just the example)

---

## How Scout-Friendly Docs Work

Reference docs in `.claude/docs/` follow a pattern:

1. Each file starts with a header block: **Purpose**, **When to use**, **Size**
2. When an agent needs context, it reads just the headers of all docs first
3. It only loads the full doc if the header indicates relevance to the current task
4. This prevents wasting the context window on irrelevant material

## Creating Your Own

When a subsystem gets complex enough to need its own doc, create a file here with:

```markdown
# Subsystem Name

**Purpose:** What this doc covers and why it exists
**When to use:** Which tasks or file areas make this doc relevant
**Size:** Approximate line count so agents can judge context cost

---

(detailed content below the separator)
```

Good candidates for reference docs:
- Database schema and migration patterns
- Authentication/authorization flow
- API design and endpoint catalog
- Queue or job processing architecture
- Third-party integration details
