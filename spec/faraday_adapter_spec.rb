# frozen_string_literal: true

require 'spec_helper'
require 'ruby_proxy_headers/faraday'

RSpec.describe RubyProxyHeaders::FaradayAdapter::NetHttp do
  it 'uses public Faraday hooks instead of the private request method' do
    expect(described_class.instance_methods(false)).to include(:call, :net_http_connection)
    expect(described_class.private_instance_methods(false)).not_to include(:request_with_wrapped_block)
    expect(described_class.private_instance_methods).to include(:request_with_wrapped_block)
  end
end
