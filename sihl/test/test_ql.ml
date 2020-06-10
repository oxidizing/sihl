let query = Alcotest.testable Sihl.Ql.pp Sihl.Ql.equal

let to_string_limit_offset () =
  let query = Sihl.Ql.(empty |> offset 10 |> limit 20) in
  let actual = Sihl.Ql.to_string query in
  let expected = "((limit 20)(offset 10))" in
  Alcotest.(check string "equals" expected actual)

let to_string_sort () =
  let query = Sihl.Ql.(empty |> sort [ Asc "foo"; Desc "bar" ]) in
  let actual = Sihl.Ql.to_string query in
  let expected = "((sort((Asc foo)(Desc bar))))" in
  Alcotest.(check string "equals" expected actual)

let to_string_filter () =
  let criterion = Sihl.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq }) in
  let query = Sihl.Ql.(empty |> filter criterion) in
  let actual = Sihl.Ql.to_string query in
  let expected = "((filter(C((key foo)(value bar)(op Eq)))))" in
  Alcotest.(check string "equals" expected actual)

let to_string () =
  let filter_criterion =
    Sihl.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq })
  in
  let sort_criterion = Sihl.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let query =
    Sihl.Ql.(
      empty |> filter filter_criterion |> sort sort_criterion |> limit 10
      |> offset 1)
  in
  let actual = Sihl.Ql.to_string query in
  let expected =
    "((filter(C((key foo)(value bar)(op Eq))))(sort((Asc foo)(Desc \
     bar)))(limit 10)(offset 1))"
  in
  Alcotest.(check string "equals" expected actual)

let to_sql_limit_offset () =
  let query = Sihl.Ql.(empty |> offset 10 |> limit 20) in
  let actual = Sihl.Ql.to_sql query in
  let expected = "LIMIT 20 OFFSET 10" in
  Alcotest.(check string "equals" expected actual)

let to_sql_sort () =
  let query = Sihl.Ql.(empty |> sort [ Asc "foo"; Desc "bar" ]) in
  let actual = Sihl.Ql.to_sql query in
  let expected = "ORDER BY foo ASC, bar DESC" in
  Alcotest.(check string "equals" expected actual)

let to_sql_filter () =
  let criterion1 = Sihl.Ql.Filter.{ key = "foo"; value = "bar"; op = Eq } in
  let criterion2 = Sihl.Ql.Filter.{ key = "fooz"; value = "baz"; op = Like } in
  let criterion3 =
    Sihl.Ql.Filter.{ key = "some"; value = "where"; op = Like }
  in
  let filter_criterions =
    Sihl.Ql.Filter.(Or [ And [ C criterion1; C criterion2 ]; C criterion3 ])
  in
  let query = Sihl.Ql.(empty |> filter filter_criterions) in
  let actual = Sihl.Ql.to_sql query in
  let expected = "WHERE ((foo = bar AND fooz LIKE baz) OR some LIKE where)" in
  Alcotest.(check string "equals" expected actual)

let to_sql () =
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
      empty |> filter filter_criterions |> sort sort_criterion |> limit 10
      |> offset 1)
  in
  let actual = Sihl.Ql.to_sql query in
  let expected =
    "WHERE ((foo = bar AND fooz LIKE baz) OR some LIKE where) ORDER BY foo \
     ASC, bar DESC LIMIT 10 OFFSET 1"
  in
  Alcotest.(check string "equals" expected actual)

let of_string_empty_sort () =
  let actual = Sihl.Ql.of_string "" in
  Alcotest.(check (result query string) "equals" (Ok Sihl.Ql.empty) actual)

let of_string_sort () =
  let actual = Sihl.Ql.of_string "((sort((Asc foo)(Desc bar))))" in
  let expected = Sihl.Ql.(empty |> sort [ Asc "foo"; Desc "bar" ]) in
  Alcotest.(check (result query string) "equals" (Ok expected) actual)

let of_string_limit_offset () =
  let actual = Sihl.Ql.of_string "((limit 20)(offset 10))" in
  let expected = Sihl.Ql.(empty |> limit 20 |> offset 10) in
  Alcotest.(check (result query string) "equals" (Ok expected) actual)

let of_string_filter () =
  let actual = Sihl.Ql.of_string "((filter(C((key foo)(value bar)(op Eq)))))" in
  let criterion = Sihl.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq }) in
  let expected = Sihl.Ql.(empty |> filter criterion) in
  Alcotest.(check (result query string) "equals" (Ok expected) actual)

let of_string () =
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
      empty |> filter filter_criterion |> sort sort_criterion |> limit 10
      |> offset 1)
  in
  Alcotest.(check (result query string) "equals" (Ok expected) actual)
