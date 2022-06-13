let () =
  Config.configure
    (module struct
      include Config.Default

      let database_url =
        "postgresql://postgres:postgres@127.0.0.1:5432/postgres"
      ;;
    end)
;;

include Test_database.Cases ()
