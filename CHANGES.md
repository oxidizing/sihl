# Changelog

## [0.1.1] - 2020-09-03
### Fixed
- Move Opium & Cohttp specific stuff into the web server service implementation to allow for swappable implementation based on something like httpaf

### Added
- HTTP Response API to respond with file `Sihl.Web.Res.file`

## [0.1.0] - 2020-09-02
### Fixed
- DB connection leaks caused deadlocks
- Provide all service dependencies using functors

### Added
- Support letters 0.2.0 for SMTP emailing
- Switch to exception based service API

## [0.0.56] - 2020-08-17
### Fixed
- Stop running integration tests during OPAM release

## [0.0.55] - 2020-08-17
### Added
- Initial release of Sihl
