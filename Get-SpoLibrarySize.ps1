
<#PSScriptInfo

.VERSION 0.1

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
    $RawDataCsv
)

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

Get-PnPListItem -List $LibraryName -PageSize 500 | Where-Object { $_.FieldValues.FileLeafRef -like "*.*" } | ForEach-Object {
    $FileSizeinKB = [Math]::Round(($_.FieldValues.File_x0020_Size / 1KB), 2)
    $File = Get-PnPProperty -ClientObject $_ -Property File
    $Versions = Get-PnPProperty -ClientObject $File -Property Versions
    $VersionSize = $Versions | Measure-Object -Property Size -Sum | Select-Object -expand Sum
    $VersionSizeinKB = [Math]::Round(($VersionSize / 1KB), 2)
    $TotalFileSizeKB = [Math]::Round(($FileSizeinKB + $VersionSizeinKB), 2)

    $itemObject = (New-Object PSObject -Property ([Ordered]@{
                "Site Url"             = $SiteUrl
                "Library Name"         = $LibraryName
                "File Name"            = $_.FieldValues.FileLeafRef
                "File URL"             = $_.FieldValues.FileRef
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
    $result | Export-Csv -NoTypeInformation -Path $RawDataCsv -ErrorAction Stop -Force
}



