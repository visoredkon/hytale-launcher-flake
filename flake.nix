{
  description = "Unofficial Hytale Launcher Nix Flake for NixOS";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      formatTargets = "apps/*.nix flake.nix package.nix release.nix";

      formatterApp = pkgs.callPackage ./apps/formatter.nix { inherit formatTargets; };

      hytale-launcher = pkgs.callPackage ./package.nix { };

      manual-check = pkgs.callPackage ./apps/manual-check.nix { inherit hytale-launcher; };

      mkApp = program: {
        inherit program;
        type = "app";
      };

      update-release = pkgs.callPackage ./apps/update-release.nix { };
    in
    {
      apps.${system} = {
        default = mkApp "${hytale-launcher}/bin/hytale-launcher";
        manual-check = mkApp "${manual-check}/bin/hytale-launcher-manual-check";
        update-release = mkApp "${update-release}/bin/hytale-launcher-update-release";
      };

      checks.${system} = {
        embedded-lint =
          pkgs.runCommand "check-embedded-lint"
            {
              nativeBuildInputs = [
                pkgs.basedpyright
                pkgs.python3
                pkgs.ruff
                pkgs.shellcheck
              ];
              src = self;
            }
            ''
              work=$(mktemp -d)
              cp -r $src/. "$work/"
              chmod -R u+w "$work"
              cd "$work"
              export HOME=$(mktemp -d)
              export RUFF_CACHE_DIR=$(mktemp -d)
              cat > script.py <<'PYEOF'
              import pathlib
              import re
              import subprocess
              import sys
              import textwrap

              quote: str = "'" + "'"
              escaped_dollar: str = quote + "$"
              shell_names: str = "installPhase|unpackPhase|text"
              shell_pattern: re.Pattern[str] = re.compile(
                  "(" + shell_names + ")\\s*=\\s*" + quote + "(.*?)" + quote + ";",
                  re.DOTALL,
              )
              python_pattern: re.Pattern[str] = re.compile(
                  '(checkPython)\\s*=\\s*pkgs\\.writeText\\s+"[^"]*"\\s*'
                  + quote
                  + "(.*?)"
                  + quote
                  + ";",
                  re.DOTALL,
              )

              failures: list[str] = []
              extracted: list[pathlib.Path] = []


              def stub_nix_interpolations(body: str) -> str:
                  stubbed: str = ""
                  index: int = 0
                  while index < len(body):
                      start: int = body.find("''${", index)
                      if start < 0 or body[max(0, start - 2) : start] == "'" + "'":
                          stubbed += body[index:]
                          break
                      stubbed += body[index:start] + "NIX_INTERPOLATION"
                      depth: int = 1
                      cursor: int = start + 2
                      while cursor < len(body) and depth > 0:
                          if body[cursor] == "{":
                              depth += 1
                          elif body[cursor] == "}":
                              depth -= 1
                          cursor += 1
                      index = cursor
                  return stubbed


              nix_files: list[pathlib.Path] = sorted(pathlib.Path(".").rglob("*.nix"))
              for path in nix_files:
                  source: str = path.read_text()
                  for pattern, suffix in ((shell_pattern, "sh"), (python_pattern, "py")):
                      for index, match in enumerate(pattern.finditer(source)):
                          body: str = match.group(2)
                          body = textwrap.dedent(body)
                          if suffix == "py":
                              body = body.lstrip("\n")
                          else:
                              body = stub_nix_interpolations(body)
                              body = body.replace(escaped_dollar, "$")
                              body = "#!/usr/bin/env bash\n" + body
                          target = pathlib.Path(
                              "extracted",
                              path.stem + "-" + match.group(1) + "-" + str(index) + "." + suffix,
                          )
                          target.parent.mkdir(exist_ok=True)
                          _ = target.write_text(body)
                          extracted.append(target)

              if not extracted:
                  print("no embedded scripts extracted from nix files")
                  sys.exit(1)

              for target in extracted:
                  if target.suffix == ".sh":
                      commands: list[list[str]] = [
                          ["bash", "-n", str(target)],
                          [
                              "shellcheck",
                              "-S",
                              "warning",
                              "-e",
                              "SC2154,SC1083,SC1009,SC1073,SC1036,SC1072,SC1065",
                              str(target),
                          ],
                      ]
                  else:
                      commands = [
                          ["ruff", "check", str(target)],
                          ["ruff", "format", "--check", str(target)],
                          ["basedpyright", str(target)],
                      ]
                  for command in commands:
                      result: subprocess.CompletedProcess[str] = subprocess.run(
                          command,
                          capture_output=True,
                          check=False,
                          text=True,
                      )
                      if result.returncode != 0:
                          failures.append(
                              target.name + " " + command[0] + "\n" + result.stdout + result.stderr
                          )

              if failures:
                  print("\n".join(failures))
                  sys.exit(1)
              PYEOF
              ruff check script.py
              ruff format --check script.py
              basedpyright script.py
              python3 script.py
              touch $out
            '';
        format =
          pkgs.runCommand "check-format"
            {
              nativeBuildInputs = [ pkgs.nixfmt ];
              src = self;
            }
            ''
              cd $src
              nixfmt --check ${formatTargets}
              touch $out
            '';
        linter =
          pkgs.runCommand "check-linter"
            {
              nativeBuildInputs = [ pkgs.statix ];
              src = self;
            }
            ''
              cd $src
              statix check .
              touch $out
            '';
      };

      formatter.${system} = formatterApp;

      overlays.default = _: prev: {
        hytale-launcher = prev.callPackage ./package.nix { };
      };

      packages.${system} = {
        default = hytale-launcher;
        inherit hytale-launcher;
      };
    };
}
