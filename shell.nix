{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = with pkgs; [
    fluxcd
    kubectl
    kustomize
    kubernetes-helm
    jq
    cmctl
  ];
}
