{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.omp
  ];

  home.file.".omp/agent/extensions/markdown-pager/package.json".text = builtins.toJSON {
    name = "markdown-pager";
    version = "1.0.0";
    type = "module";
    omp = {
      extensions = [ "./index.ts" ];
    };
  };
  home.file.".omp/agent/extensions/markdown-pager/index.ts".source =
    ../../files/omp/extensions/markdown-pager.ts;
}
