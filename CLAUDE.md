## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (eklynx/ArtCraftAppManager) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Secrets

Store every secret for this project (signing keys, tokens, passwords) in the 1Password vault `Dev-ArtCraftAppManager`, using the `op` CLI. Never commit secrets or leave them in plain files. CI copies them into GitHub Actions secrets; the vault stays the source of truth. The Sparkle EdDSA key is item `SPARKLE_ED_PRIVATE_KEY`.
