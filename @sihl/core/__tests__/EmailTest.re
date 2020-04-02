open Jest;
open Expect;

test("Replace element", () => {
  Sihl.Common.Email.replaceElement("foo{test}bar", "test", "baz")
  |> expect
  |> toBe("foobazbar")
});

test("Replace multiple element", () => {
  Sihl.Common.Email.replaceElement("foo{test}bar {test}", "test", "baz")
  |> expect
  |> toBe("foobazbar baz")
});

test("Replace empty string returns same string", () => {
  Sihl.Common.Email.replaceElement("", "test", "baz") |> expect |> toBe("")
});
