#!/bin/bash

DRUPAL_HOME_DIR="/var/www/drupal"
WORKING_HOME_DIR="/vagrant"

clear
TODAY=$(date)
HOST=$(hostname)
DRUSH=$(which drush)
TEST_RUN=false
cd $WORKING_HOME_DIR
rm -f automated_ingesting/3_errors/problems_with_start.txt

echo -e "\n\n\n+---------------------------------------------------------------------------------------------------+"
echo "Date: $TODAY                     Host:$HOST"
echo -e "+---------------------------------------------------------------------------------------------------+\n\n"
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
cat << "EOF"
            Folder Structure

            ./automated_ingesting
01.            ├── 4_completed
02.            ├── 3_errors
03.            ├── 1_final_check
04.            └── 2_ready_for_processing
05.                ├── islandora__bookCollection
06.                │   └── book
07.                │       └── issue12
08.                │           ├── 001
09.                │           │   ├── OBJ.tif
10.                │           │   └── OCR.asc
                   │           ├── 002
                   │           │   └── OBJ.tif
                   │           ├── 003
                   │           │   └── OBJ.tif
11.                │           ├── PDF.pdf
12.                │           ├── ORIGINAL.pdf
13.                │           └── MODS.xml
                   ├── islandora__sp_basic_image_collection
14.                │   └── basic
15.                │       ├── OBJ2.jpg
16.                │       ├── OBJ2.xml
                   │       ├── OBJ3.jpg
                   │       ├── OBJ3.xml
                   │       ├── SunFlowers.jpg
                   │       └── SunFlowers.xml
                   └── islandora__sp_large_image_collection
17.                    └── large_image
18.                        ├── 001001.tif
19.                        ├── 001001.xml
                           ├── 001002.tif
                           ├── 001002.xml
                           ├── 001003.jp2
                           └── 001003.xml






1. Collections folder is moved to this folder when no errors detected.
2. Collections folder is moved to this folder when errors were detected.
3. This is the folder the files are initially dropped into by the digitization department for review from the metadata librarian.
4. This is the folder the metadata librarian will move the files to when they are ready to be ingested.
5. This folder's naming convention is the PID of the parent, note the colon is replaced with 2 underscores.
                  └── islandora__bookCollection
                                 ^^^^^^^^^^^^^^ Name of the parent (PID)
6. This folder's naming convention is the content model (cModel) of the content being ingested.
          Options are: basic (basic image; jpg, png, gif, bmp), large_image (tif, jp2), book (book: tif, jp2)
                       └── book
7. Folder is ignored (name it whatever you want), this folder used to encapsulated a book object for processing. Eveything in this folder is attempted to ingest and can cause a failure if not folder structure isn't followed.
8. Is the folder for the first page
  a) Folders must be sequental
  a) Folders must start with 1 or 1 with leading zeros (example: 000001)
9. Inside page folder there must be and OBJ file with either the tif or jp2 extension (OBJ.tif)
    a) OBJ should be capital (this script will correct if not)
    a) Extension should be lowercase (this script will correct if not)
10. Is the OCR for this page (OPTIONAL)
11. PDF generated for display (this is the PDF-UA accessable version)
12. The original PDF for preservation.
13. Book level MODS for the book. Minimal information will be pasted to the pages.
14. Basic image example
15. Basic image (JPG, bmp, gif, png)
16. MODS file for the basic image. Must match the naming convention for the accompanied basic image file.
    a) Example SunFlowers.jpg must have a MODS file by the same name SunFlowers.xml
17. Large image example
15. Large image (tif, jp2)
16. MODS file for the large image. Must match the naming convention for the accompanied large image file.
        a) Example 001001.tif must have a MODS file by the same name 001001.xml









EOF

# Auto correct common mistakes.
# ------------------------------------------------------------------------------

# Check if there's anything to process.
if [[ $(find automated_ingesting/2_ready_for_processing -type d -empty) ]]; then
  echo -e "\n\n\n\nDirectory Empty\n\tnothing to process.\n\n\n\n"
  exit
elif [ -f automated_ingesting/2_ready_for_processing/*.* ]; then
  echo -e "woops, extra files in read to process folder.\n\n$(ls automated_ingesting/2_ready_for_processing/*.*)" >> automated_ingesting/3_errors/problems_with_start.txt
  exit
fi

if [[ ! -d ${DRUPAL_HOME_DIR}/sites/all/modules/islandora_datastream_crud ]]; then
  echo "islandora_datastream_crud isn't installed. ${DRUPAL_HOME_DIR}/sites/all/modules/islandora_datastream_crud"
  exit
fi

# Cleanup incase of an OSX or Windows mounts create hidden files.
find . -type f -name '*.DS_Store' -ls -delete
find . -type f -name 'Thumbs.db' -ls -delete

# Find and correct spaces in the filename.
find ./automated_ingesting/2_ready_for_processing/ -type f -name "* *" | while read file; do mv "$file" ${file// /}; done

# Rename tiff to tif
find . -name "*.tiff" -exec bash -c 'mv "$1" "${1%.tiff}".tif' - '{}' \;
# END of correct common mistakes.

# Loop through the collections
# ------------------------------------------------------------------------------
for FOLDER in automated_ingesting/2_ready_for_processing/*; do
  # reset errors log file.
  rm -f automated_ingesting/3_errors/$(basename ${FOLDER}).txt

  # Check everything first.
  # ----------------------------------------------------------------------------

  # Empty directory found alert.
  if [[ $(find $FOLDER -type d -empty) ]]; then
    echo "Found an empty directory."
    echo -e "Found an empty directory \n\t$(find $FOLDER -type d -empty)\n" >> automated_ingesting/3_errors/$(basename ${FOLDER}).txt
  fi

  # Empty file found alert.
  if [[ -n $(find $FOLDER -type f -empty) ]]; then
    echo "Found an empty file."
    echo -e "Found an empty file \n\t$(find $FOLDER -type f -empty)\n" >> automated_ingesting/3_errors/$(basename ${FOLDER}).txt
  fi

  if [[ -d $FOLDER/*/book ]]; then
    # Correct if filename for MODS/PDF is lowercase or the extension is uppercase.
    rename --force 's/\.([^.]+)$/.\L$1/' $FOLDER/*/*/*.*
    rename --force 's/([^.]*)/\U$1/' $FOLDER/*/*/*.*

    # Correct if filename for OBJ/OCR is lowercase or the extension is uppercase.
    rename --force 's/\.([^.]+)$/.\L$1/' $FOLDER/*/*/*/*.*
    rename --force 's/([^.]*)/\U$1/' $FOLDER/*/*/*/*.*

    # Look for unexpected files inside of the ready_to_process folder
    EXTRA_FILES_FOUND=$(find $FOLDER/*  -maxdepth 0 -name \* -and -type f | wc -l)
    # Look for unexpected files inside of the collection folder.
    EXTRA_FILES_FOUND=$(( $EXTRA_FILES_FOUND + $(find $FOLDER/*/*  -maxdepth 0 -name \* -and -type f | wc -l)))

    if [[ $EXTRA_FILES_FOUND > 0 ]]; then
      # If extra files were found echo a message to a file by the collection name in the errors folder.
      [[ ! -e automated_ingesting/3_errors/$(basename ${FOLDER}).txt ]] && touch automated_ingesting/3_errors/$(basename ${FOLDER}).txt
      echo -e "${EXTRA_FILES_FOUND} Extra files found in $(basename ${FOLDER})" >> automated_ingesting/3_errors/$(basename ${FOLDER}).txt
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
          "ORIGINAL.pdf" )
            ;;
          "PRE" )
            ;;
          * )
            echo -e "**** FOUND a file that shouldn't be here. **** \n"
            echo -e "$PAGE_FOLDER: not recognised" >> automated_ingesting/3_errors/$(basename ${FOLDER}).txt
            ;;
        esac
      fi
    done # end of for PAGE_FOLDER loop

    # Files to expect inside a page directory.
    # ------------------------------------------------------------------------------
    for INSIDE_OF_PAGE_FOLDER in $FOLDER/*/*/*/*; do
      if [[ ! "$(basename ${INSIDE_OF_PAGE_FOLDER})" =~ ^OBJ.*|^OCR.*|^PDF.pdf ]]; then
        echo -e "Unexpected file \n\t${INSIDE_OF_PAGE_FOLDER}\n"  >> automated_ingesting/3_errors/$(basename ${FOLDER}).txt
      fi
    done

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
    echo -e "\tFile found in collection folder!\n\t$FOLDER" >> automated_ingesting/3_errors/${FOLDER}.txt
  fi
done


# Loop through collection (Parent Islandora__PID)
# ------------------------------------------------------------------------------
for collection in automated_ingesting/2_ready_for_processing/*/; do
  unset msg
  basename_of_collection=$(basename ${collection})
  # clean out old files
  echo "" > /tmp/automated_ingestion_for_${basename_of_collection}.log
  echo "" > /tmp/automated_ingestion.log
  rm -rf /tmp/pdfs

  ADMIN_FAILURES=0
  FAILURES=0
  MESSAGES=""

  # Exit if errors in filesystem exist.
  if [ -s automated_ingesting/3_errors/$(basename ${collection}).txt ]; then
    echo -e "\tError log is not empty and directory requires attention.\n\n"

    # move collection to error folder.
    mv "${collection}" "automated_ingesting/3_errors/"
    exit

  else
    echo -e "\n\n\n\tGeneral Checks complete without any errors.\n\n"

    # Check that the PID exist
    # --------------------------------------------------------------------------

    status_code=$(curl --write-out %{http_code} --silent --output /dev/null "http://localhost:8000/islandora/object/${basename_of_collection/__/%3A}")
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
                    echo "PAGE directories are not sequential. ${folders[$ix]}"  >> automated_ingesting/3_errors/$basename_of_collection.txt
                    mv "${collection}" "automated_ingesting/3_errors/"
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
            echo "" >> /tmp/automated_ingestion.log
            book_parent="${basename_of_collection//__/:}"

            # Book queuing for ingestion.
            $($DRUSH -v --root=/var/www/drupal -u 1 --uri=http://localhost  islandora_book_batch_preprocess --create_pdfs=false --parent=$book_parent --namespace=$namespace --type=directory --target=$target --output_set_id=TRUE >> /tmp/automated_ingestion.log)
            sid_value=$(cat /tmp/automated_ingestion.log | head -2 | tail -1)

            # Locating parent PID.
            [[ $sid_value ]] && PARENT_SID=$($DRUSH -v --root=/var/www/drupal sql-query --db-prefix "SELECT parent FROM islandora_batch_queue WHERE sid=${sid_value}" | grep "[:]" | head -1)

            # Ingesting book
            $($DRUSH -v -u 1 --root=/var/www/drupal --uri=http://localhost islandora_batch_ingest >> /tmp/automated_ingestion.log)

            # Only works with one book at a time.
            for f in ${collection}book/*; do
              mkdir -p /tmp/pdfs
              # Pulls the PID from the filename of the xxxxx_ORIGINAL.pdf
              cp "${f}/ORIGINAL.pdf" "/tmp/pdfs/${PARENT_SID//:/_}_ORIGINAL.pdf"
            done

            # Ingest all files in /tmp/pdfs to their corresponding pid.
            if [[ !  $($DRUSH -u 1 --root=/var/www/drupal --uri=http://localhost -y islandora_datastream_crud_push_datastreams --datastreams_source_directory=/tmp/pdfs --datastreams_label="Original") ]]; then
              $(echo -e "Problem with ingesting $PARENT_SID ORIGINAL.pdf. \n\tThis will need to be done manually or remove $PARENT_SID and try again." >> /tmp/automated_ingestion.log)
              ADMIN_FAILURES=1
            fi

            # clean out ORIGINAL.pdf files
            rm -rf /tmp/pdfs

            msg=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Failed to ingest object.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Exception: Bad Batch.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Unknown options:.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep '\[error\]')

            if [[ $msg ]]; then
              echo -e "We have an error with the ingestion process\n\n$msg" >> automated_ingesting/3_errors/$(basename ${collection}).txt
              let FAILURES=FAILURES+1
            else
              echo -e "\tSuccess!\n\t\tBook objects ingested\n\n"
              echo "PID: ${sid_value}"
            fi
            unset msg
          fi
        fi
      fi

      # ------------------------------------------------------------------------
      # Basic Image processing
      # ------------------------------------------------------------------------
      if [[ -d ${collection}basic ]]; then
        if [ "$(ls -A ${collection}basic)" ]; then
          basic_img_namespace="${basename_of_collection#*__}"
          basic_img_target="$(pwd)/${collection}basic"
          basic_img_parent="${basename_of_collection//__/:}"

          # Check images have pairs
          echo "start ${collection}basic"
          basic_img_file_count=$(ls ${collection}basic | egrep '\.png$|\.jpg$|\.bmp$|\.gif$' | wc -l)
          basic_img_mods_count=$(ls ${collection}basic | egrep '\.xml$' | wc -l)

          # Check that the number of MODS equals the number of images.
          if [[ ! $basic_img_file_count == $basic_img_mods_count ]]; then
            echo -e "\n\tImages & MODS don't have exact matches Images:$basic_img_file_count MODS:$basic_img_mods_count\n\t\tEither missing or too many MODS files." >> automated_ingesting/3_errors/$(basename ${collection}).txt
          fi

          # Check that each image has a matching MODS file by the same name.
          for basic_image_file in $(ls ${collection}basic | egrep '\.png$|\.jpg$|\.bmp$|\.gif$'); do
            if [[ ! -f "${collection}basic/${basic_image_file%.*}.xml" ]]; then
              echo -e "\t\t${basic_image_file%.*}.xml MODS file is missing for ${basic_image_file}" >> automated_ingesting/3_errors/$(basename ${collection}).txt
            fi
          done

          # If no drupal directory was found exit.
          [[ -d $DRUPAL_HOME_DIR ]] || exit


          # Basic image ingest content
          # --------------------------------------------------------------------
          if [[ !$TEST_RUN ]]; then
            echo "" > /tmp/automated_ingestion.log
            echo "Basic -----> $basic_img_parent"
            # Basic Image queuing for ingestion.
            $($DRUSH -v --root=/var/www/drupal -u 1 --uri=http://localhost islandora_book_batch_preprocess --content_models=sp_basic_image --parent=$basic_img_parent --type=directory --target=$basic_img_target && $DRUSH -v -u 1 --root=/var/www/drupal --uri=http://localhost islandora_batch_ingest >> /tmp/automated_ingestion.log)

            msg=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Failed to ingest object.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Exception: Bad Batch.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Unknown options:.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep '\[error\]')

            if [[ $msg ]]; then
              echo -e "We have an error with the ingestion process" >> automated_ingesting/3_errors/$(basename ${collection}).txt
              let FAILURES=FAILURES+1
            else
              echo "Success!"
              echo -e "Basic Image objects ingested\n\n"
            fi
            unset msg
          fi
        fi
      fi

      # ------------------------------------------------------------------------
      # Large Image processing.
      # ------------------------------------------------------------------------
      if [[ -d ${collection}large_image ]]; then
        if [ "$(ls -A ${collection}large_image)" ]; then
          large_image_namespace="${basename_of_collection#*__}"
          large_image_target="$(pwd)/${collection}large_image/"
          large_image_parent="${basename_of_collection//__/:}"

          # Check Large images have pairs
          large_image_file_count=$(ls ${collection}large_image | egrep '\.tif$|\.jp2$' | wc -l)
          large_image_mods_count=$(ls ${collection}large_image | egrep '\.xml$' | wc -l)

          if [[ ! $large_image_file_count == $large_image_mods_count ]]; then
            echo -e "\n\tImages & MODS don't have exact matches Images:$large_image_file_count MODS:$large_image_mods_count\n\t\tEither missing or too many MODS files." >> automated_ingesting/3_errors/$(basename ${collection}).txt
          fi

          for large_image_file in $(ls ${collection}large_image | egrep '\.tif$|\.jp2$'); do
            if [[ ! -f "${collection}large_image/${large_image_file%.*}.xml" ]]; then
              echo -e "\t\t${large_image_file%.*}.xml MODS file is missing for ${large_image_file}" >> automated_ingesting/3_errors/$(basename ${collection}).txt
            fi
          done

          # If no drupal directory was found exit.
          [[ -d $DRUPAL_HOME_DIR ]] || exit

          # Large image ingest content.
          # --------------------------------------------------------------------
          if [[ !$TEST_RUN ]]; then
            echo "" > /tmp/automated_ingestion.log

            # Large Image queuing for ingestion.
            $($DRUSH -v --root=/var/www/drupal -u 1 --uri=http://localhost  islandora_batch_scan_preprocess --content_models=sp_large_image_cmodel --parent=$large_image_parent --type=directory --target=$large_image_target && $DRUSH -v -u 1 --root=/var/www/drupal --uri=http://localhost islandora_batch_ingest >> /tmp/automated_ingestion.log)

            msg=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Failed to ingest object.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Exception: Bad Batch.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep -Pzo '^.*?Unknown options:.*?(\n(?=\s).*?)*$')
            msg+=$(cat /tmp/automated_ingestion.log | grep '\[error\]')

            if [[ $msg ]]; then
              echo -e "We have an error with the ingestion process" >> automated_ingesting/3_errors/$(basename ${collection}).txt
              let FAILURES=FAILURES+1
            else
              echo "Success!"
              echo -e "Basic Image objects ingested\n\n"
            fi

          fi
        fi
      fi

    else
      MESSAGES += "PID unknown for $collection"
      let FAILURES=FAILURES+1
    fi

    # Actions for when a Failure is detected
    # --------------------------------------------------------------------------
    if [[ "$FAILURES" -gt 0 ]] || [[ "$ADMIN_FAILURES" -gt 0 ]]; then
      echo -e "\n\n\nFailure detected with ${collection}\n\t${FAILURES}\n\n"

      # Set the location where the error folder is.
      ERROR_LOCATION="automated_ingesting/3_errors/"

      # Check to see if there's a naming conflict for error directory.
      if [[ -d "automated_ingesting/3_errors/${basename_of_collection}" ]]; then
        ERROR_LOCATION="automated_ingesting/3_errors/${basename_of_collection}_NAME_CONFLICT_$(date +%N)"
      fi

      # Move to error folder.
      mv "${collection}" "${ERROR_LOCATION}"

      # Check if the error occurred after the ingestion process started.
      if [[ $ADMIN_FAILURES -eq 1 ]]; then
        # Send a warning to the log file that a SYSTEMS ADMIN is needed to correct this error and not to reattempt.
        echo -e "PLEASE CONTACT SYSTEM ADMIN.\n\tDo NOT attempt to reprocess the $(basename ${collection}) directory. This directory is set to read only until system admin has corrected the issue.\n${MESSAGES}" >> automated_ingesting/3_errors/$(basename ${collection}).txt
      else
        echo -e "${MESSAGES}" >> automated_ingesting/3_errors/$(basename ${collection}).txt
      fi

    else
      echo -e "Everything Completed without errors.\n\n\tMoving files to 'completed' directory."

      # Check to see if there's a naming conflict for completed directory.
      if [[ -d "automated_ingesting/4_completed/${basename_of_collection}" ]]; then
        mv "${collection}" "automated_ingesting/4_completed/${basename_of_collection}_NAME_CONFLICT_$(date +%N)"
      else
        mv "${collection}" "automated_ingesting/4_completed/"
      fi

      echo -e "\tMove Complete.\n\n"
    fi

  fi # End/Else of error log check
done # End of for collection

TODAY=$(date)
HOST=$(hostname)
echo -e "\n\n\n+---------------------------------------------------------------------------------------------------+"
echo "Date: $TODAY                     Host:$HOST"
echo -e "+---------------------------------------------------------------------------------------------------+ \n\n\n\n\n"
