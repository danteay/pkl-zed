{ pkgs, ... }:

let
  # Single source of truth for markdownlint rules: used by the git hook
  # directly and rendered to JSON for manual CLI runs.
  # MD013: prose is wrapped at ~80, but tables and code blocks exceed it.
  markdownlintConfig = {
    MD013 = {
      line_length = 100;
      tables = false;
      code_blocks = false;
    };
  };
  markdownlintConfigFile = pkgs.writeText "markdownlint.json" (builtins.toJSON markdownlintConfig);
in
{
  # Pkl tooling for manual testing of the extension (eval tasks, LSP).
  packages = [
    pkgs.pkl # Pkl CLI
    pkgs.pkl-lsp # Pkl language server (avoids the Java + jar download path)
    pkgs.jq
    pkgs.markdownlint-cli
  ];

  # Zed compiles extensions to WebAssembly; rust-overlay channel is required
  # for extra targets (`targets` is ignored on the default nixpkgs channel).
  languages.rust = {
    enable = true;
    channel = "stable";
    targets = [ "wasm32-wasip2" ];
    components = [
      "rustc"
      "cargo"
      "clippy"
      "rustfmt"
      "rust-analyzer"
    ];
  };

  scripts.build-extension = {
    exec = ''cargo build --release --target wasm32-wasip2 "$@"'';
    description = "Build the extension wasm the same way Zed does";
  };

  scripts.check-extension = {
    # --ignore covers Zed dev-extension build artifacts; the git hook needs
    # no ignores because it only runs on tracked files.
    exec = ''
      cargo fmt --check
      cargo clippy --target wasm32-wasip2 -- -D warnings
      markdownlint --config ${markdownlintConfigFile} --ignore grammars --ignore target '**/*.md'
    '';
    description = "Run formatter and lint checks";
  };

  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy.enable = true;
    markdownlint.enable = true;
    markdownlint.settings.configuration = markdownlintConfig;
  };

  enterTest = ''
    cargo --version
    rustc --print target-list | grep -q wasm32-wasip2
    pkl --version
    cargo build --target wasm32-wasip2
  '';
}
