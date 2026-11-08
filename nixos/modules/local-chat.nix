{ config, lib, ... }:
{
  options.services.remote-ai.baseUrl = lib.mkOption {
    type = lib.types.str;
    description = "OpenAI-compatible inference endpoint shared by Open WebUI and OpenCode.";
  };

  config.virtualisation.oci-containers = {
    backend = "docker";
    containers.open-webui = {
      # Pin the official image: the current nixpkgs Python package is broken.
      image = "ghcr.io/open-webui/open-webui:v0.12.3@sha256:a537bbe1e6b428820f52ed4a029d7fff97062e24d5cf32c365fba36fd0542def";
      autoStart = true;
      # The host's systemd-resolved stub resolves the GPU server's .local name.
      # This requires host networking so 127.0.0.53 refers to the host resolver.
      extraOptions = [ "--network=host" "--dns=127.0.0.53" ];
      volumes = [ "open-webui:/app/backend/data" ];
      environment = {
        HOST = "0.0.0.0";
        PORT = "3000";
        OPENAI_API_BASE_URL = config.services.remote-ai.baseUrl;
        OPENAI_API_KEY = "lm-studio";
        ENABLE_OPENAI_API = "True";
        # Keep the declarative endpoint authoritative across container restarts.
        ENABLE_PERSISTENT_CONFIG = "False";
        ENABLE_OLLAMA_API = "False";
        DEFAULT_MODELS = "qwen/qwen3.8-27b";
        WEBUI_AUTH = "True";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        ANONYMIZED_TELEMETRY = "False";
      };
    };
  };
}
