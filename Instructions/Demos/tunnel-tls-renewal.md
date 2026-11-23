# Demo – Renew the Microsoft Tunnel TLS certificate automatically (Module 15)

**Duration:** 20 minutes

> **Draft:** This demo page is new. The steps ran on the trainer's Tunnel server in summer 2026 but have not been re-checked against this page yet.

**Goal:** Follow a Let's Encrypt certificate from the DNS challenge in Azure DNS to the Tunnel Gateway – issued, installed and renewed without anyone logging on to the server.

**Why:** The TLS certificate of the Tunnel Gateway is the part that most often expires. Intune warns in Tenant administration → Microsoft Tunnel Gateway → Health status when it has 30 days or less left, but nothing renews it for you. Public certificates are getting shorter lifetimes, so a manual renewal every few months does not scale.

**Why a demo:** It needs an Azure VM with the Tunnel Gateway, a public Azure DNS zone and root on the server. In the course only the trainer has those.

The setup used in the demo (names are examples):

| Item | Value |
|---|---|
| Tunnel server | RHEL 9 VM in Azure with Podman, Tunnel Gateway installed |
| Tunnel FQDN | `tunnel.lab.contoso.com` |
| Azure DNS zone | `lab.contoso.com` (public, delegated) |
| ACME client | [acme.sh](https://github.com/acmesh-official/acme.sh) with the `dns_azure` plugin |
| Certificate authority | Let's Encrypt |

## What happens

1. acme.sh is a shell script in root's home (`/root/.acme.sh`). At install it adds a daily cron job.
2. To prove that it owns the name, acme.sh writes a TXT record `_acme-challenge.tunnel` into the Azure DNS zone, Let's Encrypt checks it, and acme.sh deletes it again. No inbound port is opened – no port 80 in the NSG.
3. acme.sh signs in to Azure DNS with the **system-assigned managed identity** of the VM. No secret is stored on the server.
4. After each renewal acme.sh copies certificate and key to `/etc/mstunnel` and runs the reload command: `mst-cli import_cert` and `mst-cli server restart`.

## 1. Azure side (Cloud Shell, bash)

```bash
RG_VM="<resource group of the VM>"; VM="<vm name>"
RG_DNS="<resource group of the zone>"; ZONE="lab.contoso.com"
REC="_acme-challenge.tunnel"

az vm identity assign -g $RG_VM -n $VM
PID=$(az vm show -g $RG_VM -n $VM --query identity.principalId -o tsv)
ZONE_ID=$(az network dns zone show -g $RG_DNS -n $ZONE --query id -o tsv)

# Write access to this one TXT record only
az role assignment create --assignee-object-id $PID --assignee-principal-type ServicePrincipal \
  --role "DNS Zone Contributor" --scope "$ZONE_ID/TXT/$REC"

# Read access to the zone, so the plugin finds it
az role assignment create --assignee-object-id $PID --assignee-principal-type ServicePrincipal \
  --role "Reader" --scope "$ZONE_ID"
```

The trainer points out:

- The record name is `_acme-challenge.` plus everything left of the zone name (`tunnel` here; for the zone apex just `_acme-challenge`).
- The role assignment is scoped to a record set that **does not exist yet**. A scope is a path; Azure checks it when the request comes in. The identity can create and delete exactly this TXT record and touch nothing else in the zone. The portal can't do this (the IAM blade needs an existing resource) – only CLI, PowerShell or ARM/Bicep.

## 2. Issue the certificate (on the VM, as root)

```bash
sudo -i
systemctl is-active crond || (dnf install -y cronie && systemctl enable --now crond)

curl https://get.acme.sh | sh
source ~/.bashrc
acme.sh --set-default-ca --server letsencrypt

export AZUREDNS_SUBSCRIPTIONID=$(curl -s -H Metadata:true \
  "http://169.254.169.254/metadata/instance/compute/subscriptionId?api-version=2021-02-01&format=text")
export AZUREDNS_MANAGEDIDENTITY=true

acme.sh --issue --dns dns_azure -d tunnel.lab.contoso.com --keylength 2048
```

The trainer points out:

- Everything runs as root, because the renewal later writes to `/etc/mstunnel` and restarts the gateway.
- `--keylength 2048` forces RSA. acme.sh issues ECDSA by default, and the Tunnel import rejects it with `Not an RSA key` (community finding, see sources).
- The subscription ID comes from the VM's metadata endpoint – this works only if the DNS zone is in the same subscription as the VM.
- The two variables end up in `/root/.acme.sh/account.conf`; the token is fetched fresh from the metadata endpoint on every run.

## 3. Hook it into the Tunnel Gateway

```bash
ls -l /etc/mstunnel/private /etc/mstunnel/certs

acme.sh --install-cert -d tunnel.lab.contoso.com \
  --key-file       /etc/mstunnel/private/site.key \
  --fullchain-file /etc/mstunnel/certs/site.crt \
  --reloadcmd      "chmod 600 /etc/mstunnel/private/site.key && /usr/sbin/mst-cli import_cert && /usr/sbin/mst-cli server restart"
```

The command runs once now and is stored for every later renewal. `site.crt` holds the full chain and `site.key` the unencrypted key – the PEM format the Tunnel setup expects. An old `site.pfx` from the first install is moved away first.

`mst-cli server restart` matters: `import_cert` reports success, but the running server keeps serving the old certificate until it restarts. The restart drops active VPN sessions.

## 4. Check

```bash
openssl x509 -in /etc/mstunnel/certs/site.crt -noout -serial -enddate
echo | openssl s_client -connect 127.0.0.1:443 -servername tunnel.lab.contoso.com 2>/dev/null | openssl x509 -noout -serial -issuer
mst-cli server status
crontab -l
```

- Both serial numbers match (file on disk = what the server delivers), issuer is Let's Encrypt.
- `mst-cli server status` shows running and healthy.
- `crontab -l` shows the daily acme.sh line. A lab VM that is often deallocated also gets a second line, so the check runs after each start:

```bash
(crontab -l; echo '@reboot sleep 120 && /root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null') | crontab -
```

- Intune admin center → Tenant administration → Microsoft Tunnel Gateway → the server → Health status: **TLS certificate** shows the new expiry date.

A forced renewal (`acme.sh --renew -d tunnel.lab.contoso.com --force`) shows the whole chain once. Don't repeat it: Let's Encrypt allows five identical certificates per week.

### Checkpoint

- [ ] You can explain why no inbound port is needed for the DNS challenge
- [ ] You can name the two Azure roles the VM identity gets and on which scope
- [ ] You can explain why the certificate must be RSA and why the gateway is restarted after the import
- [ ] You can show where Intune reports the TLS certificate expiry of a Tunnel server

**Note:** cron runs only while the VM is on and does not catch up missed runs – hence the `@reboot` line.

**Note:** The `dns_azure` plugin asks the metadata endpoint for a token without a `client_id`. That works with the system-assigned identity; a VM with only several user-assigned identities fails.

**Note:** Check the supported Linux versions for the Tunnel Gateway on Learn before you build a server – older RHEL minor releases drop out of support.

Sources: Learn – Configure Microsoft Tunnel for Intune (Update the TLS certificate on the Linux server), Reference for Microsoft Tunnel (mst-cli), Monitor Microsoft Tunnel (TLS certificate health), checked 2026-11-23. Community: [Microsoft Tunnel TLS renewal on autopilot – Alt Tab to Work](https://alttabtowork.com/2026/06/05/microsoft-tunnel-tls-renewal-on-autopilot/); acme.sh wiki – How to use Azure DNS.
