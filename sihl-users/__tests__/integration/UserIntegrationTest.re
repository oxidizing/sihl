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
