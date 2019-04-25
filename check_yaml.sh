#!/bin/bash
# Input is a string / Path for a YAML file
# output echos either pass or fail

# Check for empty values
function check_yaml {
  STATUS="pass"
  while IFS='' read -r line || [[ -n "$line" ]]; do
    # Removes space characters is only a space character is there.
    line="${line// /}"
    # Only pass the values after the delimiter ":".
    line_second_part="${line#*:}"

    if [ -z "${line_second_part}" ]; then
      STATUS="fail"
    elif [[ "${line_second_part/[ ]*\n/}" == "\"\"" ]] || [[ "${line_second_part/[ ]*\n/}" == "''" ]]; then
      STATUS="fail"
    fi

  done < "$1"

  echo $STATUS
}
# Calls funtcion with paracter.
check_yaml $1
