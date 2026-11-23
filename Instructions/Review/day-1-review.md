# Morning review – Day 1

Answer each question for yourself first, then open the answer. All questions refer to the Day 1 labs and demos.

<details markdown="1">
<summary><strong>1. The admin center, Graph Explorer and a PowerShell script show you the same device. Why is that, and how do you find the request behind a page in the admin center?</strong></summary>

The admin center is itself a Graph client – all three send the same Graph requests. Press **F12** in the browser, open the **Network** tab and reload the page: the requests to `graph.microsoft.com` are the ones you can try in Graph Explorer and then put into a script. (Lab 1.1)

</details>

<details markdown="1">
<summary><strong>2. The admin center answers "which groups does this policy target?". Which question does support ask instead, and why can't the admin center answer it directly?</strong></summary>

Support asks "what hits this device (or user)?". Assignments are stored on the policy, not on the device. To answer it you need every group the device or user is a member of – transitively, with nesting – plus **All devices** / **All users** assignments and exclusions. That is what the Toolbox script `Get-IntunePolicyAssignmentsByGroup` does. (Lab 1.1)

</details>

<details markdown="1">
<summary><strong>3. Graph Explorer listed a permission for your request. What is the difference between that permission and the scopes your script asked for at <code>Connect-MgGraph</code>?</strong></summary>

Both are **delegated** permissions: the request runs as you, and you can never do more than your own role allows. Graph Explorer and Microsoft Graph PowerShell are two separate apps, each with its own consent. A permission Graph Explorer has doesn't help your script – the script asks for its scopes with `Connect-MgGraph -Scopes ...`. (Lab 1.1)

</details>

<details markdown="1">
<summary><strong>4. Why does the rename script always filter by your own prefix, and why do you run it three times (dry run, real run, undo)?</strong></summary>

Without a prefix filter, a rename touches every object your role can edit – in a shared tenant also other people's policies. The dry run (`-WhatIf`) shows what would change, the real run writes and logs every rename to a CSV, and `-UndoCsv` with that log brings the old names back. Every change shows in the Intune audit log with your account. (Lab 1.2)

</details>

<details markdown="1">
<summary><strong>5. For the 7-Zip MSI, the pipeline built the commands and the detection rule by itself. For the VLC setup.exe you had to supply them. Why?</strong></summary>

An MSI carries product code and version, so the script can build `msiexec` install and uninstall commands and an MSI detection rule. A setup.exe gives it nothing: you have to know the silent switches (they depend on the installer technology, for example NSIS `/S`, Inno Setup `/VERYSILENT /NORESTART`), the uninstall command and how to detect the app. (Labs 1.3, 1.5)

</details>

<details markdown="1">
<summary><strong>6. Why did the VLC detection rule use "greater than or equal" and not "equals"?</strong></summary>

VLC can update itself. With **Equals**, a newer version counts as "not installed", and Intune installs the old version again. (Lab 1.5)

</details>

<details markdown="1">
<summary><strong>7. Why did the VLC uninstall command use the full path and not <code>%ProgramFiles%</code>?</strong></summary>

The Intune Management Extension runs as a 32-bit process. There `%ProgramFiles%` can resolve to `C:\Program Files (x86)`, and the uninstall would not find the 64-bit app. (Lab 1.5)

</details>

<details markdown="1">
<summary><strong>8. What does "Automatically update" for an Enterprise App Catalog app give you – and what do you give up?</strong></summary>

Intune installs new catalog versions on the targeted devices by itself, on a **Required** assignment. You give up rollback and rollout rings (a bad version goes everywhere), and the app can't be a blocking app in the Enrollment Status Page. (Labs 1.4, 2.5)

</details>

<details markdown="1">
<summary><strong>9. What does PSADT add that the MSI alone can't do?</strong></summary>

Asking the user to close the app (with deferral), copying configuration files such as `policies.json`, cleaning up shortcuts – with the same structure, the same log (`C:\Windows\Logs\Software`) and the same dialogs for every package. For the pipeline it is just another source folder. (Lab 1.6)

</details>

<details markdown="1">
<summary><strong>10. Why did the Firefox ESR app map return code 1602 to Retry?</strong></summary>

1602 means the user deferred. With **Retry**, Intune tries again three times, five minutes apart. Without the mapping the install counts as failed and the next attempt comes much later. (Lab 1.6)

</details>

<details markdown="1">
<summary><strong>11. A PSADT example from the internet fails with "command not found". What is the most likely cause?</strong></summary>

It uses v3 function names. In PSADT v4 all functions contain `-ADT`. Check a name with `Get-Command <name> -Module PSAppDeployToolkit`. (Lab 1.6)

</details>

<details markdown="1">
<summary><strong>12. Multi Admin Approval and an alert on Intune changes both deal with risky changes. What is the difference?</strong></summary>

Multi Admin Approval **prevents**: a change to a protected object type (for example scripts) is held until a second admin approves it – Global Administrators and automation included. An alert **reports**: every change that passes – for any object type – is mailed to support or security within minutes, no matter who made it. (Module 5 demos)

</details>

<details markdown="1">
<summary><strong>13. The MAA access policy for scripts was saved, but changes weren't protected right away. Why?</strong></summary>

The access policy itself needs approval: a second admin approves it, then the requestor selects **Complete**. Only after that is it active. (Module 5 demo)

</details>
