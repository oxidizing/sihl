open Jest;
open Expect;

describe("Http", () => {
  test("parses header", () => {
    "Bearer foobar123"
    |> Sihl.Core.Http.Core.parseAuthToken
    |> expect
    |> toEqual(Some("foobar123"))
  })
});
