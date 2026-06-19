#!/usr/bin/env bash
set -e

nix --extra-experimental-features "nix-command flakes" build github:logos-co/logos-logoscore-cli --out-link ./logos
nix --extra-experimental-features "nix-command flakes" build github:logos-co/logos-package-manager#cli --out-link ./package-manager

mkdir -p ./modules

if [[ -z "${LOGOS_STORAGE_MODULE_PATH}" ]]; then
    ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module
else
  # This assumes the module's LGX has already been built.
  module_path="${LOGOS_STORAGE_MODULE_PATH}/result"
  ./package-manager/bin/lgpm --modules-dir ./modules install --dir "$module_path"
fi