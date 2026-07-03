# Manual testing guide

Step-by-step verification of every extension feature. Run through it after
changing queries, `config.toml`, `src/lib.rs`, or bumping the grammar/LSP.

## Setup

1. Enter the dev environment so `pkl` and `pkl-lsp` are on PATH:

   ```sh
   cd ~/apps/danteay/pkl-zed
   devenv shell   # or `direnv allow` once, then it's automatic
   ```

2. Launch Zed **from that shell** so it inherits PATH (needed for the eval
   tasks and the PATH-based LSP branch):

   ```sh
   zed .
   ```

3. Install/rebuild the extension: command palette → `zed: install dev
   extension` → select this directory. If already installed, use
   `extensions: rebuild dev extension` instead.
4. Open `examples/example.pkl`. The status bar (bottom right) must say
   **Pkl**.

For any failure below, first check `zed: open log`, or relaunch with
`zed --foreground` from a terminal to see extension `println!` output and LSP
stderr.

## 1. File type detection

| Step | Expected |
| --- | --- |
| Open `examples/example.pkl` | Language shown as **Pkl** |
| Create and open an empty file named `PklProject` | Language **Pkl** |
| Create `test.pcf` | Language **Pkl** |
| Create an extensionless file whose first line is `#!/usr/bin/env pkl` | Language **Pkl** |

## 2. Syntax highlighting

Open `examples/example.pkl` and check each of these against your theme
(compare with a Rust/JSON file to confirm colors are being applied at all):

- [ ] `module`, `import`, `class`, `function`, `hidden`, `local`, `if`,
      `else`, `for`, `when`, `new`, `typealias` render as **keywords**
- [ ] `/// ...` doc comments render as doc comments (line 1) and `//`
      comments as comments
- [ ] String literals (`"localhost"`) render as **strings**; numbers
      (`8080`, `30`) as **numbers**; `true`/`false` as **booleans**
- [ ] Type names (`Endpoint`, `String`, `Port`, `Listing<Endpoint>`) render
      as **types**
- [ ] Property names (`host`, `port`, `secure`) render as **properties**
- [ ] Method name `url` renders as a **function**, and its parameter `path`
      as a **parameter**
- [ ] String interpolation: in `"\(scheme)://\(host):\(port)\(path)"` both
      the `\(` **and the closing `)`** render as special punctuation
      (regression check — Zed uses last-pattern-wins, see
      [architecture.md](architecture.md))
- [ ] Add `@Deprecated` on its own line above a property → `@` and
      `Deprecated` render as **attribute**; remove it afterwards
- [ ] Type a string with `"a\tb"` → `\t` renders as an **escape**, distinct
      from the rest of the string
- [ ] `this` (add `this.host` inside the class) renders differently from
      normal variables

## 3. Brace matching

- [ ] Place the cursor on the `{` after `class Endpoint` → its matching `}`
      is highlighted (and vice versa)
- [ ] Same for `(`/`)` in `url(path: String)` and `[`/`]` in
      `["\(endpoint.host)"]`
- [ ] Cursor on `<` in `Listing<Endpoint>` matches the closing `>`
- [ ] Autoclose: on a new line type `{` → `}` is inserted; press Enter inside
      → an indented blank line opens between them
- [ ] Autoclose: typing `"` inserts the closing quote; typing `"` **inside an
      existing string** does *not* insert a pair
- [ ] Select a word and type `{` → the selection is surrounded, not replaced

## 4. Code snippets

In a scratch `.pkl` buffer:

- [ ] Type `class` → the completion menu offers the **Class** snippet; accept
      it → tab stops jump name → property → type
- [ ] Type `module`, `amends`, `import`, `function`, `for`, `when`, `output`,
      `test` → each offers its snippet
- [ ] The `output` snippet's renderer tab stop offers the choice list
      (JsonRenderer, YamlRenderer, ...)
- [ ] Accept the `test` snippet → produces a valid `amends "pkl:test"`
      module

## 5. Live evaluation (tasks)

Requires `pkl` on PATH (step 0.2).

- [ ] A **run button** appears in the gutter next to the first top-level
      construct of `examples/example.pkl` (line 1, the doc comment above the
      module clause)
- [ ] Click it → task menu lists `pkl eval`, `pkl eval (json)`,
      `pkl eval (yaml)`, `pkl test`
- [ ] Run `pkl eval` → terminal panel opens and prints the config in pcf
      (Pkl's default format), exit code 0
- [ ] Run `pkl eval (json)` → same config rendered as JSON
- [ ] Run `pkl eval (yaml)` → same config rendered as YAML
- [ ] Gotcha check: add `output { renderer = new JsonRenderer {} }` to the
      module → *all* eval tasks now print JSON. This is Pkl semantics, not a
      task bug: an explicit `output.renderer` overrides the CLI `--format`
      flag. Remove it afterwards
- [ ] Command palette → `task: spawn` → the same tasks plus
      `pkl project resolve` are listed
- [ ] Break the file (e.g. delete a closing `}`), run `pkl eval` → the task
      fails with a Pkl error message pointing at the file; undo

## 6. Language server startup

- [ ] Open `examples/example.pkl` and check the LSP indicator / activity in
      the status bar: **Pkl LSP** should be running (also visible in
      `dev: open language server logs`)
- [ ] PATH branch: since `pkl-lsp` is on PATH from devenv, the log should
      show it launched directly (no jar download)
- [ ] Jar-download branch (optional): launch Zed from a shell *without*
      `pkl-lsp` but *with* `java` (23+) on PATH → the extension downloads
      `pkl-lsp-<version>.jar` and starts it; first start takes a few seconds
- [ ] Error branch (optional): with neither `pkl-lsp` nor `java` on PATH →
      the LSP fails with the message suggesting to install a JDK 23+ or set
      `lsp.pkl-lsp.binary.path`
- [ ] Old-Java branch (optional): with only a Java < 23 on PATH → the server
      dies at startup and the Zed log shows `UnsupportedClassVersionError`
      (expected; extensions cannot version-check Java before launching)

## 7. Hover documentation

- [ ] Hover over `Listing` in `Listing<Endpoint>` → stdlib documentation
      popup for `Listing`
- [ ] Hover over `Endpoint` in the `endpoints` declaration → shows the class
      (and its doc comment if you add one)
- [ ] Hover over `url` where it is *called* (`endpoint.url("/health")`) →
      shows the method signature
- [ ] Hover over `math.maxInt8` → stdlib docs for the property

## 8. Go-to-definition

- [ ] Cmd-click (or `editor: go to definition`) on `Endpoint` in
      `Listing<Endpoint>` → jumps to `class Endpoint`
- [ ] Go-to-definition on `endpoint.url(...)` → jumps to the `url` method
- [ ] Go-to-definition on `defaultTimeout` usage → jumps to the `local`
      declaration
- [ ] Go-to-definition on `Port` → jumps to the `typealias`
- [ ] *Known limitation:* go-to-definition into the stdlib (e.g. `Listing`
      itself) may not open a document — pkl-lsp serves those as `pkl-lsp:`
      virtual documents Zed can't display (see architecture.md)

## 9. Static analysis (diagnostics)

Each item: introduce the error, wait ~1s, check the squiggle and the
diagnostics panel (`diagnostics: deploy`), then undo.

- [ ] Type error: change `port: Port = 8080` to `port: Port = "8080"` →
      error diagnostic on the value
- [ ] Unresolved reference: add `foo = doesNotExist` at module level →
      error on `doesNotExist`
- [ ] Broken import: change `import "pkl:math"` to `import "pkl:nope"` →
      error on the import
- [ ] Completions (bonus): type `math.` → member completion list appears;
      type `endpoints[0].` → `host`, `port`, `secure`, `url` are offered

## 10. Outline, indentation, comments, text objects

- [ ] `outline: toggle` (Cmd+Shift+O) → lists `com.example.server`, `Port`,
      `Endpoint` (with `host`, `port`, `secure`, `scheme`, `url` nested),
      `defaultTimeout`, `endpoints`, `config`, `output`
- [ ] Breadcrumbs at the top of the editor update as the cursor moves into
      the class / a method
- [ ] Auto-indent: pressing Enter after `new {` indents by 2 spaces (not 4)
- [ ] `editor: toggle comments` (Cmd+/) on a code line prefixes it with `//`
      and a space; on a selection spanning several lines toggles them all
- [ ] Regex injection: type `regex = Regex("[a-z]+")` → the pattern inside
      the string gets regex highlighting
- [ ] Vim mode only: with the cursor inside the `url` method body, `vif`
      selects the method body, `vaf` the whole method; `vac` selects the
      class; `gc` motions treat consecutive `//` lines as one comment block

## 11. Settings overrides (`src/lib.rs` branches)

In `settings.json`, verify each branch (revert after each):

- [ ] Binary override — point to the devenv binary and restart the server
      (`dev: restart language server`); it must be used:

  ```json
  { "lsp": { "pkl-lsp": { "binary": { "path": "/absolute/path/to/pkl-lsp" } } } }
  ```

- [ ] Bad binary path → LSP fails to start and the log names that path
      (confirms the setting is honored)
- [ ] Workspace settings passthrough — set a bogus CLI path and check the
      server log picks it up (project sync will complain):

  ```json
  { "lsp": { "pkl-lsp": { "settings": { "cli": { "path": "/nonexistent/pkl" } } } } }
  ```

## 12. Regression sweep after grammar/query changes

Quick automated pass that complements the manual checks — validates the
example still parses and every query still compiles against the pinned
grammar:

```sh
git clone https://github.com/apple/tree-sitter-pkl /tmp/tree-sitter-pkl
git -C /tmp/tree-sitter-pkl checkout e6b390b87a3998a3ebf61f3ee7c3605953e65453
cd /tmp/tree-sitter-pkl
tree-sitter parse ~/apps/danteay/pkl-zed/examples/example.pkl --quiet
for q in highlights brackets indents outline injections overrides textobjects runnables; do
  tree-sitter query ~/apps/danteay/pkl-zed/languages/pkl/$q.scm \
    ~/apps/danteay/pkl-zed/examples/example.pkl > /dev/null && echo "$q OK"
done
```

(`tree-sitter` is available via `nix shell nixpkgs#tree-sitter`.)
