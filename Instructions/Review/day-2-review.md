# Morning review – Day 2

Think each question through – ideally with your neighbor – before you open the answer. There is rarely one right sentence; the answer shows the reasoning behind it.

<details markdown="1">
<summary><strong>1. Two admins configure the same Defender setting – one in an endpoint security policy, one in a settings catalog profile – with different values. Each thinks "mine wins". What actually happens, and what does that teach you about how to organize security settings?</strong></summary>

Neither wins. Intune reports a conflict, and a setting in conflict is not applied at all – the device may end up less protected than either admin intended. There is no "stricter value wins" rule. The lesson: one setting, one place. Endpoint security policies are that place for security settings, and the team needs to agree on it before policies grow. (Lab 2.1)

</details>

<details markdown="1">
<summary><strong>2. Your CISO wants all ASR rules in Block mode by Friday. How do you argue for a different plan without saying "no"?</strong></summary>

Block mode stops exactly the behavior the rule describes – and some line-of-business apps do exactly that (start child processes from Office, run scripts, and so on). If you switch to Block blindly, you find out from broken business processes. With Audit first you collect evidence (event 1122 or the ASR report), add exclusions where justified, and then switch rule by rule to Block. The CISO gets Block mode – with a plan that won't be rolled back after the first helpdesk storm. (Lab 2.1)

</details>

<details markdown="1">
<summary><strong>3. A policy adds the helpdesk group to the local Administrators group with "Add (Replace)". A week later the LAPS account no longer works. Connect the two.</strong></summary>

**Replace** makes the policy the only truth for that group: every member not listed is removed – including the account LAPS manages. Support still gets a valid LAPS password, but for an account without admin rights. **Add (Update)** adds members and leaves the rest alone. Putting all local group rules of a device into one policy keeps two policies from fighting over the same group. (Labs 2.1, 2.2)

</details>

<details markdown="1">
<summary><strong>4. The firewall rules arrived on CL3, are in the active store – and still no port opened. Why is that not a bug, and what does it tell you about testing policies in the lab?</strong></summary>

The rules apply to the **Domain** profile only. CL3 is Entra joined, not a domain member, so Windows never activates the Domain profile there. On a hybrid joined device in the company network the same rules work. "Arrived" is not the same as "in effect" – you have to understand which conditions on the device decide whether a setting does anything, and test on a device that matches the target. (Lab 2.1)

</details>

<details markdown="1">
<summary><strong>5. Why is the same local admin password on every device such a big deal, even if it is long and complex?</strong></summary>

Because an attacker needs it only once. Whoever gets the password (or its hash) from one device can sign in to every other device with it and move through the network. Complexity doesn't help against that – uniqueness does. LAPS gives every device its own password, and with post-authentication actions a password that was used is replaced after the support case. (Lab 2.2)

</details>

<details markdown="1">
<summary><strong>6. Why does LAPS rotate the password and sign the account out after it was used – isn't that annoying for support?</strong></summary>

A password that was used is a known password: it was shown on a screen, maybe pasted into a ticket or a chat. Rotating it after a delay makes it valid for exactly one support case. The small cost: support has to fetch the password again next time – which also leaves a new audit entry. You saw this in Remote Help when the password stopped working between parts of the lab. (Labs 2.2, 2.5)

</details>

<details markdown="1">
<summary><strong>7. Your EPM rule for Notepad++ used a file hash. Would you do the same for an in-house tool, for Notepad++ in production and for a one-off vendor installer – and why?</strong></summary>

File name and path alone would be weak – any user can rename a file, so the rule needs something that proves the file. A **hash** is exact but breaks with every new version – good for a one-off installer that will never change. A **publisher certificate** (with product and internal name) survives updates – good for Notepad++ or anything signed and updated often. An unsigned in-house tool leaves you with a hash, or a reason to start signing it. Files without a rule go through a support approval, so nothing has to be "always elevated" just in case. (Lab 2.3)

</details>

<details markdown="1">
<summary><strong>8. EPM, LAPS and Remote Help with elevation all give someone admin rights for a moment. How do they differ in who gets the rights, and when would you use which?</strong></summary>

**EPM** elevates a single file for the standard user – the user stays a standard user. **LAPS** gives a person (usually support) the full local administrator account of one device. **Remote Help with elevation** lets the helper answer a UAC prompt in the user's session. EPM is for recurring tasks the user should be able to do alone, LAPS for hands-on admin work, Remote Help for "show me and fix it with me" – and Remote Help often uses the LAPS account for the UAC prompt. (Labs 2.2, 2.3, 2.5)

</details>

<details markdown="1">
<summary><strong>9. In the SCEP profile you chose the root CA, not the issuing CA, as "Root certificate". What is the device actually doing with that information?</strong></summary>

The device uses it to decide whether it trusts the chain of the certificate it receives. Trust is anchored at the root; the issuing CA is only an intermediate signed by the root. If the root isn't trusted on the device, the issued certificate is useless – that is why the trusted certificate profiles must reach the same devices (same kind of group) as the SCEP profile. (Lab 2.4)

</details>

<details markdown="1">
<summary><strong>10. Why did the lab use 2048-bit keys, even though 4096 sounds more secure?</strong></summary>

The key is created in the TPM, and 2048 bit is the maximum the TPM supports. 4096 works only with the Software KSP – then the private key lives in software, not in the TPM, and is easier to steal from a compromised device. A 2048-bit key protected by hardware is usually the better trade. (Lab 2.4)

</details>

<details markdown="1">
<summary><strong>11. In a Remote Help session the helper sees a black screen when the user starts an admin task. The helper suspects a network problem. What is really happening?</strong></summary>

The UAC prompt runs on the secure desktop, which a normal screen-sharing session can't see or control – by design, so nothing can click "Yes" for the user. Only with the **Elevation** permission in the helper's Remote Help role can the helper see and answer it. The device restriction **Enable secure credential prompting** blocks this as well. (Lab 2.5)

</details>

<details markdown="1">
<summary><strong>12. The helper opened an elevated command prompt, fixed the problem and closed the session. Why is that a security risk, and who should end the session?</strong></summary>

When the **helper** ends the session, everything started elevated keeps running on the user's desktop – the user now has an admin prompt. Remote Help signs the user out automatically only when the **sharer** ends the session after elevation. So: the helper closes every elevated window first, or the user ends the session. (Lab 2.5)

</details>

<details markdown="1">
<summary><strong>13. Your company wants App Control in enforce mode on all devices. What does audit mode tell you that you could not find out any other way – and why did apps installed by Intune not show up?</strong></summary>

Audit mode lists every file that an enforced policy *would* block (event 3076) – on the real devices, with the real apps. That list is your rule backlog before you enforce. Apps installed by Intune after the managed installer policy reached the device carry the managed installer tag and are allowed automatically – they don't need rules. Everything installed earlier, or by hand, shows up and needs a rule, for example a supplemental policy built from the 3076 events. (Lab 2.6)

</details>

<details markdown="1">
<summary><strong>14. You switched an App Control policy to enforce by mistake and remove the assignment immediately. Are the users safe from blocked apps now?</strong></summary>

Not yet. A removed App Control policy stays active until the device restarts. Plan for that: test enforce mode on a small group, and know how you will get affected devices restarted. (Lab 2.6)

</details>
