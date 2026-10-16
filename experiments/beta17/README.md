# Beta 17 experimental source archive

Preserved on 2026-10-14 from the working tree based on commit
`bad93ed142c9dc254b9624318e09df840c16019b`:
`0.1.1-beta.17` / `ordered-directory-20261011-17`.

These four files are exact copies of the pre-Phase-1 Activity network, layer
inference, advertisement-backed markers and event wiring. They are outside
`ForeverRP/`, absent from the live TOC, and excluded by the existing packager.
Historical tests explicitly load these copies to retain the original assertions.
Their passing results do not validate the shipping Phase 1 network path.

The complete working tree, including all pre-existing tracked and untracked
changes, the original ZIP, binary patch, base commit, status and hash manifest,
is preserved locally in `build/phase1-beta17-preserved-20261014/`.
This source archive is not a replacement for that complete backup.

Phase 1's runtime tests are in `tests/phase1_same_layer.lua` and use only the
current native modules, with mocked client APIs. Do not load these experiments
in the addon or use their former cross-layer test procedure as Phase 1's gate.
