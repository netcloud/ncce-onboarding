# NCCE Prerequisites Setup Script

![Maintained by Badge](https://img.shields.io/badge/maintained_by-Netcloud-454B95)

![Netcloud logo](https://www.netcloud.ch/wp-content/uploads/2019/11/Netcloud-Logo.png)

## Overview

This script automates the setup of Azure service principals with custom roles required for the NCCE (NetCloud Cloud Environment) management. It creates an Azure AD application, service principal, and assigns custom roles at the tenant root management group level for managing Azure resources.

## Features

- Creates Azure AD application with custom name (interactive input)
- Creates service principal for the application
- Creates client secret for authentication
- Assigns Owner role at subscription level
- Creates and assigns two custom roles at tenant root management group level:
  - `cr-subscription-provisioner` - Used for subscription management and resource provisioning
  - `cr-management-administrator` - Used for managing Management Groups, Policies, and resource groups

## Prerequisites

- PowerShell 5.1 or higher
- Az PowerShell modules (`Az.Accounts`, `Az.Resources`)
- Azure CLI installed (for credential creation)
- Global Administrator rights in Azure AD tenant
- Owner rights at the subscription level
- Sufficient permissions at tenant root management group

## Required Permissions for Running the NCCE Prerequisites Script
To execute the setup script end-to-end, your identity (user or service principal) must have permissions in both Azure AD (Microsoft Graph) and Azure Resource Manager (ARM):


1. Azure AD (Microsoft Graph) Permissions
- Application Administrator (or Cloud Application Administrator)
   - Create, update and delete App registrations and their service principals
   - Manage application credentials
- (Optional) Privileged Role Administrator (or Global Administrator)
   - Consent to application API permissions under “API Permissions”

2. Azure Resource Manager (ARM) Permissions
- Owner at the subscription level
   - Create role assignments for the new service principal
- Owner (or equivalent) at the root management-group level
   - Create custom roles via New-AzRoleDefinition
   - Assign custom roles to service principals

## Installation

1. Clone this repository:
   ```
   git clone git@github.com:netcloud/ncce-onboarding.git
   cd ncce-onboarding
   ```

2. Run the script:
   ```
   pwsh ncceOnboarding.ps1
   ```

## Usage

1. Run the script in PowerShell
2. Authenticate with your Azure account when prompted
3. The script will create all necessary resources and display the results
4. Save the client secret displayed at the end - it will not be shown again!

## Output

The script will create:

- Azure AD application registration
- Service principal
- Client secret
- Custom roles and assignments
- Information file with service principal details (saved locally)

## Troubleshooting

- If credential creation fails, you may need to manually create a client secret in the Azure portal
- If role assignments fail at tenant level, check your Management Group permissions
- If errors persist, ensure you have the latest Az PowerShell modules installed

## Additional Notes

- The created service principal will have elevated rights at the subscription level
- Custom roles are created at tenant root management group level

## Security Considerations

- The script saves a file containing the service principal secret - keep this secure!
- Delete the secret file once you've stored the credentials in a secure location
- Consider using Azure Key Vault to store the secret securely
- Rotate the client secret periodically

## License

Copyright © 2025 Netcloud AG

---

For more information, contact [Netcloud](https://www.netcloud.ch/)