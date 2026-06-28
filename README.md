#Azure Cloud Security Labs: Infrastructure & Incident Post-Mortem

A hands-on engineering log documenting the programmatic deployment of an isolated cloud environment, version control guardrails, and real-world DevSecOps troubleshooting.

---

## 🛠️ Phase 1: The Target Architecture (The Honeypot Experiment)

Originally, this phase aimed to build a live cloud asset to test external network access controls, boundary firewalls, and logging capabilities in Microsoft Azure. 

### Infrastructure Components Deployed (Terraform)
* **Resource Group:** `rg-lab-secret-sweep` deployed in the `ukwest` region.
* **Network Isolation:** A Virtual Network (VNet) spanning `10.0.0.0/16` with a dedicated subnet `10.0.1.0/24`.
* **Firewall Boundaries:** A Network Security Group (NSG) configured with an explicit inbound rule allowing traffic over port 22 (`Allow-SSH-Inbound`) linked to both the Subnet and Network Interface Card (NIC).
* **Compute Target:** An Ubuntu Server 22.04 LTS virtual machine running on a `Standard_D2s_v3` footprint.

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

Case 2: Git Leak Risk - Loose .gitignore Syntax
The Symptom: Initial iterations used loose wildcard constraints like .tfstate to block local files from tracking.

The Root Cause: Non-standard globbing patterns risk breaking tracking mechanisms, which can accidentally leak highly sensitive files (like state binaries and private .pem keys) directly into public public code repositories.

The Engineering Fix: Rewrote the file exclusions to enforce industry-standard structural boundaries:

Plaintext
.terraform/
*.tfstate
*.tfvars
*.pem
Case 3: Version Control Reject - Deprecated Git Basic Auth
The Symptom: Running git push origin main threw a fatal 403: Permission denied error.

The Root Cause: GitHub fully deprecated standard account password authentication for interactive command-line operations to prevent automated credential harvesting attacks.

The Engineering Fix: Created an encrypted Personal Access Token (PAT) via GitHub Developer Settings with repo scopes checked, passing the generated token string (ghp_...) as the cryptographic credential passphrase.

Case 4: Branch Divergence - Forked Repository Origins
The Symptom: Pushing to the remote server threw a [rejected] main -> main (fetch first) exception.

The Root Cause: The online GitHub repository was pre-initialized with a default file (e.g., a web-generated README), creating a separate tracking history that did not align with the local directory's root timeline.

The Engineering Fix: Standardized the merge policy, pulled down the remote assets with history overrides, and safely pushed the combined history back up:

Bash
git config pull.rebase false
git pull origin main --allow-unrelated-histories
git push origin main
Case 5: SSH Authorization Failure - Transient Memory Assets
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
