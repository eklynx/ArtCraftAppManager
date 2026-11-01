# 0001 — Run unsandboxed

The Xcode template enables App Sandbox. The Manager has to write apps to arbitrary volumes, mount disk images, replace apps owned by other bundles and move them to the Trash. In a sandbox this needs per-folder user grants and security-scoped bookmarks for every install location, and replacing another bundle in place remains fragile.

We disable App Sandbox, enable Hardened Runtime, and distribute outside the Mac App Store (Developer ID or ad-hoc, personal use). Rejected: staying sandboxed with bookmarks (high complexity, still fragile for updates); App Store distribution (incompatible with the tool's purpose).
