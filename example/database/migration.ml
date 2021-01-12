(* Database migrations. *)
let create_todos_table =
  Sihl.Database.Migration.create_step
    ~label:"create todos table"
    {sql|
     CREATE TABLE IF NOT EXISTS todos (
       id serial,
       uuid uuid NOT NULL,
       description VARCHAR(128) NOT NULL,
       status VARCHAR(32) NOT NULL,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY (id),
       UNIQUE (uuid)
     );
     |sql}
;;

let all =
  [ Sihl.Database.Migration.(empty "demo" |> add_step create_todos_table) ]
;;
