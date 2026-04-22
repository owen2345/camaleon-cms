# Secrets Handling

Use this file as the single source of truth for secret material in this repository.

## What Counts as a Secret
- `.env` and `.env.*` runtime config files (except `.env.example`).
- Rails key files, including `config/master.key` and other `config/*.key` files.
- Certificate private key material and related artifacts, especially under `config/certs/`:
    - `*.key`, `*.pem`, `*.p12`, `*.pfx`, `*.csr`
- Sensitive credential values loaded via environment variables (client secrets, passphrases, private-key paths).

## Repository Rules
- Do not commit secrets to git.
- Keep `.env.example` as template-only (no real values).
- Keep certificate and key files local; store only non-sensitive docs/runbooks in `docs/`.
- Generated public key artifacts (for example `~/secrets/camaleon_cms/guide_2026-04-04/client_public.key`) are non-secret but should remain local unless a portal explicitly requires upload/sharing.

## Enforcement and References
- Ignore rules are defined in `.gitignore` (`.env*`, `config/*.key`, `config/certs/*`, key/cert extensions).
- Environment-variable shape: `.env.example` and `README.md`.
