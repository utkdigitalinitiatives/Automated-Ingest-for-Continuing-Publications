#!/bin/bash

cd ${3}

# $1 is the folder ie. ../islandora__bookCollection/book/issue1/001/
# $2 is the parent collection folder ie. islandora__bookCollection
# #3 is the working directory

# Folder name (aka page number)
page_folder=$(basename ${1})
# Removes leading zeros from string.
page_folder=$((10#$page_folder))
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# Pulls the yaml values for the book issue in as variables.
[ -f "$(dirname ${1}).yml" ] && yaml_values_for_book=$(/bin/bash "${CURRENT_DIR}/parse_yaml.sh" "$(dirname ${1}).yml")
eval "$(echo ${yaml_values_for_book})"

compiled=$(eval "cat <<EOF
$(<${CURRENT_DIR}/collection_templates/page_example_DC.xml)
EOF
" 2> /dev/null)

echo $compiled > "/tmp/${page_folder}_DC.xml"

# Format it correctly.
xmllint -format -recover "/tmp/${page_folder}_DC.xml" > "${1}DC.xml"

# cleanup
rm -f "/tmp/*_DC.xml"

# Validate against OAI 2.0
xmllint --noout --xinclude --schema "/tmp/oai_dc.xsd" "${1}DC.xml" 2>&1 >/dev/null || echo -e "Issue with DC validation with \n\t "$(dirname ${1})"DC.xml" >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"

cd -
