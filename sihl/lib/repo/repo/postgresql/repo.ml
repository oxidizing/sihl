open Sihl.Core.Contract.Migration.State

let create_table_if_not_exists =
  [%rapper
    execute
      {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL PRIMARY KEY,
  version INTEGER,
  dirty BOOL NOT NULL
);
 |sql}]

let get =
  [%rapper
    get_opt
      {sql|
SELECT
  @string{namespace},
  @int{version},
  @bool{dirty}
FROM core_migration_state
WHERE namespace = %string{namespace};
|sql}
      record_out]

let upsert =
  [%rapper
    execute
      {sql|
INSERT INTO core_migration_state (
  namespace,
  version,
  dirty
) VALUES (
  %string{namespace},
  %int{version},
  %bool{dirty}
) ON CONFLICT (namespace)
DO UPDATE SET version = %int{version},
dirty = %bool{dirty}
|sql}
      record_in]
