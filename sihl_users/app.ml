open Opium.Std

let app : Opium.App.t =
  App.empty |> App.cmd_name "User Management" |> Handler.get_me
