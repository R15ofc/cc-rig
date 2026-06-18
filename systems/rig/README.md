# RIG

RIG is the developer API and package tooling layer.

It should become the equivalent of a CC:Tweaked developer platform:

- package registry;
- package upload from GitHub/gist;
- package install/update/remove;
- package trust and verification;
- developer SDKs;
- app templates;
- hub APIs used by Dock and Luma.

## Current Foundation

- `rig-hub/` - current FastAPI hub.
- `cc/rig/` - current Lua runtime and CLI.
- `rig-installer.lua` - bootstrap installer for CC computers.

## Planned Folders

- `api/` - hub API specs and future service boundaries.
- `cli/` - CLI behavior specs.
- `sdk/` - SDK contracts and future language bindings.
- `packages/` - package manifest and upload specs.

