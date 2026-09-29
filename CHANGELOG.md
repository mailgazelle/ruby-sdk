# Changelog

## 1.0.1

- Declare `base64` as a dependency so Ruby 3.4 and newer do not warn when the gem loads it.

## 1.0.0

- Send and fetch transactional email, and list product domains, through the Mail Gazelle API.
- Deliver Rails mail with ActionMailer's `:mailgazelle` delivery method.
