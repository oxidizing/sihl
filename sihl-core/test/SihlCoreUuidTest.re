open BsMocha;
let (describe, it, it_only) = Mocha.(describe, it, it_only);

describe("Uuid", () =>
  it("recognizes valid uuid v4", () => {
    open SihlCore;
    Assert.equal(Uuid.V4.isValid("foobar"), false);
    Assert.equal(
      Uuid.V4.isValid("cd6c1c3f-1089-477f-8146-7becaa37dcfb"),
      true,
    );
    Assert.equal(
      Uuid.V4.isValid("cd6c1c3f-1089-477f-8146-7becaa37dcfz"),
      false,
    );
  })
);
