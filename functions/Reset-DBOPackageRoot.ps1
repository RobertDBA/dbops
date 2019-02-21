
function Reset-DBOPackageRoot {
    <#
    .SYNOPSIS
        Resets script source folder based on provided parameters

    .DESCRIPTION
        Resets and re-creates the source paths of all the scripts in the package so that their existance could be verified against a different script folder structure.
        New source path would consist of a specified root path joined with internal package path:  new\root\path\1.0\script_folder\script1.sql

    .PARAMETER Path
        Path to the existing DBOpsPackage.
        Aliases: Name, FileName, Package

    .PARAMETER Build
        Only affect certain builds

    .PARAMETER Root
        A new root folder path.

    .PARAMETER Confirm
        Prompts to confirm certain actions

    .PARAMETER WhatIf
        Shows what would happen if the command would execute, but does not actually perform the command

    .EXAMPLE
        # Reset source path of all scripts in the package to the .\Scripts folder
        Reset-DBOPackageRoot -Path MyPackage.zip -Root .\Scripts\

    .NOTES

#>
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('FileName', 'Name', 'Package')]
        [string]$Path,
        [ValidateNotNull()]
        [string]$Root = "",
        [string]$Build
    )
    Write-PSFMessage -Level Verbose -Message "Loading package information from $Path"
    $rootPath = $Root -replace '^\.\\|^\\|^\.\/|\\$|\/$', ''
    if ($package = Get-DBOPackage -Path $Path) {
        if ($Build) {
            $buildCollection = $package.GetBuild($Build)
        }
        else {
            $buildCollection = $package.GetBuilds()
        }
        foreach ($buildItem in $buildCollection) {
            foreach ($script in $buildItem.Scripts) {
                $script.SourcePath = switch ($rootPath) {
                    "" { $script.PackagePath }
                    default { Join-Path $rootPath $script.PackagePath }
                }
            }
        }
        if ($pscmdlet.ShouldProcess($package, "Saving the package")) {
            $package.Alter()
        }
        $package
    }
}