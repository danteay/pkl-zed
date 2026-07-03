use std::{env, fs};

use zed_extension_api::{
    self as zed,
    serde_json::{json, Value},
    settings::LspSettings,
    LanguageServerId, Result,
};

const SERVER_ID: &str = "pkl-lsp";
const PKL_LSP_REPO: &str = "apple/pkl-lsp";

struct PklExtension {
    cached_jar_path: Option<String>,
}

impl PklExtension {
    /// Resolve the pkl-lsp jar, downloading the latest GitHub release into the
    /// extension's work directory when needed. Returns an absolute path because
    /// the jar is passed to `java` as an argument, which Zed does not rewrite.
    fn jar_path(&mut self, language_server_id: &LanguageServerId) -> Result<String> {
        if let Some(path) = &self.cached_jar_path {
            if fs::metadata(path).is_ok_and(|stat| stat.is_file()) {
                return Ok(path.clone());
            }
        }

        zed::set_language_server_installation_status(
            language_server_id,
            &zed::LanguageServerInstallationStatus::CheckingForUpdate,
        );

        let release = zed::latest_github_release(
            PKL_LSP_REPO,
            zed::GithubReleaseOptions {
                require_assets: true,
                pre_release: false,
            },
        )?;

        let asset_name = format!("pkl-lsp-{}.jar", release.version);
        let asset = release
            .assets
            .iter()
            .find(|asset| asset.name == asset_name)
            .ok_or_else(|| format!("no asset named {asset_name:?} in pkl-lsp release"))?;

        let version_dir = format!("pkl-lsp-{}", release.version);
        let jar_path = format!("{version_dir}/{asset_name}");

        if !fs::metadata(&jar_path).is_ok_and(|stat| stat.is_file()) {
            zed::set_language_server_installation_status(
                language_server_id,
                &zed::LanguageServerInstallationStatus::Downloading,
            );

            fs::create_dir_all(&version_dir)
                .map_err(|err| format!("failed to create directory {version_dir:?}: {err}"))?;
            zed::download_file(
                &asset.download_url,
                &jar_path,
                zed::DownloadedFileType::Uncompressed,
            )
            .map_err(|err| format!("failed to download pkl-lsp: {err}"))?;

            // Prune jars from older releases.
            if let Ok(entries) = fs::read_dir(".") {
                for entry in entries.flatten() {
                    if entry.file_name().to_str() != Some(&version_dir) {
                        fs::remove_dir_all(entry.path()).ok();
                    }
                }
            }
        }

        let absolute_jar_path = env::current_dir()
            .map_err(|err| format!("failed to resolve extension work directory: {err}"))?
            .join(&jar_path)
            .to_string_lossy()
            .to_string();

        self.cached_jar_path = Some(absolute_jar_path.clone());
        Ok(absolute_jar_path)
    }
}

impl zed::Extension for PklExtension {
    fn new() -> Self {
        Self {
            cached_jar_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let settings = LspSettings::for_worktree(SERVER_ID, worktree).ok();

        // 1. Explicit binary override from Zed settings (`lsp.pkl-lsp.binary`).
        if let Some(binary) = settings
            .as_ref()
            .and_then(|settings| settings.binary.as_ref())
        {
            if let Some(path) = &binary.path {
                return Ok(zed::Command {
                    command: path.clone(),
                    args: binary.arguments.clone().unwrap_or_default(),
                    env: Default::default(),
                });
            }
        }

        // 2. A `pkl-lsp` launcher already on PATH (e.g. nixpkgs, mise).
        if let Some(path) = worktree.which("pkl-lsp") {
            return Ok(zed::Command {
                command: path,
                args: Vec::new(),
                env: worktree.shell_env(),
            });
        }

        // 3. Fall back to `java -jar pkl-lsp-<version>.jar`, auto-downloaded.
        // pkl-lsp 0.7.x requires Java 23+. Extensions cannot spawn processes,
        // so the Java version cannot be checked up front; prefer JAVA_HOME (a
        // deliberately chosen JDK) over whatever `java` happens to be on PATH.
        // An outdated Java fails at launch with UnsupportedClassVersionError.
        let env = worktree.shell_env();
        let java = env
            .iter()
            .find(|(name, _)| name == "JAVA_HOME")
            .map(|(_, java_home)| format!("{java_home}/bin/java"))
            .or_else(|| worktree.which("java"))
            .ok_or_else(|| {
                "pkl-lsp requires Java 23 or newer. Install a JDK 23+ and make \
                 `java` available on PATH (or set JAVA_HOME), install `pkl-lsp` \
                 directly (e.g. `nix profile install nixpkgs#pkl-lsp`), or set \
                 `lsp.pkl-lsp.binary.path` in your Zed settings."
                    .to_string()
            })?;
        let jar = self.jar_path(language_server_id)?;

        Ok(zed::Command {
            command: java,
            args: vec!["-jar".to_string(), jar],
            env,
        })
    }

    fn language_server_initialization_options(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<Value>> {
        Ok(LspSettings::for_worktree(SERVER_ID, worktree)
            .ok()
            .and_then(|settings| settings.initialization_options))
    }

    fn language_server_workspace_configuration(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<Value>> {
        let mut pkl_settings = LspSettings::for_worktree(SERVER_ID, worktree)
            .ok()
            .and_then(|settings| settings.settings)
            .unwrap_or_else(|| json!({}));

        // pkl-lsp uses the pkl CLI for project sync and package downloads;
        // point it at the CLI on PATH unless the user configured one.
        if pkl_settings.pointer("/cli/path").is_none() {
            if let Some(pkl_path) = worktree.which("pkl") {
                if let Some(settings_object) = pkl_settings.as_object_mut() {
                    settings_object
                        .entry("cli")
                        .or_insert_with(|| json!({}))
                        .as_object_mut()
                        .map(|cli| cli.insert("path".to_string(), json!(pkl_path)));
                }
            }
        }

        Ok(Some(json!({ "pkl": pkl_settings })))
    }
}

zed::register_extension!(PklExtension);
