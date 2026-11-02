---
title: 'Lab 2.4 – Certificates from Cloud PKI'
lab:
    title: 'Lab 2.4 – Certificates from Cloud PKI'
    module: 'Day 2 – Security, least privilege, support'
---
{% raw %}

# Lab 2.4 – Certificates from Cloud PKI

**Estimated time:** 35 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy a device certificate and a user certificate from the course issuing CA to CL3.

1. Intune admin center → Tenant administration → Cloud PKI: open the root CA and the issuing CA the trainer created. Download both certificates and copy the **SCEP URI** of the issuing CA.
2. Devices → Configuration → Create → Windows 10 and later → Templates → **Trusted certificate**: `etcX-Root` (root CA certificate) and `etcX-Issuing` (issuing CA certificate), destination store **Computer certificate store - Root** and **Intermediate**.
3. Templates → **SCEP certificate**: `etcX-Device`

   | Setting | Value |
   |---|---|
   | Certificate type | **Device** |
   | Subject name format | `CN={{DeviceName}}` |
   | Key storage provider | **Enroll to TPM KSP if present, otherwise Software KSP** |
   | Extended key usage | **Client Authentication** |
   | Root certificate | `etcX-Root` |
   | SCEP server URL | SCEP URI from step 1 – leave `{{CloudPKIFQDN}}` as it is |

4. Templates → **SCEP certificate**: `etcX-User`

   | Setting | Value |
   |---|---|
   | Certificate type | **User** |
   | Subject name format | `CN={{UserName}}` |
   | Subject alternative name | **User principal name (UPN)** = `{{UserPrincipalName}}` |
   | Key storage provider | **Enroll to TPM KSP if present, otherwise Software KSP** |
   | Extended key usage | **Client Authentication** |
   | Root certificate | `etcX-Root` |
   | SCEP server URL | SCEP URI from step 1 |

5. Assign `etcX-Root`, `etcX-Issuing` and `etcX-Device` to `studentXdevices`. Assign `etcX-Root`, `etcX-Issuing` and `etcX-User` to `studentXusers`.
6. Sign in to CL3 as `etcX` and sync.
7. On CL3, open `certlm.msc` → Personal → Certificates for the device certificate and `certmgr.msc` → Personal → Certificates for the user certificate.

### Checkpoint

- [ ] Root and issuing CA in the computer stores on CL3
- [ ] Device certificate issued by the course issuing CA in the computer store
- [ ] User certificate for `etcX` with your UPN as subject alternative name in the user store
- [ ] Both certificates listed in Cloud PKI → issuing CA → issued certificates

**Note:** The **Root certificate** setting of a SCEP profile points to the trusted certificate profile of the root CA, not the issuing CA. The trusted certificate profiles go to the same groups as the SCEP profiles.

**Note:** A tenant can have up to three Cloud PKI CAs. That is why the trainer creates the hierarchy and everybody uses the same issuing CA.

<!-- VERIFY: Lab roles can read Cloud PKI CAs and download certificates -->
<!-- Sources: Learn – Configure root and issuing CA for Microsoft Cloud PKI (Root Certificate = root CA profile, keep {{CloudPKIFQDN}}); Trusted root certificate profiles (same groups); Overview of Microsoft Cloud PKI (3 CAs); checked 2026-11-02. -->
<!-- VERIFY: issuing CA has the Client Authentication EKU -->
<!-- VERIFY: destination store values -->
{% endraw %}
