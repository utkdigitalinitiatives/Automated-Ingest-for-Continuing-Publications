#!/bin/bash

DRUPAL_HOME_DIR="/var/www/drupal"
clear
TODAY=$(date)
HOST=$(hostname)
TEST_RUN=false
echo -e "\n\n\n+---------------------------------------------------------------------------------------------------+"
echo "Date: $TODAY                     Host:$HOST"
echo -e "+---------------------------------------------------------------------------------------------------+\n\n"
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
cat << "EOF"
            Folder Structure

            ./automated_ingesting
              ├── completed
              ├── errors
              ├── final_check
              └── ready_for_processing
                  └── islandora__bookCollection
                      └── book
                          └── alumnus_2015spring
                              ├── 0001
                              │   └── OBJ.tif
                              ├── 0002
                              │   └── OBJ.tif
                              ├── 0003
                              │   ├── OBJ.tif
                              │   └── OCR.asc
                              ├── MODS.xml
                              ├── PRESERVATION.pdf
                              └── PDF.pdf

                  └── islandora__bookCollection
                                 ^^^^^^^^^^^^^^ Name of the parent (PID)



EOF

# Auto correct common mistakes.
# ------------------------------------------------------------------------------

# Cleanup incase of an OSX or Windows mounts create hidden files.
find . -type f -name '*.DS_Store' -ls -delete
find . -type f -name 'Thumbs.db' -ls -delete

# Find and correct spaces in the filename.
find ./automated_ingesting/ready_for_processing/ -type f -name "* *" | while read file; do mv "$file" ${file// /}; done

# Rename tiff to tif
find . -name "*.tiff" -exec bash -c 'mv "$1" "${1%.tiff}".tif' - '{}' \;


# Loop through the collections
# ------------------------------------------------------------------------------
for FOLDER in automated_ingesting/ready_for_processing/*; do
  # reset errors log file.
  rm -f automated_ingesting/errors/$(basename ${FOLDER}).txt

  # Check everything first.
  # ----------------------------------------------------------------------------

  # Empty directory found alert.
  if [[ $(find $FOLDER -type d -empty) ]]; then
    echo "Found an empty directory."
    echo -e "Found an empty directory \n\t$(find $FOLDER -type d -empty)\n" >> automated_ingesting/errors/$(basename ${FOLDER}).txt
  fi

  # Empty file found alert.
  if [[ -n $(find $FOLDER -type f -empty) ]]; then
    echo "Found an empty file."
    echo -e "Found an empty file \n\t$(find $FOLDER -type f -empty)\n" >> automated_ingesting/errors/$(basename ${FOLDER}).txt
  fi

  # Correct if filename for MODS/PDF is lowercase or the extension is uppercase.
  rename --force 's/\.([^.]+)$/.\L$1/' $FOLDER/*/*/*.*
  rename --force 's/([^.]*)/\U$1/' $FOLDER/*/*/*.*

  # Correct if filename for OBJ/OCR is lowercase or the extension is uppercase.
  rename --force 's/\.([^.]+)$/.\L$1/' $FOLDER/*/*/*/*.*
  rename --force 's/([^.]*)/\U$1/' $FOLDER/*/*/*/*.*


  # Check if folder is named correctly.
  if [[ ! "$FOLDER" == *"__"* ]]; then
    basename_for_folder="$(basename $FOLDER)"
    echo "Folder names is incorrect, renaming it."
    mv "${FOLDER}" "${FOLDER/$basename_for_folder/}${basename_for_folder/_/__}"
    FOLDER="${FOLDER/$basename_for_folder/}${basename_for_folder/_/__}"
  fi

  # Look for unexpected files inside of the ready_to_process folder
  EXTRA_FILES_FOUND=$(find $FOLDER/*  -maxdepth 0 -name \* -and -type f | wc -l)
  # Look for unexpected files inside of the collection folder.
  EXTRA_FILES_FOUND=$(( $EXTRA_FILES_FOUND + $(find $FOLDER/*/*  -maxdepth 0 -name \* -and -type f | wc -l)))

  if [[ $EXTRA_FILES_FOUND > 0 ]]; then
    # If extra files were found echo a message to a file by the collection name in the errors folder.
    [[ ! -e automated_ingesting/errors/$(basename ${FOLDER}).txt ]] && touch automated_ingesting/errors/$(basename ${FOLDER}).txt
    echo -e "${EXTRA_FILES_FOUND} Extra files found in $(basename ${FOLDER})" >> automated_ingesting/errors/$(basename ${FOLDER}).txt
  fi

  # Only directories (no files) are expected in the collection level folder.
  # Any files here will cause a failure. Checking to verify only directories.
  if [ ! -d "$FOLDER" ]; then
    echo -e "\tFile found in collection folder!\n\t$FOLDER" >> automated_ingesting/errors/${FOLDER}.txt
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
        echo "FOUND folder by the wrong name" ;;
    esac
  done # End of SUBFOLDER loop

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
        "PRESERVATION.pdf" )
          ;;
        * )
          echo -e "**** FOUND a file that shouldn't be here. **** \n"
          echo -e "$PAGE_FOLDER: not recognised" >> automated_ingesting/errors/$(basename ${FOLDER}).txt
          ;;
      esac
    fi
  done # end of for PAGE_FOLDER loop
done

# Files to expect inside a page directory.
# ------------------------------------------------------------------------------
for INSIDE_OF_PAGE_FOLDER in $FOLDER/*/*/*/*; do
  if [[ ! "$(basename ${INSIDE_OF_PAGE_FOLDER})" =~ ^OBJ.*|^OCR.*|^PDF.pdf ]]; then
    echo -e "Unexpected file \n\t${INSIDE_OF_PAGE_FOLDER}\n"  >> automated_ingesting/errors/$(basename ${FOLDER}).txt
  fi
done

# Loop through collection (Parent Islandora__PID)
# ------------------------------------------------------------------------------
for collection in automated_ingesting/ready_for_processing/*/; do
  FAILURES=0
  MESSAGES=""

  if [ -s automated_ingesting/errors/$(basename ${collection}).txt ]; then
    echo -e "\tError log is not empty and directory requires attention.\n\n"

    # move collection to error folder.
    mv "${collection}" "automated_ingesting/errors/"
    exit

  else
    echo -e "\tGeneral Checks complete without any errors.\n"

    # Check that the PID exist
    # --------------------------------------------------------------------------
    basename_of_collection=$(basename ${collection})
    status_code=$(curl --write-out %{http_code} --silent --output /dev/null "http://localhost:8000/islandora/object/${basename_of_collection/__/%3A}")
    if [[ "$status_code" -eq 200 ]] ; then
      # Book processing

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
                    echo "PAGE directories are not sequential. ${folders[$ix]}"
                    echo "PAGE directories are not sequential. ${folders[$ix]}"  >> automated_ingesting/errors/$basename_of_collection.txt
                    mv "${collection}" "automated_ingesting/errors/"
                    exit
                  fi
                fi
              fi
            fi

          done

          namespace="${basename_of_collection#*__}"
          target="$(pwd)/${collection}book"

          # If no drupal directory was found exit.
          [[ -d $DRUPAL_HOME_DIR ]] || exit

          # Ingest book
          # --------------------------------------------------------------------
          if [[ !$TEST_RUN ]]; then
            msg=$(cd $DRUPAL_HOME_DIR && drush -v -u 1 --uri=http://localhost islandora_book_batch_preprocess --create_pdfs=false --namespace=$namespace --type=directory --target=$target --output_set_id=TRUE && drush -v -u 1 --uri=http://localhost islandora_batch_ingest | grep -c '^error')
            if [[ "$msg" =~ *[error]* ]]; then
              echo -e "We have an error with the ingestion process" >> automated_ingesting/errors/$(basename ${collection}).txt
              let FAILURES=FAILURES+1
            else
              echo "Success!"
              echo -e "Compound objects ingested\n\n"
            fi

            # Not doing anything yet. Needs to tell know a way to point to the PID this should go into.
            for f in ${collection}book/*/*.pdf; do
              mkdir -p /tmp/pdfs
              cp $f "/tmp/pdfs/$(basename $(dirname $f))_$(basename ${f%.*}).pdf"
              ls /tmp/pdfs
              # drush -v -u 1 islandora_datastream_crud_push_datastreams --datastreams_source_directory=/tmp/pdfs --datastreams_mimetype=binary --datastreams_label="Preservations"
              rm -rf /tmp/pdfs
            done
          fi
        fi
      fi

      # Basic Image processing <<< TODO
      if [[ -d ${collection}basic_images2 ]]; then
        echo -e "Found ${collection}basic_images"
        namespace="${basename_of_collection#*__}"
        target="$(pwd)/${collection}book/"
        echo "drush -v -u 1 --uri=http://localhost islandora_book_batch_preprocess --namespace=$namespace --type=directory --target=$target"
        [[ -d $DRUPAL_HOME_DIR ]] || exit
        msg=$(cd $DRUPAL_HOME_DIR && drush -v -u 1 --uri=http://localhost islandora_book_batch_preprocess --namespace=$namespace --type=directory --target=$target --output_set_id=TRUE && drush -v -u 1 --uri=http://localhost islandora_batch_ingest )
        if [[ "$msg" =~ *[error]* ]]; then
          echo -e "We have an error!\n Moving data to error directory."
          let FAILURES=FAILURES+1
        else
          echo "Success!"
          echo -e "Basic Images ingested\n\n"
        fi
      fi

      # Compound Object processing <<< TODO
      if [[ -d ${collection}compound2 ]]; then
        echo -e "Found ${collection}compound"
      fi

      # Large Image processing <<< TODO
      if [[ -d ${collection}large_images ]]; then
        echo -e "Found ${collection}large_images"
        namespace="${basename_of_collection//__/:}"
        target="$(pwd)/${collection}book/"
        echo "drush -v -u 1 --uri=http://localhost islandora_book_batch_preprocess --namespace=$namespace --type=directory --target=$target"
        [[ -d $DRUPAL_HOME_DIR ]] || exit
        msg=$(cd $DRUPAL_HOME_DIR && drush -v -u 1 --uri=http://localhost islandora_batch_scan_preprocess --content_models=islandora:sp_large_image_cmodel --parent=$namespace --parent_relationship_pred=isMemberOfCollection --type=directory --target=$target && drush -v -u 1 --uri=http://localhost islandora_batch_ingest )
        if [[ "$msg" =~ error* ]]; then
          echo -e "We have an error!\n Moving data to error directory."
          let FAILURES=FAILURES+1
        else
          echo "Success!"
          echo -e "Large Images ingested\n\n $msg\n\n\n\n\n\n"
        fi
      fi

    else
      MESSAGES += "PID unknown for $collection"
      # exit 0
      let FAILURES=FAILURES+1
    fi

    # Failure trigger action
    # --------------------------------------------------------------------------
    if [[ "$FAILURES" -gt 0 ]]; then
      echo "Failure detected with ${collection}"
      mv "${collection}" "automated_ingesting/errors/"
      echo "${MESSAGES}" >> automated_ingesting/errors/$(basename ${collection}).txt
    else
      echo -e "Everything Completed without errors.\n\n\tMoving files to 'completed' directory."
      mv "${collection}" "automated_ingesting/completed/"
      echo -e "\tMove Complete.\n\n"
    fi

  fi # End of error log check

done # End of for collection

TODAY=$(date)
HOST=$(hostname)
echo -e "\n\n\n+---------------------------------------------------------------------------------------------------+"
echo "Date: $TODAY                     Host:$HOST"
echo -e "+---------------------------------------------------------------------------------------------------+ \n\n\n\n\n"
