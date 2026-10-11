## Hashicorp-kv-demo

Create the vault namespace:

```bash
kubectl create namespace vault
```

Add the HashiCorp Helm repository

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
```

Install HashiCorp Vault using Helm:

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --set="server.dev.enabled=true" \
  --set="ui.enabled=true" \
  --set="ui.serviceType=NodePort" \
  --namespace vault
```

Enter inside the vault pod to configure vault with kubernetes

```bash
kubectl exec -it vault-0 -n vault -- /bin/sh
```

Create a policy for reading secrets (read-policy.hcl):

```bash
cat <<EOF > /home/vault/read-policy.hcl
path "secret*" {
  capabilities = ["read"]
}
EOF
```

Write the policy to Vault:

```bash
vault policy write read-policy /home/vault/read-policy.hcl
```

Enable Kubernetes authentication in Vault:

```bash
vault auth enable kubernetes
```

Configure Vault to communicate with the Kubernetes API server

```bash
vault write auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://${KUBERNETES_PORT_443_TCP_ADDR}:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

Create a role(vault-role) that binds the above policy to a Kubernetes service account(vault-serviceaccount) in a specific namespace. This allows the service account to access secrets stored in Vault

```bash
vault write auth/kubernetes/role/vault-role \
   bound_service_account_names=vault-serviceaccount \
   bound_service_account_namespaces=vault \
   policies=read-policy \
   ttl=1h
```

Create secret using

```bash
vault kv put secret/clisecret token=secretcreatedbycli
vault kv put secret/uisecret username=admin password=supersecret
```

Verify if secret created or not

```bash
vault kv list secret
```
Create the service account and deploy to verify 

```bash
kubectl apply -f sa.yaml
kubectl apply -f deploy.yaml
```

Check data if secret is injected or not in the pod

```bash
kubectl exec -it <pod name> -n vault -- ls /vault/secrets/
kubectl exec -it <pod name> -n vault -- cat /vault/secrets/clisecret
kubectl exec -it <pod name> -n vault -- cat /vault/secrets/uisecret
```
