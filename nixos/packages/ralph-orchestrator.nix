{ lib, rustPlatform, buildNpmPackage, importNpmLock, pkg-config, openssl }:
let
  version = "2.10.1";
  # A complete Git revision makes this fetch immutable, including in pure evaluation.
  src = builtins.fetchGit {
    url = "https://github.com/mikeyobrien/ralph-orchestrator.git";
    ref = "refs/tags/v${version}";
    rev = "407cb96b25a5705a779d598282d070e6f80f712c";
    shallow = true;
  };
  dashboard = buildNpmPackage {
    pname = "ralph-orchestrator-dashboard";
    inherit version src;
    # Use integrity hashes from the upstream lockfile, rather than a mutable npm install.
    npmDeps = importNpmLock { npmRoot = src; };
    npmConfigHook = importNpmLock.npmConfigHook;
    npmBuildScript = "build:web";
    # The legacy Node API is unused; do not build its native SQLite dependency.
    # Vite/esbuild use the platform packages already present in package-lock.json.
    npmRebuildFlags = [ "--ignore-scripts" ];
    env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/ralph-orchestrator"
      cp -r frontend/ralph-web/dist "$out/share/ralph-orchestrator/web"
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "ralph-orchestrator";
  inherit version src;
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
  patches = [ ./ralph-task-log-stream.patch ./ralph-opencode-activity.patch ];
  postPatch = ''
    cp ${./ralph-task-log-watcher.rs} crates/ralph-api/src/task_log_watcher.rs
  '';
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
  cargoBuildFlags = [ "-p" "ralph-cli" "-p" "ralph-api" ];
  # API and adapter tests cover log streaming, partial-output activity, and event handoff.
  doCheck = true;
  cargoTestFlags = [ "-p" "ralph-api" "-p" "ralph-adapters" "--lib" ];
  postInstall = ''
    # Keep the separate @wiggumdev/ralph CLI unambiguous in interactive shells.
    mv "$out/bin/ralph" "$out/bin/ralph-orchestrator"
    mkdir -p "$out/share/ralph-orchestrator"
    ln -s ${dashboard}/share/ralph-orchestrator/web "$out/share/ralph-orchestrator/web"
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/ralph-orchestrator" --version | grep -F '${version}'
    test -x "$out/bin/ralph-api"
    test -s "$out/share/ralph-orchestrator/web/index.html"
    runHook postInstallCheck
  '';
  passthru = { inherit dashboard; };
  meta = {
    description = "Ralph Orchestrator CLI, Rust API, and compiled web dashboard";
    homepage = "https://github.com/mikeyobrien/ralph-orchestrator";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ralph-orchestrator";
  };
}
