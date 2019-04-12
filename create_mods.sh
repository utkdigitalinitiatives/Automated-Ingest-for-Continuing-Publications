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
# Pulls the yaml files in as variables
eval $(parse_yaml $1)

# build the mods file
modsfile=$(cat <<EOF
<?xml version="1.0"?>
<mods xmlns="http://www.loc.gov/mods/v3" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xlink="http://www.w3.org/1999/xlink">
  <titleInfo>
    <title>$mods_title</title>
    <subTitle>$mods_subTitle</subTitle>
  </titleInfo>
  <name type="personal">
    <namePart>$mods_namePart</namePart>
    <role>
      <roleTerm authority="marcrelator" type="text">$mods_role_text</roleTerm>
    </role>
  </name>
  <typeOfResource>text</typeOfResource>
  <genre authority="marcgt">$mods_text</genre>
  <tableOfContents/>
  <originInfo>
    <dateIssued>$mods_dateIssued</dateIssued>
    <copyrightDate>$mods_copyrightDate</copyrightDate>
    <issuance>monographic</issuance>
    <edition>$mods_edition</edition>
    <publisher>$mods_publisher</publisher>
    <place>
      <placeTerm authority="marccountry">$mods_place__text</placeTerm>
    </place>
    <place>
      <placeTerm type="text">Kiwa</placeTerm>
    </place>
  </originInfo>
  <language>
    <languageTerm authority="iso639-2b" type="code">eng</languageTerm>
  </language>
  <abstract>$mods_abstract</abstract>
  <identifier type="isbn"/>
  <physicalDescription>
    <form authority="marcform"/>
    <extent/>
  </physicalDescription>
  <note type="statement of responsibility"/>
  <note>Pretty amazing book</note>
  <subject>
    <topic>lobster</topic>
    <geographic/>
    <temporal/>
    <hierarchicalGeographic>
      <continent/>
      <country/>
      <province/>
      <region/>
      <county/>
      <city/>
      <citySection/>
    </hierarchicalGeographic>
    <cartographics>
      <coordinates/>
    </cartographics>
  </subject>
  <classification authority="lcc"/>
  <classification edition="21" authority="ddc"/>
</mods>
EOF
)

# creates the MODS file
echo "$modsfile" >> "${1%.*}/MODS.xml"
