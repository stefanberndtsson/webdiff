module WebDiff
  module Site
    class ETA
      require 'pp'
      require 'yaml'
      require 'nokogiri'
      require 'open-uri'
      require 'fileutils'
      BASEURL="http://auktion.eta.chalmers.se/"
      URL="#{BASEURL}index.php?act=list"

      class Item
        attr_reader :id, :thumbnail, :image, :name, :status, :created_at, :updated_at, :previous_data

        def initialize(id, thumbnail, image, name, status, timestamp)
          @id = id
          @thumbnail = thumbnail
          @image = image
          @name = name
          @status = status
          @created_at = timestamp
          @updated_at = timestamp
          @previous_data = []
        end

        def to_hash
          {
            id: @id,
            thumbnail: @thumbnail,
            image: @image,
            name: @name,
            status: @status,
            created_at: @created_at,
            updated_at: @updated_at
          }
        end

        def update(thumbnail, image, name, status, timestamp)
          return if thumbnail == @thumbnail && image == @image && name == @name && status == @status

          @previous_data << to_hash
          @thumbnail = thumbnail
          @image = image
          @name = name
          @status = status
          @updated_at = timestamp
        end

        def state_change
          state = {}
          return state if @previous_data.empty?
          prev = @previous_data.last
          state[:image] = state_change_element(prev, to_hash, :image)
          state[:thumbnail] = state_change_element(prev, to_hash, :thumbnail)
          state[:name] = state_change_element(prev, to_hash, :name)
          state[:status] = state_change_element(prev, to_hash, :status)
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
            "  <span class='id'><strong>#{@id}</strong></span>"+
            "  <span class='image'><a href='#{@image}'><img src='#{@thumbnail}'/></a></span>"+
            "  <span class='name'>#{@name}</span>"+
            "  <span class='status'><em>[#{@status}]</em></span>"+
            "</div>"
        end

        def mailer_template_update(state)
          rows = []
          rows << "<div>"
          rows << "<span class='id'><strong>#{@id}</strong></span>"
          rows << "<span class='image'><a href='#{@image}'><img src='#{@thumbnail}'/></a></span>"
          if state[:name]
            rows << "<span class='name' style='background-color: #f99'><del>#{state[:name][:old]}</del></span>"
          end
          rows << "<span class='name'>#{@name}</span>"
          if state[:status]
            rows << "  <span class='status' style='background-color: #f99'><del><em>[#{state[:status][:old]}]</em></del></span>"
          end
          rows << "  <span class='status'><em>[#{@status}]</em></span>"
          rows << "</div>"
          rows.join("\n")
        end

        def mailer_template
          state = state_change
          state.keys.empty? ? mailer_template_new : mailer_template_update(state)
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
        doc.search('#main table tr').each do |trow|
          next if trow.search('td.list_ls_iditm').empty?

          id = trow.search('td.list_ls_iditm').text
          thumbnail = BASEURL+trow.search('td.list_ls_picitm img').attr('src').value
          image = BASEURL+trow.search('td.list_ls_picitm a').attr('href').value
          name = trow.search('td.list_ls_nameitm').text
          status = trow.search('td.list_ls_statsitm').text
          create_or_update_item(id, thumbnail, image, name, status)
        end
      end

      def report
        return if @new_or_updated_items.size == 0
        WebDiff::Mailer.new("ETA: #{@new_or_updated_items.size} new or updated item(s)", @new_or_updated_items)
      end

      def create_or_update_item(id, thumbnail, image, name, status)
        if @items[id]
          if @items[id].update(thumbnail, image, name, status, @timestamp)
            @new_or_updated_items << @items[id]
          end
        else
          @items[id] = Item.new(id, thumbnail, image, name, status, @timestamp)
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

