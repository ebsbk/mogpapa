libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'paperclip/storage/mogilefs_storage'

module Mogpapa
end
