# Mail Gazelle Ruby and Rails SDK

Official Ruby client for the [Mail Gazelle](https://mailgazelle.com) transactional email API, with an ActionMailer delivery method for Rails.

A gem is a packaged Ruby library. Add this one to an application and that application can send mail through Mail Gazelle without talking to the HTTP API itself.

The HTTP contract lives in [docs/api.md](docs/api.md). Keep that file and this gem in the same change when endpoints, error codes, or attachment limits change.

## Requirements

- Ruby 3.2 or newer
- A Mail Gazelle API token for a product that is ready to send (`tes_…`)

The only runtime gem dependency is `base64`, which ships with Ruby. It is declared so Ruby 3.4 and newer do not warn when attachments are encoded. Rails is not required. The ActionMailer delivery method loads only when the host application has already loaded Rails.

## Install

Add the gem to the application's `Gemfile`:

```ruby
gem "mailgazelle"
```

Then install:

```bash
bundle install
```

Or install it for the whole machine, outside an application:

```bash
gem install mailgazelle
```

## Create a client

```ruby
require "mailgazelle"

client = MailGazelle::Client.new(api_token: ENV.fetch("MAILGAZELLE_API_TOKEN"))
```

The default API root is `https://mailgazelle.com/api/v1`. Tokens are minted in the Mail Gazelle admin UI for a product that is ready to send. The raw token is shown once.

Reuse one client per token. Do not construct a new client for every send.

| Argument | Default | Purpose |
|---|---|---|
| `api_token` | none | Bearer token (`tes_…`). Required. |
| `base_url` | `https://mailgazelle.com/api/v1` | Override the API root. A trailing slash is ignored. |
| `transport` | `Net::HTTP` | Inject an object that implements `perform` and returns a response. Useful in tests. |
| `timeout` | `30` seconds | Read and write timeout. |
| `connect_timeout` | `10` seconds | Connection timeout. |
| `user_agent_suffix` | none | Appended to `mailgazelle-ruby/{version}`. |

```ruby
client = MailGazelle::Client.new(
  api_token: ENV.fetch("MAILGAZELLE_API_TOKEN"),
  user_agent_suffix: "MyApp/2.4"
)
```

You can also set process-wide defaults. `MailGazelle.client` builds one client from them and raises `MailGazelle::ApiTokenMissing` if the token is blank:

```ruby
MailGazelle.configure do |config|
  config.api_token = ENV.fetch("MAILGAZELLE_API_TOKEN")
end
```

## Send email

Either HTML or plain text is required. Both may be sent together. `to` is one or more recipients. Together with `cc` and `bcc`, a message can include at most 50 addresses.

### Plain text

```ruby
queued = client.emails.send(
  MailGazelle::Email.to("user@example.com", "Ada")
    .subject("Welcome")
    .text("Thanks for signing up.")
)

queued.id      # Mail Gazelle message id
queued.status  # "queued"
```

`POST /emails` returns `202` immediately. The message is stored and queued. Delivery happens asynchronously.

### HTML, recipients, and attachments

```ruby
client.emails.send(
  MailGazelle::Email.to("user@example.com", "Ada")
    .add_to("other@example.com")
    .cc("billing@example.com")
    .bcc("audit@example.com")
    .subject("Invoice")
    .html("<p>Your invoice is attached.</p><img src=\"cid:logo\">")
    .text("Your invoice is attached.")
    .from("notif@example.com", "App")
    .reply_to("support@example.com")
    .header("Message-ID", "<invoice-42@example.com>")
    .tag("campaign", "welcome")
    .idempotency_key("invoice-42")
    .attach(MailGazelle::Attachment.from_path("/tmp/invoice.pdf"))
    .attach(MailGazelle::Attachment.from_contents("logo.png", png_bytes, content_id: "logo"))
)
```

`from` and `reply_to` are omitted when you do not set them, so the product defaults apply. A custom From address must use the product's primary or sending domain. `without_reply_to` sends `"reply_to": []`, which removes Reply-To. `bcc` is stored and delivered, and omitted from the visible MIME headers.

An idempotency key is unique per team. The same key returns the original message and does not send again. A replay is not checked against quota. The SDK does not retry failed requests. Set an idempotency key when a caller may repeat a send.

HTML must be 512 KB or smaller. The SDK checks that before it calls the API.

### Attachments

`Attachment.from_path` reads a file. `from_contents` takes raw bytes. `from_base64` takes content that is already base64-encoded.

Filenames must be a basename. Path segments are rejected. `content_type` is guessed from the filename when omitted. `content_id` marks an inline part. Reference it from HTML as `cid:{content_id}`. A leading `cid:` and surrounding angle brackets are stripped. Empty or duplicate ids are rejected.

The SDK enforces the 7 MB decoded platform ceiling. How many files a plan allows, and any lower size limit, are enforced by the API. The assembled raw MIME must be 10 MB or smaller (`message_too_large`).

### Fetch a message

`GET /emails/{id}` returns status, timestamps, the provider message id, the last event type, and attachment metadata. It does not return HTML, text, or file bytes.

```ruby
record = client.emails.get(queued.id)

record.status           # for example "queued" or "rejected"
record.known_status     # "queued" or "rejected" when this gem knows the value, otherwise nil
record.message_id       # provider id after accept, or nil
record.last_event_type
record.created_at
record.attachments      # filename, content type, size
record.to_h             # full payload, including fields added later
```

### List domains

```ruby
client.domains.list.each do |domain|
  domain.name
  domain.type
  domain.verification_statuses
  domain.to_h
end
```

## Rails

Add the gem to the Gemfile, then select the delivery method. Mailers stay normal ActionMailer classes. `deliver_now` and `deliver_now!` perform the HTTP call.

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :mailgazelle
config.action_mailer.mailgazelle_settings = {
  api_token: ENV.fetch("MAILGAZELLE_API_TOKEN")
  # api_base: ENV["MAILGAZELLE_BASE_URL"] # optional
}
```

`api_base`, `base_url`, `timeout`, and `connect_timeout` are optional. A token in `MailGazelle.configure` is used when the delivery settings do not include one. A missing token raises `MailGazelle::ApiTokenMissing` on the first send.

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def welcome
    mail(
      to: "Ada <ada@example.com>",
      subject: "Welcome",
      tags: { campaign: "welcome" },
      "MailGazelle-Idempotency-Key" => "welcome-42"
    )
  end
end
```

```ruby
UserMailer.welcome.deliver_now!
```

`MAIL_FROM` / `default from:` on the mailer is sent as `from` when present. Omit it to keep the product From. Reply-To on the message is sent as `reply_to`. Inline attachments (`attachments.inline`) include a content id.

`tags:` becomes the tags object. Names and values must match `[A-Za-z0-9_-]`. `team_id` and `product_id` are reserved.

`MailGazelle-Idempotency-Key` is not sent as a header. It becomes `idempotency_key`.

Custom headers are forwarded, except `From`, `To`, `Cc`, `Bcc`, `Reply-To`, `Sender`, `Subject`, `Content-Type`, `Content-Transfer-Encoding`, `Return-Path`, `MIME-Version`, and `Date`. `Message-ID` is forwarded.

`deliver_now!` returns the queued result because the delivery method asks Mail for the response. The Mail Gazelle id is also stored on the message as `X-MailGazelle-Message-Id`, and as the message id.

```ruby
message = UserMailer.welcome.deliver_now!
message.id # Mail Gazelle message id
```

## Errors

All failures subclass `MailGazelle::Error`. Catch that type when you only need to know that a call failed. Use a subclass when the recovery path depends on the cause.

```ruby
begin
  client.emails.send(email)
rescue MailGazelle::RecipientSuppressedError
  # Stored as rejected. Do not retry this address.
rescue MailGazelle::RateLimitError
  # 60 requests per minute per token. Back off and retry later.
rescue MailGazelle::Error => error
  error.message
  error.code         # API error code
  error.http_status  # 0 when no HTTP response was received
  error.details
end
```

The SDK validates documented limits before it calls the API. Local and remote failures of the same kind raise the same class. Plan-specific limits that are lower than the platform ceiling are left to the API.

| API `code` | Error class | Typical HTTP |
|---|---|---|
| `unauthenticated` | `AuthenticationError` | 401 |
| `product_not_ready` | `ProductNotReadyError` | 403 |
| `validation_error` | `ValidationError` | 422 |
| `from_not_allowed` | `FromNotAllowedError` | 422 |
| `recipient_suppressed` | `RecipientSuppressedError` | 422 |
| `attachment_invalid` | `AttachmentError` | 422 |
| `attachment_too_large` | `AttachmentTooLargeError` | 422 |
| `quota_exceeded` | `QuotaExceededError` | 422 |
| `html_too_large` | `HtmlTooLargeError` | 422 |
| `message_too_large` | `MessageTooLargeError` | 422 |
| `rate_limited` | `RateLimitError` | 429 |

`unauthenticated` also covers a token for an archived product. `recipient_suppressed` does not consume quota. `quota_exceeded` means the send would pass the team's monthly email allowance, daily send limit, or monthly attachment allowance. The message says which limit was hit.

Unknown codes become `ApiError`. Network, DNS, TLS, and timeout failures become `TransportError`.

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

Tests stub HTTP. They do not call Mail Gazelle.

## Release

The published gem is [mailgazelle on RubyGems](https://rubygems.org/gems/mailgazelle). Shipping a version is a separate step from installing it.

1. Sign in at [rubygems.org](https://rubygems.org/sign_up) with the account that should own the gem, and turn on multi-factor authentication. This gemspec requires MFA for every push.
2. Create an API key at [rubygems.org/profile/api_keys](https://rubygems.org/profile/api_keys) with the **Push rubygem** scope. RubyGems shows the key once.
3. From this repository, with a clean git tree and the version you want in `lib/mailgazelle/version.rb`:

```bash
gem build mailgazelle.gemspec
gem push mailgazelle-1.0.1.gem
```

`gem push` asks for the API key the first time and stores it in `~/.gem/credentials`. The first successful push reserves the name `mailgazelle` for that account. A version that has been pushed cannot be uploaded again, including after a yank.

`bundle exec rake release` does the same push, and also creates a git tag and pushes it. Use that only after the commit you are releasing is already on `main`.
