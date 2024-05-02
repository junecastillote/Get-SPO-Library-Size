# System Libraries to exclude
$SystemLibraries = @(
    'Form Templates',
    'Pages',
    # 'Preservation Hold Library',
    'Site Assets',
    'Site Pages',
    'Images',
    'Site Collection Documents',
    'Site Collection Images',
    'Style Library'
)

# Define the Site URL
$SiteUrl = "https://contoso.sharepoint.com/sites/SITE_NAME"

# Get all document libraries in the site excluding system libraries
$docLibs = Get-PnPList | Where-Object {$_.BaseType -eq "DocumentLibrary" -and !$_.Hidden -and $_.Title -notin $SystemLibraries}

# Get the library size
$docLibs | ForEach-Object {.\Get-SpoLibrarySize.ps1 -SiteUrl $SiteUrl -LibraryName $_.Title}
