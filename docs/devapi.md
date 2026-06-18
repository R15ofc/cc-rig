# RIG Dev API

RIG devapi is the stable foundation for the platform.

## Goals

- Make Advanced Computer UI development fast.
- Make DockOS apps feel native.
- Make Luma networking consistent.
- Avoid hub lock-in for the base system.
- Keep agents and remote control disabled unless explicitly started.

## Modules

### `devapi.ui`

Provides terminal UI primitives:

- screen context;
- hitboxes for mouse UI;
- cards;
- buttons;
- modal dialogs;
- topbar drawing;
- safe color helpers.

### `devapi.app`

Provides app/runtime helpers:

- file read/write;
- HTTP downloads;
- hidden installer execution;
- manifest-based app installation;
- shell command startup.

### `devapi.net`

Provides network helpers:

- gateway config;
- JSON GET;
- `/fetch` and `/search` gateway calls;
- rednet modem opening;
- request/reply helper.

### `devapi.store`

Provides store helpers:

- built-in verified catalog;
- rednet catalog discovery;
- package trust labels;
- package lookup.

## Hub Policy

Hub services are optional infrastructure. Base RIG should remain useful without any hosted server.
