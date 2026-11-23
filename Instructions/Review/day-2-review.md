# Morning review – Day 2

Answer each question for yourself first, then open the answer. All questions refer to the Day 2 labs and demos.

<details markdown="1">
<summary><strong>1. A setting is configured in an endpoint security policy and in a settings catalog profile with different values. What happens on the device?</strong></summary>

Nothing – it's a conflict, and a setting in conflict is not applied. The policy status shows the conflict. Endpoint security policies should be the single place for security settings. (Lab 2.1)

</details>

<details markdown="1">
<summary><strong>2. Why do you start ASR rules in Audit, and where do you see what they would have blocked?</strong></summary>

In **Block**, ASR rules break line-of-business apps that do exactly what the rule blocks. In **Audit** you read the events (Event Viewer → Microsoft → Windows → Windows Defender → Operational, event ID 1122) or the ASR report, then switch rule by rule to **Block**. (Lab 2.1)

</details>

<details markdown="1">
<summary><strong>3. Local user group membership: why "Add (Update)" and not "Add (Replace)"?</strong></summary>

**Add (Replace)** removes every member that isn't in the policy – including accounts you still need, for example the LAPS account. Use **Add (Update)** and put all local group rules of a device into one policy. (Lab 2.1)

</details>

<details markdown="1">
<summary><strong>4. The firewall rules arrived on CL3 and show in the active store, but no port opened. Why?</strong></summary>

The rules apply to the **Domain** profile only. CL3 is Entra joined and not a domain member, so Windows never uses the Domain profile there. The rule file is built for hybrid joined devices in the company network. (Lab 2.1)

</details>

<details markdown="1">
<summary><strong>5. On a cloud-native device the built-in Administrator is disabled. What does Windows LAPS manage then?</strong></summary>

Since Windows 11 24H2, **automatic account management** creates and manages its own local admin account (in the course `etcXAdmin`). You saw events 10022 and 10029 in the LAPS log. (Lab 2.2)

</details>

<details markdown="1">
<summary><strong>6. A helpdesk account sees the LAPS backup time but not the password. Why?</strong></summary>

Reading the password is its own permission. `DeviceLocalCredential.ReadBasic.All` shows backup and rotation time only. In Entra ID a role with `microsoft.directory/deviceLocalCredentials/password/read` is needed, for example Cloud Device Administrator. (Lab 2.2)

</details>

<details markdown="1">
<summary><strong>7. What are post-authentication actions in LAPS for, and what did they do after you used the password?</strong></summary>

A LAPS password that was used is a known password. After the delay, LAPS rotates it and signs the account out – so the password is valid for one support case only. You saw event 10041 after the sign-in. (Labs 2.2, 2.5)

</details>

<details markdown="1">
<summary><strong>8. Why did the Notepad++ EPM rule use a file hash, and what is the downside?</strong></summary>

File name and path are weak – any user can rename a file. The hash proves it's exactly the file you checked. Downside: every new version needs a new hash. In production you combine the publisher certificate with product name and internal name instead. (Lab 2.3)

</details>

<details markdown="1">
<summary><strong>9. A support request for regedit didn't show in the elevation report, but the user ran it elevated. Where do you look?</strong></summary>

The **Elevation report** is processed once every 24 hours. The **Elevation requests** tab is live. Approving requests is its own Intune permission (**Endpoint Privilege Management Elevation Requests**); authoring policies doesn't include it. (Lab 2.3)

</details>

<details markdown="1">
<summary><strong>10. The SCEP profile has a "Root certificate" setting. Which trusted certificate profile do you pick there, and which groups do the profiles go to?</strong></summary>

The trusted certificate profile of the **root CA**, not of the issuing CA. Trusted certificate profiles and SCEP profiles go to the same kind of group – in the course device groups. (Lab 2.4)

</details>

<details markdown="1">
<summary><strong>11. Why 2048 bit in the SCEP profile, and when does a device with a 1-year certificate and a 20 % renewal threshold ask for a new one?</strong></summary>

2048 is the maximum key size in the TPM; 4096 works only with the Software KSP. 20 % of 365 days is about 73 days before expiry. (Lab 2.4)

</details>

<details markdown="1">
<summary><strong>12. During a Remote Help session the helper sees a black area when a UAC prompt comes up. Why, and what fixes it?</strong></summary>

The UAC prompt is on the secure desktop. Without the **Elevation** permission in the helper's Remote Help role, the helper can't see or answer it. The device restriction **Enable secure credential prompting** blocks elevation in Remote Help as well. (Lab 2.5)

</details>

<details markdown="1">
<summary><strong>13. The helper elevated a window and then ended the session. What keeps running, and what should the helper do?</strong></summary>

Remote Help signs the sharer out automatically only when the **sharer** ends the session after elevation. When the **helper** ends it, everything started elevated keeps running. So the helper closes every elevated window before leaving. (Lab 2.5)

</details>

<details markdown="1">
<summary><strong>14. App Control for Business in audit mode: what does event 3076 tell you, and why did 7-Zip have none?</strong></summary>

3076 means "this file would be blocked in enforce mode" – the list of rules you still need. 7-Zip was installed by Intune after the managed installer policy reached the device, so it carries the managed installer tag and is allowed. Apps installed earlier need their own rules, for example a supplemental policy built from the 3076 events. (Lab 2.6)

</details>

<details markdown="1">
<summary><strong>15. You remove an App Control policy from the assignment. When does it stop applying?</strong></summary>

It stays active on the device until the next restart. (Lab 2.6)

</details>
