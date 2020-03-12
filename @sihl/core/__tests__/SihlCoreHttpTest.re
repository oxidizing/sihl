open Jest;
open Expect;

describe("Http", () => {
  test("parses header", () => {
    "Bearer foobar123"
    |> SihlCoreHttp.parseAuthToken
    |> expect
    |> toEqual(Some("foobar123"))
  })
});
