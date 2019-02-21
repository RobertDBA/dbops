Param (
    [switch]$Batch
)

if ($PSScriptRoot) { $commandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", ""); $here = $PSScriptRoot }
else { $commandName = "_ManualExecution"; $here = (Get-Item . ).FullName }

if (!$Batch) {
    # Is not a part of the global batch => import module
    #Explicitly import the module for testing
    Import-Module "$here\..\dbops.psd1" -Force; Get-DBOModuleFileList -Type internal | ForEach-Object { . $_.FullName }
}
else {
    # Is a part of a batch, output some eye-catching happiness
    Write-Host "Running $commandName tests" -ForegroundColor Cyan
}

$workFolder = Join-Path "$here\etc" "$commandName.Tests.dbops"

$scriptFolder = Join-PSFPath -Normalize "$here\etc\sqlserver-tests"
$v1scripts = Join-Path $scriptFolder 'success'
$v2scripts = Join-Path $scriptFolder 'transactional-failure'
$newv1scripts = $v1scripts | ForEach-Object { $_.Replace("$here\etc\", '')}
$newv2scripts = $v2scripts | ForEach-Object { $_.Replace("$here\etc\", '')}
$packageName = Join-Path $workFolder 'TempDeployment.zip'
$packageNameTest = "$packageName.test.zip"

Describe "Reset-DBOPackageRoot tests" -Tag $commandName, UnitTests {
    BeforeEach {
        if ((Test-Path $workFolder) -and $workFolder -like '*.Tests.dbops') { Remove-Item $workFolder -Recurse }
        $null = New-Item $workFolder -ItemType Directory -Force
        $package = New-DBOPackage -Absolute -ScriptPath $v1scripts -Name $packageName -Build 1.0 -Force
        $package = Add-DBOBuild -Path $package -Relative -ScriptPath $v2scripts -Build 2.0
    }
    AfterEach {
        if ((Test-Path $workFolder) -and $workFolder -like '*.Tests.dbops') { Remove-Item $workFolder -Recurse }
    }
    Context "Resetting source path" {
        It "should reset path for all scripts to empty string" {
            $result = Reset-DBOPackageRoot -Path $package
            $result | Should Not Be $null
            $result.Name | Should Be (Split-Path $packageName -Leaf)
            foreach ($build in $package.Builds) {
                foreach ($script in $build.Scripts) {
                    $script.SourcePath | Should -BeIn ($newv1scripts, $newv2scripts)
                }
            }
        }
        It "should reset path for all scripts to a certain folder" {
            $result = Reset-DBOPackageRoot -Path $package -Root .\somefolder\path
            $result | Should Not Be $null
            $result.Name | Should Be (Split-Path $packageName -Leaf)
            foreach ($build in $package.Builds) {
                foreach ($script in $build.Scripts) {
                    $script.SourcePath | Should -Be "somefolder\path\$($script.PackagePath)"
                }
            }
        }
        It "should reset path for all scripts to a drive root" {
            $result = $package | Reset-DBOPackageRoot -Root C:\Folder
            $result | Should Not Be $null
            $result.Name | Should Be (Split-Path $packageName -Leaf)
            foreach ($build in $package.Builds) {
                foreach ($script in $build.Scripts) {
                    $script.SourcePath | Should -Be "C:\Folder\$($script.PackagePath)"
                }
            }
        }
        It "should reset path for scripts of one particular build to a certain folder" {
            $result = Reset-DBOPackageRoot -Path $package -Root .\somefolder\path -Build 2.0
            $result | Should Not Be $null
            $result.Name | Should Be (Split-Path $packageName -Leaf)
            $build = $package.GetBuild('1.0')
            foreach ($script in $build.Scripts) {
                $script.SourcePath | Should -BeIn $v1scripts
            }
            $build = $package.GetBuild('2.0')
            foreach ($script in $build.Scripts) {
                $script.SourcePath | Should -Be "somefolder\path\$($script.PackagePath)"
            }
        }
    }
    Context "Negative tests" {
        It "returns error when path does not exist" {
            { Reset-DBOPackageRoot -Path 'asduwheiruwnfelwefo\sdfpoijfdsf.zip' -ErrorAction Stop} | Should Throw
        }
        It "returns error when path is an empty string" {
            { Reset-DBOPackageRoot -Path '' -ErrorAction Stop} | Should Throw
        }
        It "returns error when null is pipelined" {
            { $null | Reset-DBOPackageRoot -ErrorAction Stop } | Should Throw
        }
        It "returns error when unsupported object is pipelined" {
            { @{a = 1} | Reset-DBOPackageRoot -ErrorAction Stop } | Should Throw
        }
    }
}
