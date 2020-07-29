let migrate =
  Cmd.make ~name:"migrate" ~description:"applies all migrations" ~fn:(fun _ ->
      failwith "TODO migration command")
