#!/bin/bash

# $1 is the folder ie. ../islandora__bookCollection/book/issue1/
# $2 is the parent collection folder ie. islandora__bookCollection
cd ${3}

# Remove previous file
[[ -f /tmp/MODS.xml ]] && rm -f /tmp/MODS.xml
[[ -f /tmp/$(basename ${1%.*})_MODS.xml ]] && rm -f /tmp/$(basename ${1%.*})_MODS.xml
[[ -f "${1%.*}/MODS.xml" ]] && rm -f "${1%.*}/MODS.xml"

# Parce the yaml file for values
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# Pulls the yaml values for the book issue in as variables.
eval $(parse_yaml "${1}.yml")

# Pulls the default collection yaml values for the book issue in as variables.
compiled=$(eval "cat <<EOF
$(<${3}/Automated-Ingest-for-Continuing-Publications/collection_templates/$(basename ${2}).xml)
EOF
" 2> /dev/null)
echo $compiled > "/tmp/$(basename ${1%.*})_MODS.xml"

# Format it correctly.
xmllint -format -recover "/tmp/$(basename ${1%.*})_MODS.xml" > "${1%.*}/MODS.xml"

# Validate against MODS 3.5
xmllint --noout --xinclude --schema http://www.loc.gov/standards/mods/v3/mods-3-5.xsd "${1%.*}/MODS.xml" 2>&1 >/dev/null || echo -e "YML and/or MODS file is invalid (MODS 3.5) for \n\t ${1%.*}/MODS.xml" >> "${3}/3_errors/$(basename ${2}).txt"

cd -
