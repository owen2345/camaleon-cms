## Purpose

Hosts, plugins and themes describe themselves in JSON config files that Camaleon reads at boot. This
capability pins how those files are parsed, so a config written for json 2 keeps loading under json 3,
and it keeps the configs the gem itself ships as plain JSON.

## ADDED Requirements

### Requirement: Config files load with comments and repeated keys

Camaleon SHALL accept `//` and `/* */` comments and repeated keys when it parses these configs:

- the system config: the gem's `config/system.json` and the host's `config/system.json`;
- plugin configs: `config/config.json` of app and bundled plugins, and `config/camaleon_plugin.json` of
  plugin gems;
- theme configs: `config/config.json` of app themes, and `config/camaleon_theme.json` of theme gems.

The last value of a repeated key SHALL win. This SHALL hold on every supported json version, without json
deprecation warnings.

#### Scenario: A host theme config written by an older generator

- **WHEN** an app theme's `config/config.json` contains a comment and repeats its `name` key
- **THEN** the theme loads with the last `name` value
- **AND** no warning is emitted

### Requirement: Shipped JSON configs are plain JSON

These configs SHALL parse with comments and repeated keys rejected:

- the gem's own system config and the configs of its bundled plugins and themes;
- the configs its generators write;
- the test app's theme configs.

#### Scenario: A comment is added to a generator template

- **WHEN** a shipped config or generator template gains a comment or a repeated key
- **THEN** the shipped-configs check fails for that file
