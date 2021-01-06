exception Crypto_failed of string
exception Csrf_token_not_found

val find : Rock.Request.t -> string
val find_opt : Rock.Request.t -> string option
val xor : char list -> char list -> char list option

val decrypt_with_salt
  :  salted_cipher:char list
  -> salt_length:int
  -> char list option

val middleware
  :  ?not_allowed_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
  -> ?key:string
  -> unit
  -> Rock.Middleware.t
