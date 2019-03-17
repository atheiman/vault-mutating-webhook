# Vault Mutating Webhook Admission Controller

This is a Kubernetes [Admission Webhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#admission-webhooks) that can modify pods to interact with Vault. The basic use case is to perform attach a sidecar container running [`vault agent`](https://www.vaultproject.io/docs/agent/) and syncing the Vault token to be available to the other containers in the pod via a `volumeMount`.

Pods can customize their interaction with the webhook via annotations, see below.

A helm chart is available to deploy this project to your cluster, see below.

## Pod Annotations to Customize Interaction with Webhook

| Annotation | Description | Example |
| ---------- | ----------- | ------- |
| `vaultproject.io/vault_addr` | Address of Vault Server (must be accessible from the pod) | `http://vault.vault.svc` |

## Deploy with Helm

Helm chart available in the [`helm/`](./helm/) directory.

## Contributing

1. Create an issue
1. Create a fork and branch for your change
1. Make your change, including tests
1. Create a merge request, ensure the pipeline passes

## Tests

Unit tests are written with rspec and rack-test ([See the Sinatra docs](http://sinatrarb.com/testing.html)). Execute them with `bundle exec rspec`.

In the future, there should be integration tests with Kubernetes using something like [`kind`](https://github.com/kubernetes-sigs/kind) or [`microk8s`](https://github.com/ubuntu/microk8s).

## Notes

```shell
# Docker build, run, and push
docker build -t atheiman/vault-mutating-webhook .
docker run --rm -p 3000:3000 atheiman/vault-mutating-webhook
docker push atheiman/vault-mutating-webhook

# Create and use namespace for mutating admission webhook
kubectl create ns vault-mutating-webhook
kubectl config set-context $(kubectl config current-context) --namespace=vault-mutating-webhook
# Create cert and key secret
title=vault-mutating-webhook ./gen-cert.sh
# Deploy the helm chart with the cluster caBundle
ca_bundle="$(kubectl get configmap -n kube-system extension-apiserver-authentication \
  -o=jsonpath='{.data.client-ca-file}' | base64 | tr -d '\n')"

helm init
helm install ./helm/ --name vault-mutating-webhook \
  --set webhook.fqdn=vault-mutating-webhook.example.com \
  --set "ssl.caBundle=$ca_bundle"
helm upgrade vault-mutating-webhook ./helm/ --install \
  --set webhook.fqdn=vault-mutating-webhook.example.com \
  --set "ssl.caBundle=$ca_bundle"

# Run Vault in the default namespace
kubectl apply -n default -f test/vault.yaml

kubectl apply -f test/test-pod.yaml
kubectl get po -n webhook-test --show-labels

rspec failure? dump response to an html file:
File.open('./resp_body.html', 'w') { |file| file.write(last_response.body) }
```
