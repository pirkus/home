{ ... }:
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers.open-webui = {
      # Pin the official image: the current nixpkgs Python package is broken.
      image = "ghcr.io/open-webui/open-webui:v0.12.3@sha256:a537bbe1e6b428820f52ed4a029d7fff97062e24d5cf32c365fba36fd0542def";
      autoStart = true;
      # LM Studio listens on the host loopback interface.
      extraOptions = [ "--network=host" ];
      volumes = [ "open-webui:/app/backend/data" ];
      environment = {
        HOST = "0.0.0.0";
        PORT = "3000";
        OPENAI_API_BASE_URL = "http://127.0.0.1:1234/v1";
        OPENAI_API_KEY = "lm-studio";
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
