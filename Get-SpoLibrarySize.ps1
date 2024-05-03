
<#PSScriptInfo

.VERSION 0.3

.GUID 7354962a-7ceb-4f6c-8910-d603fec54bac

.AUTHOR June Castillote

.COMPANYNAME june.castillote@gmail.com

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<#

.DESCRIPTION
 PowerShell script to retrieve SPO library size including version history

#>

#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="PnP.PowerShell"; ModuleVersion="2.3.0" }

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $SiteUrl,

    [Parameter(Mandatory)]
    [String]
    $LibraryName,

    [Parameter()]
    [String]
    $RawDataCsv,

    [Parameter()]
    [Switch]
    $Force
)

$PSStyle.Progress.View = 'Classic'

## Test if the output path is valid
if ($RawDataCsv) {
    $filePath = (Split-Path $RawDataCsv -Parent)
    if (-not (Test-Path (Split-Path $RawDataCsv -Parent))) {
        Write-Error "The folder '$filePath' does not exist. Specify a valid file path"
        return $null
    }
}


## Connect to SharePoint Online site. This uses the interactive web login.
try {
    Connect-PnPOnline -Url $SiteURL -Interactive -ErrorAction Stop
}
catch {
    $_.Exception.Message
    return $null
}

## Test if the library exists.
try {
    $null = Get-PnPList -Identity $LibraryName -ErrorAction Stop
}
catch {
    $_.Exception.Message
    return $null
}

## Create a generic list
$result = [System.Collections.Generic.List[System.Object]]@()

Write-Verbose "Getting all files in '$($LibraryName)' in '$($SiteUrl)'..."
$listItems = @(Get-PnPListItem -List $LibraryName -PageSize 500 | Where-Object { $_.FieldValues.FileLeafRef -like "*.*" })
Write-Verbose "Total files = $($listItems.Count)"

if ($listItems.Count -eq 0) {
    Write-Verbose "There are ZERO files in this document library."
    return $null
}

for ($i = 0 ; $i -lt $($listItems.Count) ; $i++) {
    $percentComplete = (($i + 1) * 100) / $($listItems.Count)
    Write-Progress -Activity "Site: $($SiteUrl) | Library: $($LibraryName) | File: [$($listItems[$i].FieldValues.FileLeafRef)]" -Status "Progress: $($i+1) of $($listItems.Count) ($([math]::round($percentComplete,2))%)" -PercentComplete $percentComplete -ErrorAction SilentlyContinue
    Write-Verbose $($listItems[$i].FieldValues.FileLeafRef)
    $FileSizeinKB = [Math]::Round(($listItems[$i].FieldValues.File_x0020_Size / 1KB), 2)
    $File = Get-PnPProperty -ClientObject $listItems[$i] -Property File
    $Versions = Get-PnPProperty -ClientObject $File -Property Versions
    $VersionSize = $Versions | Measure-Object -Property Size -Sum | Select-Object -expand Sum
    $VersionSizeinKB = [Math]::Round(($VersionSize / 1KB), 2)
    $TotalFileSizeKB = [Math]::Round(($FileSizeinKB + $VersionSizeinKB), 2)

    $itemObject = (New-Object PSObject -Property ([Ordered]@{
                "Site Url"             = $SiteUrl
                "Library Name"         = $LibraryName
                "File Name"            = $listItems[$i].FieldValues.FileLeafRef
                "File URL"             = $listItems[$i].FieldValues.FileRef
                "Versions"             = $Versions.Count
                "File Size (KB)"       = $FileSizeinKB
                "Version Size (KB)"    = $VersionSizeinKB
                "Total File Size (KB)" = $TotalFileSizeKB
            }))
    $result.Add($itemObject)
}

New-Object PSObject -Property ([Ordered]@{
        "Site Url"                    = $SiteUrl
        "Library Name"                = $LibraryName
        "Total File Count"            = $result.Count
        "Total File Size (KB)"        = [Math]::Round((($result | Measure-Object -Property "File Size (KB)" -Sum | Select-Object -ExpandProperty Sum) ), 2)
        "Total Version History Count" = ($result | Measure-Object -Property Versions -Sum | Select-Object -ExpandProperty Sum)
        "Total Version Size (KB)"     = [Math]::Round((($result | Measure-Object -Property "Version Size (KB)" -Sum | Select-Object -ExpandProperty Sum) ), 2)
        "Total Library Size (KB)"     = [Math]::Round((($result | Measure-Object -Property "Total File Size (KB)" -Sum | Select-Object -ExpandProperty Sum) ), 2)
    })

if ($RawDataCsv) {
    $result | Export-Csv -NoTypeInformation -Path $RawDataCsv -Append -ErrorAction Stop -Force
}



