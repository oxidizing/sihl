let create_pizzas_table =
  Sihl.Migration.create_step
    ~label:"create pizzas table"
    {sql|
     CREATE TABLE IF NOT EXISTS pizzas (
       id serial,
       uuid uuid NOT NULL,
       name VARCHAR(128) NOT NULL,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
     PRIMARY KEY (id),
     UNIQUE (uuid),
     UNIQUE (name)
     );
     |sql}
;;

let create_pizzas_ingredients_table =
  Sihl.Migration.create_step
    ~label:"create pizzas_ingredients table"
    {sql|
     CREATE TABLE IF NOT EXISTS pizzas_ingredients (
       id serial,
       pizza_id uuid NOT NULL,
       ingredient VARCHAR(128) NOT NULL,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
     PRIMARY KEY (id),
     UNIQUE (pizza_id, ingredient)
     );
     |sql}
;;

let pizzas =
  Sihl.Migration.(
    empty "pizzas"
    |> add_step create_pizzas_table
    |> add_step create_pizzas_ingredients_table)
;;

let all = [ pizzas ]
