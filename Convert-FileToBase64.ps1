function Convert-FileToBase64 {
    <#
    .SYNOPSIS
        Converts the contents of a file to a Base64-encoded string.

    .DESCRIPTION
        Reads the file as raw bytes and encodes them to Base64.
        Works with any file type (images, binaries, text, executables, etc.).

    .PARAMETER Path
        The full path to the file you want to encode.

    .PARAMETER AsDataUri
        Optional switch. If specified, returns a full data URI string instead of
        pure Base64 (e.g. "data:image/png;base64,iVBORw0KGgo...").

    .EXAMPLE
        Convert-FileToBase64 -Path "C:\Photos\profile.jpg"
        # Returns pure Base64 string

    .EXAMPLE
        Convert-FileToBase64 -Path "C:\Photos\profile.jpg" -AsDataUri
        # Returns data:image/jpeg;base64,... (MIME type guessed from extension)

    .EXAMPLE
        Convert-FileToBase64 "report.pdf" | Set-Clipboard
        # Copies the Base64 directly to clipboard
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [switch]$AsDataUri
    )

    try {
        # Read all bytes at once — efficient for most files (< a few hundred MB)
        $bytes = [System.IO.File]::ReadAllBytes($Path)

        $base64 = [Convert]::ToBase64String($bytes)

        if ($AsDataUri) {
            # Guess MIME type from extension (common ones; add more if needed)
            $extension = [System.IO.Path]::GetExtension($Path).ToLower()
            $mimeMap = @{
                '.png'  = 'image/png'
                '.jpg'  = 'image/jpeg'
                '.jpeg' = 'image/jpeg'
                '.gif'  = 'image/gif'
                '.webp' = 'image/webp'
                '.pdf'  = 'application/pdf'
                '.txt'  = 'text/plain'
                '.json' = 'application/json'
                '.xml'  = 'application/xml'
            }
            $mime = $mimeMap[$extension]
            if (-not $mime) { $mime = 'application/octet-stream' }

            return "data:$mime;base64,$base64"
        }

        return $base64
    }
    catch {
        Write-Error "Failed to convert file to Base64: $($_.Exception.Message)"
        return $null
    }
}
