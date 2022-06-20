let fn _ = failwith "migrate()"

let down : Sihl.Command.t =
  { name = "migrate.down"
  ; description = "Revert last migration"
  ; usage = "sihl migrate.down"
  ; fn
  }
;;

let gen : Sihl.Command.t =
  { name = "migrate.gen"
  ; description = "Generate CREATE TABLE migrations from models"
  ; usage = "sihl migrate.gen"
  ; fn
  }
;;

let t : Sihl.Command.t =
  { name = "migrate"
  ; description = "Run migrations"
  ; usage = "sihl migrate"
  ; fn
  }
;;
