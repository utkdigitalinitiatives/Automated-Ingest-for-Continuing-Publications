#!/bin/bash

# W3 times out during validation
seconds_to_slowdown_validation=.5
seconds_for_a_pause_validation=1

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

config_read_file() {
    (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

config_get() {
    val="$(config_read_file ${CURRENT_DIR}/config.cfg "${1}")";
    if [ "${val}" = "__UNDEFINED__" ]; then
        val="$(config_read_file config.cfg.defaults "${1}")";
    fi
    printf -- "%s" "${val}";
}

TEST_RUN=$(config_get TEST_RUN)
USERNAME=$(config_get username)
BASE_URL=$(config_get BASE_URL)
BASE_URI=$(config_get BASE_URI)
DRUPAL_HOME_DIR=$(config_get DRUPAL_HOME_DIR)
WORKING_HOME_DIR=$(config_get WORKING_HOME_DIR)
BASE_URL="${BASE_URL%/}"
BASE_URI="${BASE_URI%/}"
DRUPAL_HOME_DIR="${DRUPAL_HOME_DIR%/}"
WORKING_HOME_DIR="${WORKING_HOME_DIR%/}"
EMAIL=$(config_get EMAIL)

forced=''
if [[ $(uname) == "Linux" ]]; then
  forced=''
else
  forced='--force '
fi

if [[ $USERNAME -eq 1 ]]; then
  DRUPAL_USER='-u 1'
else
  DRUPAL_USER="--user=$USERNAME"
fi

TODAY=$(date)
HOST=$(hostname)
DRUSH=$(which drush)
DRUSH_VER=$($DRUSH --version | cut -d':' -f2 | sed 's/^[ \t]*//;s/[ \t]*$//' | sed 's/\..*$//')

if [[ $DRUSH_VER -gt 6 ]]; then
  DRUSH_VERSION_TARGET="scan_target"
else
  DRUSH_VERSION_TARGET="target"
fi

three_errors="${WORKING_HOME_DIR}/automated_ingesting/3_errors"
two_ready_for_processing="${WORKING_HOME_DIR}/automated_ingesting/2_ready_for_processing"
four_completed="${WORKING_HOME_DIR}/automated_ingesting/4_completed"
clear
MAIN_TMP="${WORKING_HOME_DIR}/tmp"
INGESTION_STARTED=0
WORKING_TMP=0
WORKING_TMP_DIR=""

# Creat a tmp directory.
[ -d ${MAIN_TMP} ] || mkdir ${MAIN_TMP}

# In case process is terminated.
function cleanup_files {
  [ -f '${MAIN_TMP}/oai_dc.xsd' ] && rm -f ${MAIN_TMP}/oai_dc.xsd
  [ -f '${MAIN_TMP}/mods-3-5.xsd' ] && rm -f ${MAIN_TMP}/mods-3-5.xsd
  [ -f '${MAIN_TMP}/simpledc20021212.xsd' ] && rm -f ${MAIN_TMP}/simpledc20021212.xsd
  [ -f '${MAIN_TMP}/*_MODS.xml' ] && rm -rf ${MAIN_TMP}/*_MODS.xml
  echo -e "\n\tProcess terminated. EXIT signal recieved.\n\n"
  echo -e "\e[33m - - - - - - exiting\033[0m\n\n"
  [ $WORKING_TMP == 0 ] || rm -rf "${WORKING_TMP_DIR}"
  rm -rf ${MAIN_TMP}
}

trap cleanup_files EXIT
if [ ! -d "${DRUPAL_HOME_DIR}" ]; then
   echo "No drupal"
   exit
fi

size_needed=$(du -s "${WORKING_HOME_DIR}/automated_ingesting/2_ready_for_processing" | cut -f 1 -d "/")
size_available=$(df --output=avail -B 1 "/" |tail -n 1)
if [[ $size_needed -gt $size_available ]]; then
  echo "Not enough space available to process"
  exit
fi

# Download xsd schema
[ -f ${MAIN_TMP}/oai_dc.xsd ] || nice -n 17 curl -L "http://www.openarchives.org/OAI/2.0/oai_dc.xsd" --output "${MAIN_TMP}/oai_dc.xsd"
[ -f ${MAIN_TMP}/mods-3-5.xsd ] || nice -n 17 curl -L "http://www.loc.gov/standards/mods/v3/mods-3-5.xsd" --output "${MAIN_TMP}/mods-3-5.xsd"
[ -f ${MAIN_TMP}/simpledc20021212.xsd ] || nice -n 17 curl -L "http://dublincore.org/schemas/xmls/simpledc20021212.xsd" --output "${MAIN_TMP}/simpledc20021212.xsd"

# Replace url with string to downloaded version.
sed -i 's#http://dublincore.org/schemas/xmls/simpledc20021212.xsd#${MAIN_TMP}/simpledc20021212.xsd#g' ${MAIN_TMP}/oai_dc.xsd

cd $WORKING_HOME_DIR &>/dev/null

rm -f ${three_errors}/problems_with_start.txt

CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
clear

echo -e "\n\n\n+---------------------------------------------------------------------------------------------------+\n"
echo -e "+---------------------------------------------------------------------------------------------------+\n\n"

cat << "EOF"



       _______       ________   _____ __     _________   ________
       ___    |      ____  _/   __  // /     __  ____/   ___  __ \
       __  /| |       __  /     _  // /_     _  /        __  /_/ /
       _  ___ |      __/ /      /__  __/     / /___      _  ____/
       /_/  |_|      /___/        /_/        \____/      /_/

                                                             islandora 7.x













EOF

echo -e "\n\n\n+---------------------------------------------------------------------------------------------------+"
echo "Date: $TODAY                     Host:$HOST"
echo -e "+---------------------------------------------------------------------------------------------------+\n\n"

# Check if xmllint is installed and install if not.
command -v xmllint >/dev/null 2>&1 || { echo -e >&2 "\n\n\n\tI require xmllint but libxml2-utils is not installed.\n\n\n\tDo you wish to install this program?\n";
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) echo "installing...."
        sudo apt-get install -y --force-yes libxml2-utils 2>&1
        break ;;
      No ) exit ;;
    esac
  done
}

command -v xmllint >/dev/null 2>&1 || { echo -e >&2 "\n\txmllint install failed. Aborting.\n\n\n\n"; exit 1;}

# Check if  all of the .sh are executable.
PLUSX=0
[ ! -x ${CURRENT_DIR}/check_collection.sh ] && let PLUSX=1
[ ! -x ${CURRENT_DIR}/check_yaml.sh ] && let PLUSX=1
[ ! -x ${CURRENT_DIR}/create_dc.sh ] && let PLUSX=1
[ ! -x ${CURRENT_DIR}/create_mods.sh ] && let PLUSX=1
[ ! -x ${CURRENT_DIR}/parse_yaml.sh ] && let PLUSX=1

[ ! $PLUSX == 0 ] && { echo -e >&2 "\n\n\n\tThis requires all of the .sh files to be executable.\n\n\n\tDo you wish to have this script correct this? This will require a sudo prompt.\n";
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) echo "Running sudo chmod +x on each script."
        sudo chmod +x ${CURRENT_DIR}/*.sh
        break ;;
      No ) echo "Run sudo chmod +x on each .sh file to correct this."
       exit ;;
    esac
  done
}

# Auto correct common mistakes.
# ------------------------------------------------------------------------------

# Check if there's anything to process.
if [[ $(find automated_ingesting/2_ready_for_processing -type d -empty) ]]; then
  echo -e "\n\n\n\nDirectory Empty\n\tnothing to process.\n\n\n\n"
  exit
elif [ -f automated_ingesting/2_ready_for_processing/*.* ]; then
  echo -e "woops, extra files in read to process folder.\n\n$(ls automated_ingesting/2_ready_for_processing/*.*)" >> ${three_errors}/problems_with_start.txt
  exit
fi

if [[ ! -d ${CURRENT_DIR}/collection_templates ]]; then
  echo "YAML templates are missing."
  exit
fi

# Cleanup incase of an OSX or Windows mounts create hidden files.
find . -type f -name '*.DS_Store' -ls -delete
find . -type f -name '*._*' -ls -delete
find . -type f -name 'Thumbs.db' -ls -delete

# Rename tiff to tif
find . -name "*.tiff" -exec bash -c 'mv "$1" "${1%.tiff}".tif' - '{}' \;
# END of correct common mistakes.

# code snippet from
# https://github.com/unc-charlotte-libraries/islandora_ingest_dragndrop
system_ready=$(ps aux 2>/dev/null |grep islandora_batch_ingest 2>/dev/null |wc -l)
if (( $system_ready == '0' || $system_ready == '1')); then
  sleep 5
  # Loop through the collections
  # ------------------------------------------------------------------------------
  for FOLDER in automated_ingesting/2_ready_for_processing/*; do
    # reset errors log file.
    rm -f ${three_errors}/$(basename ${FOLDER}).txt

    # Check everything first.
    # ----------------------------------------------------------------------------

    # Empty directory found alert.
    if [[ $(find $FOLDER -type d -empty) ]]; then
      echo "Found an empty directory."
      echo -e "Found an empty directory \n\t$(find $FOLDER -type d -empty)\n" >> ${three_errors}/$(basename ${FOLDER}).txt
    fi

    # Empty file found alert.
    if [[ -n $(find $FOLDER -type f -empty) ]]; then
      echo "Found an empty file."
      echo -e "Found an empty file \n\t$(find $FOLDER -type f -empty)\n" >> ${three_errors}/$(basename ${FOLDER}).txt
    fi

    if [[ -d $FOLDER/book ]]; then
      # Reset files.
      find $FOLDER/book -type f -name 'DC.xml' -ls -delete
      find $FOLDER/book -type f -name 'MODS.xml' -ls -delete
      echo -e "\n\nRenaming files with problematic conventions."
      # Correct if filename for MODS/PDF is lowercase or the extension is uppercase.
      rename $forced's/\.([^.]+)$/.\L$1/' $FOLDER/*/*/*.* > /dev/null 2>&1
      rename $forced's/([^.]*)/\U$1/' $FOLDER/*/*/*.* > /dev/null 2>&1

      # Correct if filename for OBJ/OCR is lowercase or the extension is uppercase.
      rename $forced's/\.([^.]+)$/.\L$1/' $FOLDER/*/*/*/*.* > /dev/null 2>&1
      rename $forced's/([^.]*)/\U$1/' $FOLDER/*/*/*/*.* > /dev/null 2>&1
      echo -e "\e[32m - - - - - - Complete \033[0m\n\n"
      # Look for unexpected files inside of the ready_to_process folder
      EXTRA_FILES_FOUND=$(find $FOLDER/* -maxdepth 0 -name \* -and -type f | wc -l)

      # Look for unexpected files inside of the collection folder.
      EXTRA_FILES_FOUND=$(( $EXTRA_FILES_FOUND + $(find $FOLDER/*/* -maxdepth 0 -name \* ! -iname "*.yml" -and -type f | wc -l)))

      if [[ $EXTRA_FILES_FOUND > 0 ]]; then
        # If extra files were found echo a message to a file by the collection name in the errors folder.
        [[ ! -e ${three_errors}/$(basename ${FOLDER}).txt ]] && touch ${three_errors}/$(basename ${FOLDER}).txt
        echo -e "${EXTRA_FILES_FOUND} Extra files found in $(basename ${FOLDER})" >> ${three_errors}/$(basename ${FOLDER}).txt
      fi

      # Verify the folder's naming convention matches the content model names.
      for SUBFOLDER in $FOLDER/*; do
        case "$(basename $SUBFOLDER)" in
          "book" )
            ;;
          "large_image" )
            ;;
          "basic" )
            ;;
          * )
            echo "FOUND ${SUBFOLDER} folder by the wrong name in $FOLDER" >> ${three_errors}/$(basename ${FOLDER}).txt
            ;;
        esac
      done # End of SUBFOLDER loop

      # Create MODS and validate.
      cd $WORKING_HOME_DIR &>/dev/null

      for YML_FILE in $FOLDER/*/*.yml; do
        # Need to combine some of this.
        if [ ! -f ${CURRENT_DIR}/collection_templates/$(basename ${FOLDER}).xml ]; then
          echo -e "Missing collection_template XML file." >> ${three_errors}/$(basename ${FOLDER}).txt
          let FAILURES=FAILURES+1
        fi
        if [[ -f ${CURRENT_DIR}/collection_templates/$(basename ${FOLDER}).yml ]]; then
          if [[ -f ${CURRENT_DIR}/collection_templates/$(basename ${FOLDER}).xml ]]; then
            if [[ $(/bin/bash ${CURRENT_DIR}/check_yaml.sh $YML_FILE) == "fail" ]];  then
              echo -e >&2 "\n\n\n\tYAML file didn't pass checks. Empty value detected.\n\n\n" >> "${three_errors}/$(basename ${FOLDER}).txt"
              let FAILURES=FAILURES+1
            fi
            /bin/bash ${CURRENT_DIR}/create_mods.sh "${WORKING_HOME_DIR}/${YML_FILE%.yml}" "${FOLDER}" "${WORKING_HOME_DIR}"
          fi
        else
          echo -e "Missing collection_template YAML file." >> ${three_errors}/$(basename ${FOLDER}).txt
          let FAILURES=FAILURES+1
        fi
      done

      # Create the DC files for each page directory.
      COUNTER=0
      for PAGE_FOLDER in $FOLDER/*/*/*/; do

        count_obj_in_folder=(`find $PAGE_FOLDER -maxdepth 1 -name "*.tif"`)
        count_obj_in_folder+=(`find $PAGE_FOLDER -maxdepth 1 -name "*.jp2"`)
        if [ ${#count_obj_in_folder[@]} -gt 1 ]; then
          echo "There are ${#count_obj_in_folder[@]} number of images in the ${PAGE_FOLDER} folder. Please remove one."  >> ${three_errors}/$(basename ${FOLDER}).txt
        else
          if [ ! -f "${PAGE_FOLDER}/OBJ.tif" ] && [ $(find $PAGE_FOLDER -maxdepth 1 -name "*.tif" | wc -l) -gt 0 ]; then
            mv $PAGE_FOLDER/*.tif $PAGE_FOLDER/OBJ.tif
          fi
          if [ ! -f "$PAGE_FOLDER/*.jp2" ] && [ $(find $PAGE_FOLDER -maxdepth 1 -name "*.jp2" | wc -l) -gt 0 ]; then
            mv $PAGE_FOLDER/*.jp2 $PAGE_FOLDER/OBJ.jp2
          fi
        fi
        unset count_obj_in_folder

        /bin/bash ${CURRENT_DIR}/create_dc.sh "${WORKING_HOME_DIR}/${PAGE_FOLDER}" "${FOLDER}" "${WORKING_HOME_DIR}"
        let COUNTER=COUNTER+1
        sleep $seconds_to_slowdown_validation
        if [[ $COUNTER -gt 30 ]]; then
          sleep $seconds_for_a_pause_validation
          let COUNTER=0
        fi

      done
      cd -  &>/dev/null
      # Page level directory checks.
      # ----------------------------------------------------------------------------
      for PAGE_FOLDER in $FOLDER/*/*/*; do
        # Page level folders should only be numeric.
        if [[ ! $(basename $PAGE_FOLDER) =~ ^[0-9]+$ ]]; then
          # Checking the the files in this Folder match the expected Naming convention.
          case "$(basename $PAGE_FOLDER)" in
            "MODS.xml" )
              ;;
            "PDF.pdf" )
              ;;
            "ORIGINAL.pdf" )
              ;;
            "ORIGINAL_EDITED.pdf" )
              ;;
            * )
              echo -e "**** FOUND a file that shouldn't be here. **** \n"
              echo -e "$PAGE_FOLDER: not recognised" >> ${three_errors}/$(basename ${FOLDER}).txt
              ;;
          esac
        fi
      done # end of for PAGE_FOLDER loop
    fi

    # Check if folder is named correctly.
    if [[ ! "$FOLDER" == *"__"* ]]; then
      basename_for_folder="$(basename $FOLDER)"
      echo "Folder names is incorrect, renaming it."
      mv "${FOLDER}" "${FOLDER/$basename_for_folder/}${basename_for_folder/_/__}"
      FOLDER="${FOLDER/$basename_for_folder/}${basename_for_folder/_/__}"
    fi

    # Only directories (no files) are expected in the collection level folder.
    # Any files here will cause a failure. Checking to verify only directories.
    if [ ! -d "$FOLDER" ]; then
      echo -e "\tFile found in collection folder!\n\t$FOLDER" >> ${three_errors}/${FOLDER}.txt
    fi
  done

  # Loop through collection (Parent Islandora__PID)
  # ------------------------------------------------------------------------------
  for collection in automated_ingesting/2_ready_for_processing/*/; do
    unset msg
    basename_of_collection=$(basename ${collection})
    # clean out old files
    [ ! -f ${MAIN_TMP}/automated_ingestion.log ] && touch ${MAIN_TMP}/automated_ingestion.log
    [ ! -f ${MAIN_TMP}/automated_ingestion.log ] || echo "" > ${MAIN_TMP}/automated_ingestion.log

    ADMIN_FAILURES=0
    FAILURES=0
    MESSAGES=""

    # Exit if errors in filesystem exist.
    if [ -s ${three_errors}/$(basename ${collection}).txt ]; then
      echo -e "\tError log is not empty and directory requires attention.\n\n"

      # move collection to error folder.
      [[ $TEST_RUN == true ]] || mv "${collection}" "${three_errors}/"
      exit

    else
      echo -e "\n\n\n\tGeneral Checks complete without any errors.\n\n"

      # Check that the PID exist
      # --------------------------------------------------------------------------

      status_code=$(nice -n 17 curl --write-out %{http_code} --silent --output /dev/null "${BASE_URL}/${basename_of_collection/__/%3A}")
      if [[ "$status_code" -eq 200 ]] ; then
        # ------------------------------------------------------------------------
        # Book processing
        # ------------------------------------------------------------------------
        if [[ -d ${collection}book ]]; then
          if [ "$(ls -A ${collection}book)" ]; then

            # Are the page folders sequential.
            # --------------------------------------------------------------------
            folders=(${collection}book/*/*)
            IFS=$'\n' sorted=($(sort <<<"${folders[*]}"))
            unset IFS
            for ix in ${!folders[*]}; do
              if [[ -d "${folders[$ix]}" ]]; then
                NUM="$(basename ${folders[$ix]})"
                NUM="$(expr $NUM + 1)"

                # Compare only if the next item is a directory.
                if [[ -d "${folders[$(($ix+1))]%[*}" ]]; then
                  if [[ "$(basename ${folders[$(($ix+1))]%[*})" == ?(-)+([0-9]) ]] ; then
                    NUMTWO="$(expr $(basename ${folders[$(($ix+1))]%[*}) + 0)"
                    if [[ ! $NUM -eq $NUMTWO ]]; then
                      echo "PAGE directories are not sequential. ${folders[$ix]}" >> ${three_errors}/$basename_of_collection.txt
                      [[ $TEST_RUN == true ]] || mv "${collection}" "${three_errors}/"
                      exit
                    fi
                  fi
                fi
              fi
            done

            namespace="${basename_of_collection#*__}"
            # If no drupal directory was found exit.
            [[ -d $DRUPAL_HOME_DIR ]] || exit

            # Ingest book
            # --------------------------------------------------------------------
            if [[ ! $TEST_RUN == true ]]; then

              echo "" >> ${MAIN_TMP}/automated_ingestion.log
              book_parent="${basename_of_collection//__/:}"

              for D in ${collection}book/*/; do
                target="${MAIN_TMP}/$(basename $FOLDER)_$(basename $D)"
                WORKING_TMP_DIR="${MAIN_TMP}/$(basename $FOLDER)_$(basename $D)/issue1/"
                mkdir -p $WORKING_TMP_DIR
                let WORKING_TMP=1


                # Create initial hashes
                images=$(find ${WORKING_HOME_DIR}/${D} -type f -name "*.tif" -o -name "*.jp2")
                for file in $images; do
                    hash_check="$(ionice -c2 sha256sum $file)"
                    echo "${hash_check%%[[:space:]]*}" >> ${MAIN_TMP}/hashes.txt
                done
                sort -o ${MAIN_TMP}/hashes.txt ${MAIN_TMP}/hashes.txt

                rsync -avz "${WORKING_HOME_DIR}/${D}" $WORKING_TMP_DIR
                if [ "$?" -eq "0" ]; then
                  echo "Done"
                else
                  echo "Error while running copying files from ${WORKING_HOME_DIR}/${D} to ${MAIN_TMP}/$(basename $FOLDER)_$(basename $D)/issue1/" >> ${three_errors}/$(basename ${collection}).txt
                  exit
                fi

                INGESTION_STARTED="${collection}"
                $($DRUSH --root=$DRUPAL_HOME_DIR -v ev 'variable_set("islandora_book_ingest_derivatives", array ("pdf" => 0, "image" => "image", "ocr" => "ocr"));')
                # Book queuing for ingestion.
                $($DRUSH -v --root=$DRUPAL_HOME_DIR $DRUPAL_USER islandora_book_batch_preprocess --parent=$book_parent --namespace=$namespace --type=directory --uri=$BASE_URI --$DRUSH_VERSION_TARGET=$target --output_set_id=TRUE >> ${MAIN_TMP}/automated_ingestion.log)

                # removes blank lines
                sed -i '/^$/d' ${MAIN_TMP}/automated_ingestion.log

                sid_value=$(cat ${MAIN_TMP}/automated_ingestion.log | head -1 | tail -1)

                # Ingesting book
                $($DRUSH -v --root=$DRUPAL_HOME_DIR $DRUPAL_USER islandora_batch_ingest >> ${MAIN_TMP}/automated_ingestion.log)
                $($DRUSH --root=$DRUPAL_HOME_DIR ev 'variable_set("islandora_book_ingest_derivatives", array ("pdf" => 0, "image" => "image", "ocr" => 0));')

                # Locating parent PID.
                QU1="SELECT id FROM islandora_batch_queue WHERE sid=${sid_value} AND parent IS NOT NULL"
                QU2="SELECT COUNT(*) FROM islandora_batch_queue WHERE sid=${sid_value} AND parent IS NOT NULL"
                [[ $sid_value ]] && BATCH_PIDS=$($DRUSH -v --root=$DRUPAL_HOME_DIR sql-query --db-prefix "$QU1" | grep "[:]")
                [[ $sid_value ]] && COUNT_PIDS=$($DRUSH -v --root=$DRUPAL_HOME_DIR sql-query --extra=--skip-column-names --db-prefix "$QU2")
                mail -s "${BATCH_PIDS} Book was ingested" $EMAIL  <<< "Ingested on ${BASE_URL}, PID: ${BATCH_PIDS}, From: ${WORKING_HOME_DIR}/${D}"
                image_count=$(find ${WORKING_HOME_DIR}/${D} -type f -name "*.tif" -o -name "*.jp2" | wc -l)
                if [[ $image_count -eq $COUNT_PIDS ]]; then
                  echo "PID count matches image count"
                else
                  echo -e "There are ${#images} images in $D and $COUNT_PIDS batch processed PIDS for pages." >> ${three_errors}/$(basename ${collection}).txt
                fi
                unset images
                BATCH_PIDS=(${BATCH_PIDS//\\n/ })
                for i in "${BATCH_PIDS[@]}"
                do
                  PAGE_STATUS=$(nice -n 17 curl --write-out %{http_code} --silent --output /dev/null "${BASE_URL}/${i}/datastream/OBJ/view")
                  [ ! $PAGE_STATUS == 200 ] && echo "PAGE PID ${i} came back with a status code of ${PAGE_STATUS}" >> ${three_errors}/$(basename ${collection}).txt
                  # Hash each PID's object to check if it was found.
                    $(nice -n 17 curl -L "${BASE_URL}/${i}/datastream/OBJ/download" --output ${MAIN_TMP}/test{i})

                    declare file="${MAIN_TMP}/hashes.txt"
                    declare regex="$(ionice -c2 sha256sum ${MAIN_TMP}/test{i})"
                    declare regex_m="${regex%%[[:space:]]*}"
                    echo -e "List of Hashes: \n$(cat $file)\n\n"
                    if grep -Fxq $regex_m $file
                        then
                            echo -e "Hash matches original\n\t${regex_m}\n\n"
                        else
                            echo -e "Page hash has no match or is duplicated.\n\t${BASE_URL}/${i}" >> ${three_errors}/$(basename ${collection}).txt
                    fi
                    rm -f ${MAIN_TMP}/test{i}
                done
                unset target
                rm -rf "${MAIN_TMP}/$(basename $FOLDER)_$(basename $D)"
                let WORKING_TMP=0
                WORKING_TMP_DIR=""
                let INGESTION_STARTED=0
                rm -f ${MAIN_TMP}/hashes.txt
              done

              # Known False alarms
              sed '/java.io.FileNotFoundException:/d' ${MAIN_TMP}/automated_ingestion.log > ${MAIN_TMP}/automated_ingestion.log

              msg=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Failed to ingest object.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Exception:.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Unknown options:.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep '\[error\]')

              if [[ $msg ]]; then
                echo -e "We have an error with the ingestion process\n\n$msg" >> ${three_errors}/$(basename ${collection}).txt
                let FAILURES=FAILURES+1
              else
                echo -e "\tSuccess!\n\t\tBook objects ingested\n\n"
                echo "PID: ${sid_value}"
              fi
              unset msg
              rm -f ${MAIN_TMP}/automated_ingestion.log
            fi
          fi
        fi

        # ------------------------------------------------------------------------
        # Basic Image processing
        # ------------------------------------------------------------------------
        sleep 5
        if [[ -d ${collection}basic ]]; then
          if [ "$(ls -A ${collection}basic)" ]; then

            basic_img_namespace="${basename_of_collection#*__}"
            basic_img_target="${WORKING_HOME_DIR}/${collection}basic"
            basic_img_parent="${basename_of_collection//__/:}"

            # Find and correct spaces in the filename.
            find $basic_img_target -type f -name "* *" | while read file; do mv "$file" ${file// /}; done

            # Check images have pairs
            echo "start ${collection}basic"
            basic_img_file_count=$(ls ${collection}basic | egrep '\.png$|\.jpg$|\.bmp$|\.gif$' | wc -l)
            basic_img_mods_count=$(ls ${collection}basic | egrep '\.xml$' | wc -l)

            # Check that the number of MODS equals the number of images.
            if [[ ! $basic_img_file_count == $basic_img_mods_count ]]; then
              echo -e "\n\tImages & MODS don't have exact matches Images:$basic_img_file_count MODS:$basic_img_mods_count\n\t\tEither missing or too many MODS files." >> ${three_errors}/$(basename ${collection}).txt
            fi

            # Check that each image has a matching MODS file by the same name.
            for basic_image_file in $(ls ${collection}basic | egrep '\.png$|\.jpg$|\.bmp$|\.gif$'); do
              if [[ ! -f "${collection}basic/${basic_image_file%.*}.xml" ]]; then
                echo -e "\t\t${basic_image_file%.*}.xml MODS file is missing for ${basic_image_file}" >> ${three_errors}/$(basename ${collection}).txt
              fi
            done

            # If no drupal directory was found exit.
            [[ -d $DRUPAL_HOME_DIR ]] || exit

            # Basic image ingest content
            # --------------------------------------------------------------------
            if [[ ! $TEST_RUN == true ]]; then
              cd $DRUPAL_HOME_DIR &>/dev/null
              echo "" > ${MAIN_TMP}/automated_ingestion.log
              echo "Basic -----> $basic_img_parent"
              INGESTION_STARTED="${collection}"
              # Basic Image queuing for ingestion.
               $($DRUSH -v --root=$DRUPAL_HOME_DIR $DRUPAL_USER islandora_batch_scan_preprocess --content_models=islandora:sp_basic_image --parent=$basic_img_parent --type=directory --uri=$BASE_URI --$DRUSH_VERSION_TARGET=$basic_img_target && $DRUSH -v --root=$DRUPAL_HOME_DIR $DRUPAL_USER islandora_batch_ingest >> ${MAIN_TMP}/automated_ingestion.log)

              msg=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Failed to ingest object.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Exception:.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Unknown options:.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep '\[error\]')

              if [[ $msg ]]; then
                echo -e "We have an error with the ingestion process" >> ${three_errors}/$(basename ${collection}).txt
                let FAILURES=FAILURES+1
              else
                echo "Success!"
                echo -e "Basic Image objects ingested\n\n"
                let INGESTION_STARTED=0
              fi
              unset msg
              cd - &>/dev/null
            fi
          fi
        fi
        # ------------------------------------------------------------------------
        # Large Image processing.
        # ------------------------------------------------------------------------
        sleep 5
        if [[ -d ${collection}large_image ]]; then
          if [ "$(ls -A ${collection}large_image)" ]; then
            large_image_namespace="${basename_of_collection#*__}"
            large_image_target="${WORKING_HOME_DIR}/${collection}large_image/"
            large_image_parent="${basename_of_collection//__/:}"

            # Find and correct spaces in the filename.
            find $large_image_target -type f -name "* *" | while read file; do mv "$file" ${file// /}; done

            # Check Large images have pairs
            large_image_file_count=$(ls ${collection}large_image | egrep '\.tif$|\.jp2$' | wc -l)
            large_image_mods_count=$(ls ${collection}large_image | egrep '\.xml$' | wc -l)

            if [[ ! $large_image_file_count == $large_image_mods_count ]]; then
              echo -e "\n\tImages & MODS don't have exact matches Images:$large_image_file_count MODS:$large_image_mods_count\n\t\tEither missing or too many MODS files." >> ${three_errors}/$(basename ${collection}).txt
            fi

            for large_image_file in $(ls ${collection}large_image | egrep '\.tif$|\.jp2$'); do
              if [[ ! -f "${collection}large_image/${large_image_file%.*}.xml" ]]; then
                echo -e "\t\t${large_image_file%.*}.xml MODS file is missing for ${large_image_file}" >> ${three_errors}/$(basename ${collection}).txt
              fi
            done

            # If no drupal directory was found exit.
            [[ -d $DRUPAL_HOME_DIR ]] || exit

            # Large image ingest content.
            # --------------------------------------------------------------------
            if [[ ! $TEST_RUN == true ]]; then
              echo "" > ${MAIN_TMP}/automated_ingestion.log
              INGESTION_STARTED="${collection}"

              # Large Image queuing for ingestion.
              $($DRUSH -v --root=$DRUPAL_HOME_DIR $DRUPAL_USER islandora_batch_scan_preprocess --content_models=islandora:sp_large_image_cmodel --parent=$large_image_parent --type=directory --uri=$BASE_URI --$DRUSH_VERSION_TARGET=$large_image_target && $DRUSH -v --root=$DRUPAL_HOME_DIR $DRUPAL_USER islandora_batch_ingest >> ${MAIN_TMP}/automated_ingestion.log)

              msg=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Failed to ingest object.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Exception:.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep -Pzo '^.*?Unknown options:.*?(\n(?=\s).*?)*$')
              msg+=$(cat ${MAIN_TMP}/automated_ingestion.log | grep '\[error\]')

              if [[ $msg ]]; then
                echo -e "We have an error with the ingestion process" >> ${three_errors}/$(basename ${collection}).txt
                let FAILURES=FAILURES+1
              else
                echo "Success!"
                echo -e "Basic Image objects ingested\n\n"
              fi
              let INGESTION_STARTED=0
            fi
          fi
        fi

      else
        MESSAGES += "PID unknown for $collection"
        echo -e "Can't check parent $collection URL\n\t Unreachable: ${BASE_URL}/${basename_of_collection/__/%3A}" >> ${MAIN_TMP}/automated_ingestion.log
        echo -e "Can't check parent $collection URL\n\t Unreachable: ${BASE_URL}/${basename_of_collection/__/%3A}" >> ${three_errors}/$(basename ${collection}).txt
        let FAILURES=FAILURES+1
      fi

      if [[ -f ${three_errors}/$(basename ${collection}).txt ]]; then
        error_stats=$(stat --printf="%s" ${three_errors}/$(basename ${collection}).txt)
        [ "${error_stats:-0}" -eq 0 ] || let FAILURES=FAILURES+1
      fi
      unset error_stats

      # Actions for when a Failure is detected
      # --------------------------------------------------------------------------
      if [[ "$FAILURES" -gt 0 ]] || [[ "$ADMIN_FAILURES" -gt 0 ]]; then
        echo -e "\n\n\nFailure detected with ${collection}\n\t${FAILURES}\n\n"

        # Check to see if there's a naming conflict for error directory.
        if [[ -d "${three_errors}/${basename_of_collection}" ]]; then
          [[ $TEST_RUN == true ]] || mv "${collection}" "${three_errors}/${basename_of_collection}_NAME_CONFLICT_$(date +%N)"
        else
          [[ $TEST_RUN == true ]] || mv "${collection}" "${three_errors}/"
        fi

        # Check if the error occurred after the ingestion process started.
        if [[ $ADMIN_FAILURES -eq 1 ]]; then
          # Send a warning to the log file that a SYSTEMS ADMIN is needed to correct this error and not to reattempt.
          echo -e "PLEASE CONTACT SYSTEM ADMIN.\n\tDo NOT attempt to reprocess the $(basename ${collection}) directory. This directory is set to read only until system admin has corrected the issue.\n${MESSAGES}" >> ${three_errors}/$(basename ${collection}).txt
        else
          echo -e "${MESSAGES}" >> ${three_errors}/$(basename ${collection}).txt
        fi
      else
        echo -e "Everything Completed Successfully.\n\n\tMoving files to 'completed' directory."

        # Check to see if there's a naming conflict for completed directory.
        if [[ -d "${four_completed}/${basename_of_collection}" ]]; then
          [[ $TEST_RUN == true ]] || mv "${collection}" "${four_completed}/${basename_of_collection}_NAME_CONFLICT_$(date +%N)"
        else
          [[ $TEST_RUN == true ]] || mv "${collection}" "${four_completed}/"
        fi

        echo -e "\tMove Complete.\n\n"
      fi
    fi # End/Else of error log check
  done # End of for collection

  # Cleanup
  cleanup_files
else
  echo "Another ingest is running. Aborting."
fi

TODAY=$(date)
HOST=$(hostname)
echo -e "\n\n\n+---------------------------------------------------------------------------------------------------+"
echo "Date: $TODAY                     Host:$HOST"
echo -e "+---------------------------------------------------------------------------------------------------+ \n\n\n\n\n"
