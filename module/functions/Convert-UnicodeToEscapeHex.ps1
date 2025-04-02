# <copyright file="Convert-UnicodeToEscapeHex.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
    .SYNOPSIS
    Converts Unicode characters in a JSON string to their escaped hexadecimal representation, useful when passing
    unicode strings to REST APIs.

    .DESCRIPTION
    The `Convert-UnicodeToEscapeHex` function takes a JSON string as input, parses it into a PowerShell object, 
    and processes each property. If a property value is a string, it converts any Unicode characters (with a 
    decimal value greater than 127) into their escaped hexadecimal representation (e.g., `\u00E9` for "é"). 
    The modified JSON object is then converted back to a JSON string and returned.

    .PARAMETER JsonString
    A JSON-formatted string to be processed. This parameter is mandatory.

    .PARAMETER Compress
    A switch parameter that, when specified, compresses the output JSON string. If not specified, the output will be pretty-printed.

    .INPUTS
    String. The function accepts a JSON string as input.

    .OUTPUTS
    String. The function returns a JSON string with Unicode characters converted to their escaped hexadecimal representation.

    .EXAMPLE
    PS> $json = '{"Name": "Café", "Description": "A place to enjoy coffee ☕"}'
    PS> Convert-UnicodeToEscapeHex -JsonString $json
    {"Name":"Caf\u00e9","Description":"A place to enjoy coffee \u2615"}

    This example demonstrates how the function converts Unicode characters in the input JSON string to their escaped hexadecimal form.

    .NOTES
    - This function uses `ConvertFrom-Json` and `ConvertTo-Json` cmdlets to parse and serialize JSON data.
    - Unicode characters with decimal values less than or equal to 127 are not modified.
    - The function processes only string values within the JSON object.
#>

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