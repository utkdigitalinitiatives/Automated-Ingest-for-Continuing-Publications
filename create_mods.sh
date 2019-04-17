#!/bin/bash

# Remove previous file
[[ -f /tmp/MODS.xml ]] && rm -f /tmp/MODS.xml

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
eval $(parse_yaml "collection_templates/$(basename ${2}).yml")

# build the mods file
modsfile=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mods xmlns="http://www.loc.gov/mods/v3" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xlink="http://www.w3.org/1999/xlink">
  <titleInfo>
    <title>${mods_title}</title>
    <subTitle>${mods_subTitle}</subTitle>
  </titleInfo>
  <typeOfResource>text</typeOfResource>
  <originInfo>
    <dateIssued>${mods_dateIssued}</dateIssued>
    <issuance>monographic</issuance>
    <publisher>University of Tennessee Knoxville</publisher>
  </originInfo>
  <note>${mods_notes}</note>
</mods>
EOF
)

# creates the MODS file
echo "$modsfile" > "${1%.*}/MODS.xml"
