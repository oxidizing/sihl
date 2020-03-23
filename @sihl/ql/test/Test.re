open BsMocha;
let (describe, it, it_only) = Mocha.(describe, it, it_only);

let (<$>) = Rationale.Result.(<$>);

describe("End to end test", () => {
  describe("Parser", () => {
    it("parses empty string", () => {
      let query = Parser.parse("");
      Assert.deep_equal(query <$> Sql.generate, Ok(""));
    });
    it("parses invalid string", () => {
      let actual = Parser.parse("foobar") <$> Sql.generate;
      let expected = Error(Query.Error.InvalidString);
      Assert.deep_equal(actual, expected);
    });
  });
  describe("End to end", () => {
    describe("filtering", () => {
      it("age=lt.13", () => {
        let actual = Parser.parse("age=lt.13") <$> Sql.generate;
        let expected = Ok("WHERE age < 13");
        Assert.deep_equal(actual, expected);
      });
      it("age=gte.18&student=is.true", () => {
        let actual =
          Parser.parse("age=gte.18&student=is.true") <$> Sql.generate;
        let expected = Ok("WHERE age >= 18 AND student IS TRUE");
        Assert.deep_equal(actual, expected);
      });
      it("or=(age.gte.14,age.lte.18)", () => {
        let actual =
          Parser.parse("or=(age.gte.14,age.lte.18)") <$> Sql.generate;
        let expected = Ok("WHERE age >= 14 OR age <= 18");
        Assert.deep_equal(actual, expected);
      });
      it("and=(grade.gte.90,student.is.true,or(age.gte.14,age.is.null))", () => {
        let actual =
          Parser.parse(
            "and=(grade.gte.90,student.is.true,or(age.gte.14,age.is.null))",
          )
          <$> Sql.generate;
        let expected =
          Ok(
            "WHERE grade >= 90 AND student IS TRUE AND (age >= 14 OR age IS NULL)",
          );
        Assert.deep_equal(actual, expected);
      });
    });
    describe("ordering", () => {
      it("order=age.desc,height.asc", () => {
        let actual =
          Parser.parse("order=age.desc,height.asc") <$> Sql.generate;
        let expected = Ok("ORDER BY age DESC height ASC");
        Assert.deep_equal(actual, expected);
      });
      it("order=age", () => {
        let actual = Parser.parse("order=age") <$> Sql.generate;
        let expected = Ok("ORDER BY age ASC");
        Assert.deep_equal(actual, expected);
      });
    });
    it("pagination", () => {
      it("limit=15&offset=30", () => {
        let actual = Parser.parse("limit=15&offset=30") <$> Sql.generate;
        let expected = Ok("LIMIT 15 OFFSET 30");
        Assert.deep_equal(actual, expected);
      })
    });
  });
});
