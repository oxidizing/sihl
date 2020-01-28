open BsMocha;
let (describe, it, it_only) = Mocha.(describe, it, it_only);

describe("Base64", () => {
  it("encodes string", () =>
    Assert.equal(SihlCore.Base64.encode("123"), "MTIz")
  );
  it("decodes string", () =>
    Assert.equal(SihlCore.Base64.decode("MTIz"), "123")
  );
  it("decodes encoded string yields string", () => {
    SihlCore.(Assert.equal(Base64.decode(Base64.encode("123")), "123"))
  });
});
