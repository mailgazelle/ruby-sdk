# frozen_string_literal: true

require "mailgazelle/address"
require "mailgazelle/attachment"
require "mailgazelle/error"

module MailGazelle
  # Immutable builder for a +POST /emails+ payload.
  #
  # Either HTML or plain text is required. Optional fields are omitted from the
  # JSON body so Mail Gazelle can apply product defaults.
  class Email
    MAX_HTML_BYTES = 512 * 1024
    MAX_ATTACHMENT_BYTES = 7 * 1024 * 1024
    MAX_RECIPIENTS = 50
    MAX_TAGS = 48
    MAX_TAG_NAME_LENGTH = 64
    MAX_TAG_VALUE_LENGTH = 256
    MAX_HEADERS = 50
    MAX_HEADER_VALUE_LENGTH = 8192
    RESERVED_TAGS = %w[team_id product_id].freeze
    TAG_PATTERN = /\A[A-Za-z0-9_-]+\z/
    HEADER_NAME_PATTERN = /\A[A-Za-z0-9-]+\z/

    def self.to(email, name = nil)
      new(to: [Address.new(email, name)])
    end

    def add_to(email, name = nil)
      append_recipient(:to, Address.new(email, name))
    end

    def cc(email, name = nil)
      append_recipient(:cc, Address.new(email, name))
    end

    def bcc(email, name = nil)
      append_recipient(:bcc, Address.new(email, name))
    end

    def subject(value)
      copy(subject: value)
    end

    def text(value)
      copy(text: value)
    end

    def html(value)
      copy(html: value)
    end

    def from(email, name = nil)
      copy(from: Address.new(email, name))
    end

    def reply_to(email, name = nil)
      addresses = @reply_to.dup
      addresses << Address.new(email, name)
      copy(reply_to: addresses.freeze, omit_reply_to: false)
    end

    def without_reply_to
      copy(reply_to: [].freeze, omit_reply_to: true)
    end

    def header(name, value)
      self.class.assert_header(name, value)
      headers = @headers.dup
      if !headers.key?(name) && headers.size >= MAX_HEADERS
        raise ValidationError.new(
          "A message can include at most #{MAX_HEADERS} headers.",
          code: "validation_error",
          http_status: 422
        )
      end

      headers[name] = value
      copy(headers: headers.freeze)
    end

    def headers(values)
      updated = copy(headers: {}.freeze)
      values.each { |name, value| updated = updated.header(name.to_s, value.to_s) }
      updated
    end

    def tag(key, value)
      self.class.assert_tag_part(key, MAX_TAG_NAME_LENGTH)
      self.class.assert_tag_part(value, MAX_TAG_VALUE_LENGTH)
      if RESERVED_TAGS.include?(key)
        raise ValidationError.new(
          "The tag names team_id and product_id are reserved.",
          code: "validation_error",
          http_status: 422
        )
      end

      tags = @tags.dup
      if !tags.key?(key) && tags.size >= MAX_TAGS
        raise ValidationError.new(
          "A message can include at most #{MAX_TAGS} tags.",
          code: "validation_error",
          http_status: 422
        )
      end

      tags[key] = value
      copy(tags: tags.freeze)
    end

    def tags(values)
      updated = copy(tags: {}.freeze)
      values.each { |key, value| updated = updated.tag(key.to_s, value.to_s) }
      updated
    end

    def idempotency_key(key)
      copy(idempotency_key: key)
    end

    def attach(attachment)
      raise ArgumentError, "Expected a MailGazelle::Attachment" unless attachment.is_a?(Attachment)

      if attachment.content_id
        @attachments.each do |existing|
          next unless existing.content_id == attachment.content_id

          raise AttachmentError.new(
            "Attachment content ids must be unique.",
            code: "attachment_invalid",
            http_status: 422
          )
        end
      end

      attachments = @attachments.dup
      attachments << attachment
      copy(attachments: attachments.freeze)
    end

    # Validate documented limits and return the JSON body for +POST /emails+.
    def to_payload
      assert_ready

      payload = {
        to: @to.map(&:to_h),
        subject: @subject
      }
      payload[:html] = @html unless @html.nil?
      payload[:text] = @text unless @text.nil?
      payload[:from] = @from.to_h unless @from.nil?
      payload[:cc] = @cc.map(&:to_h) unless @cc.empty?
      payload[:bcc] = @bcc.map(&:to_h) unless @bcc.empty?

      if @omit_reply_to
        payload[:reply_to] = []
      elsif !@reply_to.empty?
        payload[:reply_to] = @reply_to.map(&:to_h)
      end

      payload[:headers] = @headers unless @headers.empty?
      payload[:tags] = @tags unless @tags.empty?
      payload[:idempotency_key] = @idempotency_key if @idempotency_key.is_a?(String) && !@idempotency_key.empty?
      payload[:attachments] = @attachments.map(&:to_h) unless @attachments.empty?
      payload
    end

    def self.assert_header(name, value)
      unless HEADER_NAME_PATTERN.match?(name)
        raise ValidationError.new(
          "Header names must contain only letters, numbers, and hyphens.",
          code: "validation_error",
          http_status: 422
        )
      end

      if value.match?(/[\r\n]/)
        raise ValidationError.new(
          "Header values cannot contain line breaks.",
          code: "validation_error",
          http_status: 422
        )
      end

      return if value.length <= MAX_HEADER_VALUE_LENGTH

      raise ValidationError.new(
        "Header values must be at most #{MAX_HEADER_VALUE_LENGTH} characters.",
        code: "validation_error",
        http_status: 422
      )
    end

    def self.assert_tag_part(value, max_length)
      return if TAG_PATTERN.match?(value) && value.length <= max_length

      raise ValidationError.new(
        "Tag names and values may only contain letters, numbers, underscores, and hyphens.",
        code: "validation_error",
        http_status: 422
      )
    end

    def initialize(to:, subject: nil, text: nil, html: nil, from: nil, cc: [].freeze, bcc: [].freeze,
                   reply_to: [].freeze, omit_reply_to: false, headers: {}.freeze, tags: {}.freeze,
                   idempotency_key: nil, attachments: [].freeze)
      @to = to.freeze
      @subject = subject
      @text = text
      @html = html
      @from = from
      @cc = cc.freeze
      @bcc = bcc.freeze
      @reply_to = reply_to.freeze
      @omit_reply_to = omit_reply_to
      @headers = headers.freeze
      @tags = tags.freeze
      @idempotency_key = idempotency_key
      @attachments = attachments.freeze
      freeze
    end

    private

    def copy(**changes)
      self.class.new(
        to: changes.fetch(:to, @to),
        subject: changes.fetch(:subject, @subject),
        text: changes.fetch(:text, @text),
        html: changes.fetch(:html, @html),
        from: changes.fetch(:from, @from),
        cc: changes.fetch(:cc, @cc),
        bcc: changes.fetch(:bcc, @bcc),
        reply_to: changes.fetch(:reply_to, @reply_to),
        omit_reply_to: changes.fetch(:omit_reply_to, @omit_reply_to),
        headers: changes.fetch(:headers, @headers),
        tags: changes.fetch(:tags, @tags),
        idempotency_key: changes.fetch(:idempotency_key, @idempotency_key),
        attachments: changes.fetch(:attachments, @attachments)
      )
    end

    def append_recipient(field, address)
      if @to.size + @cc.size + @bcc.size >= MAX_RECIPIENTS
        raise ValidationError.new(
          "A message can include at most #{MAX_RECIPIENTS} recipients.",
          code: "validation_error",
          http_status: 422
        )
      end

      list = instance_variable_get(:"@#{field}").dup
      list << address
      copy(field => list.freeze)
    end

    def assert_ready
      if @subject.nil? || @subject.strip.empty?
        raise ValidationError.new("A subject is required.", code: "validation_error", http_status: 422)
      end

      has_html = !@html.nil? && !@html.empty?
      has_text = !@text.nil? && !@text.empty?
      unless has_html || has_text
        raise ValidationError.new(
          "Either html or text is required.",
          code: "validation_error",
          http_status: 422
        )
      end

      if has_html && @html.bytesize > MAX_HTML_BYTES
        raise HtmlTooLargeError.new(
          "HTML must be at most #{MAX_HTML_BYTES} bytes.",
          code: "html_too_large",
          http_status: 422
        )
      end

      total = @attachments.sum(&:decoded_size)
      return if total <= MAX_ATTACHMENT_BYTES

      raise AttachmentTooLargeError.new(
        "Decoded attachments must total at most #{MAX_ATTACHMENT_BYTES} bytes.",
        code: "attachment_too_large",
        http_status: 422
      )
    end
  end
end
