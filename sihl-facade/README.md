# sihl-facade

The `sihl-facade` package contains service facades which is the API and helper functions. When a user accesses services throughout their Sihl app like `Sihl.User.find` or `Sihl.Token.create`, they are using the API of the user and the token facade.

The facade is the same no matter what service implementation is registered.
