---
title: 'Lab 2.4 – Certificates from Cloud PKI'
lab:
    title: 'Lab 2.4 – Certificates from Cloud PKI'
    module: 'Day 2 – Security, least privilege, support'
---
{% raw %}

# Lab 2.4 – Certificates from Cloud PKI

**Estimated time:** 40 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy a device certificate and a user certificate from the course issuing CA to CL3.

1. Intune admin center → Tenant administration → Cloud PKI: open the root CA and the issuing CA the trainer created. Download both certificates and copy the **SCEP URI** of the issuing CA.
2. Devices → Configuration → Create → Windows 10 and later → Templates → **Trusted certificate**: `etcX-Root` (root CA certificate) and `etcX-Issuing` (issuing CA certificate), destination store **Computer certificate store - Root** and **Intermediate**.
3. Templates → **SCEP certificate**: `etcX-Device`

   | Setting | Value |
   |---|---|
   | Certificate type | **Device** |
   | Subject name format | `CN={{DeviceName}}` |
   | Certificate validity period | `1` **Years** |
   | Key storage provider | **Enroll to TPM KSP if present, otherwise Software KSP** |
   | Key usage | **Digital signature** and **Key encipherment** |
   | Key size (bits) | **2048** |
   | Hash algorithm | **SHA-2** |
   | Root certificate | `etcX-Root` |
   | Extended key usage | **Client Authentication** (`1.3.6.1.5.5.7.3.2`) |
   | Renewal threshold (%) | `20` |
   | SCEP server URL | SCEP URI from step 1 – leave `{{CloudPKIFQDN}}` as it is |

4. Templates → **SCEP certificate**: `etcX-User`

   | Setting | Value |
   |---|---|
   | Certificate type | **User** |
   | Subject name format | `CN={{UserName}}` |
   | Subject alternative name | **User principal name (UPN)** = `{{UserPrincipalName}}` |
   | Certificate validity period | `1` **Years** |
   | Key storage provider | **Enroll to TPM KSP if present, otherwise Software KSP** |
   | Key usage | **Digital signature** and **Key encipherment** |
   | Key size (bits) | **2048** |
   | Hash algorithm | **SHA-2** |
   | Root certificate | `etcX-Root` |
   | Extended key usage | **Client Authentication** (`1.3.6.1.5.5.7.3.2`) |
   | Renewal threshold (%) | `20` |
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

**Note:** Key size 2048 is the maximum for keys in the TPM. 4096 works on Windows only with the Software KSP. The extended key usage of the profile must be one the issuing CA allows – the trainer's issuing CA allows Client Authentication. With a validity of 1 year and a renewal threshold of 20 %, the device requests a new certificate about 73 days before expiry.

**Note:** A tenant can have up to three Cloud PKI CAs. That is why the trainer creates the hierarchy and everybody uses the same issuing CA.

<!-- Sources: Learn – Configure root and issuing CA for Microsoft Cloud PKI (Root Certificate = root CA profile, keep {{CloudPKIFQDN}}); Trusted root certificate profiles (same groups); Overview of Microsoft Cloud PKI (3 CAs); checked 2026-11-02. -->
<!-- VERIFY: destination store values -->
<!-- Sources: Learn – Create and assign SCEP certificate profiles in Intune (key usage, key size 4096 only Software KSP on Windows, hash, root certificate = top-level root, renewal threshold); checked 2026-11-20. -->
<!-- VERIFY: Cloud PKI honors the validity period of the profile (capped by the issuing CA) and the EKUs of the trainer's issuing CA -->
{% endraw %}
