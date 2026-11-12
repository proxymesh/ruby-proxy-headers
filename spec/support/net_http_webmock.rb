# frozen_string_literal: true

# WebMock replaces Net::HTTP with a subclass created before patch!.
# Specs prepend the saved original class so WebMock.disable! still has the
# CONNECT wrapper. The library itself only patches Net::HTTP.
module RubyProxyHeaders
  module NetHTTP
    class << self
      alias patch_net_http! patch!

      def patch!
        original = ::WebMock::HttpLibAdapters::NetHttpAdapter::OriginalNetHTTP
        original.prepend(Extension) unless original.ancestors.include?(Extension)
        patch_net_http!
      end
    end
  end
end
