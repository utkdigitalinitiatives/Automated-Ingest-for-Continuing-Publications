#!/bin/bash

cd ${3}

# $1 is the folder ie. ../islandora__bookCollection/book/issue1/001/
# $2 is the parent collection folder ie. islandora__bookCollection

# Folder name (aka page number)
page_folder=$(basename ${1})
# Removes leading zeros from string.
page_folder=$((10#$page_folder))

compiled=$(eval "cat <<EOF
$(<${3}/Automated-Ingest-for-Continuing-Publications/collection_templates/page_example_DC.xml)
EOF
" 2> /dev/null)

echo $compiled > "/tmp/${page_folder}_DC.xml"

# Format it correctly.
xmllint -format -recover "/tmp/${page_folder}_DC.xml" > "${1}DC.xml"

# cleanup
rm -f "/tmp${page_folder}_DC.xml"

# Validate against OAI 2.0
xmllint --noout --xinclude --schema http://www.openarchives.org/OAI/2.0/oai_dc.xsd "${1}/DC.xml" 2>&1 >/dev/null || echo -e "Issue with DC validation with \n\t ${1}/DC.xml" >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"

cd -
