# pkl-zed

[Pkl](https://pkl-lang.org) language support for the [Zed](https://zed.dev) editor.

## Features

- **Syntax highlighting** via the official
  [apple/tree-sitter-pkl](https://github.com/apple/tree-sitter-pkl) grammar
- **Brace matching** and rainbow brackets, including `<>` type arguments
- **Code snippets** for modules, classes, generators, tests, and more
- **Live evaluation** — a run button on every Pkl module plus `pkl eval` /
  `pkl test` tasks (pcf, JSON, YAML output)
- **Go-to-definition, hover documentation, completions, and static analysis**
  via the official [apple/pkl-lsp](https://github.com/apple/pkl-lsp) language
  server
- Auto-indentation, code outline/breadcrumbs, Vim text objects, and regex
  injection inside `Regex("...")`

Recognized files: `*.pkl`, `*.pcf`, `PklProject`, and shebang scripts (`#!/usr/bin/env pkl`).

## Requirements

| Feature | Requirement |
| --- | --- |
| Highlighting, brackets, snippets, outline | none |
| Live evaluation tasks | `pkl` CLI on PATH ([install guide](https://pkl-lang.org/main/current/pkl-cli/index.html)) |
| LSP features (hover, go-to-def, diagnostics) | `pkl-lsp` on PATH, **or** Java 23+ on PATH/`JAVA_HOME` (the extension auto-downloads the pkl-lsp jar) |

The language server is resolved in this order:

1. `lsp.pkl-lsp.binary.path` from your Zed settings
2. A `pkl-lsp` executable on PATH (e.g. from nixpkgs or Homebrew)
3. `java -jar pkl-lsp-<version>.jar`, downloaded automatically from GitHub
   releases; `$JAVA_HOME/bin/java` is preferred over `java` from PATH

> [!IMPORTANT]
> Zed launched from the Dock/Finder does not see your dev-shell PATH. If the
> language server fails with `UnsupportedClassVersionError`, the `java` Zed
> found is older than 23. Either install a current JDK, or install the server
> globally (`nix profile install nixpkgs#pkl-lsp`), or point
> `lsp.pkl-lsp.binary.path` at one.

## Configuration

All settings go under `lsp.pkl-lsp` in your Zed `settings.json`:

```json
{
  "lsp": {
    "pkl-lsp": {
      "binary": {
        "path": "/path/to/pkl-lsp"
      },
      "settings": {
        "cli": { "path": "/path/to/pkl" }
      }
    }
  }
}
```

`settings` is forwarded to pkl-lsp as the `pkl` workspace configuration section
(e.g. `cli.path`, `modulepath`, `projects.excludedDirectories`). When
`cli.path` is not set, the extension points pkl-lsp at the `pkl` binary found
on PATH automatically.

## Live evaluation

Open any `.pkl` file and either click the run button in the gutter of the
first line or open the task picker (`task: spawn`) and choose one of:

- `pkl eval <file>` — renders the module as pcf (Pkl's default)
- `pkl eval <file> (json)` / `(yaml)` — renders as JSON/YAML
- `pkl test <file>` — runs a `pkl:test` module
- `pkl project resolve` — resolves `PklProject` dependencies

## Development

Tooling is defined with [devenv](https://devenv.sh) (Rust stable +
`wasm32-wasip2` target, `pkl`, `pkl-lsp`, rustfmt/clippy git hooks):

```sh
devenv shell          # or `direnv allow` for automatic activation
build-extension       # cargo build --release --target wasm32-wasip2
check-extension       # fmt + clippy
devenv test           # full check: toolchain, target, wasm build
```

To try the extension in Zed:

1. Zed compiles extensions with your local Rust — it must be installed **via
   rustup** (the devenv toolchain covers building/linting; Zed's dev-extension
   installer invokes its own cargo).
2. In Zed run `zed: install dev extension` and pick this directory.
3. Open a `.pkl` file. Check `zed: open log` (or run `zed --foreground`) if
   the language server does not start.

Architecture notes and decisions live in [docs/architecture.md](docs/architecture.md).
A feature-by-feature manual test plan lives in [docs/manual-testing.md](docs/manual-testing.md).

## Publishing

Releases are published by PR to
[zed-industries/extensions](https://github.com/zed-industries/extensions):
this repo is registered as the `pkl-lang` extension (submodule
`extensions/pkl-lang`), with the `extensions.toml` version matching
`extension.toml`. The `pkl` ID belongs to a pre-existing community extension;
this one differentiates with snippets, live evaluation tasks, and a richer
query set. To release a new version: bump `version` in `extension.toml`,
merge to `main`, then update the submodule + version in the registry.

## License

Apache-2.0 — see [LICENSE](LICENSE).
