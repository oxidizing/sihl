let migrate =
  Core_cmd.create ~name:"migrate" ~description:"applies all migrations"
    ~fn:(fun _ -> failwith "TODO migration command")
