# Roadmap

## Initial Release

The first version contains the smallest set of features that allows usage of Sihl in production.

### Persistence API
Extract persistence implementation so Sihl is database agnostic.

- `Database.t`: database handle, might map to pool
- `Connection.t`: where queries can be made on
- `Trx.t`: where queries in a transaction can be made
- `QueryResult.t`: contains query result and meta data
- `ExecutionResult.t`: meta data

### App Configuration
Each app should provide its own configuration. Sihl makes sure at startup-time that the configurations that are required are provided in the env vars. It also does some basic checking on the types.

The goal is to switch away from the decco using static types to a small DSL that can express valid configuration setups.

Something like this:

```reasonml
let config = [
  Enum("EMAIL_BACKEND", ["smtp", "console"]),
  String("SMTP_HOST"),
  Int("SMTP_PORT"),
  Optional(String("EMAIL_HEADER"), "Default header")
  ];
```

The disadvantage is, that we don't have static type checks. But because the configurations are values, it is self-documenting. `yarn sihl app:config <appname>` can show how the app wants to be configured.

### User Management SMTP

Currently the emails are written to the console. By implementing a proper SMTP backend, we can allow the password reset and user confirmation flows in the example app.

### Scaffolding

Initial scaffolding should be done using Spin. We could have a template for a common setup like React, Postgres and user management.

Creating and adding new apps could be done either with Spin as well, or by providing those CLI commands in @sihl/core.

### Token generation

Generate other tokens than just UUIDs.
