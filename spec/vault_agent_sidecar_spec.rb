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
    patches = JSON.parse(Base64.decode64(resp['response']['patch']))
    expect(patches).to eq(
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
          ['echo "$VAULT_AGENT_CONFIG_B64" | base64 -d > /vault-agent-config.hcl && vault agent -config=/vault-agent-config.hcl'],
          'command' => ['/bin/sh', '-c'],
          'env' =>
            [{ 'name' => 'VAULT_ADDR', 'value' => 'https://vault.example.com' },
             { 'name' => 'VAULT_AGENT_CONFIG_B64',
               'value' =>
               "ZXhpdF9hZnRlcl9hdXRoID0gZmFsc2UKCmF1dG9fYXV0aCB7CiAgbWV0aG9k\nICJrdWJlcm5ldGVzIiB7CiAgICBtb3VudF9wYXRoID0gImF1dGgva3ViZXJu\nZXRlcyIKICAgIGNvbmZpZyA9IHsKICAgICAgcm9sZSA9ICJteWFwcCIKICAg\nIH0KICB9CgogIHNpbmsgImZpbGUiIHsKICAgIGNvbmZpZyA9IHsKICAgICAg\ncGF0aCA9ICIvbW50L3ZhdWx0L3Rva2VuIgogICAgfQogIH0KfQ==\n" }],
          'image' => 'vault',
          'name' => 'vault-agent',
          'volumeMounts' =>
          [{ 'mountPath' => '/mnt/vault', 'name' => 'vault' },
           { 'mountPath' => '/var/run/secrets/kubernetes.io/serviceaccount',
             'name' => 'default-token-vks5v',
             'readOnly' => true }] } }]
    )
    vault_agent_config = patches.last['value']['env'].last['value']
    expect(Base64.decode64(vault_agent_config)).to eq('exit_after_auth = false

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "myapp"
    }
  }

  sink "file" {
    config = {
      path = "/mnt/vault/token"
    }
  }
}')
  end
end
