# Package Trust Policy

RIG Hub is the source of truth for package trust decisions.

## Upload Sources

Supported upload targets:

- GitHub repository ID or URL;
- GitHub gist ID or URL;
- raw manifest URL;
- manual upload API later.

## Required Package Metadata

Every package should define:

- name;
- version;
- description;
- files;
- bin entries;
- permissions requested;
- source URL;
- author/account;
- license or usage note.

## Verification States

### unreviewed

Default state for new uploads. Clients must warn before install.

### verified

Reviewed package with acceptable behavior. Clients may install without an extra warning.

### warned

Package is allowed, but has important caveats. Clients must display the warning.

### blocked

Package is forbidden through official clients. Existing installs should be shown as unsafe and removable.

### removed

Package is hidden from search/listing, but historical records remain in hub audit data.

## Removal Reasons

Examples:

- secret messenger bypassing server rules;
- hidden network tunnel;
- credential/token theft;
- destructive file behavior;
- impersonation of trusted packages;
- hidden persistence outside declared install paths;
- policy bypass or moderation evasion tooling.

## Client Behavior

Official clients should:

- warn on `unreviewed`;
- warn strongly on `warned`;
- refuse install on `blocked`;
- provide uninstall/remove action for blocked installed packages;
- show source URL and requested permissions before install.

