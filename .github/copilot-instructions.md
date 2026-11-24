# Robot_Viper project instructions

Before changing Robot Framework tests, read `AGENT.md` and the relevant
sections of `IT_CONVENTIONS.md`, `IT_DUT_REFERENCE.md`, and `IT_PROGRESS.md`.
Tests under `IT/` are generated: edit the matching module under
`IT/_generator/` and regenerate instead of editing generated suites by hand.

The DUT is shared and stateful. Do not run hardware tests, deploy, build, or
push changes unless the user explicitly asks. Prefer the project's documented
RobotCode analysis and dry-run checks for local validation.
