open Jest;
open Expect;

describe("Http", () => {
  test("parses header", () => {
    "Bearer foobar123"
    |> Sihl.Core.Http.parseAuthToken
    |> expect
    |> toEqual(Some("foobar123"))
  })
});
