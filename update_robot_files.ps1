# Get all robot files recursively
$robotFiles = Get-ChildItem -Path "tests" -Recurse -Filter "*.robot"

foreach ($file in $robotFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Check if file already has the variables.robot resource
    if ($content -notmatch "Resource\s+\.\./\.\./Variables/variables\.robot") {
        # Add the resource line after the last Library line
        $newContent = $content -replace "(Library\s+[^\r\n]+)(?![\s\S]*Library)", "`$1`nResource          ../../Variables/variables.robot"
        
        # Remove the Variables section
        $newContent = $newContent -replace "(?ms)\*\*\* Variables \*\*\*.*?(?=\*\*\* (?:Keywords|Test Cases|Settings) \*\*\*)", ""
        
        # Write the updated content back to the file
        $newContent | Set-Content $file.FullName -NoNewline
        
        Write-Host "Updated $($file.FullName)"
    } else {
        Write-Host "Skipped $($file.FullName) - already has variables.robot resource"
    }
} 