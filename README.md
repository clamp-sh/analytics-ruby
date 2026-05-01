# clamp-analytics (Ruby)

Server-side analytics SDK for [Clamp Analytics](https://clamp.sh) in Ruby.

Send tracked events from any Ruby app to Clamp. Works with Rails, Sinatra, Sidekiq workers, scheduled jobs, and anything else that runs Ruby 3.0+ and can make outbound HTTPS calls.

## Install

Add to your `Gemfile`:

```ruby
gem "clamp-analytics"
```

Or:

```bash
gem install clamp-analytics
```

Ruby 3.0+ supported. The gem uses only the standard library (`net/http`, `json`, `time`, `uri`).

## Quick start

```ruby
require "clamp_analytics"

Clamp::Analytics.init(
  project_id: "proj_xxx",
  api_key: ENV.fetch("CLAMP_API_KEY")
)

# Simple event
Clamp::Analytics.track("signup", properties: { plan: "pro", method: "email" })

# Link a server event to a browser visitor
Clamp::Analytics.track(
  "subscription_started",
  properties: {
    plan: "pro",
    total: Clamp::Analytics::Money.new(29.00, "USD")
  },
  anonymous_id: "aid_xxx"
)
```

Get a server API key at <https://clamp.sh/dashboard> (Settings → API Keys, format `sk_proj_...`). Read it from the environment; never commit it.

## API

### `Clamp::Analytics.init(project_id:, api_key:, endpoint: nil)`

Initializes the SDK. Call once at app boot (Rails initializer, Sinatra setup, Sidekiq server middleware). State is held at the module level behind a Mutex, so it's safe across threads.

`endpoint` is optional and overrides the default `https://api.clamp.sh`.

### `Clamp::Analytics.track(name, properties: {}, anonymous_id: nil, timestamp: nil)`

Sends a server event. Returns `true` on success.

- **`name`**: event name string. Examples: `"signup"`, `"subscription_started"`.
- **`properties`**: optional hash. Values may be `String`, `Integer`, `Float`, `true`/`false`, or `Money`. Other types raise `ArgumentError`.
- **`anonymous_id`**: optional string. Links the server event to a browser visitor.
- **`timestamp`**: optional `Time` (non-UTC times are normalized to UTC) or ISO 8601 string. If omitted, uses `Time.now.utc`.

Raises `Clamp::Analytics::HTTPError` on a non-2xx response, `Clamp::Analytics::NotInitializedError` if `init` wasn't called.

### `Clamp::Analytics::Money`

```ruby
Clamp::Analytics::Money.new(29.00, "USD")
```

A typed monetary value. `amount` is in major units (29.00, not 2900). `currency` is an ISO 4217 code (uppercase, three letters).

### `Clamp::Analytics.capture_error(exception, context: {}, anonymous_id: nil, timestamp: nil)`

Sends an exception as a `$error` event. Convenience over `track` that extracts message, class name, and backtrace from the exception. The server adds a stable fingerprint at ingest so the same bug groups across occurrences.

```ruby
begin
  process_webhook(payload)
rescue => e
  Clamp::Analytics.capture_error(e, context: { webhook: "stripe" })
end
```

- **`exception`**: any `Exception` instance. Stack via `exception.backtrace`, type via `exception.class.name`.
- **`context`**: optional flat hash of additional properties. Values must be primitives (`String`, `Integer`, `Float`, `true`/`false`); the reserved key `:handled` is ignored.
- **`anonymous_id`**: optional. Links the error to a browser visitor.
- **`timestamp`**: optional `Time` or ISO 8601 string.

Same return value and exceptions as `track`. Lengths are capped (`error.message` 1KB, `error.type` 64 chars, `error.stack` 16KB) to match server-side limits.

## Framework integrations

Per-framework integration patterns (Rails initializer + concern, Sinatra helper, Sidekiq middleware) are documented at <https://clamp.sh/docs/sdk/ruby>.

## Errors

The gem is synchronous and raises on failure. There are no automatic retries. If you want fire-and-forget behaviour, rescue around the call:

```ruby
begin
  Clamp::Analytics.track("subscription_started", properties: ...)
rescue Clamp::Analytics::Error => e
  Rails.logger.error("clamp: #{e.message}")
end
```

For high-throughput webhook handlers, defer the call to a Sidekiq job.

## Links

- RubyGems: <https://rubygems.org/gems/clamp-analytics>
- Docs: <https://clamp.sh/docs/sdk/ruby>
- Source: <https://github.com/clamp-sh/analytics-ruby>
- Issues: <https://github.com/clamp-sh/analytics-ruby/issues>
