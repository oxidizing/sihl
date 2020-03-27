open Jest;
open Expect;

describe("Migrations", () => {
  open Sihl.App.Db.Migration;
  test("steps to apply returns empty list", () => {
    let migration = {steps: _ => [], namespace: "foo-namespace"};
    stepsToApply(migration, 10)
    |> Belt.List.toArray
    |> expect
    |> toHaveLength(0);
  });
  test("steps to apply returns missing migrations", () => {
    let migration = {
      steps: _ => [(1, "foo"), (0, "bar"), (2, "baz")],
      namespace: "foo-namespace",
    };
    let expected = [(2, "baz")];
    stepsToApply(migration, 1) |> expect |> toEqual(expected);
  });
  test("steps to apply returns sorted missing migrations", () => {
    let migration = {
      steps: _ => [(1, "foo"), (0, "bar"), (2, "baz")],
      namespace: "foo-namespace",
    };
    let expected = [(1, "foo"), (2, "baz")];
    stepsToApply(migration, 0) |> expect |> toEqual(expected);
  });
  test("gets maximum version", () => {
    maxVersion([(1, "foo"), (0, "bar"), (2, "baz")]) |> expect |> toBe(2)
  });
});

describe("Parses DATABASE_URL", () => {
  test("is empty with empty string", () => {
    Sihl.Core.Config.Db.Url.parse("")
    |> expect
    |> toEqual(Error("Invalid database url provided"))
  });
  test("is empty with invalid url", () => {
    Sihl.Core.Config.Db.Url.parse("sdfaadsf")
    |> expect
    |> toEqual(Error("Invalid database url provided"))
  });
  test("returns config", () => {
    let config =
      Sihl.Core.Config.Db.make(
        ~user="username",
        ~password="password",
        ~host="host",
        ~port="port",
        ~db="db",
      );
    Sihl.Core.Config.Db.makeFromUrl("mysql://username:password@host:port/db")
    |> expect
    |> toEqual(Ok(config));
  });
});
