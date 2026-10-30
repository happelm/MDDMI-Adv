---
title: 'Lab 2.7 – Help your partner with Remote Help'
lab:
    title: 'Lab 2.7 – Help your partner with Remote Help'
    module: 'Day 2 – Apps, security, support'
---

# Lab 2.7 – Help your partner with Remote Help

**Estimated time:** 20 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Start an attended Remote Help session to your partner's CL3 from the Intune admin center.

1. Check that the Remote Help app is installed on CL3 (Start → Remote Help).
2. Intune admin center → Devices → your partner's CL3 → **New remote assistance session** → **Remote Help** → **Continue**.
3. Select **Initiate attended control** → **Open Remote Help** and sign in with your `etcX` account.
4. Your partner accepts on CL3. Request full control.
5. Ask your partner to start something that needs a UAC prompt and see what you can do as helper.
6. End the session. Tenant administration → Remote Help → **Monitor**: find the session.

### Checkpoint

- [ ] Session with full control established
- [ ] You know which permission answering UAC prompts needs
- [ ] Session listed in the Remote Help report

**Note:** Unattended control needs a physical, corporate-owned device – the trainer shows it.

<!-- VERIFY: Remote Help enabled in the course tenant -->
<!-- VERIFY: Remote Help app deployed to the lab devices -->
<!-- VERIFY: helper permissions and scope of the Lab roles (partner device group) -->
