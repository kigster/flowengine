# frozen_string_literal: true

module FlowEngine
  module LLM
    # Scans introduction text for sensitive data patterns (SSN, ITIN, EIN,
    # bank account numbers) and raises {SensitiveDataError} if any are found.
    # This prevents sensitive information from being sent to an LLM.
    module SensitiveDataFilter
      # SSN: 3 digits, dash, 2 digits, dash, 4 digits (e.g. 123-45-6789)
      SSN_PATTERN = /\b\d{3}-\d{2}-\d{4}\b/

      # ITIN: 9XX-XX-XXXX where first digit is 9
      ITIN_PATTERN = /\b9\d{2}-\d{2}-\d{4}\b/

      # EIN: 2 digits, dash, 7 digits (e.g. 12-3456789)
      EIN_PATTERN = /\b\d{2}-\d{7}\b/

      # Nine consecutive digits (SSN/ITIN without dashes)
      NINE_DIGITS_PATTERN = /\b\d{9}\b/

      PATTERNS = {
        "SSN" => SSN_PATTERN,
        "ITIN" => ITIN_PATTERN,
        "EIN" => EIN_PATTERN,
        "SSN/ITIN (no dashes)" => NINE_DIGITS_PATTERN
      }.freeze

      # Checks text for sensitive data patterns.
      #
      # @param text [String] introduction text to scan
      # @raise [SensitiveDataError] if any sensitive patterns are detected
      def self.check!(text)
        detected = PATTERNS.each_with_object([]) do |(label, pattern), found|
          found << label if text.match?(pattern)
        end

        return if detected.empty?

        raise SensitiveDataError,
              "Introduction contains sensitive information (#{detected.join(", ")}). " \
              "Please remove all SSN, ITIN, EIN, and account numbers before proceeding."
      end
    end
  end
end
