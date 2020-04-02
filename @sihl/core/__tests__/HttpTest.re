open Jest;
open Expect;

describe("Http", () => {
  test("parses header", () => {
    "Bearer foobar123"
    |> Sihl.Common.Http.parseAuthToken
    |> expect
    |> toEqual(Some("foobar123"))
  })
});
