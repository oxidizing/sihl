module P = Command_pure

let fn _ = failwith "migrate()"

let down : P.t =
  { name = "migrate.down"
  ; description = "Revert last migration"
  ; usage = "sihl migrate.down"
  ; fn
  }
;;

let gen : P.t =
  { name = "migrate.gen"
  ; description = "Generate CREATE TABLE migrations from models"
  ; usage = "sihl migrate.gen"
  ; fn
  }
;;

let t : P.t =
  { name = "migrate"
  ; description = "Run migrations"
  ; usage = "sihl migrate"
  ; fn
  }
;;
