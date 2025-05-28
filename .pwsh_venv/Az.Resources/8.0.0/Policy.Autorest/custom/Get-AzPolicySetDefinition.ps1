
# ----------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

<#
.Synopsis
Gets policy set definitions.
.Description
The **Get-AzPolicySetDefinition** cmdlet gets a collection of policy set definitions or a specific policy set definition identified by name or ID.
.Notes
## RELATED LINKS

[New-AzPolicySetDefinition](./New-AzPolicySetDefinition.md)

[Remove-AzPolicySetDefinition](./Remove-AzPolicySetDefinition.md)

[Update-AzPolicySetDefinition](./Update-AzPolicySetDefinition.md)
.Link
https://learn.microsoft.com/powershell/module/az.resources/get-azpolicysetdefinition
#>
function Get-AzPolicySetDefinition {
[OutputType([Microsoft.Azure.PowerShell.Cmdlets.Policy.Models.IPolicySetDefinition])]
[CmdletBinding(DefaultParameterSetName='Name')]
param(
    [Parameter(ParameterSetName='Name', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='ManagementGroupName', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='SubscriptionId', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='Version', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='ListVersion', ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Alias('PolicySetDefinitionName')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Path')]
    [System.String]
    # The name of the policy definition to get.
    ${Name},

    [Parameter(ParameterSetName='Id', Mandatory, ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='Version', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='ListVersion', ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Alias('ResourceId')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Path')]
    [System.String]
    # The full Id of the policy definition to get.
    ${Id},

    [Parameter(ParameterSetName='ManagementGroupName', Mandatory, ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='Builtin', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='Custom', ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Path')]
    [System.String]
    # The name of the management group.
    ${ManagementGroupName},

    [Parameter(ParameterSetName='SubscriptionId', Mandatory, ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='Builtin', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='Custom', ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Path')]
    [System.String]
    # The ID of the target subscription.
    ${SubscriptionId},

    [Parameter(ParameterSetName='Builtin', Mandatory, ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Query')]
    [System.Management.Automation.SwitchParameter]
    # Causes cmdlet to return only built-in policy definitions.
    ${Builtin},

    [Parameter(ParameterSetName='Custom', Mandatory, ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Query')]
    [System.Management.Automation.SwitchParameter]
    # Causes cmdlet to return only custom policy definitions.
    ${Custom},

    [Parameter(ParameterSetName='Version', Mandatory, ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Body')]
    [ValidateNotNullOrEmpty()]
    [Alias('PolicySetDefinitionVersion')]
    [System.String]
    # The policy definition version in #.#.# format.
    ${Version},

    [Parameter(ParameterSetName='ListVersion', Mandatory, ValueFromPipelineByPropertyName)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Query')]
    [System.Management.Automation.SwitchParameter]
    # Causes cmdlet to return only custom policy definitions.
    ${ListVersion},

    [Parameter()]
    [Obsolete('This parameter is a temporary bridge to new types and formats and will be removed in a future release.')]
    [System.Management.Automation.SwitchParameter]
    # Causes cmdlet to return artifacts using legacy format placing policy-specific properties in a property bag object.
    ${BackwardCompatible} = $false,

    [Parameter(DontShow)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Query')]
    [System.String]
    # The filter to apply on the operation.
    # Valid values for $filter are: 'atExactScope()', 'policyType -eq {value}' or 'category eq '{value}''.
    # If $filter is not provided, no filtering is performed.
    # If $filter=atExactScope() is provided, the returned list only includes all policy set definitions that at the given scope.
    # If $filter='policyType -eq {value}' is provided, the returned list only includes all policy set definitions whose type match the {value}.
    # Possible policyType values are NotSpecified, Builtin, Custom, and Static.
    # If $filter='category -eq {value}' is provided, the returned list only includes all policy set definitions whose category match the {value}.
    ${Filter},

    [Parameter()]
    [Alias('AzureRMContext', 'AzureCredential')]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Azure')]
    [System.Management.Automation.PSObject]
    # The DefaultProfile parameter is not functional.
    # Use the SubscriptionId parameter when available if executing the cmdlet against a different subscription.
    ${DefaultProfile},

    [Parameter(DontShow)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Management.Automation.SwitchParameter]
    # Wait for .NET debugger to attach
    ${Break},

    [Parameter(DontShow)]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.SendAsyncStep[]]
    # SendAsync Pipeline Steps to be appended to the front of the pipeline
    ${HttpPipelineAppend},

    [Parameter(DontShow)]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.SendAsyncStep[]]
    # SendAsync Pipeline Steps to be prepended to the front of the pipeline
    ${HttpPipelinePrepend},

    [Parameter(DontShow)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Uri]
    # The URI for the proxy server to use
    ${Proxy},

    [Parameter(DontShow)]
    [ValidateNotNull()]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Management.Automation.PSCredential]
    # Credentials for a proxy server to use for the remote call
    ${ProxyCredential},

    [Parameter(DontShow)]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Category('Runtime')]
    [System.Management.Automation.SwitchParameter]
    # Use the default credentials for the proxy
    ${ProxyUseDefaultCredentials}
)

begin {
    # turn on console debug messages
    $writeln = ($PSCmdlet.MyInvocation.BoundParameters.Debug -as [bool]) -or ($PSCmdlet.MyInvocation.BoundParameters.Verbose -as [bool])

    if ($writeln) {
        Write-Host -ForegroundColor Cyan "begin:Get-AzPolicySetDefinition(" $PSBoundParameters ") - (ParameterSet: $($PSCmdlet.ParameterSetName))"
    }

    # mapping table of generated cmdlet parameter sets
    if ($Version -or $ListVersion) {
        $mapping = @{
            NameSub = 'Az.Policy.private\Get-AzPolicySetDefinitionVersion_Get';               # Name, SubscriptionId
            NameMG = 'Az.Policy.private\Get-AzPolicySetDefinitionVersion_Get1';               # Name, ManagementGroupName
            MG = 'Az.Policy.private\Get-AzPolicySetDefinitionVersion_List';                   # ManagementGroupName
            Sub = 'Az.Policy.private\Get-AzPolicySetDefinitionVersion_List1';                 # SubscriptionId
            BuiltinId='Az.Policy.private\Get-AzPolicySetDefinitionVersionBuilt_Get';          # Id
            BuiltinGet='Az.Policy.private\Get-AzPolicySetDefinitionVersionBuilt_Get';         # Name
        }
    }
    else {
        $mapping = @{
            NameSub = 'Az.Policy.private\Get-AzPolicySetDefinition_Get';                      # Name, SubscriptionId
            NameMG = 'Az.Policy.private\Get-AzPolicySetDefinition_Get1';                      # Name, ManagementGroupName
            Sub = 'Az.Policy.private\Get-AzPolicySetDefinition_List';                         # SubscriptionId
            MG = 'Az.Policy.private\Get-AzPolicySetDefinition_List1';                         # ManagementGroupName
            BuiltinId='Az.Policy.private\Get-AzPolicySetDefinitionBuilt_Get';                 # Id
            BuiltinGet='Az.Policy.private\Get-AzPolicySetDefinitionBuilt_Get';                # Name
        }
    }

    if ($ListVersion) {
        $mapping['NameSub'] = 'Az.Policy.private\Get-AzPolicySetDefinitionVersion_List2';         # Name, SubscriptionId
        $mapping['NameMG'] = 'Az.Policy.private\Get-AzPolicySetDefinitionVersion_List3';          # Name, ManagementGroup
        $mapping['BuiltinId'] = 'Az.Policy.private\Get-AzPolicySetDefinitionVersionBuilt_List';   # Id
        $mapping['BuiltinGet'] = 'Az.Policy.private\Get-AzPolicySetDefinitionVersionBuilt_List';  # Name
   }
}

process {
    if ($writeln) {
        Write-Host -ForegroundColor Cyan "process:Get-AzPolicySetDefinition(" $PSBoundParameters ") - (ParameterSet: $($PSCmdlet.ParameterSetName))"
    }

    # ensure fallback try/catch is invoked if necessary
    $PSBoundParameters['ErrorAction'] = 'Stop'

    # handle disallowed cases not handled by PS parameter attributes
    if ($PSBoundParameters['SubscriptionId'] -and $PSBoundParameters['ManagementGroupName']) {
        throw 'Only ManagementGroupName or SubscriptionId can be provided, not both.'
    }

    if ($PSBoundParameters['Version'] -and !$PSBoundParameters['Name'] -and !$PSBoundParameters['Id']) {
        throw 'Version is only allowed if Name or Id  are provided.'
    }

    if ($PSBoundParameters['ListVersion'] -and !$PSBoundParameters['Name'] -and !$PSBoundParameters['Id']) {
        throw 'ListVersion is only allowed if Name or Id  are provided.'
    }

    # handle specific parameter sets
    $parameterSet = $PSCmdlet.ParameterSetName
    $calledParameterSet = 'Sub'

    switch ($parameterSet) {
        'Builtin' {
            $PSBoundParameters.Add('Filter', "policyType eq 'Builtin'")
        }
        'Custom' {
            $PSBoundParameters.Add('Filter', "policyType eq 'Custom'")
        }
        default {
            if ($Id) {
                $parsed = ParsePolicySetDefinitionId $Id   # function is imported from Helpers.psm1
                switch ($parsed.ScopeType)
                {
                    'subid' {
                        $PSBoundParameters['SubscriptionId'] = $parsed['SubscriptionId']
                        if ($parsed['Name']) {
                            $calledParameterSet = 'NameSub';
                            $PSBoundParameters['Name'] = $parsed['Name']
                        }
                    }
                    'mgname' {
                        $PSBoundParameters['ManagementGroupName'] = $parsed['ManagementGroupName']
                        $PSBoundParameters['Name'] = $parsed['Name']
                        $calledParameterSet = 'NameMG';
                    }
                    'builtin' {
                        $calledParameterSet = 'BuiltinId'
                        $PSBoundParameters['PolicySetDefinitionName'] = $parsed['Name']
                    }
                }
            }
        }
    }

    # this check is needed because builtin Ids are special (no subId, no mgId)
    if ($calledParameterSet -ne 'BuiltinId') {
        # determine parameter set for call to generated cmdlet
        if ($PSBoundParameters['SubscriptionId']) {
            if ($PSBoundParameters['Name']) {
                $calledParameterSet = 'NameSub';
            }
            else {
                $calledParameterSet = 'Sub';
            }
        }
        elseif ($PSBoundParameters['ManagementGroupName']) {
            $PSBoundParameters['ManagementGroupId'] = $PSBoundParameters['ManagementGroupName']
            if ($PSBoundParameters['Name']) {
                $calledParameterSet = 'NameMG'
            }
            else {
                $calledParameterSet = 'MG'
            }
        }
        elseif ($parameterSet -ne 'Id') {
            $PSBoundParameters['SubscriptionId'] = (Get-SubscriptionId)
            if ($PSBoundParameters['Name']) {
                $calledParameterSet = 'NameSub'
            }
        }
    }

    if ($PSBoundParameters['Name']) {
        $PSBoundParameters['PolicySetDefinitionName'] = $PSBoundParameters['Name']
        $null = $PSBoundParameters.Remove('Name')
    }

    if ($PSBoundParameters['Version']) {
        $PSBoundParameters['PolicyDefinitionVersion'] = $PSBoundParameters['Version']
        $null = $PSBoundParameters.Remove('Version')
    }

    # remove parameters not used by generated cmdlets
    $null = $PSBoundParameters.Remove('BackwardCompatible')
    $null = $PSBoundParameters.Remove('ManagementGroupName')
    $null = $PSBoundParameters.Remove('Id')
    $null = $PSBoundParameters.Remove('Builtin')
    $null = $PSBoundParameters.Remove('Custom')
    $null = $PSBoundParameters.Remove('ListVersion')

    if ($writeln) {
        Write-Host -ForegroundColor Blue -> $mapping[$calledParameterSet]'(' $PSBoundParameters ')'
    }

    $cmdInfo = Get-Command -Name $mapping[$calledParameterSet]
    [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.MessageAttributeHelper]::ProcessCustomAttributesAtRuntime($cmdInfo, $MyInvocation, $calledParameterSet, $PSCmdlet)
    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(($mapping[$calledParameterSet]), [System.Management.Automation.CommandTypes]::Cmdlet)
    $scriptCmd = {& $wrappedCmd @PSBoundParameters}

    # get output and fix up for backward compatibility
    try {
        $output = Invoke-Command -ScriptBlock $scriptCmd
    }
    catch {
        if (($_.Exception.Message -like '*PolicySetDefinitionNotFound*') -and $PSBoundParameters.PolicySetDefinitionName -and $PSBoundParameters.SubscriptionId) {

            # failed by name at subscription level, try builtins
            $null = $PSBoundParameters.Remove('SubscriptionId')

            $cmdInfo = Get-Command -Name $mapping['BuiltinGet']
            [Microsoft.Azure.PowerShell.Cmdlets.Policy.Runtime.MessageAttributeHelper]::ProcessCustomAttributesAtRuntime($cmdInfo, $MyInvocation, $calledParameterSet, $PSCmdlet)
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(($mapping['BuiltinGet']), [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters}

            if ($writeln) {
                Write-Host -ForegroundColor Blue -> $mapping['BuiltinGet']'(' $PSBoundParameters ')'
            }

            $output = Invoke-Command -ScriptBlock $scriptCmd
        }
        else {
            throw
        }
    }

    foreach ($item in $output) {
        # add property bag for backward compatibility with previous SDK cmdlets
        if ($BackwardCompatible) {
            $propertyBag = @{
                Description = $item.Description;
                DisplayName = $item.DisplayName;
                Metadata = ConvertObjectToPSObject $item.Metadata;
                Parameters = ConvertObjectToPSObject $item.Parameter;
                PolicyDefinitionGroups = ConvertObjectToPSObject $item.PolicyDefinitionGroup;
                PolicyDefinitions = ConvertObjectToPSObject $item.PolicyDefinition;
                PolicyType = $item.PolicyType
            }

            $item | Add-Member -MemberType NoteProperty -Name 'Properties' -Value ([PSCustomObject]($propertyBag))
            $item | Add-Member -MemberType NoteProperty -Name 'ResourceId' -Value $item.Id
            $item | Add-Member -MemberType NoteProperty -Name 'ResourceName' -Value $item.Name
            $item | Add-Member -MemberType NoteProperty -Name 'ResourceType' -Value $item.Type
            $item | Add-Member -MemberType NoteProperty -Name 'PolicySetDefinitionId' -Value $item.Id
        }

        # use PSCustomObject for JSON properties
        $item | Add-Member -MemberType NoteProperty -Name 'Metadata' -Value (ConvertObjectToPSObject $item.Metadata) -Force
        $item | Add-Member -MemberType NoteProperty -Name 'Parameter' -Value (ConvertObjectToPSObject $item.Parameter) -Force
        $item | Add-Member -MemberType NoteProperty -Name 'PolicyDefinitionGroup' -Value (ConvertObjectToPSObject $item.PolicyDefinitionGroup) -Force
        $item | Add-Member -MemberType NoteProperty -Name 'PolicyDefinition' -Value (ConvertObjectToPSObject $item.PolicyDefinition) -Force
        $item | Add-Member -MemberType NoteProperty -Name 'Versions' -Value ([array]($item.Versions)) -Force
        $PSCmdlet.WriteObject($item)
    }
}

end {
}
}

# SIG # Begin signature block
# MIIoVQYJKoZIhvcNAQcCoIIoRjCCKEICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB7ynP0a7utjc3d
# zj94ca+NhyxlyTaeMqjLndsiMmhQhKCCDYUwggYDMIID66ADAgECAhMzAAAEA73V
# lV0POxitAAAAAAQDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjQwOTEyMjAxMTEzWhcNMjUwOTExMjAxMTEzWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCfdGddwIOnbRYUyg03O3iz19XXZPmuhEmW/5uyEN+8mgxl+HJGeLGBR8YButGV
# LVK38RxcVcPYyFGQXcKcxgih4w4y4zJi3GvawLYHlsNExQwz+v0jgY/aejBS2EJY
# oUhLVE+UzRihV8ooxoftsmKLb2xb7BoFS6UAo3Zz4afnOdqI7FGoi7g4vx/0MIdi
# kwTn5N56TdIv3mwfkZCFmrsKpN0zR8HD8WYsvH3xKkG7u/xdqmhPPqMmnI2jOFw/
# /n2aL8W7i1Pasja8PnRXH/QaVH0M1nanL+LI9TsMb/enWfXOW65Gne5cqMN9Uofv
# ENtdwwEmJ3bZrcI9u4LZAkujAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU6m4qAkpz4641iK2irF8eWsSBcBkw
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwMjkyNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AFFo/6E4LX51IqFuoKvUsi80QytGI5ASQ9zsPpBa0z78hutiJd6w154JkcIx/f7r
# EBK4NhD4DIFNfRiVdI7EacEs7OAS6QHF7Nt+eFRNOTtgHb9PExRy4EI/jnMwzQJV
# NokTxu2WgHr/fBsWs6G9AcIgvHjWNN3qRSrhsgEdqHc0bRDUf8UILAdEZOMBvKLC
# rmf+kJPEvPldgK7hFO/L9kmcVe67BnKejDKO73Sa56AJOhM7CkeATrJFxO9GLXos
# oKvrwBvynxAg18W+pagTAkJefzneuWSmniTurPCUE2JnvW7DalvONDOtG01sIVAB
# +ahO2wcUPa2Zm9AiDVBWTMz9XUoKMcvngi2oqbsDLhbK+pYrRUgRpNt0y1sxZsXO
# raGRF8lM2cWvtEkV5UL+TQM1ppv5unDHkW8JS+QnfPbB8dZVRyRmMQ4aY/tx5x5+
# sX6semJ//FbiclSMxSI+zINu1jYerdUwuCi+P6p7SmQmClhDM+6Q+btE2FtpsU0W
# +r6RdYFf/P+nK6j2otl9Nvr3tWLu+WXmz8MGM+18ynJ+lYbSmFWcAj7SYziAfT0s
# IwlQRFkyC71tsIZUhBHtxPliGUu362lIO0Lpe0DOrg8lspnEWOkHnCT5JEnWCbzu
# iVt8RX1IV07uIveNZuOBWLVCzWJjEGa+HhaEtavjy6i7MIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGiYwghoiAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAQDvdWVXQ87GK0AAAAA
# BAMwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKC9
# TqgXYMdmHkrEXb5hyzqGHmjJOK1Uya5ou3+d3bgPMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEARDBQmPZObIqO3KG73K5iz55t5oCK90mSe7WX
# +v3S2fh/PjVBurb3AG8rmuUaDODoDGxNmLh4TEBYD6Vvx1JS8p6UstQCnZzoBLNE
# Km3FcW6I4ieDzQ/NHIlqerswinD/OuR6AC79I++bVNrf1928Ky4RxIBse+2lb6Mv
# tWjwOT/OxZZ0dB6A38FoBxHImjgFkF6Znh58aJp4hLap4mDnX9iCp9x+2etP8Gja
# EtXRlgN7VYUj+u2bN73Gfhk45e/lv5/UVx2RoYQGj3dKvM2Gw6mVdf3F7OvlrlUr
# 6wneOn8GIziQUGOCcqUkgcywvvdWRZRM7Pd1Fjc8ojcXbnu1wKGCF7AwghesBgor
# BgEEAYI3AwMBMYIXnDCCF5gGCSqGSIb3DQEHAqCCF4kwgheFAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFaBgsqhkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCADKPJFB+ZxndmemCqX7ax62HfpVyQ8xypY
# J4O9GQabDQIGaBLO1QZxGBMyMDI1MDUxNDA5MjAzMS40NzFaMASAAgH0oIHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2RjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEf4wggcoMIIFEKADAgECAhMzAAAB/Big
# r8xpWoc6AAEAAAH8MA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMB4XDTI0MDcyNTE4MzExNFoXDTI1MTAyMjE4MzExNFowgdMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jv
# c29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVs
# ZCBUU1MgRVNOOjZGMUEtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# p1DAKLxpbQcPVYPHlJHyW7W5lBZjJWWDjMfl5WyhuAylP/LDm2hb4ymUmSymV0EF
# RQcmM8BypwjhWP8F7x4iO88d+9GZ9MQmNh3jSDohhXXgf8rONEAyfCPVmJzM7yts
# urZ9xocbuEL7+P7EkIwoOuMFlTF2G/zuqx1E+wANslpPqPpb8PC56BQxgJCI1LOF
# 5lk3AePJ78OL3aw/NdlkvdVl3VgBSPX4Nawt3UgUofuPn/cp9vwKKBwuIWQEFZ83
# 7GXXITshd2Mfs6oYfxXEtmj2SBGEhxVs7xERuWGb0cK6afy7naKkbZI2v1UqsxuZ
# t94rn/ey2ynvunlx0R6/b6nNkC1rOTAfWlpsAj/QlzyM6uYTSxYZC2YWzLbbRl0l
# RtSz+4TdpUU/oAZSB+Y+s12Rqmgzi7RVxNcI2lm//sCEm6A63nCJCgYtM+LLe9pT
# shl/Wf8OOuPQRiA+stTsg89BOG9tblaz2kfeOkYf5hdH8phAbuOuDQfr6s5Ya6W+
# vZz6E0Zsenzi0OtMf5RCa2hADYVgUxD+grC8EptfWeVAWgYCaQFheNN/ZGNQMkk7
# 8V63yoPBffJEAu+B5xlTPYoijUdo9NXovJmoGXj6R8Tgso+QPaAGHKxCbHa1QL9A
# SMF3Os1jrogCHGiykfp1dKGnmA5wJT6Nx7BedlSDsAkCAwEAAaOCAUkwggFFMB0G
# A1UdDgQWBBSY8aUrsUazhxByH79dhiQCL/7QdjAfBgNVHSMEGDAWgBSfpxVdAF5i
# XYP05dJlpxtTNRnpcjBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vcGtpb3BzL2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENB
# JTIwMjAxMCgxKS5jcmwwbAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1Ud
# JQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsF
# AAOCAgEAT7ss/ZAZ0bTaFsrsiJYd//LQ6ImKb9JZSKiRw9xs8hwk5Y/7zign9gGt
# weRChC2lJ8GVRHgrFkBxACjuuPprSz/UYX7n522JKcudnWuIeE1p30BZrqPTOnsc
# D98DZi6WNTAymnaS7it5qAgNInreAJbTU2cAosJoeXAHr50YgSGlmJM+cN6mYLAL
# 6TTFMtFYJrpK9TM5Ryh5eZmm6UTJnGg0jt1pF/2u8PSdz3dDy7DF7KDJad2qHxZO
# RvM3k9V8Yn3JI5YLPuLso2J5s3fpXyCVgR/hq86g5zjd9bRRyyiC8iLIm/N95q6H
# WVsCeySetrqfsDyYWStwL96hy7DIyLL5ih8YFMd0AdmvTRoylmADuKwE2TQCTvPn
# jnLk7ypJW29t17Yya4V+Jlz54sBnPU7kIeYZsvUT+YKgykP1QB+p+uUdRH6e79Va
# iz+iewWrIJZ4tXkDMmL21nh0j+58E1ecAYDvT6B4yFIeonxA/6Gl9Xs7JLciPCIC
# 6hGdliiEBpyYeUF0ohZFn7NKQu80IZ0jd511WA2bq6x9aUq/zFyf8Egw+dunUj1K
# tNoWpq7VuJqapckYsmvmmYHZXCjK1Eus7V1I+aXjrBYuqyM9QpeFZU4U01YG15uW
# wUCaj0uZlah/RGSYMd84y9DCqOpfeKE6PLMk7hLnhvcOQrnxP6kwggdxMIIFWaAD
# AgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3Nv
# ZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIy
# MjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5
# vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64
# NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhu
# je3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl
# 3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPg
# yY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I
# 5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2
# ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/
# TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy
# 16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y
# 1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6H
# XtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMB
# AAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQW
# BBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30B
# ATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYB
# BAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1Vffwq
# reEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27
# DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pv
# vinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9Ak
# vUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWK
# NsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2
# kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+
# c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep
# 8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+Dvk
# txW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1Zyvg
# DbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/
# 2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYIDWTCCAkECAQEwggEBoYHZpIHW
# MIHTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsT
# Hm5TaGllbGQgVFNTIEVTTjo2RjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUATkEpJXOaqI2w
# fqBsw4NLVwqYqqqggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDANBgkqhkiG9w0BAQsFAAIFAOvOcAMwIhgPMjAyNTA1MTQwMTI3MzFaGA8yMDI1
# MDUxNTAxMjczMVowdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA685wAwIBADAKAgEA
# AgIhPAIB/zAHAgEAAgITYTAKAgUA68/BgwIBADA2BgorBgEEAYRZCgQCMSgwJjAM
# BgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEB
# CwUAA4IBAQAUKg+hqVOdvI/rUu+kxoJLbYoiV3H5hjxU5VkKMOaQRH2z/IvSQu6o
# KSkSyA13l6p9MLYxRPemB0Ho6h06pq3nB7E0cr3D34oObujUHEGSLdfKkeL52Cjo
# c0dAWV4YFvFCqAWgxgo8tWkq2zgKfFwupIKgHd6xLZIqe4bsVAEvsjJUUpo4rKlU
# GQkpAeWnOhZzLUMBIm524XANuUhwgUP7onmH+jQvrxbgxys/CSVjhboPOv67d8II
# edeoAN4XLqm4H9eOhf//Xfmyvmdh/irwxjj+HknreRgIGPVK81BXWEEutSu+WSwt
# BPrOTqTnKVoa9z6TIWzHVR055TSVa7RVMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAH8GKCvzGlahzoAAQAAAfwwDQYJYIZI
# AWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG
# 9w0BCQQxIgQgmV7MWAz8AHGuPwuQlr4mfnFfqar7BslhUIrzjcR48OIwgfoGCyqG
# SIb3DQEJEAIvMYHqMIHnMIHkMIG9BCCVQq+Qu+/h/BOVP4wweUwbHuCUhh+T7hq3
# d5MCaNEtYjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMz
# AAAB/Bigr8xpWoc6AAEAAAH8MCIEIMOVjbwdlrNBErScgAVHOreIGYbkZy35Nwez
# RIeP1hlgMA0GCSqGSIb3DQEBCwUABIICAAL6JvrrRMPVoTyX0Ls9ImX63VJlKl/+
# 9RNCWXUWXzNDoOAvEBzuA2jGYbvdB8pWku4Q8QeCuOBUF5AL9cwTTr4Zi4shLuZc
# ch8C9uFYD2dzuZDqPlyqn2NKSDFJqyUSoelqAyeMJVTPqYykz/s+Mqxyk6yHMRd9
# GsEpY7gw5Eg3NzAeymXgBrGZS/YvfUCySiTQt/UtQDwnOHX6IcePYHyzHlJ9FEyE
# fMB4iUqVaLmQuRfr989bmR2QC+u5/4aS4zQlYhW4rHI0A9vRzy0Ej41vCRk/HrK3
# qeEGSQ05LkwMUl3ecgKimTms0qlfgrz35fSmkQ1Hnu5TukWgFdD8Ivkn/OaUpzEY
# r1i4W8v6aIvmZcDSmn15g+w6U/OGedK6WKFLUAY9+iKdGZNQj9QLt6YYxrQIsmhp
# 86bt7udh+SOGSpMc/s1lC8xAs3pSM+FI/+Yc5uURrvqgsZu4y/xpm/ACOV0LuSS/
# 8zY800+bEZMXZkwIfsBv2Spo11flHigy0W4Vv0K4TSxvWtBQWmRiJW3kiQJihVvC
# 9dwi74fmMzq9Mw96hm2G7pqdkP99k1dxzStGGQ43/UiHO7QZPZLoDEG3yw9ntJDk
# Z7q2VVZMT0hsGC/wbT9mKJUg+Hm17vylFTTEN1sCxLTnh1dqS8fqvdT3WPBxEOiq
# Md8RJePCjWfw
# SIG # End signature block
