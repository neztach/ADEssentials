﻿function Invoke-ADEssentials {
    <#
    .SYNOPSIS
    This command invokes ADEssentials to perform essential Active Directory operations and generates reports.

    .DESCRIPTION
    This command runs ADEssentials to perform essential Active Directory operations and generates reports. It supports the option to include specific domains for the operations.

    .PARAMETER FilePath
    Specifies the path to the folder where the generated reports will be saved.

    .PARAMETER Type
    Specifies the type of operations to perform. If not specified, all supported types will be performed.

    .PARAMETER PassThru
    If specified, the command returns the generated reports.

    .PARAMETER HideHTML
    If specified, the HTML report will not be displayed.

    .PARAMETER HideSteps
    If specified, the steps of the operations will not be displayed.

    .PARAMETER ShowError
    If specified, any errors during the operations will be displayed.

    .PARAMETER ShowWarning
    If specified, any warnings during the operations will be displayed.

    .PARAMETER Forest
    Specifies the name of the forest to perform the operations. If not specified, the current forest will be used.

    .PARAMETER ExcludeDomains
    Specifies an array of domain names to exclude from the operations.

    .PARAMETER IncludeDomains
    Specifies an array of domain names to include in the operations. If not specified, all domains will be included.

    .PARAMETER Online
    If specified, the command will perform the operations online.

    .PARAMETER SplitReports
    If specified, the command will generate separate reports for each type of operation.

    .EXAMPLE
    Invoke-ADEssentials -FilePath "C:\Reports" -Type "UserManagement" -PassThru -HideHTML -HideSteps -ShowError -ShowWarning -Forest "example.com" -ExcludeDomains "subdomain.example.com" -IncludeDomains "example.com" -Online -SplitReports

    This example runs ADEssentials to perform user management operations on the "example.com" domain and generates separate reports for each operation type. The reports are saved to "C:\Reports" and the HTML report is not displayed.

    .NOTES
    This cmdlet requires the ADEssentials PowerShell module to be installed and imported.
    #>
    [cmdletBinding()]
    param(
        [string] $FilePath,
        [Parameter(Position = 0)][string[]] $Type,
        [switch] $PassThru,
        [switch] $HideHTML,
        [switch] $HideSteps,
        [switch] $ShowError,
        [switch] $ShowWarning,
        [alias('ForestName')][string] $Forest,
        [string[]] $ExcludeDomains,
        [alias('Domain', 'Domains')][string[]] $IncludeDomains,
        [switch] $Online,
        [switch] $SplitReports
    )
    Reset-ADEssentialsStatus

    #$Script:AllUsers = [ordered] @{}
    $Script:Cache = [ordered] @{}
    $Script:Reporting = [ordered] @{}
    $Script:Reporting['Version'] = Get-GitHubVersion -Cmdlet 'Invoke-ADEssentials' -RepositoryOwner 'evotecit' -RepositoryName 'ADEssentials'
    $Script:Reporting['Settings'] = @{
        ShowError   = $ShowError.IsPresent
        ShowWarning = $ShowWarning.IsPresent
        HideSteps   = $HideSteps.IsPresent
    }

    Write-Color '[i]', "[ADEssentials] ", 'Version', ' [Informative] ', $Script:Reporting['Version'] -Color Yellow, DarkGray, Yellow, DarkGray, Magenta

    # Verify requested types are supported
    $Supported = [System.Collections.Generic.List[string]]::new()
    [Array] $NotSupported = foreach ($T in $Type) {
        if ($T -notin $Script:ADEssentialsConfiguration.Keys ) {
            $T
        } else {
            $Supported.Add($T)
        }
    }
    if ($Supported) {
        Write-Color '[i]', "[ADEssentials] ", 'Supported types', ' [Informative] ', "Chosen by user: ", ($Supported -join ', ') -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
    }
    if ($NotSupported) {
        Write-Color '[i]', "[ADEssentials] ", 'Not supported types', ' [Informative] ', "Following types are not supported: ", ($NotSupported -join ', ') -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
        Write-Color '[i]', "[ADEssentials] ", 'Not supported types', ' [Informative] ', "Please use one/multiple from the list: ", ($Script:ADEssentialsConfiguration.Keys -join ', ') -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
        return
    }
    $DisplayForest = if ($Forest) { $Forest } else { 'Not defined. Using current one' }
    $DisplayIncludedDomains = if ($IncludeDomains) { $IncludeDomains -join "," } else { 'Not defined. Using all domains of forest' }
    $DisplayExcludedDomains = if ($ExcludeDomains) { $ExcludeDomains -join ',' } else { 'No exclusions provided' }
    Write-Color '[i]', "[ADEssentials] ", 'Domain Information', ' [Informative] ', "Forest: ", $DisplayForest -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
    Write-Color '[i]', "[ADEssentials] ", 'Domain Information', ' [Informative] ', "Included Domains: ", $DisplayIncludedDomains -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta
    Write-Color '[i]', "[ADEssentials] ", 'Domain Information', ' [Informative] ', "Excluded Domains: ", $DisplayExcludedDomains -Color Yellow, DarkGray, Yellow, DarkGray, Yellow, Magenta

    # Lets make sure we only enable those types which are requestd by user
    if ($Type) {
        foreach ($T in $Script:ADEssentialsConfiguration.Keys) {
            $Script:ADEssentialsConfiguration[$T].Enabled = $false
        }
        # Lets enable all requested ones
        foreach ($T in $Type) {
            $Script:ADEssentialsConfiguration[$T].Enabled = $true
        }
    }

    # Build data
    foreach ($T in $Script:ADEssentialsConfiguration.Keys) {
        if ($Script:ADEssentialsConfiguration[$T].Enabled -eq $true) {
            $Script:Reporting[$T] = [ordered] @{
                Name              = $Script:ADEssentialsConfiguration[$T].Name
                ActionRequired    = $null
                Data              = $null
                Exclusions        = $null
                WarningsAndErrors = $null
                Time              = $null
                Summary           = $null
                Variables         = Copy-Dictionary -Dictionary $Script:ADEssentialsConfiguration[$T]['Variables']
            }
            if ($Exclusions) {
                if ($Exclusions -is [scriptblock]) {
                    $Script:Reporting[$T]['ExclusionsCode'] = $Exclusions
                }
                if ($Exclusions -is [Array]) {
                    $Script:Reporting[$T]['Exclusions'] = $Exclusions
                }
            }

            $TimeLogADEssentials = Start-TimeLog
            Write-Color -Text '[i]', '[Start] ', $($Script:ADEssentialsConfiguration[$T]['Name']) -Color Yellow, DarkGray, Yellow
            $OutputCommand = Invoke-Command -ScriptBlock $Script:ADEssentialsConfiguration[$T]['Execute'] -WarningVariable CommandWarnings -ErrorVariable CommandErrors -ArgumentList $Forest, $ExcludeDomains, $IncludeDomains
            if ($OutputCommand -is [System.Collections.IDictionary]) {
                # in some cases the return will be wrapped in Hashtable/orderedDictionary and we need to handle this without an array
                $Script:Reporting[$T]['Data'] = $OutputCommand
            } else {
                # since sometimes it can be 0 or 1 objects being returned we force it being an array
                $Script:Reporting[$T]['Data'] = [Array] $OutputCommand
            }
            Invoke-Command -ScriptBlock $Script:ADEssentialsConfiguration[$T]['Processing']
            $Script:Reporting[$T]['WarningsAndErrors'] = @(
                if ($ShowWarning) {
                    foreach ($War in $CommandWarnings) {
                        [PSCustomObject] @{
                            Type       = 'Warning'
                            Comment    = $War
                            Reason     = ''
                            TargetName = ''
                        }
                    }
                }
                if ($ShowError) {
                    foreach ($Err in $CommandErrors) {
                        [PSCustomObject] @{
                            Type       = 'Error'
                            Comment    = $Err
                            Reason     = $Err.CategoryInfo.Reason
                            TargetName = $Err.CategoryInfo.TargetName
                        }
                    }
                }
            )
            $TimeEndADEssentials = Stop-TimeLog -Time $TimeLogADEssentials -Option OneLiner
            $Script:Reporting[$T]['Time'] = $TimeEndADEssentials
            Write-Color -Text '[i]', '[End  ] ', $($Script:ADEssentialsConfiguration[$T]['Name']), " [Time to execute: $TimeEndADEssentials]" -Color Yellow, DarkGray, Yellow, DarkGray

            if ($SplitReports) {
                Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report for ', $T -Color Yellow, DarkGray, Yellow
                $TimeLogHTML = Start-TimeLog
                New-HTMLReportADEssentialsWithSplit -FilePath $FilePath -Online:$Online -HideHTML:$HideHTML -CurrentReport $T
                $TimeLogEndHTML = Stop-TimeLog -Time $TimeLogHTML -Option OneLiner
                Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report for', $T, " [Time to execute: $TimeLogEndHTML]" -Color Yellow, DarkGray, Yellow, DarkGray
            }
        }
    }
    if ( -not $SplitReports) {
        Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report' -Color Yellow, DarkGray, Yellow
        $TimeLogHTML = Start-TimeLog
        if (-not $FilePath) {
            $FilePath = Get-FileName -Extension 'html' -Temporary
        }
        New-HTMLReportADEssentials -Type $Type -Online:$Online.IsPresent -HideHTML:$HideHTML.IsPresent -FilePath $FilePath
        $TimeLogEndHTML = Stop-TimeLog -Time $TimeLogHTML -Option OneLiner
        Write-Color -Text '[i]', '[HTML ] ', 'Generating HTML report', " [Time to execute: $TimeLogEndHTML]" -Color Yellow, DarkGray, Yellow, DarkGray
    }
    Reset-ADEssentialsStatus
    if ($PassThru) {
        $Script:Reporting
    }
}

[scriptblock] $SourcesAutoCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $Script:ADEssentialsConfiguration.Keys | Sort-Object | Where-Object { $_ -like "*$wordToComplete*" }
}

Register-ArgumentCompleter -CommandName Invoke-ADEssentials -ParameterName Type -ScriptBlock $SourcesAutoCompleter