module WebDiff
  module Site
    class Hackaday
      require 'pp'
      require 'yaml'
      require 'nokogiri'
      require 'open-uri'
      require 'fileutils'
      BASEURL="http://hackaday.com"
      URL=BASEURL+"/"

      class Item
        attr_reader :id, :url, :title, :image, :content, :created_at, :updated_at, :previous_data

        def initialize(id, url, title, image, content, timestamp)
          @id = id
          @url = url
          @title = title
          @image = image
          @content = content
          @created_at = timestamp
          @updated_at = timestamp
          @previous_data = []
        end

        def to_hash
          {
            id: @id,
            url: @url,
            title: @title,
            image: @image,
            content: @content,
            created_at: @created_at,
            updated_at: @updated_at
          }
        end

        def update(url, title, image, content, timestamp)
          return if title == @title && image == @image && url == @url

          @previous_data << to_hash
          @url = url
          @title = title
          @image = image
          @content = content
          @updated_at = timestamp
        end

        def state_change
          state = {}
          return state if @previous_data.empty?
          prev = @previous_data.last
          state[:url] = state_change_element(prev, to_hash, :url)
          state[:title] = state_change_element(prev, to_hash, :title)
          state[:image] = state_change_element(prev, to_hash, :image)
          state[:content] = state_change_element(prev, to_hash, :content)
          state
        end

        def state_change_element(prev, current, element)
          if prev[element] != current[element]
            return {
              old: prev[element],
              new: current[element]
            }
          end
          return nil
        end

        def mailer_template_new
          ""+
            "<div>"+
            "  <h2 class='title'><a href='#{@url}'>#{@title}</h2>"+
            "  <div class='image'><img src='#{@image}'/></div>"+
            "  <div class='content'>#{@content}</div>"+
            "</div>"
        end

        def mailer_template
          mailer_template_new
        end
      end

      def initialize(filename = nil)
        @url = URL
        @data = nil
        @items = {}
        @new_or_updated_items = []
        @filename = filename || default_filename
        @timestamp = Time.now
        serialize_load
        fetch
        parse
        serialize_save
        report
      end

      def fetch
        open(@url) do |u|
          @data = u.read
        end
      end

      def parse
        doc = Nokogiri::HTML(@data)
        doc.search('.post').each do |post|
          next if post.search('.entry-content').empty?
          id = post.attr('class').split(/ /).map {|x| x[/^post-(\d+)$/] && $1.to_i }.compact.first
          title = post.search('h2').text
          url = post.search('h2 a').attr('href').value
          image = post.search('.entry-content p img')
          image = image.attr('src').value if image && !image.empty?
          content = post.search('.entry-content p').map do |blk|
            next if !blk.search('img').empty?
            next if !blk.search('.more-link').empty?
            blk.to_s
          end.compact.join("\n")
          create_or_update_item(id, url, title, image, content)
        end
      end

      def report
        return if @new_or_updated_items.size == 0
        WebDiff::Mailer.new("Hackaday: #{@new_or_updated_items.size} new or updated item(s)", @new_or_updated_items)
      end

      def create_or_update_item(id, url, title, image, content)
        if @items[id]
          if @items[id].update(url, title, image, content, @timestamp)
            @new_or_updated_items << @items[id]
          end
        else
          @items[id] = Item.new(id, url, title, image, content, @timestamp)
          @new_or_updated_items << @items[id]
        end
      end

      def serialize_load
        return if !File.exist?(@filename) || !File.file?(@filename)
        @items = YAML.load(File.read(@filename))
      end

      def serialize_save
        File.open(@filename, "w") do |f|
          f.write(@items.to_yaml)
        end
      end

      def default_filename
        FileUtils.mkdir_p(SERIALIZE_DIR)
        class_name = self.class.name.split("::").last
        SERIALIZE_DIR+"/"+class_name+".data"
      end
    end
  end
end

