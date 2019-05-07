#!/bin/bash

# $1 is the folder ie. ../islandora__bookCollection/book/issue1/
# $2 is the parent collection folder ie. islandora__bookCollection
cd ${3}

# Remove previous file
[[ -f /tmp/MODS.xml ]] && rm -f /tmp/MODS.xml
[[ -f /tmp/$(basename ${1%.*})_MODS.xml ]] && rm -f /tmp/$(basename ${1%.*})_MODS.xml
[[ -f "${1%.*}/MODS.xml" ]] && rm -f "${1%.*}/MODS.xml"

# Pulls the yaml values for the book issue in as variables.
[ -f "${1}.yml" ] && yaml_values_for_book=$(/bin/bash ${3}/Automated-Ingest-for-Continuing-Publications/parse_yaml.sh "${1}.yml")
eval $yaml_values_for_book

# Pulls the default collection yaml values for the book issue in as variables.
compiled=$(eval "cat <<EOF
$(<${3}/Automated-Ingest-for-Continuing-Publications/collection_templates/$(basename ${2}).xml)
EOF
" 2> /dev/null)
echo $compiled > "/tmp/$(basename ${1%.*})_MODS.xml"

# Format it correctly.
xmllint -format -recover "/tmp/$(basename ${1%.*})_MODS.xml" > "${1%.*}/MODS.xml"

# Validate against MODS 3.5
xmllint --noout --xinclude --schema "/tmp/mods-3-5.xsd" "${1%.*}/MODS.xml" 2>&1 >/dev/null || echo -e "YML and/or MODS file is invalid (MODS 3.5) for \n\t ${1%.*}/MODS.xml" >> "${3}/3_errors/$(basename ${2}).txt"

cd -
