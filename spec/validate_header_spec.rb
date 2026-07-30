# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RubyProxyHeaders.validate_header!' do
  it 'accepts clean header name and value' do
    expect { RubyProxyHeaders.validate_header!('X-Custom', 'safe-value') }.not_to raise_error
  end

  it 'rejects header name containing CR' do
    expect { RubyProxyHeaders.validate_header!("Bad\rName", 'value') }
      .to raise_error(ArgumentError, /header name.*invalid/)
  end

  it 'rejects header name containing LF' do
    expect { RubyProxyHeaders.validate_header!("Bad\nName", 'value') }
      .to raise_error(ArgumentError, /header name.*invalid/)
  end

  it 'rejects header name containing NUL' do
    expect { RubyProxyHeaders.validate_header!("Bad\0Name", 'value') }
      .to raise_error(ArgumentError, /header name.*invalid/)
  end

  it 'rejects header value containing CRLF' do
    expect { RubyProxyHeaders.validate_header!('X-Good', "value\r\nInjected: evil") }
      .to raise_error(ArgumentError, /header value.*invalid/)
  end

  it 'rejects header value containing bare LF' do
    expect { RubyProxyHeaders.validate_header!('X-Good', "value\nInjected: evil") }
      .to raise_error(ArgumentError, /header value.*invalid/)
  end

  it 'rejects header value containing bare CR' do
    expect { RubyProxyHeaders.validate_header!('X-Good', "value\rInjected: evil") }
      .to raise_error(ArgumentError, /header value.*invalid/)
  end

  it 'rejects header value containing NUL' do
    expect { RubyProxyHeaders.validate_header!('X-Good', "value\0evil") }
      .to raise_error(ArgumentError, /header value.*invalid/)
  end

  it 'converts non-string name and value via to_s' do
    expect { RubyProxyHeaders.validate_header!(:'X-Symbol', 42) }.not_to raise_error
  end
end
