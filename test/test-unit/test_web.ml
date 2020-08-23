open Base

let externalize_link _ () =
  let actual = Sihl.Web.Utils.externalize ~prefix:"prefix" "foo/bar" in
  Alcotest.(check @@ string) "prefixes path" "prefix/foo/bar" actual;
  let actual = Sihl.Web.Utils.externalize ~prefix:"prefix" "foo/bar/" in
  Alcotest.(check @@ string) "preserve trailing" "prefix/foo/bar/" actual;
  let actual = Sihl.Web.Utils.externalize ~prefix:"prefix" "/foo/bar/" in
  Alcotest.(check @@ string) "no duplicate slash" "prefix/foo/bar/" actual;
  Lwt.return ()
