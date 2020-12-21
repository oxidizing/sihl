let run =
  Sihl.Command.make
    ~name:"createpizza"
    ~help:"<pizza name> <ingredient1> <ingredient2> ..."
    ~description:"Create a pizza"
    (fun args ->
      match args with
      | name :: ingredients -> Pizza.create name ingredients |> Lwt.map ignore
      | _ ->
        raise
          (Sihl.Command.Exception "Usage: <pizza name> <ingredient1> <ingredient2> ..."))
;;
