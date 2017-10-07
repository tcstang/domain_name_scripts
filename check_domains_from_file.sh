#!/usr/bin/env bash

# Author: Tim Tang
#
# This script is used to look for unclaimed  domain names using words
# from a file - querying Whois. Whois servers will actually serve quite 
# a lot of requests from an IP before they throttle you in which case 
# you will get failed queries. Because of this, there is a simple
# exponential backoff implementation in place so as to not skip
# potential domain names.

FIRST_WORD_DIR=first
SECOND_WORD_DIR=second
TLDs=(".uk" ".de" ".jp" ".info" ".job")

input_file=common_english.txt
output_file=please_be_there.txt

# vars for exponential backoff
EB_VALUES=(1 2 4 8 16 32 64)
EB_VALUES_COUNT="${#EB_VALUES[@]}"
eb_index=0

_get_exponential_backoff()
{
    printf ${EB_VALUES[$eb_index]}
}

_increment_eb()
{
    if [ "$eb_index" -lt "$((${EB_VALUES_COUNT}-1))" ]; then
        eb_index=$(($eb_index+1))
    fi
}

_decrement_eb()
{
    if [ "$eb_index" -gt "0" ]; then
        eb_index=$(($eb_index-1))
    fi
}

_is_domain_available()
{
    local domain=$1
    local rc="1"

    # imitates do-while in bash
    whois_result=$(whois $domain)
    while [ "$?" != "0" ]; do
        # if this loop is reached, start exponential backoff
        _increment_eb
        sleep $(_get_exponential_backoff)
        whois_result=$(whois $domain)
    done
    _decrement_eb

    if [[ ! -z "$(echo $whois_result | grep 'No match')" ]]; then
        return 0
    else
        return 1
    fi
}


for tld in ${TLDs[@]}; do
    for domain in $(cat $input_file); do
        if _is_domain_available "${domain}${tld}"; then
            echo $domain >> $output_file
        fi
    done
done
