#!/bin/bash

# Passphraser v1.0.0
#
# This program generates secure and memorable passphrases

arguments=$(getopt --quiet --options "w:vh" --longoptions "wordCount:,verbose,version,help" -- $@)

WORD_COUNT=3  # number of words in the generated passphrase
VERBOSE=false # print the complexity details of the generated passphrase
VERSION=false
HELP=false

wordlist_file="wordlist.txt"
number_lower_bound_inclusive=1000
number_upper_bound_exclusive=10000
# there are 32 special characters on a US-English keyboard
special_characters=(
    '`' "~" "!" "@"
    "#" "$" "%" "^"
    "&" "*" "(" ")"
    "-" "_" "+" "="
    "[" "]" "{" "}"
    ":" ";" '"' "'"
    "," "<" "." ">"
    "?" "/" "|" "\\"
)

print_version() {
    echo "1.0.0"
}

print_help() {
    echo "Description:
    Generates a secure and memorable passphrase

Usage:
    ./passphraser.sh [options]

Options:
    -w, --word_count <wordCount>      The number of words that should be in the generated passphrase [default: 3]
    -v, --verbose                     Print the complexity details of the generated passphrase [default: False]
    --version                         Show version information
    -h, --help                        Show help and usage information

"
}

get_log_base_2() {
    # https://stackoverflow.com/a/7962339 and https://stackoverflow.com/a/53532113
    number=$1
    log_base_2=$(echo "x = l($number) / l(2); scale = 0; x / 1" | bc -l)

    echo $log_base_2
}

get_factorial() {
    # https://stackoverflow.com/a/3394634
    number=$1
    factorial=$(echo "define f(x) {if (x > 1) { return x * f(x-1) }; return 1 } f($number)" | BC_LINE_LENGTH=99999 bc)

    echo $factorial
}

generate_random_unsigned_int() {
    # retrieve an unsigned 64-bit random number from 8 bytes provided by /dev/urandom
    # sed is used to remove the space character(s) that od prints at the beginning of its output
    random_number=$(od --address-radix=n --read-bytes=8 --format=u8 < /dev/urandom | sed -e "s/ //g")

    echo $random_number
}

# returns 0 for true, 1 for false
generate_random_bool() {
    random_number=$(generate_random_unsigned_int)
    random_bool=$(echo "$random_number % 2" | bc)

    echo $random_bool
}

generate_random_unsigned_int_in_range() {
    lower_bound_inclusive=$1
    upper_bound_exclusive=$2
    modulus=$(echo "$upper_bound_exclusive - $lower_bound_inclusive" | bc)

    random_number=$(generate_random_unsigned_int)
    random_number_in_range=$(echo "($random_number % $modulus) + $lower_bound_inclusive" | bc)

    echo $random_number_in_range
}

generate_random_number() {
    number=$(generate_random_unsigned_int_in_range $number_lower_bound_inclusive $number_upper_bound_exclusive)

    echo $number
}

generate_random_special_character() {
    index=$(generate_random_unsigned_int_in_range 0 ${#special_characters[@]})

    echo "${special_characters[$index]}"
}

generate_random_word() {
    is_lowercase=$1
    wordlist=$2

    index=$(generate_random_unsigned_int_in_range 0 ${#wordlist[@]})
    word=${wordlist[$index]}

    if [[ $is_lowercase -eq 0 ]]
    then
        echo $word
    else
        echo ${word^^}
    fi
}

generate_passphrase() {
    word_count=$1
    wordlist=$2

    passphrase=""
    declare {lowercase_word_count,uppercase_word_count,number_count,special_character_count}=$(echo "$word_count / 2" | bc)

    # for an odd word_count (word_count = 2N + 1), there will be:
    #      N numbers and N + 1 special characters
    #      N uppercase words and N + 1 lowercase words

    # for an even word_count (word_count = 2N), there will be:
    #      N numbers and N special characters
    #      N uppercase words and N lowercase words
    if [[ $(echo "$word_count % 2" | bc) -eq 1 ]]
    then
        lowercase_word_count=$((lowercase_word_count + 1))
        special_character_count=$((special_character_count + 1))
    fi

    # run the loop while there are words to append
    while [[ $lowercase_word_count -gt 0 ]] || [[ $uppercase_word_count -gt 0 ]]
    do
        if [[ $number_count -gt 0 ]] && [[ $special_character_count -gt 0 ]]
        then
            if [[ $(generate_random_bool) -eq 0 ]]
            then
                # append a special character to the passphrase
                passphrase+=$(generate_random_special_character)
                special_character_count=$((special_character_count - 1))
            else
                # append a number to the passphrase
                passphrase+=$(generate_random_number)
                number_count=$((number_count - 1))
            fi
        elif [[ $special_character_count -gt 0 ]]
        then
            # append a special character to the passphrase
            passphrase+=$(generate_random_special_character)
            special_character_count=$((special_character_count - 1))
        else
            # append a number to the passphrase
            passphrase+=$(generate_random_number)
            number_count=$((number_count - 1))
        fi

        if [[ $uppercase_word_count -gt 0 ]] && [[ $lowercase_word_count -gt 0 ]]
        then
            if [[ $(generate_random_bool) -eq 0 ]]
            then
                # append a lowercase word to the passphrase
                passphrase+=$(generate_random_word 0 $wordlist)
                lowercase_word_count=$((lowercase_word_count - 1))
            else
                # append an uppercase word to the passphrase
                passphrase+=$(generate_random_word 1 $wordlist)
                uppercase_word_count=$((uppercase_word_count - 1))
            fi
        elif [[ $lowercase_word_count -gt 0 ]]
        then
            # append a lowercase word to the passphrase
            passphrase+=$(generate_random_word 0 $wordlist)
            lowercase_word_count=$((lowercase_word_count - 1))
        else
            # append an uppercase word to the passphrase
            passphrase+=$(generate_random_word 1 $wordlist)
            uppercase_word_count=$((uppercase_word_count - 1))
        fi
    done

    echo $passphrase
}

get_passphrase_strength() {
    word_count=$1
    wordlist=$2

    # https://stackoverflow.com/a/3953666
    declare {special_character_count,lowercase_word_count}=$([[ $((word_count % 2)) -eq 0 ]] && echo "$word_count / 2" | bc || echo "($word_count / 2) + 1" | bc)
    declare {number_count,uppercase_word_count}=$(echo "$word_count / 2" | bc)

    word_count_factorial=$(get_factorial $word_count)
    lowercase_word_count_factorial=$(get_factorial $lowercase_word_count)
    uppercase_word_count_factorial=$(get_factorial $uppercase_word_count)
    lowercase_uppercase_word_permutations=$(echo "$word_count_factorial / ($lowercase_word_count_factorial * $uppercase_word_count_factorial)" | bc)
    passphrase_format_permutations=$(echo "$lowercase_uppercase_word_permutations ^ 2" | bc)
    passphrase_permutations=$(echo "((${#wordlist[@]} ^ $word_count) * (${#special_characters[@]} ^ $special_character_count)) * ((($number_upper_bound_exclusive - $number_lower_bound_inclusive) ^ $number_count) * $passphrase_format_permutations)" | bc)

    # this is a good explanation of password entropy calculation
    # https://crypto.stackexchange.com/a/376
    passphrase_bit_entropy=$(get_log_base_2 $passphrase_permutations)

    echo $passphrase_permutations $passphrase_bit_entropy
}

get_comparable_password_strength() {
    passphrase_permutations=$1
    password_length=12
    valid_ascii_character_count=94
    password_permutations=$(echo "$valid_ascii_character_count ^ $password_length" | bc)
    previous_password_permutations=$password_permutations

    while [[ $(echo "$password_permutations < $passphrase_permutations" | bc) -eq 1 ]]
    do
        previous_password_permutations=$password_permutations
        password_length=$((password_length + 1))
        password_permutations=$(echo "$valid_ascii_character_count ^ $password_length" | bc)
    done

    echo "$password_permutations > $passphrase_permutations" >> out.txt

    # previous_password_permutations is used here because at this point in the code password_permutations will be greater than passphrase_permutations
    # we need to return the maximum password permutations which is less than the passphrase permutations
    password_bit_entropy=$(get_log_base_2 $previous_password_permutations)

    echo $previous_password_permutations $((password_length - 1)) $password_bit_entropy
}

run_program() {
    word_count=$1
    verbose=$2

    if [[ $word_count -lt 3 ]]
    then
        word_count=3

        echo -e "The -w/--word_count parameter has a minimum value of 3\n"
    fi

    readarray -t wordlist < $wordlist_file
    passphrase=$(generate_passphrase $word_count $wordlist)
    
    echo $passphrase

    if [[ $verbose = true ]]
    then
        # https://stackoverflow.com/a/39063403
        read passphrase_permutations passphrase_bit_entropy < <(get_passphrase_strength $word_count $wordlist)
        read password_permutations password_length password_bit_entropy < <(get_comparable_password_strength $passphrase_permutations)

        passphrase_permutations_scientific=$(printf "%.2e" $passphrase_permutations)
        password_permutations_scientific=$(printf "%.2e" $password_permutations)

        echo -e "\nThis passphrase is 1 of $passphrase_permutations_scientific possible passphrases and has $passphrase_bit_entropy bits of entropy"
        echo "The strength of this passphrase is equivalent to or better than that of a fully-random $password_length-character ASCII password, which has $password_permutations_scientific possible passwords and $password_bit_entropy bits of entropy"
    fi
}

# https://www.shellscript.sh/examples/getopt/
eval set -- "$arguments"
while true
do
    case "$1" in
        -w | --word_count)  WORD_COUNT=$2       ;   shift 2 ;;
        -v | --verbose)     VERBOSE=true        ;   shift   ;;
        --version)          VERSION=true        ;   shift   ;;
        -h | --help)        HELP=true           ;   shift   ;;
        # a -- indicates the end of the argument list, the loop should stop processing entries if this is matched
        --) shift; break ;;
        *) ;;
    esac
done

if [[ $VERSION = true ]]
then
    print_version
    exit 0
fi

if [[ $HELP = true ]]
then
    print_help
    exit 0
fi

run_program $WORD_COUNT $VERBOSE
