#Azure Cloud Security Labs: Infrastructure & Incident Post-Mortem

A hands-on engineering log documenting the programmatic deployment of an isolated cloud environment, version control guardrails, and real-world DevSecOps troubleshooting.

Tools used: 
  - Terraform
  - Github
  - Azure Cloud Shell (CLI for easy access to IaC (Infrastructure as Code)

---

## 🛠️ Phase 1: The Target Architecture (The Honeypot Experiment)

Originally, this phase aimed to build a live cloud asset to test external network access controls, boundary firewalls, and logging capabilities in Microsoft Azure. 

### Infrastructure Components Deployed (Terraform)
* **Resource Group:** `rg-lab` deployed in the `ukwest` region.
* **Network Isolation:** A Virtual Network (VNet) spanning `10.0.0.0/16` with a dedicated subnet `10.0.1.0/24`.
* **Firewall Boundaries:** A Network Security Group (NSG) configured with an explicit inbound rule allowing traffic over port 22 (`Allow-SSH-Inbound`) linked to both the Subnet and Network Interface Card (NIC).
* **Compute Target:** An Ubuntu Server 22.04 LTS virtual machine running on a `Standard_D2s_v3` footprint. (Tip: whenever you need to deploy the VM and don't know which one is available to you, go to the GUI version within the Azure portal after selecting "Region" and down the in the option "Size" you'll be able to find the available sizes for your VM that you can run in that region. It can be done through the CLI but a lot harder since the response is a lot slower.)

---

## 🛑 The Troubleshooting Log: Mistakes, Root Causes, & Patches

Below is the chronological engineering breakdown of the deployment failures encountered, the analytical root causes, and how they were programmatically mitigated.

### Case 1: Azure Deployment Failure - Legacy SKU Sunset
* **The Symptom:** Terraform deployment stalled or threw an allocation failure when generating the Public IP address resource.
* **The Root Cause:** Legacy `Basic` SKU public IP allocations have been deprecated by Microsoft cloud routers across standard subscription regions. Newer subscription accounts are hardcoded with a legacy quota of `0`.
* **The Engineering Fix:** Explicitly upgraded the infrastructure declaration to the modern `Standard` SKU format:
  ```hcl
  resource "azurerm_public_ip" "honeypot_pip" {
    allocation_method   = "Static"
    sku                 = "Standard" 
  }

---

## 🔐 Case 2: Git Leak Risk - Loose .gitignore Syntax

The Symptom: Initial iterations used loose wildcard constraints like .tfstate to block local files from tracking.

The Root Cause: Non-standard globbing patterns risk breaking tracking mechanisms, which can accidentally leak highly sensitive files (like state binaries and private .pem keys) directly into public public code repositories.

The Engineering Fix: Rewrote the file exclusions to enforce industry-standard structural boundaries:

// Plaintext

.terraform/
*.tfstate
*.tfvars
*.pem

(The AI also misled the "protection" leading me to add an extra " * ". Ex: "*.tfstate* or **.tfstate**". Be cautious when following instructions and try to ask comparison questions to help in the analysis in case you don't now a thing about the topic)

---

## Case 3: Version Control Reject - Deprecated Git Basic Auth

The Symptom: Running git push origin main threw a fatal 403: Permission denied error.

The Root Cause: GitHub fully deprecated standard account password authentication for interactive command-line operations to prevent automated credential harvesting attacks.

The Engineering Fix: Created an encrypted Personal Access Token (PAT) via GitHub Developer Settings with repo scopes checked, passing the generated token string (ghp_...) as the cryptographic credential passphrase.

---

## Case 4: Branch Divergence - Forked Repository Origins
The Symptom: Pushing to the remote server threw a [rejected] main -> main (fetch first) exception.

The Root Cause: The online GitHub repository was pre-initialized with a default file (e.g., a web-generated README), creating a separate tracking history that did not align with the local directory's root timeline.

The Engineering Fix: Standardized the merge policy, pulled down the remote assets with history overrides, and safely pushed the combined history back up:

Bash
git config pull.rebase false
git pull origin main --allow-unrelated-histories
git push origin main

---

### Case 5: SSH Authorization Failure - Transient Memory Assets

The Symptom: Attempting to establish an SSH session resulted in Permission denied (publickey).

The Root Cause: Double-fold issue: A typo in the interactive target username (attackers_bait vs attacker_bait), combined with the total absence of a local file system resource block in the core code. The tls_private_key module generated the keypair purely inside transient RAM state, meaning no physical matching .pem file existed on the local Mac hard drive.

The Engineering Fix: Appended an explicit local file extraction block to drop the generated key directly onto the local host directory:

Terraform
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/honeypot_key.pem"
}

🔄 The Architectural Pivot: Shifting Left to "Secret Sweep"
The Major Realization
While the cloud network configurations we engineered were perfectly sound, we recognized a major divergence from our primary target goal. We built a live, network-level infrastructure environment (a Honeypot), but the primary goal of the Secret Sweep project is to build an automated application security scanning utility.

Moving Forward
Instead of running an active cloud honeypot, we are tearing down our compute nodes and building a local security script that utilizes regular expressions (Regex) to scan code repositories. This tool will automatically scan staging directories and lock down files before they leak onto the internet, achieving true Shift-Left Security inside CI/CD automation pipelines.

Documented by Thomas CloudSec - 2026


Here is the complete, rewritten `README.md`. I translated the rigid, corporate jargon into plain English so it reads like an authentic, hands-on log from someone actually in the trenches figuring this out.

I also integrated your excellent GUI tip and the honest warning about my AI hallucination with the `.gitignore` syntax—transparency like that is exactly what makes documentation valuable.

Copy and paste this entire block into your terminal editor:



# Azure Cloud Security Labs: Infrastructure & Incident Post-Mortem

Hey there! This is my hands-on engineering log. It documents how I set up an isolated cloud security lab in Microsoft Azure, ran into real-world errors, and figured out how to fix them using modern DevSecOps practices. 

Instead of just clicking buttons in a cloud portal, I built everything through code. It wasn't a perfectly smooth ride—I hit roadblocks with cloud quotas, Git sync issues, and key mismatches. I’ve documented every mistake and fix below so you don't have to waste time failing the same way I did.

---

## 🛠️ The Toolkit: What I Used & Why

* **Terraform:** An IaC (Infrastructure as Code) tool. Instead of manually creating virtual machines and firewalls in the Azure interface, I wrote out my entire lab setup in a text file. Terraform then reads that file and builds it all automatically. 
* **GitHub:** A cloud platform for version control. It acts as my safety net, tracking changes and backing up my code securely.
* **Azure Cloud Shell:** A browser-based terminal directly inside the Azure portal. It gave me quick CLI (Command Line Interface) access without having to configure complex permissions on my local machine.

---

## 🏗️ Phase 1: The Target Architecture (The Honeypot)

Originally, the goal here was to build a live "Honeypot"—a vulnerable server placed on the internet to attract attackers so I could log and analyze their behavior.

### What I Built with Terraform:
* **Resource Group:** `rg-lab` deployed in the `ukwest` region (the main folder holding all the cloud resources).
* **Network Isolation:** A Virtual Network (VNet) with a dedicated subnet to keep this experiment separated from anything else.
* **Firewall Boundaries:** A Network Security Group (NSG) configured with an explicit rule allowing inbound traffic over Port 22 (SSH).
* **Compute Target:** An Ubuntu Server 22.04 LTS virtual machine running on a `Standard_D2s_v3` size. 

> **💡 Pro-Tip for finding VM Sizes:** If you are writing Terraform code and don't know which VM sizes are actually available to your specific account, don't guess. Go to the Azure Portal GUI, start creating a virtual machine manually, select your region, and look at the "Size" dropdown. It will show you exactly what is allowed. Doing this via the CLI is possible but much slower!

---

## 🛑 The Troubleshooting Log: Mistakes & Fixes

Here is the chronological breakdown of everything that broke during deployment, why it broke, and the exact code used to fix it.

### Case 1: Azure Deployment Failure - The "Basic SKU" Error
* **What Happened:** Terraform froze and threw an error when trying to create a Public IP address for the VM.
* **Why it Happened:** I was trying to use a legacy `Basic` IP address. Microsoft Azure has completely phased these out for newer subscriptions (the quota is strictly set to 0). You now have to use `Standard` IP addresses.
* **The Fix:** I explicitly told Terraform to use the Standard tier in the configuration:

  ```hcl
  resource "azurerm_public_ip" "honeypot_pip" {
    allocation_method   = "Static"
    sku                 = "Standard" 
  }

```
---

```
### Case 2: Git Leak Risk - Bad `.gitignore` Advice

* **What Happened:** I needed to hide my sensitive Terraform state files and private keys from uploading to GitHub, but my initial wildcard tracking was messed up.
* **Why it Happened:** The AI assistant I was using gave me bad advice, telling me to use weird double-asterisk syntax like `.tfstate` or `*.tfstate*`. This broke the tracking mechanism, which is dangerous because it could accidentally leak highly sensitive `.pem` private keys to the public internet. *Always double-check AI advice if you aren't familiar with the topic!*
* **The Fix:** I rewrote the file exclusions to use the clean, industry-standard format:
```text
.terraform/
*.tfstate
*.tfvars
*.pem

```

### Case 3: GitHub Rejection - Passwords Don't Work Anymore

* **What Happened:** When I typed `git push origin main`, GitHub threw a `fatal 403: Permission denied` error, even though my password was correct.
* **Why it Happened:** GitHub completely disabled standard passwords for command-line pushes to stop automated hacking bots.
* **The Fix:** I had to go into my GitHub Developer Settings and generate a Personal Access Token (PAT). When the terminal asks for a password, you paste this long `ghp_...` token instead.

### Case 4: Branch Divergence - The "Unrelated Histories" Block

* **What Happened:** GitHub refused my push, throwing a `[rejected] main -> main (fetch first)` error.
* **Why it Happened:** When I created the repository on GitHub's website, it generated a default file (like a README). Because my local Mac folder and the GitHub folder had two completely different starting points, Git panicked and refused to overwrite anything.
* **The Fix:** I forced Git to merge the two separate timelines together using the terminal:
```bash
git config pull.rebase false
git pull origin main --allow-unrelated-histories
git push origin main

```

### Case 5: Locked Out of My Own Server - SSH Failures

* **What Happened:** I finally got the VM running, but when I tried to log in via SSH, the server rejected me with `Permission denied (publickey)`.
* **Why it Happened:** This was a combination of two mistakes:
1. A simple typo: I tried logging in as `attackers_bait` instead of `attacker_bait`.
2. The Missing Key: My Terraform code generated the cryptographic key in the cloud's memory, but I forgot to tell Terraform to actually save the `.pem` file onto my local Mac hard drive.

* **The Fix:** I added a local file resource block to force Terraform to drop the private key directly into my project folder:
```hcl
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/honeypot_key.pem"
}

```

---

## 🔄 The Pivot: Realizing I Was Building the Wrong Thing

**The Major Realization:**
After spending hours successfully building and securing this cloud network, I realized something important: I had drifted away from my actual goal.

My target was to build a **Secret Sweep** project (an automated tool that scans developers' code for leaked passwords before they get uploaded). Building a live Honeypot virtual machine is a cool infrastructure exercise, but it has nothing to do with writing a code-scanning script.

**Moving Forward:**
I am destroying the active Azure compute nodes to avoid unnecessary costs. Instead of managing a live server, I am pivoting to writing a local Python/Bash script using Regular Expressions (Regex). This tool will automatically scan staging directories in a CI/CD pipeline, achieving true "Shift-Left Security" by catching leaked keys before they ever hit the internet.

---

*Documented by Thomas CloudSec - 2026*

```

```
