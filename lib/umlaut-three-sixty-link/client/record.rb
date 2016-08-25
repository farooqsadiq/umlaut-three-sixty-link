# Copyright (c) 2016, Regents of the University of Michigan.
# All rights reserved. See LICENSE.txt for details.

module UmlautThreeSixtyLink
  module Client
    class Record
      ATTRIBUTES = %w(creator source isbn issn other
                      issue volume spage epage title
                      eisbn eissn date
      ).freeze

      SEPARATOR = ', '.freeze

      attr_accessor *ATTRIBUTES, :links

      def initialize
        @other = []
        @links = []
      end

      def to_h
        h = {}
        ATTRIBUTES.each do |a|
          h[a] = send(a)
        end
        h
      end

      def link?
        links.inject(false) { |val, link| val || !link.urls.empty? }
      end

      def add_disambiguation(request, base)
        request.add_service_response(
          base.merge(
            notes: links.map { |link| link.urls.notes }.compact.uniq,
            metadata: to_h,
            url: 'URL PLACEHOLDER'
          )
        )
      end

      def add_fulltext(request, base)
        links.each do |link|
          request.add_service_response(
            base.merge(
              service_type_value: 'fulltext_bundle',
              headings: {
                article: display_text(:article),
                journal: display_text(:journal),
                source: link.source,
                provider: link.holdings.provider_name,
                database: link.holdings.database_name
              },
              notes: link.urls.notes,
              structured_notes: link.urls.structured_notes,
              urls: link.urls,
              available: {
                start: link.holdings.start_date,
                end: link.holdings.end_date
              }
            )
          )
          Urls::LEVELS.keys.each do |level|
            request.add_service_response(
              base.merge(
                display_text: display_text(level),
                notes: link.notes,
                url: link.urls.send(level)
              )
            ) if link.urls.send(level)
          end
        end
      end

      def display_text(level = :article)
        case level
        when :article
          title || source
        when :issue
          "#{title || source} (#{volume}): #{issue}"
        when :volume
          "#{title || source} (#{volume})"
        when :journal
          source
        when :source
          source
        end
      end

      def set(name, value)
        if attribute?(name)
          send("#{name}=", value)
        else
          @other << "#{name} => #{value}"
        end
      end

      def self.from_parsed_xml(parsed_xml)
        record = Record.new
        attributes(parsed_xml).each do |attribute|
          record.set(attribute.name, attribute.inner_text)
        end

        link_groups(parsed_xml).each do |link_group|
          record.links << link_group
        end
        record
      end

      def attribute?(name)
        self.class.attribute?(name)
      end

      def self.attributes(input)
        input.xpath('./ssopenurl:citation/*')
      end

      def self.link_groups(input)
        links = []
        input.xpath('./ssopenurl:linkGroups/ssopenurl:linkGroup').each do |link_group|
          links << LinkGroup.from_parsed_xml(link_group)
        end
        UmlautThreeSixtyLink.sort_link_groups(links)
      end

      def self.attribute?(attribute)
        ATTRIBUTES.include?(attribute)
      end
    end
  end
end
