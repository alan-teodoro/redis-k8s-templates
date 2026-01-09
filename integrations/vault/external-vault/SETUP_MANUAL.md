# Setup Manual do Vault com HTTPS

> ⚠️ **NOTA:** Este arquivo é apenas para referência.
>
> Este projeto foca apenas na **integração Kubernetes ↔ Vault**.
> Para setup da infraestrutura do Vault (VM/Cloud), use seu projeto dedicado de infra.
>
> Este guia assume que você **já tem Vault rodando com HTTPS**.

## Informações da VM

- **IP:** `<VAULT_IP>`
- **SSH:** `ssh -i <key.pem> ubuntu@<VAULT_IP>`
- **Vault API:** `https://<VAULT_IP>:8200`
- **Vault UI:** `https://<VAULT_IP>:8200/ui`

**⚠️ Substitua `<VAULT_IP>` e `<key.pem>` pelos valores do seu ambiente**

## Opção 1: Script Automático

```bash
cd security/vault-integration
chmod +x setup-vault-complete.sh
./setup-vault-complete.sh
```

Isso vai:
1. Configurar HTTPS no Vault
2. Inicializar e fazer unseal
3. Habilitar KV v2
4. Copiar certificado CA
5. Salvar keys em `vault-keys.txt`

## Opção 2: Passo a Passo Manual

### 1. Acessar a VM

```bash
ssh -i <key.pem> ubuntu@<VAULT_IP>
```

### 2. Criar diretório para TLS

```bash
sudo mkdir -p /opt/vault/tls
cd /opt/vault/tls
```

### 3. Gerar certificado auto-assinado

```bash
sudo openssl genrsa -out vault-key.pem 2048

sudo openssl req -new -x509 -key vault-key.pem -out vault-cert.pem -days 365 \
  -subj "/C=US/ST=NY/L=NYC/O=Redis/CN=<VAULT_IP>"

sudo chmod 600 vault-key.pem
sudo chmod 644 vault-cert.pem
sudo chown -R vault:vault /opt/vault/tls
```

### 4. Configurar Vault para HTTPS

```bash
sudo tee /etc/vault.d/vault.hcl > /dev/null <<'EOF'
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/vault-cert.pem"
  tls_key_file  = "/opt/vault/tls/vault-key.pem"
}

api_addr = "https://<VAULT_IP>:8200"
cluster_addr = "https://<VAULT_IP>:8201"
ui = true
disable_mlock = true
EOF
```

**⚠️ IMPORTANTE:** Substitua `<VAULT_IP>` pelo IP público da sua VM do Vault antes de executar

### 5. Reiniciar Vault

```bash
sudo systemctl restart vault
sudo systemctl status vault
```

### 6. Testar HTTPS

```bash
curl -k https://127.0.0.1:8200/v1/sys/health
```

Deve retornar JSON com `"initialized": false, "sealed": true`

### 7. Configurar variáveis de ambiente

```bash
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_SKIP_VERIFY=true
```

### 8. Inicializar Vault

```bash
vault operator init -key-shares=5 -key-threshold=3
```

**⚠️ IMPORTANTE:** Salve as 5 unseal keys e o root token!

Exemplo de output:
```
Unseal Key 1: xxx
Unseal Key 2: xxx
Unseal Key 3: xxx
Unseal Key 4: xxx
Unseal Key 5: xxx

Initial Root Token: hvs.xxx
```

### 9. Fazer Unseal (3 vezes)

```bash
vault operator unseal <UNSEAL_KEY_1>
vault operator unseal <UNSEAL_KEY_2>
vault operator unseal <UNSEAL_KEY_3>
```

Após a 3ª key, deve mostrar `Sealed: false`

### 10. Fazer Login

```bash
vault login <ROOT_TOKEN>
```

### 11. Habilitar KV v2

```bash
vault secrets enable -version=2 -path=secret kv
```

### 12. Verificar status

```bash
vault status
```

Deve mostrar:
- Sealed: false
- Initialized: true

### 13. Copiar certificado CA (na sua máquina local)

```bash
scp -i ~/Downloads/vault-vault.pem ubuntu@44.203.198.21:/opt/vault/tls/vault-cert.pem ./vault-ca.pem
```

## Próximos Passos

Após o Vault estar configurado com HTTPS:

1. **Criar secret no Kubernetes:**
   ```bash
   kubectl create secret generic vault-ca-cert \
     --namespace redis-enterprise \
     --from-file=vault.ca=./vault-ca.pem
   ```

2. **Configurar Kubernetes Auth** (ver `00-README.md`)

3. **Aplicar operator config** (ver `01-operator-config.yaml`)

## Troubleshooting

### Vault não inicia
```bash
sudo journalctl -u vault -f
```

### Erro de permissão
```bash
sudo chown -R vault:vault /opt/vault
```

### Testar conectividade
```bash
curl -k https://44.203.198.21:8200/v1/sys/health
```

