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

```
docker build -t atheiman/vault-mutating-webhook .
docker run --rm -p 3000:3000 atheiman/vault-mutating-webhook
docker push atheiman/vault-mutating-webhook
```
