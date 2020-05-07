let create_templates_table =
  [%rapper
    execute
      {sql|
CREATE TABLE emails_templates (
  id serial,
  uuid uuid NOT NULL,
  label VARCHAR(128) NOT NULL,
  value VARCHAR(1000) NOT NULL,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (uuid)
);
|sql}]

let migration () =
  ("emails", [ ("create templates table", create_templates_table) ])
