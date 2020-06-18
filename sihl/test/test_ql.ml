let query = Alcotest.testable Sihl.Ql.pp Sihl.Ql.equal

let to_string_limit_offset _ () =
  let query = Sihl.Ql.(empty |> set_offset 10 |> set_limit 20) in
  let actual = Sihl.Ql.to_string query in
  let expected = "((limit 20)(offset 10))" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let to_string_sort _ () =
  let query = Sihl.Ql.(empty |> set_sort [ Asc "foo"; Desc "bar" ]) in
  let actual = Sihl.Ql.to_string query in
  let expected = "((sort((Asc foo)(Desc bar))))" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let to_string_filter _ () =
  let criterion = Sihl.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq }) in
  let query = Sihl.Ql.(empty |> set_filter criterion) in
  let actual = Sihl.Ql.to_string query in
  let expected = "((filter(C((key foo)(value bar)(op Eq)))))" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let to_string _ () =
  let filter_criterion =
    Sihl.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq })
  in
  let sort_criterion = Sihl.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let query =
    Sihl.Ql.(
      empty
      |> set_filter filter_criterion
      |> set_sort sort_criterion |> set_limit 10 |> set_offset 1)
  in
  let actual = Sihl.Ql.to_string query in
  let expected =
    "((filter(C((key foo)(value bar)(op Eq))))(sort((Asc foo)(Desc \
     bar)))(limit 10)(offset 1))"
  in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let to_sql_limit_offset _ () =
  let query = Sihl.Ql.(empty |> set_offset 10 |> set_limit 20) in
  let actual = Sihl.Ql.to_sql query in
  let expected = "LIMIT 20 OFFSET 10" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let to_sql_sort _ () =
  let query = Sihl.Ql.(empty |> set_sort [ Asc "foo"; Desc "bar" ]) in
  let actual = Sihl.Ql.to_sql query in
  let expected = "ORDER BY foo ASC, bar DESC" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let to_sql_filter _ () =
  let criterion1 = Sihl.Ql.Filter.{ key = "foo"; value = "bar"; op = Eq } in
  let criterion2 = Sihl.Ql.Filter.{ key = "fooz"; value = "baz"; op = Like } in
  let criterion3 =
    Sihl.Ql.Filter.{ key = "some"; value = "where"; op = Like }
  in
  let filter_criterions =
    Sihl.Ql.Filter.(Or [ And [ C criterion1; C criterion2 ]; C criterion3 ])
  in
  let query = Sihl.Ql.(empty |> set_filter filter_criterions) in
  let actual = Sihl.Ql.to_sql query in
  let expected = "WHERE ((foo = bar AND fooz LIKE baz) OR some LIKE where)" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let to_sql _ () =
  let criterion1 = Sihl.Ql.Filter.{ key = "foo"; value = "bar"; op = Eq } in
  let criterion2 = Sihl.Ql.Filter.{ key = "fooz"; value = "baz"; op = Like } in
  let criterion3 =
    Sihl.Ql.Filter.{ key = "some"; value = "where"; op = Like }
  in
  let filter_criterions =
    Sihl.Ql.Filter.(Or [ And [ C criterion1; C criterion2 ]; C criterion3 ])
  in
  let sort_criterion = Sihl.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let query =
    Sihl.Ql.(
      empty
      |> set_filter filter_criterions
      |> set_sort sort_criterion |> set_limit 10 |> set_offset 1)
  in
  let actual = Sihl.Ql.to_sql query in
  let expected =
    "WHERE ((foo = bar AND fooz LIKE baz) OR some LIKE where) ORDER BY foo \
     ASC, bar DESC LIMIT 10 OFFSET 1"
  in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)

let of_string_empty_sort _ () =
  let actual = Sihl.Ql.of_string "" in
  Lwt.return
  @@ Alcotest.(check (result query string) "equals" (Ok Sihl.Ql.empty) actual)

let of_string_sort _ () =
  let actual = Sihl.Ql.of_string "((sort((Asc foo)(Desc bar))))" in
  let expected = Sihl.Ql.(empty |> set_sort [ Asc "foo"; Desc "bar" ]) in
  Lwt.return
  @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)

let of_string_limit_offset _ () =
  let actual = Sihl.Ql.of_string "((limit 20)(offset 10))" in
  let expected = Sihl.Ql.(empty |> set_limit 20 |> set_offset 10) in
  Lwt.return
  @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)

let of_string_filter _ () =
  let actual = Sihl.Ql.of_string "((filter(C((key foo)(value bar)(op Eq)))))" in
  let criterion = Sihl.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq }) in
  let expected = Sihl.Ql.(empty |> set_filter criterion) in
  Lwt.return
  @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)

let of_string _ () =
  let actual =
    Sihl.Ql.of_string
      "((filter(C((key foo)(value bar)(op Eq))))(sort((Asc foo)(Desc \
       bar)))(limit 10)(offset 1))"
  in
  let filter_criterion =
    Sihl.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq })
  in
  let sort_criterion = Sihl.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let expected =
    Sihl.Ql.(
      empty
      |> set_filter filter_criterion
      |> set_sort sort_criterion |> set_limit 10 |> set_offset 1)
  in
  Lwt.return
  @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)
