open Jest;
open Expect;

test("Replace element", () => {
  Model.Email.replaceElement("foo{test}bar", "test", "baz")
  |> expect
  |> toBe("foobazbar")
});

test("Replace multiple element", () => {
  Model.Email.replaceElement("foo{test}bar {test}", "test", "baz")
  |> expect
  |> toBe("foobazbar baz")
});

test("Replace empty string returns same string", () => {
  Model.Email.replaceElement("", "test", "baz") |> expect |> toBe("")
});
