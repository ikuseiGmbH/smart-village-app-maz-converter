# frozen_string_literal: true

class ContentBlockParser
  def self.perform(data, record)
    content_blocks = []
    content_blocks << parse_single_content_block(data, record)
  end

  private

    def self.parse_single_content_block(data, record)
      {
        title: data.dig("title", "value"),
        intro: data.dig("intro", "value"),
        body: data.dig("body", "value"),
        media_contents: media_contents(data, record)
      }
    end

    def self.media_contents(data, record)
      media = []
      media << article_image(data, record)
      media << related_objects_images(data, record)
      media.compact.flatten.delete_if(&:blank?)
    end

    #
    # Bilder kommen bei der Maz zum einen aus den keys die mit article images beginnen.
    # diese Methode parsed dieses article image in ein media content object
    #
    # @param [HASH/JSON] data JSON Data
    #
    # @return [<HASH/JSON>] JSON Objekt welches mit dem media_content model der main_app_server app
    #  korrespondiert.
    #
    def self.article_image(data, record)
      origin_image_url = data.dig("article_image", "value", "url")
      begin
        uri = URI.open(origin_image_url)
        file = open(uri)
        record.image.attach(io: file, filename: File.basename(uri.path))
      rescue
        return {}
      end

      {
        content_type: "image",
        copyright: data.dig("article_image_photographer", "value"),
        caption_text: data.dig("article_image_caption", "value"),
        width: data.dig("article_image", "value", "width").to_i,
        height: data.dig("article_image", "value", "height").to_i,
        source_url: {
          url: record.image.service_url.sub(/\?.*/, "")
        }
      }
    end

    #
    # Bilder kommen bei der Maz zum Anderen aus dem images array der sich
    # im related_objects array befindet.
    # diese Methode parsed diese images in je ein media content object.
    #
    # @param [JSON] data JSON Hash
    #
    # @return [<HASH/JSON>] JSON Objekt welches mit dem media_content model der main_app_server app
    #  korrespondiert.
    #
    def self.related_objects_images(data, record)
      return nil unless data["related_objects"].present?
      return nil unless data["related_objects"].first.present?
      return nil unless data["related_objects"].first["images"].present?

      data["related_objects"].first["images"].map do |image|
        {
          content_type: "image",
          caption_text: image.dig("caption", "value"),
          copyright: image.dig("photographer", "value"),
          width: image.dig("image", "value", "width"),
          height: image.dig("image", "value", "height")
        }.merge(parse_image_url(image, record))
      end.delete_if(&:blank?).compact
    end

    def self.parse_image_url(image, record)
      origin_image_url = image.dig("image", "value", "url")
      return {} if origin_image_url.blank?

      origin_image_url = "http://www.maz-online.de#{origin_image_url}" unless origin_image_url.starts_with?("http")
      begin
        uri = URI.open(origin_image_url)
        file = open(uri)
        record.related_images.attach(io: file, filename: File.basename(uri.path))
      rescue
        return {}
      end

      {
        source_url: {
          url: record.related_images.last.service_url.sub(/\?.*/, "")
        }
      }
    end
end
