# Architecture

How this extension is put together and why. Reference docs:
[Zed language extensions](https://zed.dev/docs/extensions/languages),
[apple/pkl-vscode](https://github.com/apple/pkl-vscode) (feature reference),
[apple/pkl-lsp](https://github.com/apple/pkl-lsp).

## Layout

```text
extension.toml        # manifest: grammar pin, language server, snippets
Cargo.toml, src/      # Rust → WebAssembly glue that launches pkl-lsp
languages/pkl/        # language config + tree-sitter queries + tasks
snippets/pkl.json     # code snippets
devenv.{yaml,nix}     # development toolchain
```

## Feature map

| Feature | Mechanism |
| --- | --- |
| Syntax highlighting | tree-sitter grammar + `highlights.scm` |
| Brace matching | `brackets.scm` + `brackets` in `config.toml` (autoclose) |
| Code snippets | `snippets/pkl.json` (static) + pkl-lsp completions |
| Live evaluation | `runnables.scm` tag + `tasks.json` running the `pkl` CLI |
| Go-to-definition | pkl-lsp |
| Hover documentation | pkl-lsp |
| Static analysis (diagnostics, type checking) | pkl-lsp |
| Outline, indentation, text objects, regex injection | remaining `.scm` queries |

## Decisions

### Grammar pinned to tree-sitter-pkl v0.20.0

`extension.toml` pins `apple/tree-sitter-pkl` at the v0.20.0 tag commit
(`e6b390b8…`) rather than tracking `main`, so grammar updates are explicit and
query breakage can't happen underneath us. The grammar ships an external C
scanner (`src/scanner.c`); Zed compiles it fine.

`highlights.scm` and `injections.scm` are adapted from the grammar's canonical
queries with captures remapped to Zed's theme keys (`@escape` →
`@string.escape`, `@variable.builtin` → `@variable.special`, boolean literals
→ `@boolean`, `docComment` → `@comment.doc`).

The pattern order is **inverted** relative to upstream: Zed gives precedence
to the *last* matching pattern, while tree-sitter-highlight (which upstream
targets) uses the first. Generic rules (`(identifier) @variable`, bare
punctuation/keywords) must stay at the top and specific overrides (builtins,
annotations, string interpolation) at the bottom, or the generic rules win —
e.g. the `)` closing a `\(...)` interpolation falls back to
`@punctuation.bracket`. The method-name rule also captures the inner
`(identifier)` rather than the whole `methodHeader`, because Zed styles the
deepest capture for a span. The remaining queries
(`brackets`, `indents`, `outline`, `overrides`, `textobjects`, `runnables`)
are written for this extension — upstream doesn't provide them. Zed has no
`folds.scm`; folding is derived from indentation, so pkl-vscode's fold query
has no equivalent here.

### Language server resolution order

`src/lib.rs` resolves pkl-lsp as: user setting (`lsp.pkl-lsp.binary.path`) →
`pkl-lsp` on PATH → auto-downloaded jar run with `java -jar`. Rationale:

- pkl-lsp is distributed as a **jar only** (GitHub releases / Maven Central)
  and needs Java 23+ as of 0.7.x (class file version 67); there is no native
  binary to download. Extensions cannot spawn processes, so the Java version
  cannot be checked before launch — `$JAVA_HOME/bin/java` is preferred over
  PATH lookup, and an old runtime surfaces as `UnsupportedClassVersionError`
  in the server logs.
- Nix/Homebrew users already have a `pkl-lsp` launcher wrapping the JVM, which
  avoids the Java requirement entirely — so PATH wins over downloading.
- The jar path passed to `-jar` is made absolute with `env::current_dir()`
  because Zed only resolves the *command* relative to the extension work dir,
  not its arguments.
- The jar launches in stdio mode by default; there is no `--stdio` flag.
- Old jar versions are pruned from the extension work dir after a successful
  download (same pattern as the canonical zed-gleam extension).

Zed's published-extension policy forbids bundling server binaries, which rules
out shipping the jar (pkl-vscode bundles one; we can't).

### Workspace configuration

pkl-lsp reads VS Code-style settings under the `pkl` section (`pkl.cli.path`,
`pkl.modulepath`, …). `language_server_workspace_configuration` forwards
whatever the user puts in `lsp.pkl-lsp.settings` under `{"pkl": …}` and
defaults `cli.path` to the `pkl` binary on PATH so project sync and package
downloads work out of the box.

### Live evaluation via tasks, not the LSP

pkl-vscode has **no** evaluation feature; evaluation is a `pkl` CLI concern.
Zed's runnables mechanism fits: `runnables.scm` tags the module's first
top-level construct (`(module . (_) @run)`, tag `pkl-eval`), which places a
run button near the top of every Pkl file, bound to the `tasks.json`
templates (`pkl eval`, `pkl eval -f json|yaml`, `pkl test`). The first child
is used instead of the `(module)` root node because a root capture spans the
entire file and Zed's gutter never surfaces an indicator for it (every
runnables query in the ecosystem captures a small named node); it also can't
be `moduleHeader`, which is absent in plain config files.

### Snippets are ours, not ported

pkl-vscode ships no snippet file (its "snippets" are pkl-lsp completion
items), so `snippets/pkl.json` was written for this extension following the
[Pkl language reference](https://pkl-lang.org/main/current/language-reference/index.html).

### devenv toolchain

`languages.rust.channel = "stable"` (rust-overlay) is required because the
default `nixpkgs` channel ignores `targets`; Zed builds extensions for
`wasm32-wasip2`. `pkl` and `pkl-lsp` come from nixpkgs so eval tasks and the
PATH-based LSP branch are testable inside the shell. Note that Zed's own
dev-extension installer uses the rustup-managed toolchain on the host, not the
devenv one — devenv covers building, linting, and CI parity.

## Known limitations

- pkl-lsp serves stdlib/package sources as virtual documents under a
  `pkl-lsp:` URI scheme with custom requests (`pkl/downloadPackage`,
  `pkl/syncProjects`). Zed has no extension hook for custom URI schemes or
  commands, so go-to-definition *into the stdlib or packages* may not open a
  document, and package downloads must be done via `pkl` CLI tasks instead.
- Custom string delimiters (`#"…"#` … up to `#####`) are highlighted, but
  autoclose pairs cover only the plain `"` and `` ` `` delimiters — Zed
  bracket pairs are static strings and adding every pound/triple-quote
  combination creates noisy autoclosing.
