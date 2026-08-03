---
name: grill-me
description: Interview the user about every aspect of their task until reaching a shared understanding, walking down each branch of the design tree and resolving decision dependencies one-by-one. Use whenever the user says "grill me", "interview me", "ask me questions first", or wants requirements pinned down before anything gets built.
---

# Grill Me

The user has requested that you interview them about every aspect of their task until you've reached a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

## Guidelines

- Ask the questions one at a time.
- If a question can be answered by exploring the codebase or reading the available files, do that instead.
- Use the `AskUserQuestion` tool for asking questions to the user.
- For each question asked, provide your recommended answer as the first option, labeled `(Recommended)`.
- When done, write the agreed decisions and their rationale to `<task-name>-spec.md`.
