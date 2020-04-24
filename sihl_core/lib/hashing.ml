let hash ?count plain =
  match (count, Config.is_testing ()) with
  | _, true -> Bcrypt.hash ~count:4 plain |> Bcrypt.string_of_hash
  | Some count, false ->
      if count < 4 || count > 31 then
        Fail.raise_server "password hashing count has to be between 4 and 31 "
      else Bcrypt.hash ~count plain |> Bcrypt.string_of_hash
  | None, false -> Bcrypt.hash ~count:10 plain |> Bcrypt.string_of_hash

module Bcrypt_ = Bcrypt
