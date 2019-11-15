#!/bin/bash

# $1 is the folder ie. ../islandora__bookCollection/book/issue1/001/
# $2 is the parent collection folder ie. islandora__bookCollection
# $3 is the working directory

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR &>/dev/null
WORKING_HOME_DIR="${3}"

PAGE_DC_FILE=${DIR}/collection_templates/page_example_DC.xml
[ -f "$DIR/collection_templates/$(dirname ${1}).xml" ] && PAGE_DC_FILE="$DIR/collection_templates/$(dirname ${1}).xml"
[ -f "${PAGE_DC_FILE}" ] || echo -e "DC:\n\t ${PAGE_DC_FILE} missing." >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"
# Folder name (aka page number)
page_folder="$(basename ${1})"

# Removes leading zeros from string.
page_folder=$((10#$page_folder))

# Crazy quick solution, this needs to be condensed.
mods_title=$(grep -o "<title>.*</title>" "$(dirname ${1})/MODS.xml")
mods_title=$(echo "${mods_title}" | head -1 )
mods_title=$(echo ${mods_title#"<title>"})
mods_title=$(echo ${mods_title%"</title>"})
[ "${mods_title}" == "" ] && echo -e "DC:\n\t MODS title not evaluated for\n\t\t$(dirname ${1})" >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"

TITLE_LINE_OF_EXAMPLE_DC=$(xmllint --xpath "/*[local-name()='dc']/*[local-name()='title']" $PAGE_DC_FILE | sed ':again;$!N;$!b again; s/{[^}]*}//g' | tr -d '[:space:]')

# Pulls the yaml values for the book issue in as variables.
[ -f "${3}/$(dirname ${1}).yml" ] && yaml_values_for_book=$(/bin/bash "./parse_yaml.sh" "${3}/$(dirname ${1}).yml")
eval "$(echo ${yaml_values_for_book})"

compiled=$(eval "cat <<EOF
$(<$PAGE_DC_FILE)
EOF
" 2> /dev/null)

echo $compiled > "${WORKING_HOME_DIR}/tmp/${page_folder}_DC.xml"
[ -f "${WORKING_HOME_DIR}/tmp/${page_folder}_DC.xml" ] || echo -e "DC:\n\t ${PAGE_DC_FILE} failed to create ${page_folder}_DC.xml" >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"

# Format it correctly.
xmllint -format -recover "${WORKING_HOME_DIR}/tmp/${page_folder}_DC.xml" > "${1%/}/DC.xml"
[ -f "${1%/}/DC.xml" ] || echo -e "DC:\n\t ${PAGE_DC_FILE} failed to move ${1%/}/DC.xml" >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"

TITLE_LINE_OF_DC=$(xmllint --xpath "/*[local-name()='dc']/*[local-name()='title']" "${1%/}/DC.xml" | sed ':again;$!N;$!b again; s/{[^}]*}//g' | tr -d '[:space:]')
TITLE_LINE_OF_DC=${TITLE_LINE_OF_DC//[[:digit:]]/}
[ "${TITLE_LINE_OF_DC}" == "" ] && echo -e "DC:\n\t ${PAGE_DC_FILE} failed to read title of DC file." >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"

if [ "${TITLE_LINE_OF_EXAMPLE_DC//$/}" == "${TITLE_LINE_OF_DC}" ]; then
  echo -e "The is a problem generating DC files from \n\t$(dirname ${1}).yml \n\t  with \n\t    ${PAGE_DC_FILE}." >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"
fi

# cleanup
rm -f "${WORKING_HOME_DIR}/tmp/${page_folder}_DC.xml"

# Validate against OAI 2.0
xmllint --noout --xinclude --schema "${WORKING_HOME_DIR}/automated_ingesting/tmp/dc.xsd" --schema "${WORKING_HOME_DIR}/automated_ingesting/tmp/oai_dc.xsd" "${1%/}/DC.xml" 2>&1 >/dev/null || echo -e "Issue with DC validation with \n\t "$(dirname ${1})"DC.xml" >> "${3}/automated_ingesting/3_errors/$(basename ${2}).txt"

cd - &>/dev/null
