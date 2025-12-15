{
  description = "nixy-lock: Lock tool for nixy inputs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in
    {
      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          script = pkgs.writeShellScript "nixy-lock" ''
            if [ $# -lt 2 ]; then
              echo "Usage: nix run github:anialic/nixy-lock <n> <url> [<n> <url> ...]" >&2
              echo "Example: nix run github:anialic/nixy-lock nixpkgs github:NixOS/nixpkgs/nixos-unstable" >&2
              exit 1
            fi

            entries=""
            while [ $# -ge 2 ]; do
              name="$1"
              url="$2"
              shift 2

              if [[ "$url" =~ ^github:([^/]+)/([^/]+)(/(.+))?$ ]]; then
                owner="''${BASH_REMATCH[1]}"
                repo="''${BASH_REMATCH[2]}"
                ref="''${BASH_REMATCH[4]:-main}"
                tarball="https://github.com/$owner/$repo/archive/$ref.tar.gz"
              elif [[ "$url" =~ ^https?:// ]]; then
                tarball="$url"
              else
                echo "Skipping unsupported URL: $url" >&2
                continue
              fi

              echo "Locking $name ($tarball)..." >&2
              sha256=$(${pkgs.nix}/bin/nix-prefetch-url --unpack "$tarball" 2>/dev/null) || {
                echo "Failed to lock $name" >&2
                continue
              }

              if [ -n "$entries" ]; then
                entries="$entries,"$'\n'
              fi
              entries="$entries  \"$name\": { \"url\": \"$tarball\", \"sha256\": \"$sha256\" }"
            done

            echo "{"
            echo "$entries"
            echo "}"
          '';
        in
        {
          default = { type = "app"; program = toString script; };
        });

      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.writeShellScriptBin "nixy-lock" (builtins.readFile "${self.apps.${system}.default.program}");
        });
    };
}
