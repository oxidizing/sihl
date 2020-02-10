let (<$>) = Future.(<$>);
let (>>=) = Future.(>>=);

module Utils = {
  let cleanDb = pool => {
    pool
    |> Sihl.Core.Db.Pool.connect
    >>= (
      connection =>
        Future.map(
          Belt.List.map(App.Database.clean, f => f(connection)) |> Future.all,
          Sihl.Core.Error.flatten,
        )
    );
  };
};

open Jest;

describe("Expect", () => {
  Expect.(test("toBe", () =>
            expect(1 + 2) |> toBe(3)
          ))
});

describe("Expect.Operators", () => {
  open Expect;
  open! Expect.Operators;

  test("==", () =>
    expect(1 + 2) === 3
  );
});
