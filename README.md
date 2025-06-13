# NCCE Prerequisites Setup

![Maintained by Badge](https://img.shields.io/badge/maintained_by-Netcloud-454B95)
![Netcloud logo](https://www.netcloud.ch/wp-content/uploads/2019/11/Netcloud-Logo.png)

## Overview

The `Initialize-NCCE.ps1` script automates creation and configuration of Azure AD apps, service principals, and custom roles required for NCCE (NetCloud Cloud Environment) management. It now uses reusable modules under the `Modules/` folder for:

- Module version pinning and caching (`ModuleVenvHelper`)
- Device-code authentication for Azure & Microsoft Graph (`AuthHelper`)
- Service principal creation/credential management (`AzureSpHelper`)
- RBAC role assignments and custom roles (`AzureRbacHelper`)
- Granting Graph permissions (`GraphPermissionHelper`)
- Assigning Graph directory roles (`GraphDirectoryRoleHelper`)

## Features

- **Environment Setup**  
  - Pinned‐version caching of required PowerShell modules (Az.* and Microsoft.Graph.*)  
  - Cross-platform PSModulePath adjustment  

- **Authentication**  
  - Azure device-code login (tenant and subscription selection)  
  - Microsoft Graph device-code login (with required scopes)  
  - Summary of tenant ID, tenant name, and Graph user  

- **Service Principal (SP1) – `sp-ncce-global-provisioner`**  
  - Create or retrieve Azure AD application  
  - Create or retrieve service principal  
  - Create or reuse client secret  
  - Grant `Directory.ReadWrite.All` via Microsoft Graph  
  - Assign Owner role on chosen subscription  
  - Create and assign custom roles at tenant-root management group:  
    - `cr-subscription-provisioner`  
    - `cr-management-administrator`  
  - Assign “Application Administrator” directory role  

- **Service Principal (SP2) – `sp-ncce-token-rotator`**  
  - Create or retrieve Azure AD application  
  - Create or retrieve service principal  
  - Create or reuse client secret  

- **Final Step Summary**  
  - Lists each step with key info (app names, IDs, secrets, role assignments)  

## Prerequisites

- PowerShell 7.0 or higher (for cross-platform and `-DeviceCode`)  
- Az PowerShell modules (pinned versions will be cached)  
- Global Administrator or Application Administrator rights in Azure AD  
- Owner role on the subscription you target  
- Owner (or equivalent) at tenant-root management group  
- Elevated Access Azure AD -> Properties -> Access management for Azure resources switch to Yes

## Required Permissions

1. **Azure AD (Microsoft Graph)**  
   - **Application Administrator** (or Cloud Application Administrator)  
     - Create, update, delete app registrations & service principals  
     - Manage application credentials  
   - **Optional**: Privileged Role Administrator or Global Administrator for consenting to API permissions  

2. **Azure Resource Manager (ARM)**  
   - **Owner** on subscription  
     - Create role assignments  
   - **Owner** (or equivalent) at tenant-root management group  
     - Create custom roles via `New-AzRoleDefinition`  
     - Assign custom roles to service principals  

## Installation

1. Clone the repository:
   ```bash
   git clone git@github.com:netcloud/ncce-onboarding.git
   cd ncce-onboarding
   
Verify the Modules/ folder and Initialize-NCCE.ps1 exist:
├── Initialize-NCCE.ps1
└── Modules/
    ├── AuthHelper.psm1
    ├── ModuleVenvHelper.psm1
    ├── AzureSpHelper.psm1
    ├── AzureRbacHelper.psm1
    ├── GraphPermissionHelper.psm1
    └── GraphDirectoryRoleHelper.psm1
Run the setup script:
pwsh ./Initialize-NCCE.ps1
Usage

Open a PowerShell 7 session in the repository root.
Execute ./Initialize-NCCE.ps1.
Authenticate when prompted:
Azure device-code login → enter code at https://microsoft.com/devicelogin
Microsoft Graph device-code login → enter code at https://microsoft.com/devicelogin
Wait for each step to complete; key details will be printed as they run.
At the end, a “📑 Step Summary” displays all steps and their info.
Note: Copy any client secret shown to a secure location. It will not be repeated.


Running the script will produce:

Azure AD application registrations:
sp-ncce-global-provisioner
sp-ncce-token-rotator
Associated service principals
Client secrets (new or existing)
Custom roles created and assigned:
cr-subscription-provisioner
cr-management-administrator
“Application Administrator” directory role assignment for SP1
A final summary table shows each step name and its “AppName, AppId, ObjectId, Secret, Role assigned,” etc.

Troubleshooting

Credential creation fails → manually create a client secret in Azure portal under App Registration → Certificates & secrets.
RBAC assignment error → check that you have Owner rights at subscription or tenant-root management group.
Graph login suppressed → run in PowerShell 7, ensure Connect-MgGraph -DeviceCode output is not piped to a variable.
Module import warnings → ensure each module uses approved verbs or use -DisableNameChecking.
Security Considerations

Store client secrets securely (e.g. Azure Key Vault).
Remove any local copy of secrets after storing.
Rotate client secrets periodically.
Review custom roles and scope assignments for least privilege.
License

Copyright © 2025 Netcloud AG

For more info, contact Netcloud.