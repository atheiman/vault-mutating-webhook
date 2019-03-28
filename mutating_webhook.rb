require 'base64'
require 'json'
require 'sinatra'

ANNOTATION_DOMAIN = 'vaultproject.io'.freeze
VAULT_ADDR_ENV = { name: 'VAULT_ADDR', value: ENV.fetch('VAULT_ADDR') }.freeze

get '/health' do
  'OK'
end

def vault_k8s_auth_role(annotations)
  ann = "#{ANNOTATION_DOMAIN}/vault_k8s_auth_role"
  return annotations[ann] if annotations && annotations[ann]

  false
end

def vault_agent_exit_after_auth(annotations)
  ann = "#{ANNOTATION_DOMAIN}/vault_agent_exit_after_auth"
  if annotations && annotations[ann]
    annotations[ann]
  else
    # default to false
    false
  end
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

  annotations = admission_review['request']['object']['metadata']['annotations']

  # if the vault_k8s_auth_role annotation is not set, do not set any patch
  unless vault_k8s_auth_role(annotations)
    logger.info { "Excluding request uid '#{uid}' because annotation '#{ANNOTATION_DOMAIN}/vault_k8s_auth_role' not set" }
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
  # patch the each container
  vault_volume_mount = { name: volume['name'], mountPath: '/mnt/vault' }
  spec['containers'].each_with_index do |cont, idx|
    # add the vault token volumeMount
    patches << { op: 'add', path: "/spec/containers/#{idx}/volumeMounts/-", value: vault_volume_mount }

    # add the VAULT_ADDR env var
    if cont['env'].is_a? Array
      patches << { op: 'add', path: "/spec/containers/#{idx}/env/-", value: VAULT_ADDR_ENV }
    else
      patches << { op: 'add', path: "/spec/containers/#{idx}/env", value: [VAULT_ADDR_ENV] }
    end
  end

  # find the service account token volume mount on another container to replicate
  # onto the vault agent container
  all_volume_mounts = []
  spec['containers'].each do |c|
    all_volume_mounts += c['volumeMounts'] if c['volumeMounts']
  end
  sa_vol_mount = all_volume_mounts.select { |vm| vm['name'].match(/#{spec['serviceAccountName']}-token-\w+/) }.first

  vault_agent_config = %(
exit_after_auth = #{vault_agent_exit_after_auth(annotations)}

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "#{vault_k8s_auth_role(annotations)}"
    }
  }

  sink "file" {
    config = {
      path = "/mnt/vault/token"
    }
  }
}
).strip

  # add the vault agent container
  patches << { op: 'add', path: '/spec/containers/-', value: {
    name: 'vault-agent',
    image: 'vault',
    command: ['/bin/sh', '-c'],
    args: [%(
      echo "$VAULT_AGENT_CONFIG_B64" | base64 -d > /vault-agent-config.hcl && vault agent -config=/vault-agent-config.hcl
    ).strip],

    env: [
      VAULT_ADDR_ENV,
      { name: 'VAULT_AGENT_CONFIG_B64', value: Base64.encode64(vault_agent_config) }
    ],
    volumeMounts: [{ name: volume['name'], mountPath: '/mnt/vault' }, sa_vol_mount]
  } }

  logger.info { "Patches: #{patches}" }
  resp[:response][:patch] = Base64.encode64(patches.to_json)
  resp[:response][:patchType] = 'JSONPatch'

  resp.to_json
end
