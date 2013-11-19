module WebDiff
  module Site
    SERIALIZE_DIR=ENV['HOME']+"/.webdiff/sites"
  end
end

$: << "."
require 'sites/eta.rb'
require 'sites/hackaday.rb'
