open Jest;
open Expect;

describe("Http", () => {
  test("parses header", () => {
    "Bearer foobar123"
    |> SihlCore.Http.parseAuthToken
    |> expect
    |> toEqual(Some("foobar123"))
  })
});
