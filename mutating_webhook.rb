require 'base64'
require 'json'
require 'sinatra'

WEBHOOK_FQDN = ENV.fetch('WEBHOOK_FQDN', 'vault-mutating-webhook.vaultproject.io')

get '/health' do
  'OK'
end

def exclude?(admission_review)
  annotations = admission_review['request']['object']['metadata']['annotations']
  # Return false if no annotations
  return false unless annotations.is_a? Hash
  # Return true if the exclude annotation is set
  return true if annotations.key?("#{WEBHOOK_FQDN}/exclude")

  # Otherwise return false
  false
end

post '/vault-agent-sidecar', provides: 'application/json' do
  admission_review = JSON.parse(request.body.read)
  uid = admission_review['request']['uid']
  logger.info { "Processing request uid '#{uid}'" }
  resp = {
    response: {
      uid: uid,
      allowed: true # Allow all requests, this could be extended to reject certain requests
    }
  }

  # This annotation excludes pods from getting the patch
  if exclude?(admission_review)
    logger.info { "Excluding request uid '#{uid}' due to annotation" }
    return resp.to_json
  end

  # Set the patches
  spec = admission_review['request']['object']['spec']
  patches = []
  # add a volume for the token file
  volume = {
    'name' => 'vault',
    'emptyDir' => {
      'medium' => 'Memory'
    }
  }
  patches << if spec['volumes']
               { op: 'add', path: '/spec/volumes/-', value: volume }
             else
               { op: 'add', path: '/spec/volumes', value: [volume] }
             end
  # patch the vault token volumeMount onto each container
  vault_volume_mount = { name: volume['name'], mountPath: '/mnt/vault' }
  spec['containers'].each_with_index do |_cont, idx|
    patches << { op: 'add', path: "/spec/containers/#{idx}/volumeMounts/-", value: vault_volume_mount }
  end

  # find the service account token volume mount on another container to replicate
  # onto the vault agent container
  all_volume_mounts = []
  spec['containers'].each do |c|
    all_volume_mounts += c['volumeMounts'] if c['volumeMounts']
  end
  sa_vol_mount = all_volume_mounts.select { |vm| vm['name'].match(/#{spec['serviceAccountName']}-token-\w+/) }.first

  # TODO: pull role from annotation
  vault_agent_config = %(auto_auth {
    method "kubernetes" {
      mount_path = "auth/kubernetes"
      config = {
        role = "app"
      }
    }

    sink "file" {
      config = {
        path = "/mnt/vault/token"
      }
    }
  })

  # add the vault agent container
  patches << { op: 'add', path: '/spec/containers/-', value: {
    name: 'vault-agent',
    image: 'vault',
    command: ['/bin/sh', '-c'],
    args: [%(
      echo -e '#{vault_agent_config}' > /vault-agent-config.hcl && vault agent -config=/vault-agent-config.hcl
    )],

    # TODO: pull vault_addr from annotation
    env: [{ name: 'VAULT_ADDR', value: 'http://vault.default.svc' }],
    volumeMounts: [{ name: volume['name'], mountPath: '/mnt/vault' }, sa_vol_mount]
  } }

  logger.info { "Patches: #{patches}" }
  resp[:response][:patch] = Base64.encode64(patches.to_json)
  resp[:response][:patchType] = 'JSONPatch'

  resp.to_json
end
