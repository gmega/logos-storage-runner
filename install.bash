#!/usr/bin/env bash

nix --extra-experimental-features "nix-command flakes" build github:logos-co/logos-liblogos --out-link ./logos
nix --extra-experimental-features "nix-command flakes" build github:logos-co/logos-package-manager-module#cli --out-link ./package-manager
./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module