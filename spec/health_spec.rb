require_relative 'spec_helper'

describe app do
  it 'returns health check' do
    get '/health'
    expect(last_response).to be_ok
    expect(last_response.body).to eq('OK')
  end
end
