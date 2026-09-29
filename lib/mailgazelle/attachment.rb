# frozen_string_literal: true

require "base64"
require "mailgazelle/error"

module MailGazelle
  # A file attached to an email, encoded as the API expects.
  #
  # Use the named constructors so callers encode bytes only when they already
  # have base64 content.
  class Attachment
    CONTENT_TYPES = {
      "pdf" => "application/pdf",
      "png" => "image/png",
      "jpg" => "image/jpeg",
      "jpeg" => "image/jpeg",
      "gif" => "image/gif",
      "webp" => "image/webp",
      "svg" => "image/svg+xml",
      "txt" => "text/plain",
      "html" => "text/html",
      "htm" => "text/html",
      "csv" => "text/csv",
      "json" => "application/json",
      "xml" => "application/xml",
      "zip" => "application/zip",
      "ics" => "text/calendar",
      "doc" => "application/msword",
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "xls" => "application/vnd.ms-excel",
      "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }.freeze

    attr_reader :filename, :content, :content_type, :content_id, :decoded_size

    def self.from_path(path, filename: nil, content_type: nil, content_id: nil)
      contents = File.binread(path)
      from_contents(
        filename || File.basename(path),
        contents,
        content_type: content_type,
        content_id: content_id
      )
    rescue SystemCallError
      raise AttachmentError.new(
        "Unable to read attachment from \"#{path}\".",
        code: "attachment_invalid",
        http_status: 422
      )
    end

    def self.from_contents(filename, contents, content_type: nil, content_id: nil)
      binary = contents.to_s.b
      create(
        filename,
        Base64.strict_encode64(binary),
        binary.bytesize,
        content_type,
        content_id
      )
    end

    def self.from_base64(filename, encoded, content_type: nil, content_id: nil)
      decoded = strict_decode(encoded)
      if decoded.nil? || decoded.empty?
        raise AttachmentError.new(
          "Attachment \"#{filename}\" is not valid base64.",
          code: "attachment_invalid",
          http_status: 422
        )
      end

      create(filename, encoded, decoded.bytesize, content_type, content_id)
    end

    def to_h
      payload = { filename: filename, content: content }
      payload[:content_type] = content_type unless content_type.nil?
      payload[:content_id] = content_id unless content_id.nil?
      payload
    end

    def self.create(filename, encoded, decoded_size, content_type, content_id)
      name = filename.to_s.strip
      assert_basename(name)

      if decoded_size < 1
        raise AttachmentError.new(
          "Attachment \"#{name}\" is empty.",
          code: "attachment_invalid",
          http_status: 422
        )
      end

      type = content_type.to_s.strip
      type = guess_content_type(name) if type.empty?

      new(name, encoded, type, normalize_content_id(content_id), decoded_size)
    end
    private_class_method :create

    def self.assert_basename(filename)
      return unless filename.empty? || filename == "." || filename == ".." ||
                    filename.include?("/") || filename.include?("\\") ||
                    filename != File.basename(filename)

      raise AttachmentError.new(
        "Attachment filenames must be a basename without path segments.",
        code: "attachment_invalid",
        http_status: 422
      )
    end
    private_class_method :assert_basename

    def self.normalize_content_id(content_id)
      return nil if content_id.nil?

      value = content_id.to_s.strip
      return nil if value.empty?

      value = value[4..] if value.downcase.start_with?("cid:")
      value = value.gsub(/\A[ \t<>]+|[ \t<>]+\z/, "")
      if value.empty? || value.match?(/\s/)
        raise AttachmentError.new(
          "Attachment content ids must not be empty.",
          code: "attachment_invalid",
          http_status: 422
        )
      end

      value
    end
    private_class_method :normalize_content_id

    def self.guess_content_type(filename)
      extension = File.extname(filename).delete_prefix(".").downcase
      CONTENT_TYPES.fetch(extension, "application/octet-stream")
    end
    private_class_method :guess_content_type

    def self.strict_decode(encoded)
      Base64.strict_decode64(encoded.to_s)
    rescue ArgumentError
      nil
    end
    private_class_method :strict_decode

    def initialize(filename, content, content_type, content_id, decoded_size)
      @filename = filename
      @content = content
      @content_type = content_type
      @content_id = content_id
      @decoded_size = decoded_size
      freeze
    end
    private_class_method :new
  end
end
