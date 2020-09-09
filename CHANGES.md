# Changelog

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
