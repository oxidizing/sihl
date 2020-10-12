let unique_keys _ () =
  let key1 : string Sihl.Core.Ctx.key = Sihl.Core.Ctx.create_key () in
  let key2 : string Sihl.Core.Ctx.key = Sihl.Core.Ctx.create_key () in
  let ctx =
    Sihl.Core.Ctx.empty
    |> Sihl.Core.Ctx.add key1 "value1"
    |> Sihl.Core.Ctx.add key2 "value2"
  in
  Alcotest.(
    check (option string) "has value" (Sihl.Core.Ctx.find key1 ctx) (Some "value1"));
  Alcotest.(
    check (option string) "has value" (Sihl.Core.Ctx.find key2 ctx) (Some "value2"));
  Lwt.return ()
;;

let replace_value _ () =
  let key : string Sihl.Core.Ctx.key = Sihl.Core.Ctx.create_key () in
  let ctx =
    Sihl.Core.Ctx.empty
    |> Sihl.Core.Ctx.add key "value1"
    |> Sihl.Core.Ctx.add key "value2"
  in
  Alcotest.(
    check (option string) "has value" (Sihl.Core.Ctx.find key ctx) (Some "value2"));
  Lwt.return ()
;;
