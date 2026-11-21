---
title: 'Lab 2.5 – Support CL3 from CL4 with Remote Help'
lab:
    title: 'Lab 2.5 – Support CL3 from CL4 with Remote Help'
    module: 'Day 2 – Security, least privilege, support'
---

# Lab 2.5 – Support CL3 from CL4 with Remote Help

**Estimated time:** 45 minutes

> **Draft:** This lab is new and has not been run in this environment yet. If a step behaves differently, tell the trainer.

**Goal:** Deploy Remote Help as an Enterprise App Catalog app that updates itself, help a standard user on CL3 from CL4 with an attended session including a UAC prompt, and sign in to CL3 with an unattended session.

**Who is who in this lab:** You play both roles. The **helper** is `etcX` on CL4. The **sharer** is the standard user `etcY` on CL3, the same account you used in Lab 2.3. Keep both clients open side by side.

**Why:** Remote Help is the support tool that knows Intune: both sides sign in with their work account, RBAC decides who may help whom, and every session is logged.

## Part A – Prepare

1. On CL4, Intune admin center → Apps → All apps → **Create** → Windows → **Enterprise App Catalog app** → **Select**. **Search the Enterprise App Catalog** for `Remote Help`, select it, select the **x64** package and **Next**.
2. Keep the program, requirements and detection settings from the catalog. Set:

   | Setting | Value |
   |---|---|
   | Name | `etcX-Remote Help` |
   | Assignment | **Required** → `studentXdevices` |
   | Auto-update (in the Required assignment) | **On** |

   Remote Help goes to device groups only – an assignment to a user group does nothing. Helper and sharer both need the app, so CL3 and CL4 get it.
3. Sync CL3 and CL4 (Settings → Accounts → Access work or school → your account → **Info** → **Sync**). Go on with step 4 while the IME installs the app; before Part B, check Start → **Remote Help** on both clients.
4. Intune admin center → Tenant administration → Roles → **My permissions**: check that your role has these permissions:

   | Permission | Right | What it allows |
   |---|---|---|
   | RemoteAssistanceApp | **ViewScreen** | Watch the sharer's screen |
   | RemoteAssistanceApp | **TakeFullControl** | Mouse and keyboard |
   | RemoteAssistanceApp | **Elevation** | See and answer UAC prompts on the sharer's device |
   | RemoteAssistanceApp | **WindowsUnattended** | Unattended remote sign-in on Windows (Part E) |
   | RemoteTasks | **RequestRemoteAssistance** | Start a session from the device in the admin center |
   | RemoteAssistance | **Read** | See that Remote Help is set up for the tenant |

5. On CL3, sign in as `etcY`. On CL4, sign in as `etcX`.

**Why auto-update:** Without it, a new Remote Help version in the catalog shows up under Apps → **Enterprise App Catalog apps with updates**, and you build a new app with supersedence for every update. With auto-update on a **Required** assignment, Intune installs the new catalog version on the targeted devices by itself. There is no rollback and no rollout ring – a bad version goes everywhere at once.

## Part B – Session from the admin center

6. On CL4, Intune admin center → Devices → All devices → **CL3-yourname** → **New remote assistance session** → **Remote Help** → **Continue**.
7. Select **Initiate attended control** → **Open Remote Help**. Remote Help opens on CL4 – sign in with `etcX` if asked.
8. On CL3, `etcY` gets the notification to join the session. Open it, check the helper's name, company and verified badge, and select **Allow**.
9. On CL4, you see the screen of CL3. **Request control**; on CL3 accept it.

## Part C – Elevation

10. On CL4, in the Remote Help toolbar, request elevation (UAC control) – Remote Help doesn't do that on its own. On CL3, `etcY` allows it.
11. Still in the session: on CL3, right-click Start → **Terminal (Admin)**. The UAC prompt asks for administrator credentials – `etcY` is a standard user.
12. Because your role has **Elevation**, you see the UAC prompt on CL4 and can type into it. Sign in with the LAPS account from Lab 2.2 as **`.\etcXAdmin`** – the `.\` points to the local account of CL3. Without it, the sign-in fails although the password is right. Password from Intune admin center → CL3-yourname → **Local admin password**. Copy it there; to put it into the prompt, Hyper-V enhanced session on CL4 is the easiest way, otherwise use **Clipboard → Type clipboard text** in the Hyper-V console as in Lab 2.2.
13. The elevated terminal opens on CL3. Run `whoami`: it shows `CL3-yourname\etcxadmin`. Leave the terminal open.

## Part D – End and report

14. End the session as the **helper** on CL4. Look at CL3: `etcY` stays signed in, and the elevated terminal is **still open** with the rights of `etcXAdmin`. Close it on CL3.
15. Intune admin center → Tenant administration → Remote Help → **Monitor**: find your session with helper, sharer, device and duration.

**Why this matters:** Remote Help signs the sharer out automatically only when the **sharer** ends a session after the helper used elevation (the sharer gets a warning first). When the helper ends it, everything the helper started elevated keeps running. So as helper, close every elevated window before you leave the session.

## Part E – Unattended session

Nobody has to accept an unattended session: the helper signs in to the device with their own account in a separate Windows session. It needs the Azure Virtual Desktop agent and agent bootloader on the device (the trainer deployed both to all course devices as `Remote Desktop Services Infrastructure Agent` and `Remote Desktop Agent Boot Loader`), Remote Desktop enabled, and the **WindowsUnattended** right.

16. On CL3, check the prerequisites. Settings → System → **Remote Desktop** is **On**. In PowerShell:

    ```powershell
    Get-Service RDAgent*
    ```

    The agent and the agent loader service show `Running`.
17. On CL3, `etcY` is still signed in. On CL4, Intune admin center → Devices → All devices → **CL3-yourname** → **New remote assistance session** → **Remote Help** → **Continue** → **Initiate unattended control**.
18. The progress panel shows how Intune prepares the connection. If a prerequisite is missing, the admin center names it – note it and tell the trainer. When the session is ready, select **Open Remote Help**.
19. A new browser tab opens Windows App (web client). Sign in with `etcX`, then decide which local resources you allow (clipboard, file transfer, printer).
20. On CL3, `etcY` gets a notification and can allow or refuse the session. Don't answer: after 30 seconds the session starts, the session of `etcY` is locked and stays open.
21. In the web client, sign in to CL3 with `etcX`. You work in your own Windows session, not in the one of `etcY`. Run `whoami` and `query user` in PowerShell.
22. On CL3, sign in again as `etcY` from the lock screen: `etcY` takes the device back and can continue or end your session. End it.
23. Tenant administration → Remote Help → **Monitor**: the session type of this session is **unattended**.

### Checkpoint

- [ ] `etcX-Remote Help` installed on CL3 and CL4, Required to `studentXdevices` with auto-update on
- [ ] Session from CL4 to CL3 with full control
- [ ] UAC prompt on CL3 answered from CL4 with the LAPS account
- [ ] Unattended session to CL3 with your own sign-in, while the session of `etcY` stayed open
- [ ] Both sessions listed in Remote Help → Monitor
- [ ] You can name the permission that shows the UAC prompt to the helper

**Note:** Without **Elevation**, the helper sees a black area or a pause image while the UAC prompt is on the secure desktop and can't help with it. The setting **Enable secure credential prompting** in a device restriction blocks elevation in Remote Help as well.

**Note:** The LAPS password was used now. With the post-authentication action from Lab 2.2, LAPS rotates it after the delay – exactly what you want after a support case.

**Note:** Unattended control is for corporate-owned, Intune-managed x64 devices that are Microsoft Entra joined or hybrid joined, and only one unattended session per device is possible at a time. Signing in with a standard user account in an unattended session gives you no admin rights. Conditional Access and chat apply to attended sessions only.

<!-- Sources: Learn – Remote Help with Microsoft Intune (permissions View screen / Take full control / Elevation, Remote tasks – Offer remote assistance; both sides sign in with org accounts; start from admin center: device → New remote assistance session → Remote Help → Continue → Initiate attended control → Open Remote Help; sharer signed out when ending after elevation; Monitor report; EnableSecureCredentialPrompting blocks elevation); checked 2026-11-17. -->
<!-- Sources: Learn – Deploying Remote Help (Enterprise App Catalog app; device groups only; latest Windows version 5.2.1037.0; unattended needs AVD agent + bootloader, agent first; enable Remote Desktop via settings catalog "Allow users to connect remotely by using Remote Desktop Services"); Planning for Remote Help (unattended prerequisites incl. IME, device on, permission "Windows unattended control remote sign-in"; RBAC table incl. Remote Assistance Connector – Read); Using Remote Help (Initiate unattended control, progress panel, Windows App web client, 30-second notification, separate Windows session, reclaim from lock screen); Troubleshoot and monitor Remote Help (session type unattended in report); Add an Enterprise App Catalog app (auto-update in Required assignment); Enterprise Application Management (auto-update: Required only, Windows 10/11, no rollback, no rings, "apps with updates" view); checked 2026-11-21. Tenant: role Lab-Administrator for Students holds RemoteAssistanceApp_ViewScreen/TakeFullControl/Elevation/WindowsUnattended, RemoteTasks_RequestRemoteAssistance, RemoteAssistance_Read; AVD agent + bootloader Required to "All StudentDev Groups"; "Win Custom Settings" (all devices) enables AllowUsersToConnectRemotely; checked 2026-11-21. -->
<!-- VERIFY: Learn says virtual devices aren't supported for unattended control – CL3 is a Hyper-V VM; Michael's test decides whether Part E stays -->
<!-- VERIFY: auto-update toggle name and place in the Required assignment; which catalog package to pick -->
<!-- VERIFY: RDP firewall rule needed for unattended on CL3 (Learn: "ensure the firewall allows RDP") -->
<!-- Tested by Michael 2026-11-21: etcY gets the notification; .\etcXAdmin needed in the UAC prompt; helper ending leaves the elevated terminal open (sign-out only when the sharer ends). -->
<!-- VERIFY: exact label of the elevation request in the Remote Help toolbar -->
