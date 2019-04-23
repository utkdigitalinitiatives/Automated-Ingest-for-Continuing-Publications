#!/bin/bash

# $1 is the folder ie. ../islandora__bookCollection/book/issue1/001/
# $2 is the parent collection folder ie. islandora__bookCollection

# Folder name (aka page number)
page_folder=$(basename ${1})

compiled=$(eval "cat <<EOF
$(<collection_templates/page_example_DC.xml)
EOF
" 2> /dev/null)

echo $compiled > "/tmp/${page_folder}_DC.xml"

# Format it correctly.
xmllint -format -recover "/tmp/${page_folder}_DC.xml" > "${1}/DC.xml"

# cleanup
rm -f "/tmp/$(basename ${1})_DC.xml"

# Validate against OAI 2.0
xmllint --noout --xinclude --schema http://www.openarchives.org/OAI/2.0/oai_dc.xsd "${1}/DC.xml" 2>&1 >/dev/null || echo -e "Issue with DC validation with \n\t ${1}/DC.xml" >> automated_ingesting/3_errors/$(basename ${2}).txt
