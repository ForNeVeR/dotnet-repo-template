# SPDX-FileCopyrightText: 2026 Friedrich von Never <friedrich@fornever.me>
#
# SPDX-License-Identifier: MIT

param (
    $RepoRoot = "$PSScriptRoot/..",

    [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$owner = Read-Host 'GitHub repository owner'
$repository = Read-Host 'GitHub repository'
$projectName = Read-Host 'Project name'
$description = Read-Host 'Project description'

[array] $filesToRemove = @()
function RemoveFile($file) {
    if ($WhatIf) {
        $script:filesToRemove += $file
    } else {
        Remove-Item "$RepoRoot/$file"
    }
}

$filesToReplace = @{}
function ReplaceStringInFile($path, $from, $to) {
    if ($filesToReplace.ContainsKey($path)) {
        $filesToReplace[$path] = $filesToReplace[$path].Replace($from, $to)
    } else {
        $currentContent = Get-Content -Raw "$RepoRoot/$path"
        if ($currentContent.Contains($from)) {
            $newContent = $currentContent.Replace($from, $to)
            if ($WhatIf) {
                $filesToReplace[$path] = $newContent
            } else {
                [IO.File]::WriteAllText("$RepoRoot/$path", $newContent)
            }
        }
    }
}

function ReplaceString($from, $to) {
    foreach ($path in git ls-files) {
        if ((Test-Path "$RepoRoot/$path") -and ($path -notin $script:filesToRemove)) {
            ReplaceStringInFile $path $from $to
        }
    }
}

$filesToRename = @{}
function ReplaceFileNames($from, $to) {
    $root = (Resolve-Path $RepoRoot).Path
    foreach ($path in git ls-files) {
        if ((Test-Path "$RepoRoot/$path") -and ($path -notin $script:filesToRemove)) {
            if ($path.Contains($from)) {
                $targetPath = $path.Replace($from, $to)
                if ($WhatIf) {
                    $filesToRename[$path] = $targetPath
                } else {
                    $parent = [IO.Path]::GetDirectoryName("$RepoRoot/$targetPath")
                    if (!(Test-Path $parent)) {
                        New-Item $parent -Type Directory | Out-Null
                    }

                    [IO.File]::Move("$RepoRoot/$path", "$RepoRoot/$targetPath")
                }
            }
        }
    }
}

function ReportStatus() {
    if ($WhatIf) {
        if ($filesToRemove.Count) {
            Write-Host '# Files to Remove'
            foreach ($file in $filesToRemove) {
                Write-Host "- $file"
            }
        }

        if ($filesToReplace.Count) {
            Write-Host '# Files to Replace'
            foreach ($file in $filesToReplace.GetEnumerator()) {
                Write-Host "## $($file.Name)"
                $tempFile = [IO.Path]::GetTempFileName()
                try {
                    [IO.File]::WriteAllText($tempFile, $file.Value)
                    git diff --no-index "$RepoRoot/$($file.Name)" $tempFile
                } finally {
                    Remove-Item $tempFile
                }
            }
        }

        if ($filesToRename.Count) {
            Write-Host '# Files to Rename'
            foreach ($file in $filesToRename.GetEnumerator()) {
                Write-Host "- $($file.Name) -> $($file.Value)"
            }
        }
    }
}

RemoveFile 'FVNeverDotNetTemplate/Class1.cs'
RemoveFile '.github/README.md'
RemoveFile 'scripts/Initiate.ps1'

ReplaceString 'FVNeverDotNetTemplateOwner' $owner
ReplaceString 'FVNeverDotNetTemplate' $projectName
ReplaceString 'FVNeverDotNetTemplateDescription' $description

ReplaceString "<File Path=`".github\README.md`" />" ''
ReplaceString "<File Path=`"scripts/Initiate.ps1`" />" ''

ReplaceFileNames 'FVNeverDotNetTemplate' $projectName

Read-Host "Please visit https://github.com/$owner/$repository/settings/pages and enable pages, then press Enter"
Read-Host 'Please visit https://github.com/apps/renovate/installations/new and enable Renovate for the repository, then press Enter'

ReportStatus
