---
title: 'Lab 2.4 – Certificates from Cloud PKI'
lab:
    title: 'Lab 2.4 – Certificates from Cloud PKI'
    module: 'Day 2 – Security, least privilege, support'
---
{% raw %}

# Lab 2.4 – Certificates from Cloud PKI

**Estimated time:** 30 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy a device certificate and a user certificate from the course issuing CA to CL3.

The trainer created the Cloud PKI hierarchy and already deploys both CA certificates to all course devices with two trusted certificate profiles: `Win MSLab Cloud PKI Root CA` (computer store **Root**) and `Win MSLab Cloud PKI Issuing CA` (computer store **Intermediate**). You check that they arrived and build the SCEP profiles on top.

1. Intune admin center → Tenant administration → Cloud PKI: open the issuing CA `MsLabLive Issuing CA` and copy its **SCEP URI**.
2. On CL3, in PowerShell, check that both CA certificates are there:

   ```powershell
   Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*MsLabLive Root CA*' | Format-List Subject, Thumbprint, NotAfter
   Get-ChildItem Cert:\LocalMachine\CA   | Where-Object Subject -like '*MsLabLive Issuing CA*' | Format-List Subject, Issuer, NotAfter
   ```

   Or in `certlm.msc`: **Trusted Root Certification Authorities** and **Intermediate Certification Authorities**. The issuer of the issuing CA is the root CA.
3. Devices → Configuration → Create → Windows 10 and later → Templates → **SCEP certificate**: `etcX-Device`

   | Setting | Value |
   |---|---|
   | Certificate type | **Device** |
   | Subject name format | `CN={{DeviceName}}` |
   | Certificate validity period | `1` **Years** |
   | Key storage provider | **Enroll to TPM KSP if present, otherwise Software KSP** |
   | Key usage | **Digital signature** and **Key encipherment** |
   | Key size (bits) | **2048** |
   | Hash algorithm | **SHA-2** |
   | Root certificate | `Win MSLab Cloud PKI Root CA` |
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
   | Root certificate | `Win MSLab Cloud PKI Root CA` |
   | Extended key usage | **Client Authentication** (`1.3.6.1.5.5.7.3.2`) |
   | Renewal threshold (%) | `20` |
   | SCEP server URL | SCEP URI from step 1 |

5. Assign **both** SCEP profiles, `etcX-Device` and `etcX-User`, to `studentXdevices`. The trusted certificate profiles of the trainer are assigned to device groups, and a SCEP profile only works when it reaches the same devices as its root certificate profile – a user group here would not match the device group of the root profile.
6. Sign in to CL3 as `etcX` and sync.
7. On CL3, open `certlm.msc` → Personal → Certificates for the device certificate and `certmgr.msc` → Personal → Certificates for the user certificate.

### Checkpoint

- [ ] Root CA in **Trusted Root**, issuing CA in **Intermediate** on CL3 (from the trainer's profiles)
- [ ] Device certificate issued by the course issuing CA in the computer store
- [ ] User certificate for `etcX` with your UPN as subject alternative name in the user store
- [ ] Both certificates listed in Cloud PKI → issuing CA → issued certificates

**Note:** The **Root certificate** setting of a SCEP profile points to the trusted certificate profile of the root CA, not the issuing CA. The trusted certificate profiles and the SCEP profiles go to the same kind of group – here device groups.

**Note:** Key size 2048 is the maximum for keys in the TPM. 4096 works on Windows only with the Software KSP. The extended key usage of the profile must be one the issuing CA allows – the trainer's issuing CA allows Client Authentication. With a validity of 1 year and a renewal threshold of 20 %, the device requests a new certificate about 73 days before expiry.

**Note:** A tenant can have up to three Cloud PKI CAs. That is why the trainer creates the hierarchy and everybody uses the same issuing CA.

<!-- Sources: Learn – Configure root and issuing CA for Microsoft Cloud PKI (Root Certificate = root CA profile, keep {{CloudPKIFQDN}}); Trusted root certificate profiles (same groups); Overview of Microsoft Cloud PKI (3 CAs); checked 2026-11-02. -->
<!-- Tenant check 2026-11-21 (read-only): trainer profiles 'Win MSLab Cloud PKI Root CA' / 'Win MSLab Cloud PKI Issuing CA' (Intermediate store), assigned to the course device group; CA names MsLabLive Root CA / MsLabLive Issuing CA. -->
<!-- VERIFY: participants (Lab-Administrator role) can select the trainer's root certificate profile in the SCEP profile -->
<!-- Sources: Learn – Create and assign SCEP certificate profiles in Intune (key usage, key size 4096 only Software KSP on Windows, hash, root certificate = top-level root, renewal threshold); checked 2026-11-20. -->
<!-- VERIFY: Cloud PKI honors the validity period of the profile (capped by the issuing CA) and the EKUs of the trainer's issuing CA -->
{% endraw %}
