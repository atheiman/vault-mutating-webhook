require 'base64'
require 'json'
require 'sinatra'

WEBHOOK_FQDN = ENV.fetch('WEBHOOK_FQDN', 'vault-mutating-webhook.vaultproject.io')

get '/health' do
  'OK'
end

def vault_addr(admission_review)
  annotations = admission_review['request']['object']['metadata']['annotations']
  if annotations && annotations["#{WEBHOOK_FQDN}/vault_addr"]
    return annotations["#{WEBHOOK_FQDN}/vault_addr"]
  end

  ENV.fetch('VAULT_ADDR')
end

def vault_k8s_auth_role(admission_review)
  annotations = admission_review['request']['object']['metadata']['annotations']
  if annotations && annotations["#{WEBHOOK_FQDN}/vault_k8s_auth_role"]
    return annotations["#{WEBHOOK_FQDN}/vault_k8s_auth_role"]
  end

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

  # if the vault_k8s_auth_role annotation is not set, do not set any patch
  unless vault_k8s_auth_role(admission_review)
    logger.info { "Excluding request uid '#{uid}' because annotation '#{WEBHOOK_FQDN}/vault_k8s_auth_role' not set" }
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

  vault_agent_config = %(auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "#{vault_k8s_auth_role(admission_review)}"
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
    env: [{ name: 'VAULT_ADDR', value: vault_addr(admission_review) }],
    volumeMounts: [{ name: volume['name'], mountPath: '/mnt/vault' }, sa_vol_mount]
  } }

  logger.info { "Patches: #{patches}" }
  resp[:response][:patch] = Base64.encode64(patches.to_json)
  resp[:response][:patchType] = 'JSONPatch'

  resp.to_json
end
