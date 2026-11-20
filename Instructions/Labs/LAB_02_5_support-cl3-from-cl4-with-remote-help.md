---
title: 'Lab 2.5 – Support CL3 from CL4 with Remote Help'
lab:
    title: 'Lab 2.5 – Support CL3 from CL4 with Remote Help'
    module: 'Day 2 – Security, least privilege, support'
---

# Lab 2.5 – Support CL3 from CL4 with Remote Help

**Estimated time:** 30 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Help a standard user on CL3 from CL4 with Remote Help: start the session from the Intune admin center, take full control, and answer a UAC prompt with the LAPS account from Lab 2.2.

**Who is who in this lab:** You play both roles. The **helper** is `etcX` on CL4. The **sharer** is the standard user `etcY` on CL3, the same account you used in Lab 2.3. Keep both clients open side by side.

**Why:** Remote Help is the support tool that knows Intune: both sides sign in with their work account, RBAC decides who may help whom, and every session is logged.

## Part A – Prepare

1. Check that the Remote Help app is installed on CL3 and on CL4 (Start → **Remote Help**). If it is missing, tell the trainer.
2. Intune admin center → Tenant administration → Roles → **My permissions**: check that your role has these permissions:

   | Permission | Right | What it allows |
   |---|---|---|
   | Remote Help app | **View screen** | Watch the sharer's screen |
   | Remote Help app | **Take full control** | Mouse and keyboard |
   | Remote Help app | **Elevation** | See and answer UAC prompts on the sharer's device |
   | Remote tasks | **Offer remote assistance** | Start a session from the device in the admin center |

3. On CL3, sign in as `etcY`. On CL4, sign in as `etcX`.

## Part B – Session from the admin center

4. On CL4, Intune admin center → Devices → All devices → **CL3-yourname** → **New remote assistance session** → **Remote Help** → **Continue**.
5. Select **Initiate attended control** → **Open Remote Help**. Remote Help opens on CL4 – sign in with `etcX` if asked.
6. On CL3, `etcY` gets the notification to join the session. Open it, check the helper's name, company and verified badge, and select **Allow**.
7. On CL4, you see the screen of CL3. **Request control**; on CL3 accept it.

## Part C – Elevation

8. On CL4, in the Remote Help session: on CL3, right-click Start → **Terminal (Admin)**. The UAC prompt asks `etcY` for administrator credentials – `etcY` is a standard user.
9. Because your role has **Elevation**, you see the UAC prompt on CL4 and can type into it. Enter the LAPS account from Lab 2.2: user name `.\etcXAdmin`, password from Intune admin center → CL3-yourname → **Local admin password**.
10. The elevated terminal opens on CL3. Run `whoami` and note which account it shows. Close the terminal.

## Part D – End and report

11. End the session on CL4. Look at CL3: if the sharer ends a session after the helper used elevation, the sharer is signed out. Note what happened on CL3.
12. Intune admin center → Tenant administration → Remote Help → **Monitor**: find your session with helper, sharer, device and duration.

### Checkpoint

- [ ] Session from CL4 to CL3 with full control
- [ ] UAC prompt on CL3 answered from CL4 with the LAPS account
- [ ] Session listed in Remote Help → Monitor
- [ ] You can name the permission that shows the UAC prompt to the helper

**Note:** Without **Elevation**, the helper sees a black area or a pause image while the UAC prompt is on the secure desktop and can't help with it. The setting **Enable secure credential prompting** in a device restriction blocks elevation in Remote Help as well.

**Note:** The LAPS password was used now. With the post-authentication action from Lab 2.2, LAPS rotates it after the delay – exactly what you want after a support case.

**Note:** Unattended control needs a physical, corporate-owned device and is not part of this lab – the trainer shows it.

<!-- Sources: Learn – Remote Help with Microsoft Intune (permissions View screen / Take full control / Elevation, Remote tasks – Offer remote assistance; both sides sign in with org accounts; start from admin center: device → New remote assistance session → Remote Help → Continue → Initiate attended control → Open Remote Help; sharer signed out when ending after elevation; Monitor report; EnableSecureCredentialPrompting blocks elevation); checked 2026-11-17. -->
<!-- VERIFY: etcY receives the session notification on CL3 although etcY is not the primary user of CL3 -->
<!-- VERIFY: helper sees the UAC prompt on 26H2 with elevation permission; sign-out of the sharer after elevation -->
