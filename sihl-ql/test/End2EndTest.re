open BsMocha;
let (describe, it, it_only) = Mocha.(describe, it, it_only);

let (<$>) = Rationale.Result.(<$>);

describe("End to end test", () => {
  it("empty string", () => {
    let query = Parser.parse("");
    Assert.deep_equal(query <$> Sql.generate, Belt.Result.Ok(""));
  });
  it("invalid string", () => {
    let actual = Parser.parse("foobar") <$> Sql.generate;
    let expected = Belt.Result.Error(Query.Error.InvalidString);
    Assert.deep_equal(actual, expected);
  });
});
