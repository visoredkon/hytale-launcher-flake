{
  formatTargets,
  pkgs,
}:

pkgs.writeShellApplication {
  name = "hytale-launcher-fmt";
  runtimeInputs = with pkgs; [ nixfmt ];
  text = ''
    set -euo pipefail

    if [ "$#" -gt 0 ]; then
      exec nixfmt "$@"
    fi

    exec nixfmt ${formatTargets}
  '';
}
