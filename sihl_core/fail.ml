type t =
  | BadRequest of string
  | ClientError of string
  | DatabaseError of string
  | ServerError of string
  | NotAuthenticated of string
  | Permission of string

let show = function
  | BadRequest msg -> msg
  | ClientError msg -> msg
  | DatabaseError msg -> msg
  | ServerError msg -> msg
  | NotAuthenticated msg -> msg
  | Permission msg -> msg

module Exception = struct
  exception BadRequest of string

  exception ClientError of string

  exception DatabaseError of string

  exception ServerError of string

  exception NotAuthenticated of string

  exception Permission of string
end

let or_exn = function
  | Ok value -> value
  | Error (BadRequest msg) -> raise @@ Exception.BadRequest msg
  | Error (ClientError msg) -> raise @@ Exception.ClientError msg
  | Error (DatabaseError msg) -> raise @@ Exception.DatabaseError msg
  | Error (ServerError msg) -> raise @@ Exception.ServerError msg
  | Error (NotAuthenticated msg) -> raise @@ Exception.NotAuthenticated msg
  | Error (Permission msg) -> raise @@ Exception.Permission msg

let or_exn' result = result |> Lwt.map or_exn

let of_exn f =
  try f () with
  | Exception.BadRequest msg -> Error (BadRequest msg)
  | Exception.ClientError msg -> Error (ClientError msg)
  | Exception.DatabaseError msg -> Error (DatabaseError msg)
  | Exception.ServerError msg -> Error (ServerError msg)
  | Exception.NotAuthenticated msg -> Error (NotAuthenticated msg)
  | Exception.Permission msg -> Error (Permission msg)
