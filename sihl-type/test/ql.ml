let query = Alcotest.testable Sihl_type.Database.Ql.pp Sihl_type.Database.Ql.equal

let to_string_limit_offset _ () =
  let query = Sihl_type.Database.Ql.(empty |> set_offset 10 |> set_limit 20) in
  let actual = Sihl_type.Database.Ql.to_string query in
  let expected = "((page((limit 20)(offset 10))))" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)
;;

let to_string_sort _ () =
  let query = Sihl_type.Database.Ql.(empty |> set_sort [ Asc "foo"; Desc "bar" ]) in
  let actual = Sihl_type.Database.Ql.to_string query in
  let expected = "((sort((Asc foo)(Desc bar)))(page()))" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)
;;

let to_string_filter _ () =
  let criterion =
    Sihl_type.Database.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq })
  in
  let query = Sihl_type.Database.Ql.(empty |> set_filter criterion) in
  let actual = Sihl_type.Database.Ql.to_string query in
  let expected = "((filter(C((key foo)(value bar)(op Eq))))(page()))" in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)
;;

let to_string _ () =
  let filter_criterion =
    Sihl_type.Database.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq })
  in
  let sort_criterion = Sihl_type.Database.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let query =
    Sihl_type.Database.Ql.(
      empty
      |> set_filter filter_criterion
      |> set_sort sort_criterion
      |> set_limit 10
      |> set_offset 1)
  in
  let actual = Sihl_type.Database.Ql.to_string query in
  let expected =
    "((filter(C((key foo)(value bar)(op Eq))))(sort((Asc foo)(Desc bar)))(page((limit \
     10)(offset 1))))"
  in
  Lwt.return @@ Alcotest.(check string "equals" expected actual)
;;

let to_sql_limit_offset _ () =
  let query = Sihl_type.Database.Ql.(empty |> set_offset 10 |> set_limit 20) in
  let actual, values = Sihl_type.Database.Ql.to_sql [] query in
  let expected = "LIMIT ? OFFSET ?" in
  Alcotest.(check string "equals query" expected actual);
  Alcotest.(check (list string) "equals values" values [ "20"; "10" ]);
  Lwt.return ()
;;

let to_sql_sort _ () =
  let query = Sihl_type.Database.Ql.(empty |> set_sort [ Asc "foo"; Desc "bar" ]) in
  let actual, values = Sihl_type.Database.Ql.to_sql [ "foo"; "bar" ] query in
  let expected = "ORDER BY foo ASC, bar DESC" in
  Alcotest.(check string "equals query" expected actual);
  Alcotest.(check (list string) "equals value" [] values);
  Lwt.return ()
;;

let to_sql_sort_empty_whitelist _ () =
  let query = Sihl_type.Database.Ql.(empty |> set_sort [ Asc "foo"; Desc "bar" ]) in
  let actual, values = Sihl_type.Database.Ql.to_sql [] query in
  let expected = "" in
  Alcotest.(check string "equals query" expected actual);
  Alcotest.(check (list string) "equals value" [] values);
  Lwt.return ()
;;

let to_sql_filter _ () =
  let whitelist = [ "foo"; "fooz"; "some" ] in
  let criterion1 = Sihl_type.Database.Ql.Filter.{ key = "foo"; value = "bar"; op = Eq } in
  let criterion2 =
    Sihl_type.Database.Ql.Filter.{ key = "fooz"; value = "baz"; op = Like }
  in
  let criterion3 =
    Sihl_type.Database.Ql.Filter.{ key = "some"; value = "where"; op = Like }
  in
  let filter_criterions =
    Sihl_type.Database.Ql.Filter.(Or [ And [ C criterion1; C criterion2 ]; C criterion3 ])
  in
  let query = Sihl_type.Database.Ql.(empty |> set_filter filter_criterions) in
  let actual, values = Sihl_type.Database.Ql.to_sql whitelist query in
  let expected = "WHERE ((foo = ? AND fooz LIKE ?) OR some LIKE ?)" in
  Alcotest.(check string "equals query" expected actual);
  Alcotest.(check (list string) "equals values" [ "bar"; "baz"; "where" ] values);
  Lwt.return ()
;;

let to_sql_filter_with_partial_whitelist _ () =
  let whitelist = [ "foo"; "some" ] in
  let criterion1 = Sihl_type.Database.Ql.Filter.{ key = "foo"; value = "bar"; op = Eq } in
  let criterion2 =
    Sihl_type.Database.Ql.Filter.{ key = "fooz"; value = "baz"; op = Like }
  in
  let criterion3 =
    Sihl_type.Database.Ql.Filter.{ key = "some"; value = "where"; op = Like }
  in
  let filter_criterions =
    Sihl_type.Database.Ql.Filter.(Or [ And [ C criterion1; C criterion2 ]; C criterion3 ])
  in
  let query = Sihl_type.Database.Ql.(empty |> set_filter filter_criterions) in
  let actual, values = Sihl_type.Database.Ql.to_sql whitelist query in
  let expected = "WHERE (foo = ? OR some LIKE ?)" in
  Alcotest.(check string "equals query" expected actual);
  Alcotest.(check (list string) "equals values" [ "bar"; "where" ] values);
  Lwt.return ()
;;

let to_sql _ () =
  let criterion1 = Sihl_type.Database.Ql.Filter.{ key = "foo"; value = "bar"; op = Eq } in
  let criterion2 =
    Sihl_type.Database.Ql.Filter.{ key = "fooz"; value = "baz"; op = Like }
  in
  let criterion3 =
    Sihl_type.Database.Ql.Filter.{ key = "some"; value = "where"; op = Like }
  in
  let filter_criterions =
    Sihl_type.Database.Ql.Filter.(Or [ And [ C criterion1; C criterion2 ]; C criterion3 ])
  in
  let sort_criterion = Sihl_type.Database.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let query =
    Sihl_type.Database.Ql.(
      empty
      |> set_filter filter_criterions
      |> set_sort sort_criterion
      |> set_limit 10
      |> set_offset 1)
  in
  let whitelist = [ "foo"; "fooz"; "some"; "bar" ] in
  let query, values = Sihl_type.Database.Ql.to_sql whitelist query in
  let expected_query =
    "WHERE ((foo = ? AND fooz LIKE ?) OR some LIKE ?) ORDER BY foo ASC, bar DESC LIMIT ? \
     OFFSET ?"
  in
  let expected_values = [ "bar"; "baz"; "where"; "10"; "1" ] in
  Alcotest.(check string "query equals" expected_query query);
  Alcotest.(check (list string) "values equals" expected_values values);
  Lwt.return ()
;;

let to_sql_fragments _ () =
  let criterion1 = Sihl_type.Database.Ql.Filter.{ key = "foo"; value = "bar"; op = Eq } in
  let criterion2 =
    Sihl_type.Database.Ql.Filter.{ key = "fooz"; value = "baz"; op = Like }
  in
  let criterion3 =
    Sihl_type.Database.Ql.Filter.{ key = "some"; value = "where"; op = Like }
  in
  let filter_criterions =
    Sihl_type.Database.Ql.Filter.(Or [ And [ C criterion1; C criterion2 ]; C criterion3 ])
  in
  let sort_criterion = Sihl_type.Database.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let query =
    Sihl_type.Database.Ql.(
      empty
      |> set_filter filter_criterions
      |> set_sort sort_criterion
      |> set_limit 10
      |> set_offset 1)
  in
  let filter_whitelist = [ "foo"; "fooz"; "some"; "bar" ] in
  let filter, sort, pagination, values =
    Sihl_type.Database.Ql.to_sql_fragments filter_whitelist query
  in
  Alcotest.(check (list string) "values" [ "bar"; "baz"; "where"; "10"; "1" ] values);
  Alcotest.(
    check string "filters" "WHERE ((foo = ? AND fooz LIKE ?) OR some LIKE ?)" filter);
  Alcotest.(check string "sort query" "ORDER BY foo ASC, bar DESC" sort);
  Alcotest.(check string "pagination query" "LIMIT ? OFFSET ?" pagination);
  Lwt.return ()
;;

let of_string_empty_sort _ () =
  let actual = Sihl_type.Database.Ql.of_string "" in
  Lwt.return
  @@ Alcotest.(
       check (result query string) "equals" (Ok Sihl_type.Database.Ql.empty) actual)
;;

let of_string_sort _ () =
  let actual = Sihl_type.Database.Ql.of_string "((sort((Asc foo)(Desc bar)))(page()))" in
  let expected = Sihl_type.Database.Ql.(empty |> set_sort [ Asc "foo"; Desc "bar" ]) in
  Lwt.return @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)
;;

let of_string_limit_offset _ () =
  let actual = Sihl_type.Database.Ql.of_string "((page((limit 20)(offset 10))))" in
  let expected = Sihl_type.Database.Ql.(empty |> set_limit 20 |> set_offset 10) in
  Lwt.return @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)
;;

let of_string_filter _ () =
  let actual =
    Sihl_type.Database.Ql.of_string "((filter(C((key foo)(value bar)(op Eq))))(page()))"
  in
  let criterion =
    Sihl_type.Database.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq })
  in
  let expected = Sihl_type.Database.Ql.(empty |> set_filter criterion) in
  Lwt.return @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)
;;

let of_string _ () =
  let actual =
    Sihl_type.Database.Ql.of_string
      "((filter(C((key foo)(value bar)(op Eq))))(sort((Asc foo)(Desc bar)))(page((limit \
       10)(offset 1))))"
  in
  let filter_criterion =
    Sihl_type.Database.Ql.Filter.(C { key = "foo"; value = "bar"; op = Eq })
  in
  let sort_criterion = Sihl_type.Database.Ql.Sort.[ Asc "foo"; Desc "bar" ] in
  let expected =
    Sihl_type.Database.Ql.(
      empty
      |> set_filter filter_criterion
      |> set_sort sort_criterion
      |> set_limit 10
      |> set_offset 1)
  in
  Lwt.return @@ Alcotest.(check (result query string) "equals" (Ok expected) actual)
;;

let suite =
  Alcotest_lwt.
    [ ( "query language"
      , [ test_case "to string limit offset" `Quick to_string_limit_offset
        ; test_case "to string sort" `Quick to_string_sort
        ; test_case "to string filter" `Quick to_string_filter
        ; test_case "to string" `Quick to_string
        ; test_case "to sql limit offset" `Quick to_sql_limit_offset
        ; test_case "to sql sort" `Quick to_sql_sort
        ; test_case "to sql filter" `Quick to_sql_filter
        ; test_case
            "to sql filter with partial whitelist"
            `Quick
            to_sql_filter_with_partial_whitelist
        ; test_case "to sql" `Quick to_sql
        ; test_case "to sql fragments" `Quick to_sql_fragments
        ; test_case "of string empty sort" `Quick of_string_empty_sort
        ; test_case "of string limit offset" `Quick of_string_limit_offset
        ; test_case "of string sort" `Quick of_string_sort
        ; test_case "of string filter" `Quick of_string_filter
        ; test_case "of string" `Quick of_string
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "ql" suite)
;;
