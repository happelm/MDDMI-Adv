---
title: 'Lab 2.6 – Certificates from Cloud PKI'
lab:
    title: 'Lab 2.6 – Certificates from Cloud PKI'
    module: 'Day 2 – Apps, security, support'
---

# Lab 2.6 – Certificates from Cloud PKI

**Estimated time:** 25 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy a device certificate from the course issuing CA to CL3.

1. Intune admin center → Tenant administration → Cloud PKI: open the root CA and the issuing CA the trainer created. Download both certificates and copy the **SCEP URI** of the issuing CA.
2. Devices → Configuration → Create → Windows 10 and later → Templates → **Trusted certificate**: `etcX-Root` (root CA certificate) and `etcX-Issuing` (issuing CA certificate), destination store **Computer certificate store - Root** and **Intermediate**.
3. Templates → **SCEP certificate**: `etcX-Device`

   | Setting | Value |
   |---|---|
   | Certificate type | **Device** |
   | Subject name format | `CN={{DeviceName}}` |
   | Key storage provider | **Enroll to TPM KSP if present, otherwise Software KSP** |
   | Extended key usage | **Client Authentication** |
   | Root certificate | `etcX-Issuing` |
   | SCEP server URL | SCEP URI from step 1 |

4. Assign all three profiles to `studentXdevices`. Sync CL3.
5. On CL3, open `certlm.msc` → Personal → Certificates.

### Checkpoint

- [ ] Root and issuing CA in the computer stores on CL3
- [ ] Device certificate issued by the course issuing CA
- [ ] Certificate listed in Cloud PKI → issuing CA → issued certificates

**Note:** A tenant can have up to three Cloud PKI CAs. That is why the trainer creates the hierarchy and everybody uses the same issuing CA.

<!-- VERIFY: Lab roles can read Cloud PKI CAs and download certificates -->
<!-- VERIFY: root certificate setting of the SCEP profile with Cloud PKI (issuing vs root trusted profile) -->
<!-- VERIFY: destination store values -->
