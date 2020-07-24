open Alcotest_lwt
open Base

let ( let* ) = Lwt.bind

module Make
    (DbService : Sihl.Data.Db.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (TokenService : Sihl.Token.Sig.SERVICE) =
struct
  let create_and_find_token _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let* created =
      TokenService.create ctx ~kind:"test" ~data:"foo" ()
      |> Lwt.map Result.ok_or_failwith
    in
    let created_value = Sihl.Token.value created in
    let* found =
      TokenService.find ctx ~value:created_value ()
      |> Lwt.map Result.ok_or_failwith
    in
    let () =
      Alcotest.(check Sihl.Token.alco "Has created session" created found)
    in
    Lwt.return ()

  let test_suite =
    ("token", [ test_case "create and find token" `Quick create_and_find_token ])
end
