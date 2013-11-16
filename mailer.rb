module WebDiff
  class Mailer
    require 'pp'
    require 'yaml'
    require 'mail'
    CONFIG_FILE=ENV['HOME']+"/.webdiff/config"

    def initialize(subject, items)
      config = read_config

      message_subject = subject
      message_body = []
      items.each do |item|
        message_body << item.mailer_template
      end

      Mail.defaults do
        delivery_method :smtp, address: config["smtp"], port: 25, enable_starttls_auto: false
      end

      receiver = config["receiver"]
      if !receiver.is_a?(Array)
        receiver = [receiver]
      end

      receiver.each do |recv|
        mail = Mail.deliver do
          to recv
          from config["sender"]
          subject message_subject

          html_part do
            content_type 'text/html; charset=UTF-8'
            body message_body.join("\n")
          end
        end
      end
    end

    def read_config
      YAML.load(File.read(CONFIG_FILE))
    end
  end
end
