module Settings = {
  let name = "User Management App";
  let prefix = "users";
  let minPasswordLength = 8;
};

module Database = {
  let migrations = prefix => [
    {j|
CREATE TABLE IF NOT EXISTS $(prefix)_users (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  email VARCHAR(128) NOT NULL,
  password VARCHAR(128) NOT NULL,
  given_name VARCHAR(128) NOT NULL,
  family_name VARCHAR(128) NOT NULL,
  username VARCHAR(128),
  phone VARCHAR(128),
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_email UNIQUE KEY (email),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|j},
  ];
};

module Http = {
  open Sihl.Core.Http;
  let routes = pool => [
    Route.post("/register/", Routes.register),
    Route.get("/login/", Routes.login),
    Route.get("/", Routes.getUsers(pool) |> Routes.auth),
    Route.get("/:id/", Routes.getUser(pool) |> Routes.auth),
    Route.get("/me/", Routes.getMyUser |> Routes.auth),
    Route.post(
      "/request-password-reset/",
      Routes.requestPasswordReset |> Routes.auth,
    ),
    Route.post("/reset-password/", Routes.resetPassword |> Routes.auth),
    Route.post("/update-password/", Routes.updatePassword |> Routes.auth),
    Route.post("/set-password/", Routes.setPassword |> Routes.auth),
  ];
};
