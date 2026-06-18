# RIG Platform Direction

This repository is moving toward a CC:Tweaked developer platform with three major systems:

- **RIG** - developer API, package tooling, SDKs, hub services, and app/package registry.
- **Dock** - OS layer for Pocket Computers and Advanced Computers, with apps, accounts, and app store UX.
- **Luma** - in-game internet layer: browser, domains, search, site builder, and web app runtime.

The current `rig-hub/` and `cc/` runtime stay as the foundation, but the long-term product shape is broader than fleet monitoring.

## Product Principles

- RIG is a developer platform, not spyware.
- Packages and apps can be reviewed, verified, warned on, removed, or blocked by the hub.
- Unverified installs must show a clear warning before the user continues.
- Hub moderation should target package/app safety, policy violations, and malicious behavior.
- Admin tools should be explicit and auditable.

## Core Systems

### RIG

RIG provides the core APIs:

- package registry;
- upload from GitHub repo, gist, or raw source bundle;
- package verification status;
- package warnings;
- package removal/blocklist;
- Lua SDK for apps;
- dev commands and local tooling;
- hub APIs for Dock and Luma.

### Dock

Dock is the OS/user shell:

- Pocket Computer edition for apps, account login, app store, settings, notifications;
- Advanced Computer edition for developer tools, package management, terminals, and admin panels;
- app permissions;
- app install/remove/update UX;
- account/session integration with the hub.

### Luma

Luma is the internet layer:

- browser UI;
- domain/directory system;
- search;
- hosted page/app format;
- site builders;
- app/site publishing via RIG packages;
- safety labels for verified/unverified sites.

## Package Trust Model

Package states:

- `unreviewed` - uploaded but not checked;
- `verified` - reviewed and approved;
- `warned` - allowed, but shows a warning before install;
- `blocked` - cannot be installed through official clients;
- `removed` - hidden from registry listings.

Users may install unverified packages only after a clear warning.

