#!/usr/bin/env bash

nix bundle --bundler github:logos-co/nix-bundle-dir/complete-qt-plugin-bundling#qtApp github:logos-co/logos-liblogos/properly-handle-portable-modules --out-link ./logos --refresh
nix bundle --bundler github:logos-co/nix-bundle-dir/complete-qt-plugin-bundling#qtApp github:logos-co/logos-package-manager-module/properly-handle-portable-modules#cli --out-link ./package-manager --refresh
./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module