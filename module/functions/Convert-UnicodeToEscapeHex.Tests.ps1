# <copyright file="Convert-UnicodeToEscapeHex.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe 'Convert-UnicodeToEscapeHex' {

    Context 'When given a JSON string with unicode characters' {
        It 'Should convert unicode characters to escape hex format' {
            $inputJson = '{"key": "value with unicode: ©"}'
            $expectedOutput = '{"key":"value with unicode: \\u00a9"}'
            
            $result = Convert-UnicodeToEscapeHex -JsonString $inputJson -Compress
            
            $result | Should -BeExactly $expectedOutput
        }
    }

    Context 'When given a JSON string without unicode characters' {
        It 'Should return the original string' {
            $inputJson = '{"key": "value without unicode"}'
            $expectedOutput = '{"key":"value without unicode"}'
            
            $result = Convert-UnicodeToEscapeHex -JsonString $inputJson -Compress
            
            $result | Should -BeExactly $expectedOutput
        }
    }

    Context 'When given a JSON string and compressed output is not requested' {
        It 'Should return the original string' {
            $inputJson = '{"key": "value"}'
            $expectedOutput = @(
                '{',
                '  "key": "value"',
                '}'
            ) -join [System.Environment]::NewLine

            $result = Convert-UnicodeToEscapeHex -JsonString $inputJson
            
            $result | Should -BeExactly $expectedOutput
        }
    }

    Context 'When given an empty JSON string' {
        It 'Should return an empty string' {
            $inputJson = ''
            
            $result = Convert-UnicodeToEscapeHex -JsonString $inputJson
            
            $result | Should -BeExactly ''
        }
    }

    Context 'When given a null JSON string' {
        It 'Should return an empty string' {
            $inputJson = $null
            
            $result = Convert-UnicodeToEscapeHex -JsonString $inputJson
            
            $result | Should -BeExactly ''
        }
    }
}