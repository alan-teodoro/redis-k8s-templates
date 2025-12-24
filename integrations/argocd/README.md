# poc-argocd

## Adding Redis Databases via ApplicationSet

To deploy a new `RedisEnterpriseDatabase`:

1. Create a new overlay directory under `charts/redis-database/overlays/<name>` and add a `values.yaml` file.
   Set the secret reference using `databaseSecretName: <name>-secret`.
2. Update `argocd/redis-db-appset.yaml` by adding a new element under
   `generators.list.elements` with the database `name` and path to the overlay's
   `values.yaml`.
3. Apply the modified ApplicationSet manifest to Argo CD.

The referenced secret must exist. Use the `redis-secret-appset` to create it per database.

## Managing Database Credentials

Secrets are also managed through an ApplicationSet. Each secret is templated as
an `ExternalSecret` that pulls the credentials from Vault. To add credentials
for a new database:

1. Edit `argocd/redis-secret-appset.yaml` and append the database name under
   `generators.list.elements`.
2. Apply the updated ApplicationSet manifest to Argo CD.

The ApplicationSet will create one secret per database named `<db>-secret`
which references the Vault path configured in the chart values.

## Deploying Vault

Deploy HashiCorp Vault using the provided Argo CD Application:

```shell
kubectl apply -f argocd/vault-app.yaml
```

This installs the official Helm chart into the `vault` namespace in development
mode with TLS disabled.

Create a `ClusterSecretStore` named `vault` so the charts can read secrets from
Vault:

```shell
kubectl apply -f argocd/vault-secret-store.yaml
```

Create the Vault token secret that the `ClusterSecretStore` references:

```shell
kubectl -n redis create secret generic vault-token --from-literal=token=<VAULT_TOKEN>
```

Deploy the External Secrets Operator so `ExternalSecret` resources are reconciled:

```shell
kubectl apply -f argocd/external-secrets-operator.yaml
```

## Using Vault for Database Secrets

Store the Redis credentials under `secret/data/redis-creds` in Vault with keys
`username` and `password`. The `redis-secret-appset` creates an `ExternalSecret`
for each database that reads these values via a `ClusterSecretStore` named
`vault`.

Example Vault policy:

```hcl
path "secret/data/redis-creds" {
  capabilities = ["read"]
}
```

Grant this policy to the service account used by the External Secrets Operator
in the `redis` namespace. To add a new database secret, update
`argocd/redis-secret-appset.yaml` as described above and apply the manifest.
