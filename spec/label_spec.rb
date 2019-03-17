require_relative 'spec_helper'

describe Sinatra::Application do
  def app
    Sinatra::Application
  end

  it 'returns a label patch' do
    json = test_admission_review.to_json
    post('/fun-label', json, 'CONTENT_TYPE' => 'application/json')
    expect(last_response).to be_ok
    resp = JSON.parse(last_response.body)
    expect(resp['response']).to include(
      'uid' => test_uid,
      'allowed' => true,
      'patchType' => 'JSONPatch'
    )
    patch = JSON.parse(Base64.decode64(resp['response']['patch']))
    expect(patch).to eq(
      [{ 'op' => 'add', 'path' => '/metadata/labels', 'value' => { 'fun' => 'hello' } }]
    )
  end
end
