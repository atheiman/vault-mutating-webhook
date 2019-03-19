require_relative 'spec_helper'

describe Sinatra::Application do
  def app
    Sinatra::Application
  end

  it 'returns vault agent sidecar patches' do
    json = test_admission_review.to_json
    post('/vault-agent-sidecar', json, 'CONTENT_TYPE' => 'application/json')
    expect(last_response).to be_ok
    resp = JSON.parse(last_response.body)
    expect(resp['response']).to include(
      'uid' => test_uid,
      'allowed' => true,
      'patchType' => 'JSONPatch'
    )
    patch = JSON.parse(Base64.decode64(resp['response']['patch']))
    expect(patch).to eq(
      [{ 'op' => 'add',
         'path' => '/spec/volumes/-',
         'value' => { 'emptyDir' => { 'medium' => 'Memory' }, 'name' => 'vault' } },
       { 'op' => 'add',
         'path' => '/spec/containers/0/volumeMounts/-',
         'value' => { 'mountPath' => '/mnt/vault', 'name' => 'vault' } },
       { 'op' => 'add',
         'path' => '/spec/containers/0/env',
         'value' => [{ 'name' => 'VAULT_ADDR', 'value' => 'https://vault.example.com' }] },
       { 'op' => 'add', 'path' => '/spec/containers/-',
         'value' =>
        { 'args' =>
          ["\n      echo -e '\nexit_after_auth = \n\nauto_auth {\n  method \"kubernetes\" {\n    mount_path = \"auth/kubernetes\"\n    config = {\n      role = \"myapp\"\n    }\n  }\n\n  sink \"file\" {\n    config = {\n      path = \"/mnt/vault/token\"\n    }\n  }\n}\n' > /vault-agent-config.hcl && vault agent -config=/vault-agent-config.hcl\n    "],
          'command' => ['/bin/sh', '-c'],
          'env' => [{ 'name' => 'VAULT_ADDR', 'value' => 'https://vault.example.com' }],
          'image' => 'vault',
          'name' => 'vault-agent',
          'volumeMounts' =>
          [{ 'mountPath' => '/mnt/vault', 'name' => 'vault' },
           { 'mountPath' => '/var/run/secrets/kubernetes.io/serviceaccount',
             'name' => 'default-token-vks5v',
             'readOnly' => true }] } }]
    )
  end
end
