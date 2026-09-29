# frozen_string_literal: true

module MailGazelle
  # Message statuses documented by the send path.
  #
  # Additional statuses may appear on {EmailRecord#status} as raw strings when
  # the API adds new values.
  module EmailStatus
    QUEUED = "queued"
    REJECTED = "rejected"
    KNOWN = [QUEUED, REJECTED].freeze

    module_function

    def known?(value)
      KNOWN.include?(value)
    end
  end
end
