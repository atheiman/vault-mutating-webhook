# Vault Mutating Webhook Admission Controller

This is a Kubernetes [Admission Webhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#admission-webhooks) that can modify pods to interact with Vault. The basic use case is to attach a sidecar container running [`vault agent`](https://www.vaultproject.io/docs/agent/) and syncing the Vault token to be available to the other containers in the pod via a `volumeMount`.

Pods can customize their interaction with the webhook via annotations, see below.

A helm chart is available to deploy this project to your cluster, see below.

## Pod Annotations to Customize Interaction with Webhook

| Annotation | Description | Examples |
| ---------- | ----------- | -------- |
| `vaultproject.io/vault_k8s_auth_role` | **Required**. Vault Kubernetes auth method role name for the pod to authenticate as. If this is not set, the Pod will not be modified by the admission webhook. | `myapp` |
| `vaultproject.io/vault_agent_exit_after_auth` | Optional.

## Deploy with Helm

Helm chart available in the [`helm/`](./helm/) directory. See the `values.yaml` there for available configuration options. The basic deployment will look something like:

```shell
# Get the CA bundle data from the cluster
ca_bundle="$(kubectl get configmap -n kube-system extension-apiserver-authentication \
  -o=jsonpath='{.data.client-ca-file}' | base64 | tr -d '\n')"

# Install the admission webhook chart
helm upgrade vault-mutating-webhook ./helm/ --install --recreate-pods \
  --set webhook.fqdn=vault-mutating-webhook.example.com \
  --set webhook.vault_addr=https://vault.example.com \
  --set "ssl.caBundle=$ca_bundle"
```

## Contributing

1. Create an issue
1. Create a fork and branch for your change
1. Make your change, including tests
1. Create a merge request, ensure the pipeline passes

## Tests

### Unit

Unit tests are written with rspec and rack-test ([See the Sinatra docs](http://sinatrarb.com/testing.html)). They are meant to verify the Sinatra app responds with appropriate JSON when it receives requests like kube-apiserver would send it. Execute the tests with `bundle exec rspec`.

If you run into an rspec failure that dumps out abbreviated Sinatra response HTML, you can save the HTML to a file and view in your browser. The rendered HTML will have info about the failure from Sinatra:

```ruby
it 'returns vault agent sidecar patches' do
  json = test_admission_review.to_json
  post('/vault-agent-sidecar', json, 'CONTENT_TYPE' => 'application/json')
  File.open('./resp_body.html', 'w') { |file| file.write(last_response.body) }
  # ...
```

### Integration

Integration tests can be run with [`helm test`](https://github.com/helm/helm/blob/master/docs/chart_tests.md). They are meant to verify that a deployed Pod has a valid Vault token mounted into it's container(s). The test manifests are located in [`helm/templates/tests/`](./helm/templates/test/).

```shell
# initialize helm / tiller
kubectl create sa tiller -n kube-system
kubectl create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account=tiller

# Create and use namespace for mutating admission webhook
kubectl create ns vault-mutating-webhook
kubectl config set-context $(kubectl config current-context) --namespace=vault-mutating-webhook
# Create cert and key secret
title=vault-mutating-webhook ./gen-cert.sh
# Get the cluster caBundle for the helm chart
ca_bundle="$(kubectl get configmap -n kube-system extension-apiserver-authentication \
  -o=jsonpath='{.data.client-ca-file}' | base64 | tr -d '\n')"

# Install / upgrade the helm chart for testing
helm upgrade vault-mutating-webhook ./helm/ --install --recreate-pods \
  --set create_test_resources=true \
  --set "ssl.caBundle=$ca_bundle"

# Test the helm chart installation
helm test vault-mutating-webhook --parallel --cleanup

# Cleanup the extra test resources
kubectl delete ns vault-mutating-webhook-test
kubectl delete clusterrolebinding vault-auth-delegator
```

In the future, these integration tests should be executed in a pipeline using something like [`kind`](https://github.com/kubernetes-sigs/kind) or [`microk8s`](https://github.com/ubuntu/microk8s).

## Docker Image

Installs [Phusion Passenger Standalone](https://www.phusionpassenger.com/library/config/standalone/reference/), RubyGems dependencies, and runs the Sinatra app in Passenger.

```shell
# Docker build, run, and push
docker build -t atheiman/vault-mutating-webhook .
docker run --rm -p 3000:3000 atheiman/vault-mutating-webhook
docker push atheiman/vault-mutating-webhook
```
