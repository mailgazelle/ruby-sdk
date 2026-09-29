# frozen_string_literal: true

require "mail"
require "mailgazelle/attachment"
require "mailgazelle/client"
require "mailgazelle/email"
require "mailgazelle/error"

module MailGazelle
  # ActionMailer delivery method. Registered as +:mailgazelle+ by {Railtie}.
  class Mailer
    SKIPPED_HEADERS = %w[
      bcc
      cc
      content-transfer-encoding
      content-type
      date
      from
      idempotency-key
      idempotency_key
      mailgazelle-idempotency-key
      mime-version
      reply-to
      return-path
      sender
      subject
      tags
      to
      x-mailgazelle-message-id
    ].freeze

    IDEMPOTENCY_HEADERS = %w[
      idempotency-key
      idempotency_key
      mailgazelle-idempotency-key
    ].freeze

    attr_reader :settings

    def initialize(settings = nil)
      @config = settings.is_a?(Hash) ? settings : {}
      @settings = @config.merge(return_response: true)
    end

    def deliver!(mail)
      queued = client.emails.send(build_email(mail))
      remember_id(mail, queued.id)
      queued
    end

    private

    def client
      @client ||= build_client
    end

    def build_client
      token = first_present(setting(:api_token), MailGazelle.config.api_token)
      raise ApiTokenMissing if token.nil? || token.to_s.strip.empty?

      Client.new(
        api_token: token,
        base_url: first_present(setting(:api_base), setting(:base_url), MailGazelle.config.api_base),
        transport: setting(:transport),
        timeout: first_present(setting(:timeout), MailGazelle.config.timeout) || 30,
        connect_timeout: first_present(setting(:connect_timeout), MailGazelle.config.connect_timeout) || 10,
        user_agent_suffix: user_agent_suffix
      )
    end

    def user_agent_suffix
      extra = first_present(setting(:user_agent_suffix), MailGazelle.config.user_agent_suffix)
      ["rails", extra].compact.map { |value| value.to_s.strip }.reject(&:empty?).join(" ")
    end

    def setting(key)
      return @config[key] if @config.key?(key)

      @config[key.to_s] if @config.key?(key.to_s)
    end

    def first_present(*values)
      values.find { |value| !value.nil? && !(value.is_a?(String) && value.strip.empty?) }
    end

    def build_email(message)
      recipients = address_pairs(message[:to])
      if recipients.empty?
        raise ValidationError.new(
          "A Mail Gazelle message requires at least one To address.",
          code: "validation_error",
          http_status: 422
        )
      end

      email = Email.to(recipients.first[0], recipients.first[1])
      recipients.drop(1).each { |address, name| email = email.add_to(address, name) }
      address_pairs(message[:cc]).each { |address, name| email = email.cc(address, name) }
      address_pairs(message[:bcc]).each { |address, name| email = email.bcc(address, name) }
      email = email.subject(message.subject.to_s)
      email = apply_body(email, message)

      from = address_pairs(message[:from]).first
      email = email.from(from[0], from[1]) if from
      address_pairs(message[:reply_to]).each { |address, name| email = email.reply_to(address, name) }
      email = apply_headers(email, message)
      apply_attachments(email, message)
    end

    def apply_body(email, message)
      if message.multipart?
        text = part_body(message.text_part)
        html = part_body(message.html_part)
        email = email.text(text) if text
        email = email.html(html) if html
        return email
      end

      body = message.body.decoded.to_s
      return email if body.empty?

      if message.mime_type == "text/html"
        email.html(body)
      else
        email.text(body)
      end
    end

    def part_body(part)
      return nil if part.nil?

      body = part.decoded.to_s
      body.empty? ? nil : body
    end

    def apply_headers(email, message)
      tags = nil
      idempotency = nil
      headers = {}

      message.header_fields.each do |field|
        name = field.name.to_s
        lowered = name.downcase

        if lowered == "tags"
          tags = hash_value(field)
          next
        end

        if IDEMPOTENCY_HEADERS.include?(lowered)
          idempotency = field.value.to_s
          next
        end

        next if SKIPPED_HEADERS.include?(lowered)

        value = field.value
        next if value.nil?

        headers[name] = value.to_s
      end

      headers.each { |name, value| email = email.header(name, value) }
      tags&.each { |key, value| email = email.tag(key.to_s, value.to_s) }
      email = email.idempotency_key(idempotency.strip) if idempotency.is_a?(String) && !idempotency.strip.empty?
      email
    end

    def hash_value(field)
      unparsed = field.unparsed_value if field.respond_to?(:unparsed_value)
      return unparsed if unparsed.is_a?(Hash)
      return field.value if field.value.is_a?(Hash)

      nil
    end

    def apply_attachments(email, message)
      message.attachments.each do |part|
        filename = part.filename.to_s
        filename = "attachment" if filename.empty?
        email = email.attach(
          Attachment.from_contents(
            filename,
            part.body.decoded.to_s,
            content_type: part.mime_type,
            content_id: part.inline? ? part.cid : nil
          )
        )
      end
      email
    end

    def address_pairs(header)
      return [] if header.nil? || !header.respond_to?(:addrs)

      header.addrs.filter_map do |address|
        email = address.address.to_s.strip
        next if email.empty?

        name = address.display_name.to_s.strip
        [email, name.empty? ? nil : name]
      end
    end

    def remember_id(message, id)
      return if id.nil? || id.empty?

      message.header["X-MailGazelle-Message-Id"] = id
      message.message_id = id
    end
  end
end
