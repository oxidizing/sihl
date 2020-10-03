let hash ?count plain =
  match count, Core.Configuration.is_testing () with
  | _, true -> Ok (Bcrypt.hash ~count:4 plain |> Bcrypt.string_of_hash)
  | Some count, false ->
    if count < 4 || count > 31
    then Error "Password hashing count has to be between 4 and 31"
    else Ok (Bcrypt.hash ~count plain |> Bcrypt.string_of_hash)
  | None, false -> Ok (Bcrypt.hash ~count:10 plain |> Bcrypt.string_of_hash)
;;

let matches ~hash ~plain = Bcrypt.verify plain (Bcrypt.hash_of_string hash)

module Bcrypt = Bcrypt
