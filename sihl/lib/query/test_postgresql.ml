module Config = Sihl__config.Config

let () =
  Config.configure
    [ "SIHL_ENV", "test"
    ; "DATABASE_URL", "postgresql://postgres:postgres@127.0.0.1:5432/postgres"
    ]
;;

include Test_database.Cases ()
