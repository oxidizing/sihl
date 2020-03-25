open Jest;
open Expect;

module Persistence = SihlCoreDbCore.Make(SihlCoreDbMysql.Mysql);
module SihlCore = SihlCore.Make(Persistence);

describe("Http", () => {
  test("parses header", () => {
    "Bearer foobar123"
    |> SihlCore.Http.parseAuthToken
    |> expect
    |> toEqual(Some("foobar123"))
  })
});
