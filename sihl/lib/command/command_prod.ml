open Command_pure
module Config = Sihl__config.Config

let fn _ = ()

let t : t =
  { name = "prod"
  ; description = "Prepare static files and the binary for deployment"
  ; usage = "sihl prod"
  ; fn
  ; stateful = false
  }
;;
