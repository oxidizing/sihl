let create_tables () =
  (* TODO 1. create table 2. create indices *)
  {|CREATE TABLE a_models (
  id SERIAL PRIMARY KEY,
  int INTEGER NOT NULL,
  bool BOOLEAN NOT NULL,
  string TEXT NOT NULL,
  timestamp TIMESTAMP NOT NULL
);

CREATE TABLE b_models (
  id SERIAL PRIMARY KEY,
  a_model INTEGER NOT NULL,
  string TEXT NOT NULL,
  FOREIGN KEY (a_model) REFERENCES a_models (id)
);
|}
;;
