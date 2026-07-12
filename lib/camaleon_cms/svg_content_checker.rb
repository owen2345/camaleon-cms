# frozen_string_literal: true

module CamaleonCms
  module SvgContentChecker
    BANNED_TAGS = %w[
      script foreignObject iframe object embed animate set handler
    ].freeze

    module_function

    def unsafe?(svg_content)
      return true if svg_content.nil? || svg_content.empty? # rubocop:disable Rails/Blank

      doc = Nokogiri::XML(svg_content, &:nonet)
      return true unless doc.root

      banned_tags_query = BANNED_TAGS.map { |tag| "local-name() = '#{tag}'" }.join(' or ')
      return true if doc.xpath("//*[#{banned_tags_query}]").any?

      return true if doc.xpath('//@*[starts-with(local-name(), "on")]').any?

      return true if doc.xpath('//@*[local-name() = "href"]').any? do |attr|
        attr.value.strip.match?(/\A(javascript|data|vbscript):/i)
      end

      serialized = doc.to_xml
      return true if serialized.match?(/<script[\s>]/i)
      return true if serialized.match?(/(javascript|data|vbscript):/i)

      false
    rescue Nokogiri::XML::SyntaxError
      true
    end
  end
end
