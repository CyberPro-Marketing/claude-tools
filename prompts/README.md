# Prompts

Prompts Adam pastes into a session. Each file holds one prompt inside a code
block, ready to copy. They are not run by `setup.sh`; nothing here installs
anything.

| File | When to use it |
|---|---|
| [`website-warmup.md`](website-warmup.md) | First message of a new website session: checks the tools loaded, loads the design skills, reads the repo, then waits |
| [`website-template.md`](website-template.md) | Second message: the design brief, with brackets to fill in per site |

When a tool is added to or removed from `tools/`, update the tool list in
`website-warmup.md` and the HOW TO WORK line in `website-template.md` to match.
