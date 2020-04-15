let create_excerpts_table = [%rapper execute
    {sql|
    CREATE TABLE excerpts (
      excerpt_id serial PRIMARY KEY,
      author VARCHAR(100) NOT NULL,
      excerpt TEXT NOT NULL,
      source VARCHAR(100) NOT NULL,
      page VARCHAR(20)
    )
    |sql}
]

let migrations =
  [ "create excerpts table", create_excerpts_table
  ]

let () =
  match Lwt_main.run (Db.Migration.execute migrations) with
  | Ok ()     -> print_endline "Migration complete"
  | Error err -> failwith err
