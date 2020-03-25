open Jest;
open Expect;

describe("Http", () => {
  test("parses header", () => {
    "Bearer foobar123"
    |> SihlTestSetup.App.Http.parseAuthToken
    |> expect
    |> toEqual(Some("foobar123"))
  })
});
