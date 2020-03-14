open Jest;
open Expect;

describe("Migrations", () => {
  open SihlCoreDb.Migration;
  test("steps to apply returns empty list", () => {
    let migration = {steps: _ => [], namespace: "foo-namespace"};
    SihlCoreDb.Migration.stepsToApply(migration, 10)
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
    SihlCoreDb.Migration.stepsToApply(migration, 1)
    |> expect
    |> toEqual(expected);
  });
  test("steps to apply returns sorted missing migrations", () => {
    let migration = {
      steps: _ => [(1, "foo"), (0, "bar"), (2, "baz")],
      namespace: "foo-namespace",
    };
    let expected = [(1, "foo"), (2, "baz")];
    SihlCoreDb.Migration.stepsToApply(migration, 0)
    |> expect
    |> toEqual(expected);
  });
  test("gets maximum version", () => {
    SihlCoreDb.Migration.maxVersion([(1, "foo"), (0, "bar"), (2, "baz")])
    |> expect
    |> toBe(2)
  });
});

describe("Parses DATABASE_URL", () => {
  test("is empty with empty string", () => {
    SihlCoreDb.Database.parseUrl("") |> expect |> toBe(None)
  });
  test("is empty with invalid url", () => {
    SihlCoreDb.Database.parseUrl("sdfaadsf") |> expect |> toBe(None)
  });
  test("returns config", () => {
    let config =
      SihlCoreConfig.Db.make(
        ~user="username",
        ~password="password",
        ~host="host",
        ~port="port",
        ~db="db",
      );
    SihlCoreDb.Database.parseUrl("mysql://username:password@host:port/db")
    |> expect
    |> toEqual(Some(config));
  });
});
