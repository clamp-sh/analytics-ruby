# clamp-analytics (Ruby) changelog

## 0.2.0

- Added `Clamp::Analytics.capture_error(exception, context: {}, anonymous_id: nil, timestamp: nil)` for sending exceptions as `$error` events. Extracts message, class name, and backtrace. Server adds a stable fingerprint at ingest so the same bug groups across occurrences.
- Context hash is passed through; the reserved key `:handled` is ignored.

## 0.1.0

Initial release.

- `Clamp::Analytics.init(project_id:, api_key:, endpoint: nil)`: configure the SDK once at application boot. Module-level state is held behind a Mutex, safe across threads.
- `Clamp::Analytics.track(name, properties: {}, anonymous_id: nil, timestamp: nil)`: send a server event. Returns `true`; raises `Clamp::Analytics::HTTPError` on non-2xx, `Clamp::Analytics::NotInitializedError` when called before init.
- `Clamp::Analytics::Money.new(amount, currency)`: typed monetary value for revenue, refunds, taxes.
- Property values: `String`, `Integer`, `Float`, `true`/`false`, `Money`. Other types raise `ArgumentError`.
- Pure standard library, no external runtime dependencies (`net/http`, `json`, `time`, `uri`).
- Tested on Ruby 3.0 through 3.3.
