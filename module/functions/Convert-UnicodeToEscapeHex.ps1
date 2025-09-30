# <copyright file="Convert-UnicodeToEscapeHex.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Convert-UnicodeToEscapeHex {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $JsonString,

        [parameter()]
        [switch] $Compress
    )

    if ([string]::IsNullOrEmpty($JsonString)) {
        return ""
    }
    
    $JsonObject = ConvertFrom-Json -InputObject $JsonString
    foreach ($property in $JsonObject.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value
        if ($value -is [string]) {
            $value = [regex]::Unescape($value)
            $OutputString = ""
            foreach ($char in $value.ToCharArray()) {
                $dec = [int]$char
                if ($dec -gt 127) {
                    $hex = [convert]::ToString($dec, 16)
                    $hex = $hex.PadLeft(4, '0')
                    $OutputString += "\u$hex"
                }
                else {
                    $OutputString += $char
                }
            }
            $JsonObject.$name = $OutputString
        }
    }
    return ConvertTo-Json -InputObject $JsonObject -Compress:$Compress
}