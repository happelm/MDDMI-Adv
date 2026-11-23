# Morning review – Day 1

Think each question through – ideally with your neighbor – before you open the answer. There is rarely one right sentence; the answer shows the reasoning behind it.

<details markdown="1">
<summary><strong>1. A colleague says: "Graph is the API for developers, the admin center is for admins." What did you see yesterday that contradicts this – and why does it matter for your daily work?</strong></summary>

The admin center *is* a Graph client. With F12 → Network you saw it send the same requests to `graph.microsoft.com` that you then ran in Graph Explorer and in PowerShell. So every view in the admin center is a request you can find, try and script – and anything the portal can't show you in one view (for example "everything that hits this device") is just a few requests put together. That is how the Toolbox scripts were built. (Lab 1.1)

</details>

<details markdown="1">
<summary><strong>2. A user complains that "some policy" changed a setting on their laptop. Why is the admin center a poor tool for this question, and what does a script have to do to answer it properly?</strong></summary>

The admin center is built around the policy: "which groups does this policy target?". The ticket asks the reverse: "what reaches this device and this user?". Assignments are stored on the policy, so you have to walk all policies, resolve every group the device and the user are in – transitively, because groups can be nested – add **All devices** / **All users** assignments and subtract exclusions. And you need both sides, device and user, because user-targeted policies apply to the device the user signs in to. (Lab 1.1)

</details>

<details markdown="1">
<summary><strong>3. Your script works for you. A colleague with a helpdesk role runs the same script and gets less data or a 403. Is the script wrong?</strong></summary>

No. The script uses **delegated** permissions: it runs as the signed-in person. The scopes requested at `Connect-MgGraph` are the upper limit of what the app may do, but the person's own Entra and Intune roles still decide what they can actually read or change. Two people, same script, different results – that is by design and the reason a script is never a way around RBAC. (Lab 1.1)

</details>

<details markdown="1">
<summary><strong>4. Why is "dry run – real run – undo" more than caution? What would go wrong in production without each step?</strong></summary>

Without the **dry run** you find out what a filter really matches only after it has changed things – in a shared tenant possibly other teams' policies. Without the **log** you can't tell afterwards what the old names were. Without the **undo** a mistake becomes manual work across hundreds of objects. The audit log tells you *who* changed something, but it doesn't bring anything back. The pattern applies to every bulk change you script, not only renames. (Lab 1.2)

</details>

<details markdown="1">
<summary><strong>5. The same pipeline turned an MSI into an app on its own, but needed your input for a setup.exe. What does that tell you about where the real packaging effort lies?</strong></summary>

The upload, the `.intunewin` file and the Graph calls are the same every time – that part is easy to automate. The real knowledge is per installer: the silent switches (they depend on the installer technology, not the app), a reliable uninstall command and a detection rule that still holds after the app updates itself. An MSI carries most of that in its metadata; a setup.exe carries none of it. That knowledge is what a packaging team is for. (Labs 1.3, 1.5)

</details>

<details markdown="1">
<summary><strong>6. Imagine the VLC detection rule had used "equals" with the version you packaged. Describe what happens on a device over the next few weeks.</strong></summary>

VLC updates itself to a newer version. At the next check the detection rule says "not installed", because the version no longer equals the packaged one. For a **Required** app Intune then runs the install of the old version again – depending on the installer a downgrade, a failed install or an endless reinstall, and every check repeats it. "Greater than or equal" accepts any newer version. Detection should answer "is it there in an acceptable state?", not "is it exactly my package?". (Lab 1.5)

</details>

<details markdown="1">
<summary><strong>7. Why can an uninstall command that works perfectly when you test it in your admin PowerShell fail when Intune runs it?</strong></summary>

Different context. The Intune Management Extension runs as SYSTEM in a 32-bit process. There `%ProgramFiles%` can resolve to `C:\Program Files (x86)`, so a 64-bit app is not found. Your interactive test ran as you in a 64-bit shell. Test in the context the agent uses, or write commands that don't depend on it – here the full path. (Lab 1.5)

</details>

<details markdown="1">
<summary><strong>8. When would you deliberately choose the pipeline over an Enterprise App Catalog app with automatic update – even though the catalog app is less work?</strong></summary>

When you need control over *when* and *where* a new version lands: automatic update has no rollout rings and no rollback, so a bad version reaches every targeted device. Also when the app must be a blocking app in the Enrollment Status Page, when you need your own configuration around the install (PSADT), or when the app simply isn't in the catalog. The catalog is great for tools where "always the latest" is the goal and a broken version is a small risk. (Labs 1.4, 1.6)

</details>

<details markdown="1">
<summary><strong>9. Why does the Firefox package need its own detection rule on <code>policies.json</code>, and what would happen if it only checked the Firefox MSI?</strong></summary>

The package delivers more than the MSI: it also copies the policy file. If detection only checks the MSI, a device where Firefox is installed but the policy file is missing or was deleted counts as "installed" and never gets fixed. Detection should check the last thing the package does – then "detected" really means "the whole package is in place". (Lab 1.6)

</details>

<details markdown="1">
<summary><strong>10. A user clicks "Defer" in the PSADT dialog. Walk through what happens next with and without the 1602 = Retry mapping.</strong></summary>

PSADT exits with 1602 ("user deferred"). **With** the mapping, Intune treats it as "try again soon" – three retries, five minutes apart – so the install happens once the user is ready. **Without** it, 1602 counts as a failure: the app shows as failed in the report, and the next attempt comes much later. The mapping turns a user decision into a planned delay instead of an error. (Lab 1.6)

</details>

<details markdown="1">
<summary><strong>11. Multi Admin Approval and alerts both protect against risky changes. Why do you need both – and which one would have helped when a compromised Global Administrator account wiped devices?</strong></summary>

They answer different questions. **Multi Admin Approval prevents** a change to the object types it covers – even by a Global Administrator – until a second person approves. **Alerts report** every change that passed, for any object type, within minutes. A wipe of many devices would be stopped only if device actions are covered by an access policy; otherwise the alert is what tells you quickly that it happened. Prevention covers a few high-risk types; detection covers the rest. (Module 5 demos)

</details>
