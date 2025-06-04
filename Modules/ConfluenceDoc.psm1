# Modules/ConfluenceDoc.psm1
function New-ConfluenceDoc {
    [CmdletBinding()]
    param(
        [string[]]$Steps
    )
    # Baue das Confluence-HTML-Dokument als Here-String
    $doc = @"
<h1>progress-example.ps1 Script Documentation</h1>

<h2>Description</h2>
<p>This script executes predefined steps with a progress bar:</p>
<ul>
<li>Fetch Data – Retrieves data items.</li>
<li>Process Data – Processes each data item.</li>
<li>Export Data – Exports processed data.</li>
</ul>

<h2>Usage</h2>
{code:bash}
.\progress-example.ps1
{code}

<h2>Steps</h2>
| Step Name | Purpose |
|---|---|
"@
    # Hänge jede Schritt-Zeile als Tabellen-Eintrag an
    foreach ($step in $Steps) {
        $doc += "| $step | Description for $step. |`n"
    }
    # Gib die generierte Dokumentation zum Copy/Paste für Confluence aus
    Write-Host "`nCopy the following documentation to Confluence:`n"
    Write-Host $doc
}

# Exportiere nur New-ConfluenceDoc
Export-ModuleMember -Function New-ConfluenceDoc
