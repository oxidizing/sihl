# Changelog

## [0.1.9] - ?
### Fixed
- Get rid of `Core.Ctx.t`

## [0.1.8] - 2020-11-12
### Fixed
- Get rid of `Result.get_ok` because it swallows errors

## [0.1.7] - 2020-11-03
### Fixed
- Simplify `Database.Service` API: Only provide `transaction`, `query` and `fetch_pool`
- Fixe dune package names, private dune packages don't have generic names like `http` or `database` causing conflicts in a Sihl app

## [0.1.6] - 2020-10-31
### Fixed
- `Database.Service` and `Repository.Service` are assumed to have just one implementation, so they are referenced directly in service implementations instead of passing them as functor arguments
- Extract `Random.Service` from utils as standalone top level service
- Merge utils into one `utils.ml` file
#### HTTP API
- `Sihl.Http.Response` and `Sihl.Http.Request` have consistent API
- `Sihl.Middleware` contains all provided middlewares
- Implement multi-part form data parsing

## [0.1.5] - 2020-10-14
### Fixed
- Remove seed service since the same functionality
- Simplify app abstraction, instead of `with_` use service APIs directly
- Extract storage service as `sihl-storage` opam package
- Extract email service as `sihl-email` opam package
- Extract queue service as `sihl-queue` opam package
- Move configuration and logging into core, neither of the are implemented as services
- Replace `pcre` with `re` as regex library to get rid of a system dependency on pcre
- Split up `Sihl.Data` into `Sihl.Migration`, `Sihl.Repository` and `Sihl.Database`
- Move module signatures from `Foo.Service.Sig` to `Foo.Sig`, the services might live in a third party opam package, but the signatures are staying in `sihl`
- Move `Sihl.App` to `Sihl.Core.App` and simplify app API
- Move log service, config service and cmd service into core (they don't have to be provided to other services through functors)
- Simplify Sihl app creation and service configuration

## [0.1.4] - 2020-09-24
### Fixed
- Remove `reason` and `tyxml-jsx` as dependency as they are not used anymore

### Added
- Various combinators for `Sihl.Seed.t` including constructor and field accessors

## [0.1.3] - 2020-09-14
### Added
- Seed Service with commands `seedlist` and `seedrun <name>`

### Fixed
- Lifecycle API: A service now has two additional functions `start` and `stop`, which are used in the lifecycle definition
- Database service query functions `query`, `atomic` and `with_connection` can now be nested

## [0.1.2] - 2020-09-09
### Fixed
- Re-export `Sihl.Queue.Job.t`
- Export content types under `Sihl.Web`

## [0.1.1] - 2020-09-07
### Fixed
- Don't raise exception when user login fails if it is a user error
- Remove dev tools as dev dependencies

### Added
- Storage service can remove files
- Move README.md documentation to ocamldoc based documentation

## [0.1.0] - 2020-09-03
### Fixed
- DB connection leaks caused deadlocks
- Provide all service dependencies using functors
- Move Opium & Cohttp specific stuff into the web server service implementation to allow for swappable implementation based on something like httpaf
- Inject log service to all other services by default

### Added
- Support letters 0.2.0 for SMTP emailing
- Switch to exception based service API
- HTTP Response API to respond with file `Sihl.Web.Res.file`

## [0.0.56] - 2020-08-17
### Fixed
- Stop running integration tests during OPAM release

## [0.0.55] - 2020-08-17
### Added
- Initial release of Sihl
