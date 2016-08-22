module UmlautThreeSixtyLink
  module Client
    class Record
      ATTRIBUTES = %w(creator source isbn issn other
                      issue volume spage epage title).freeze

      SEPARATOR = ', '.freeze

      attr_accessor :creator, :source, :isbn,
        :issn, :other, :issue, :volume,
        :spage, :epage, :links, :title

      def initialize
        @other = []
        @links = []
      end

      def add_service(request, base)

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
                end: link.holdings.end_date,
              }
            )
          )
          request.add_service_response(
            base.merge(
              display_text: display_text(:article),
              notes: 'Article-level: ' + link.notes,
              url: link.urls.article
            )
          ) if link.urls.article
          request.add_service_response(
            base.merge(
              display_text: display_text(:volume),
              notes: 'Volume-level: ' + link.notes,
              url: link.urls.volume
            )
          ) if link.urls.volume
          request.add_service_response(
            base.merge(
              display_text: display_text(:issue),
              notes: 'Issue-level: ' + link.notes,
              url: link.urls.issue
            )
          ) if link.urls.issue
          request.add_service_response(
            base.merge(
              display_text: display_text(:journal),
              notes: 'Journal-level: ' + link.notes,
              url: link.urls.journal
            )
          ) if link.urls.journal
          request.add_service_response(
            base.merge(
              display_text: link.source,
              notes: 'Database-level: ' + link.notes,
              url: link.urls.source
            )
          ) if link.urls.source
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
