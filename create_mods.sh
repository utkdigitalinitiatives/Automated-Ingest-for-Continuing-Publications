#!/bin/bash

# $1 is the folder ie. ../islandora__bookCollection/book/issue1/
# $2 is the parent collection folder ie. islandora__bookCollection
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
WORKING_HOME_DIR="$(dirname $(dirname $(dirname $(dirname $1))))"
[ -d "${WORKING_HOME_DIR}" ] || echo -e "MODS: Working directory doesn't exist\n\t${WORKING_HOME_DIR}" >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"
[ -d ${WORKING_HOME_DIR}/tmp ] || mkdir ${WORKING_HOME_DIR}/tmp
#[ -f ${WORKING_HOME_DIR}/tmp/oai_dc.xsd ] || curl -L "http://www.openarchives.org/OAI/2.0/oai_dc.xsd" --output "${WORKING_HOME_DIR}/tmp/oai_dc.xsd"
#[ -f ${WORKING_HOME_DIR}/tmp/oai_dc.xsd ] || echo -e "MODS: Failed to downlowd\n\t${WORKING_HOME_DIR}/tmp/oai_dc.xsd" >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"
[ -f ${WORKING_HOME_DIR}/tmp/mods-3-5.xsd ] || curl -L "http://www.loc.gov/standards/mods/v3/mods-3-5.xsd" --output "${WORKING_HOME_DIR}/tmp/mods-3-5.xsd"
[ -f ${WORKING_HOME_DIR}/tmp/mods-3-5.xsd ] || echo -e "MODS: Failed to downlowd\n\t${WORKING_HOME_DIR}/tmp/mods-3-5.xsd" >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"
[ -f ${WORKING_HOME_DIR}/tmp/simpledc20021212.xsd ] || curl -L "http://dublincore.org/schemas/xmls/simpledc20021212.xsd" --output "${WORKING_HOME_DIR}/tmp/simpledc20021212.xsd"
[ -f ${WORKING_HOME_DIR}/tmp/simpledc20021212.xsd ] || echo -e "MODS: Failed to downlowd\n\t${WORKING_HOME_DIR}/tmp/simpledc20021212.xsd" >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"

# Remove previous file
[[ -f ${WORKING_HOME_DIR}/tmp/MODS.xml ]] && rm -f ${WORKING_HOME_DIR}/tmp/MODS.xml
[[ -f ${WORKING_HOME_DIR}/tmp/$(basename ${1%.*})_MODS.xml ]] && rm -f ${WORKING_HOME_DIR}/tmp/$(basename ${1%.*})_MODS.xml
[[ -f "${1%.*}/MODS.xml" ]] && rm -f "${1%.*}/MODS.xml"

cd $DIR &>/dev/null

# Pulls the yaml values for the book issue in as variables.
[ -d $1 ] || echo -e "MODS \n\t${1} folder does not exist and cannot create MODS file." >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"
[ -d "$(dirname $WORKING_HOME_DIR)/${2}" ] || echo -e "MODS \n\t$(dirname $WORKING_HOME_DIR)/${2} parent folder does not exist and cannot create MODS file." >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"
[ -f "${1}.yml" ] || -e "MODS \n\tNo YAML file evaluated. Contact admin." >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"
[ -f "${1}.yml" ] && yaml_values_for_book=$(/bin/bash parse_yaml.sh "${1}.yml")
eval $yaml_values_for_book

# Pulls the default collection yaml values for the book issue in as variables.
compiled=$(eval "cat <<EOF
$(<${DIR}/collection_templates/$(basename ${2}).xml)
EOF
" 2> /dev/null)
echo $compiled > "${WORKING_HOME_DIR}/tmp/$(basename ${1%.*})_MODS.xml"
[ -f "${WORKING_HOME_DIR}/tmp/$(basename ${1%.*})_MODS.xml" ] || echo -e "MODS: Failed to create\n\t${WORKING_HOME_DIR}/tmp/$(basename ${1%.*})_MODS.xml" >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"

# Format it correctly.
xmllint -format -recover "${WORKING_HOME_DIR}/tmp/$(basename ${1%.*})_MODS.xml" > "${1%.*}/MODS.xml"
[ -f "${1%.*}/MODS.xml" ] || echo -e "MODS: Failed to move\n\t${1%.*}/MODS.xml" >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"

# Validate against MODS 3.5
xmllint --noout --xinclude --schema "${WORKING_HOME_DIR}/tmp/mods-3-5.xsd" "${1%.*}/MODS.xml" 2>&1 >/dev/null || echo -e "YML and/or MODS file is invalid (MODS 3.5) for \n\t ${1%.*}/MODS.xml" >> "${WORKING_HOME_DIR}/3_errors/$(basename ${2}).txt"

rm -f "${WORKING_HOME_DIR}/tmp/$(basename ${1%.*})_MODS.xml"

cd - &>/dev/null
