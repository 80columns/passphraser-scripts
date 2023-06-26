<#
    Passphraser v1.0.0

    This program generates secure and memorable passphrases
#>

param(
    # number of words in the generated passphrase
    [Alias("w")]
    [int]$wordCount = 3,

    # print the complexity details of the generated passphrase
    [Alias("v")]
    [switch]$verbose = $false,

    [switch]$version = $false,

    [Alias("h", "?")]
    [switch]$help = $false
);

$BIGINT = [System.Numerics.BigInteger];
$MATH = [System.Math];
$RNG = [System.Security.Cryptography.RandomNumberGenerator];

$wordlistFile = "wordlist/wordlist.txt";
$numberLowerBoundInclusive = 1000;
$numberUpperBoundExclusive = 10000;
# there are 32 special characters on a US-English keyboard
$specialCharacters = [string[]](
    '`', "~", "!", "@",
    "#", "$", "%", "^",
    "&", "*", "(", ")",
    "-", "_", "+", "=",
    "[", "]", "{", "}",
    ":", ";", '"', "'",
    ",", "<", ".", ">",
    "?", "/", "|", "\"
);

function Print-Version {
    Write-Host "1.0.0";
}

function Print-Help {
    Write-Host @"
Description:
    Generates a secure and memorable passphrase

Usage:
    ./passphraser.ps1 [options]

Options:
    -w, -wordCount <wordCount>      The number of words that should be in the generated passphrase [default: 3]
    -v, -verbose                    Print the complexity details of the generated passphrase [default: False]
    -version                        Show version information
    -?, -h, -help                   Show help and usage information


"@;
}

function Get-Factorial([System.Numerics.BigInteger]$number) {
    $factorial = $number;
    $i = $BIGINT::op_Subtraction($number, 1);

    while ($BIGINT::op_GreaterThan($i, 0)) {
        $factorial = $BIGINT::op_Multiply($factorial, $i);
        $i = $BIGINT::op_Subtraction($i, 1);
    }

    return $factorial;
}

function Generate-RandomBool {
    # this call returns either a 0 or a 1
    # for more details, see https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.randomnumbergenerator.getint32?view=net-7.0
    $result = $RNG::GetInt32(0, 2);

    # 0 -> true
    # 1 -> false
    return ($result -eq 0);
}

function Generate-RandomNumber {
    # this call returns a random 4-digit year
    $number = $RNG::GetInt32($numberLowerBoundInclusive, $numberUpperBoundExclusive);

    return [System.Convert]::ToString($number);
}

function Generate-RandomSpecialCharacter {
    return $specialCharacters[$RNG::GetInt32(0, $specialCharacters.Length)];
}

function Generate-RandomWord([bool]$isLowercase, [string[]]$wordlist) {
    $word = $wordlist[$RNG::GetInt32(0, $wordlist.Length)];

    return $isLowercase ? $word : $word.ToUpper();
}

function Generate-Passphrase([int]$wordCount, [string[]]$wordlist) {
    $passphrase = [System.Text.StringBuilder]::new();
    $lowercaseWordCount = $uppercaseWordCount = $numberCount = $specialCharacterCount = $MATH::Floor($wordCount / 2);

    function Append-SpecialCharacter {
        $passphrase.Append($(Generate-RandomSpecialCharacter));
        Set-Variable -Scope 1 -Name "specialCharacterCount" -Value $($specialCharacterCount - 1);
    }

    function Append-Number {
        $passphrase.Append($(Generate-RandomNumber));
        Set-Variable -Scope 1 -Name "numberCount" -Value $($numberCount - 1);
    }

    function Append-LowercaseWord {
        $passphrase.Append($(Generate-RandomWord -isLowercase $true $wordlist));
        Set-Variable -Scope 1 -Name "lowercaseWordCount" -Value $($lowercaseWordCount - 1);
    }

    function Append-UppercaseWord {
        $passphrase.Append($(Generate-RandomWord -isLowercase $false $wordlist));
        Set-Variable -Scope 1 -Name "uppercaseWordCount" -Value $($uppercaseWordCount - 1);
    }

    # for an odd wordCount (wordCount = 2N + 1), there will be:
    #      N numbers and N + 1 special characters
    #      N uppercase words and N + 1 lowercase words

    # for an even wordCount (wordCount = 2N), there will be:
    #      N numbers and N special characters
    #      N uppercase words and N lowercase words
    if ($wordCount % 2 -eq 1) {
        $lowercaseWordCount += 1;
        $specialCharacterCount += 1;
    }

    # run the loop while there are words to append
    while (($lowercaseWordCount -gt 0) -or ($uppercaseWordCount -gt 0)) {
        if (($numberCount -gt 0) -and ($specialCharacterCount -gt 0)) {
            if ($(Generate-RandomBool)) {
                Append-SpecialCharacter | Out-Null;
            } else {
                Append-Number | Out-Null;
            }
        } elseif ($specialCharacterCount -gt 0) {
            Append-SpecialCharacter | Out-Null;
        } else {
            Append-Number | Out-Null;
        }

        if (($uppercaseWordCount -gt 0) -and ($lowercaseWordCount -gt 0)) {
            if ($(Generate-RandomBool)) {
                Append-LowercaseWord | Out-Null;
            } else {
                Append-UppercaseWord | Out-Null;
            }
        } elseif ($lowercaseWordCount -gt 0) {
            Append-LowercaseWord | Out-Null;
        } else {
            Append-UppercaseWord | Out-Null;
        }
    }

    return $passphrase.ToString();
}

function Get-PassphraseStrength([int]$wordCount, [string[]]$wordlist) {
    $specialCharacterCount = $lowercaseWordCount = ($wordCount % 2 -eq 0) ? $MATH::Floor($wordCount / 2) : ($MATH::Floor($wordCount / 2) + 1);
    $numberCount = $uppercaseWordCount = $MATH::Floor($wordCount / 2);

    # see https://en.wikipedia.org/wiki/Permutation, "Permutations of multisets"
    # or https://byjus.com/maths/permutation/, "Permutation of multi-sets"
    #
    # below we take the multiset permutation of the words, which is the same as the multiset permutation of the special characters & numbers,
    # and then multiply them together to get the total number of passphrase formats which can be generated by this program given a specific N number of words
    # this is different than taking the multiset of all items together, because there is a specific alternating order and all generated passphrases start
    # with either a special character or a number
    $wordCountFactorial = Get-Factorial $($BIGINT::new($wordCount));
    $lowercaseWordCountFactorial = Get-Factorial $($BIGINT::new($lowercaseWordCount));
    $uppercaseWordCountFactorial = Get-Factorial $($BIGINT::new($uppercaseWordCount));
    $lowercaseUppercaseWordPermutations = $BIGINT::op_Division(
        $wordCountFactorial,
        $BIGINT::op_Multiply($lowercaseWordCountFactorial, $uppercaseWordCountFactorial)
    );
    $passphraseFormatPermutations = $BIGINT::Pow($lowercaseUppercaseWordPermutations, 2);
    $passphrasePermutations = $BIGINT::op_Multiply(
        $BIGINT::op_Multiply(
            $BIGINT::Pow($wordlist.Length, $wordCount),
            $BIGINT::Pow($specialCharacters.Length, $specialCharacterCount)
        ),
        $BIGINT::op_Multiply(
            $BIGINT::Pow($numberUpperBoundExclusive - $numberLowerBoundInclusive, $numberCount),
            $passphraseFormatPermutations
        )
    );

    # this is a good explanation of password entropy calculation
    # https://crypto.stackexchange.com/a/376
    $passphraseBitEntropy = $BIGINT::Log2($passphrasePermutations);

    return $(New-Object PsObject -Property @{
        passphrasePermutations=$passphrasePermutations;
        passphraseBitEntropy=$passphraseBitEntropy
    });
}

function Get-ComparablePasswordStrength([System.Numerics.BigInteger]$passphrasePermutations) {
    $passwordLength = 12;
    $validAsciiCharacterCount = 94;
    $passwordPermutations = $BIGINT::Pow($validAsciiCharacterCount, $passwordLength);
    $previousPasswordPermutations = $passwordPermutations;

    while ($BIGINT::op_LessThan($passwordPermutations, $passphrasePermutations)) {
        $previousPasswordPermutations = $passwordPermutations;
        $passwordLength += 1;
        $passwordPermutations = $BIGINT::Pow($validAsciiCharacterCount, $passwordLength);
    }

    # previousPasswordPermutations is used here because at this point in the code passwordPermutations will be greater than passphrasePermutations
    # we need to return the maximum password permutations which is less than the passphrase permutations
    $passwordBitEntropy = $BIGINT::Log2($previousPasswordPermutations);

    return $(New-Object PsObject -Property @{
        passwordPermutations=$previousPasswordPermutations;
        passwordLength=$($passwordLength - 1);
        passwordBitEntropy=$passwordBitEntropy
    });
}

function Run-Program([int]$wordCount, [bool]$verbose) {
    if ($wordCount -lt 3) {
        $wordCount = 3;
    
        Write-Host "The -w/-wordCount parameter has a minimum value of 3`n";
    }

    $wordlist = Get-Content $wordlistFile;
    $passphrase = Generate-Passphrase $wordCount $wordlist;

    Write-Host $passphrase;

    if ($verbose) {
        $passphraseStrength = Get-PassphraseStrength $wordCount $wordlist;
        $passwordStrength = Get-ComparablePasswordStrength $passphraseStrength.passphrasePermutations;

        Write-Host "`nThis passphrase is 1 of $($passphraseStrength.passphrasePermutations.ToString("e2")) possible passphrases and has $($passphraseStrength.passphraseBitEntropy) bits of entropy";
        Write-Host "The strength of this passphrase is equivalent to or better than that of a fully-random $($passwordStrength.passwordLength)-character ASCII password, which has $($passwordStrength.passwordPermutations.ToString("e2")) possible passwords and $($passwordStrength.passwordBitEntropy) bits of entropy";
    }
}

if ($version) {
    Print-Version;
    Exit;
}

if ($help) {
    Print-Help;
    Exit;
}

Run-Program $wordCount $verbose;
