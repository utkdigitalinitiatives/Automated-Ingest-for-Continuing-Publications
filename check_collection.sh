#/bin/bash

clear
cat << "EOF"

      _      `-._     `-.     `.   \      :      /   .'     .-'     _.-'      _
       `--._     `-._    `-.    `.  `.    :    .'  .'    .-'    _.-'     _.--'
            `--._    `-._   `-.   `.  \   :   /  .'   .-'   _.-'    _.--'
      `--.__     `--._   `-._  `-.  `. `. : .' .'  .-'  _.-'   _.--'     __.--'
      __    `--.__    `--._  `-._ `-. `. \:/ .' .-' _.-'  _.--'    __.--'    __
        `--..__   `--.__   `--._ `-._`-.`_=_'.-'_.-' _.--'   __.--'   __..--'
      --..__   `--..__  `--.__  `--._`-q(-_-)p-'_.--'  __.--'  __..--'   __..--
            ``--..__  `--..__ `--.__ `-'_) (_`-' __.--' __..--'  __..--''
      ...___        ``--..__ `--..__`--/__/  \--'__..--' __..--''        ___...
            ```---...___    ``--..__`_(<_   _/)_'__..--''    ___...---'''
      ```-----....._____```---...___(__\_\_|_/__)___...---'''_____.....-----'''

EOF
OOPS="\n\n\t./check_collection.sh \$1 \$2 \$3\n\t\t\t      \$1 collection PID\n\t\t\t         \$2 /path/to/original/files/\n\t\t\t            \$3 (audio, video, book, pdf, lg OR basic)\n\n\t./check_collection.sh islandora:einstein_oro /path/to/original/files/ audio\n\n\n"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR

if [[ ! -f config.cfg ]]; then
  cp config.cfg.defaults config.cfg
fi

[ -d check_collection_logs ] || mkdir check_collection_logs

# Set Variables of where to look
COLLECTION_NAMESPACE="${1#*:}"
COLLECTION_PARENT_NAME="${1//:*/}"
if [[ $COLLECTION_PARENT_NAME == $COLLECTION_NAMESPACE ]]; then
  echo -e "$OOPS"
  exit
fi

FIND_PATTERN="$2"
PATH_NAME=$(echo ${2:1} | sed -e 's/\//_/g')
LOG_PATH_LIST="check_collection_logs/${PATH_NAME}_${3}_list.txt"
LOG_PATH_LOCAL_HASHES="check_collection_logs/${PATH_NAME}_${3}_local_hashes.txt"
LOG_PATH_LOCAL_HASHES_DUPLICATES="check_collection_logs/${PATH_NAME}_${3}_local_hashes_duplicates.txt"
LOG_PATH_LOCAL_HASH_LIST="check_collection_logs/${PATH_NAME}_${3}_local_hash_list.txt"
LOG_PATH_ERRORS="check_collection_logs/${PATH_NAME}_${3}_errors.txt"
LOG_PATH_DOWNLOADED_HASH_LIST="check_collection_logs/${PATH_NAME}_${3}_downloaded_hash_list.txt"
LOG_PATH_DOWNLOAD_HASHES="check_collection_logs/${PATH_NAME}_${3}_download_hashes.txt"
LOG_PATH_DUPLICATES="check_collection_logs/${PATH_NAME}_${3}_duplicates.txt"
LOG_PATH_MISSING="check_collection_logs/${PATH_NAME}_${3}_missing.txt"
LOG_PATH_MISSING_HASHES="check_collection_logs/${PATH_NAME}_${3}_missing_hashes.txt"
LOG_PATH_FINAL_REPORT="check_collection_logs/${PATH_NAME}_${3}_final_report.txt"

# For limiting core usages.
if [[ -f /proc/cpuinfo ]]; then
  CORE_COUNT=$(grep -c ^processor /proc/cpuinfo)
  CORE_COUNT=$(bc <<< "$CORE_COUNT - 2");
  [ $CORE_COUNT -lt 3 ] && CORE_COUNT=2
else
  CORE_COUNT=2
fi
ENDCOLORIZE="\033[0m"
# In case process is terminated.
cleanup_files() {
  remove_array=($LOG_PATH_DOWNLOADED_HASH_LIST $LOG_PATH_ERRORS $LOG_PATH_DOWNLOAD_HASHES $LOG_PATH_DUPLICATES $LOG_PATH_DOWNLOADED_HASH_LIST $LOG_PATH_DOWNLOAD_HASHES $LOG_PATH_FINAL_REPORT $LOG_PATH_MISSING_HASHES $LOG_PATH_LOCAL_HASHES_DUPLICATES $LOG_PATH_LIST)
  for rmf in ${remove_array[@]}; do
    [ -f $rmf ] && rm -f $rmf
  done
}
cleanup_files
trap cleanup_files EXIT

config_read_file() {
  (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

config_get() {
  val="$(config_read_file config.cfg "${1}")";
  printf -- "%s" "${val}";
}

has_duplicates() {
  {
    sort | uniq -d | grep . -qc
  } < "$1"
}
center_text() {
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' ={1..500})"
  printf '%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" "$1" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

DOMAIN=$(config_get CHECK_COLLECTION_DOMAIN)
SOLR_DOMAIN_AND_PORT=$(config_get CHECK_COLLECTION_SOLR_DOMAIN_AND_PORT)
COLLECTION_URL=$(config_get CHECK_COLLECTION_COLLECTION_URL)
OBJECT_URL=$(config_get BASE_URL)
FEDORAUSERNAME=$(config_get CHECK_COLLECTION_FEDORAUSERNAME)
FEDORAPASS=$(config_get CHECK_COLLECTION_FEDORAPASS)

DOMAIN="${DOMAIN%/}"
SOLR_DOMAIN_AND_PORT="${SOLR_DOMAIN_AND_PORT%/}"
COLLECTION_URL="${COLLECTION_URL%/}/${COLLECTION_PARENT_NAME}%3A"
OBJECT_URL="${OBJECT_URL%/}"
if [[ "${COLLECTION_URL}" == "__UNDEFINED__" ]]; then
  echo -e "Problem reading config file."
  exit
fi

[ -f $LOG_PATH_LIST ] && touch $LOG_PATH_LIST

case "$3" in
  audio)
    # Creating an index of pages in the given directory
    echo -e "\n\tCounting and indexing \e[36m${FIND_PATTERN}${ENDCOLORIZE} on the filesystem."
    CHECK_COLLECTION_LOCAL_FILES=$(find ${FIND_PATTERN} -type f -name "*.wav" -o -name "*.mp3")
    echo "${CHECK_COLLECTION_LOCAL_FILES}" > $LOG_PATH_LIST
    CONTENT_MODEL="&fq=%2BRELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3Asp-audioCModel"
    CHECK_COUNTING_FILES_COUNT=$(cat $LOG_PATH_LIST | sed '/^\s*$/d' | wc -l)
    echo -e "\t\t\e[32m ${CHECK_COUNTING_FILES_COUNT} ${ENDCOLORIZE}\n"
    ;;
  video)
    echo -e "\n\tCounting and indexing \e[36m${FIND_PATTERN}${ENDCOLORIZE} on the filesystem."
    CHECK_COLLECTION_LOCAL_FILES=$(find ${FIND_PATTERN} -type f -name "*.ogg" -o -name "*.mp4" -o -name "*.mov" -o -name "*.qt" -o -name "*.m4v" -o -name "*.avi" -o -name "*.mkv")
    $(echo "${CHECK_COLLECTION_LOCAL_FILES}" > $LOG_PATH_LIST)
    CONTENT_MODEL="&fq=%2BRELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3Asp_videoCModel"
    CHECK_COUNTING_FILES_COUNT=$(cat $LOG_PATH_LIST | sed '/^\s*$/d' | wc -l)
    echo -e "\t\t\e[32m ${CHECK_COUNTING_FILES_COUNT} ${ENDCOLORIZE}\n"
    ;;
  book)
    echo -e "\n\tCounting and indexing \e[36m${FIND_PATTERN}${ENDCOLORIZE} on the filesystem."
    CHECK_COLLECTION_LOCAL_FILES=$(find ${FIND_PATTERN} -type f -name "*.tif" -o -name "*.jp2")
    $(echo "${CHECK_COLLECTION_LOCAL_FILES}" > $LOG_PATH_LIST)
    CONTENT_MODEL="&fq=%2BRELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3ApageCModel"
    CHECK_COUNTING_FILES_COUNT=$(cat $LOG_PATH_LIST | sed '/^\s*$/d' | wc -l)
    echo -e "\t\t\e[32m ${CHECK_COUNTING_FILES_COUNT} ${ENDCOLORIZE}\n"
    ;;
  lg)
    echo -e "\n\tCounting and indexing \e[36m${FIND_PATTERN}${ENDCOLORIZE} on the filesystem."
    CHECK_COLLECTION_LOCAL_FILES=$(find ${FIND_PATTERN} -type f -name "*.tif" -o -name "*.jp2")
    $(echo "${CHECK_COLLECTION_LOCAL_FILES}" > $LOG_PATH_LIST)
    CONTENT_MODEL="&fq=%2BRELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3Asp_large_image_cmodel"
    CHECK_COUNTING_FILES_COUNT=$(cat $LOG_PATH_LIST | sed '/^\s*$/d' | wc -l)
    echo -e "\t\t\e[32m ${CHECK_COUNTING_FILES_COUNT} ${ENDCOLORIZE}\n"
    ;;
  basic)
    echo -e "\n\tCounting and indexing \e[36m${FIND_PATTERN}${ENDCOLORIZE} on the filesystem."
    CHECK_COLLECTION_LOCAL_FILES=$(find ${FIND_PATTERN} -type f -name "*.gif" -o -name "*.jpg" -o -name "*.bmp")
    $(echo "${CHECK_COLLECTION_LOCAL_FILES}" > $LOG_PATH_LIST)
    CONTENT_MODEL="&fq=%2BRELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3Asp_basic_image"
    CHECK_COUNTING_FILES_COUNT=$(cat $LOG_PATH_LIST | sed '/^\s*$/d' | wc -l)
    echo -e "\t\t\e[32m ${CHECK_COUNTING_FILES_COUNT} ${ENDCOLORIZE}\n"
    ;;
  pdf)
    echo -e "\n\tCounting and indexing \e[36m${FIND_PATTERN}${ENDCOLORIZE} on the filesystem."
    CHECK_COLLECTION_LOCAL_FILES=$(find ${FIND_PATTERN} -type f -name "*.pdf")
    $(echo "${CHECK_COLLECTION_LOCAL_FILES}" > $LOG_PATH_LIST)
    CONTENT_MODEL="&fq=%2BRELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3Asp_pdf"
    CHECK_COUNTING_FILES_COUNT=$(cat $LOG_PATH_LIST | sed '/^\s*$/d' | wc -l)
    echo -e "\t\t\e[32m ${CHECK_COUNTING_FILES_COUNT} ${ENDCOLORIZE}\n"
    ;;
  *)
    echo -e "$OOPS"
    exit 1
esac

# Making sure the collection is findable
echo -e "\tChecking if ${COLLECTION_URL}${COLLECTION_NAMESPACE} is reachable"
declare -i count=0
connect_to_collection(){
  # try up to five times before timing out.
  if [ $count -gt 5 ]; then
    echo -e "\t  Can not find \"\033[38;5;2m${COLLECTION_URL}${COLLECTION_NAMESPACE}${ENDCOLORIZE}\"\n\tLook at the URL after \"collections%3A\" \n\t   ${COLLECTION_URL}\033[38;5;2mCOLLECTION-NAME${ENDCOLORIZE}\ \n\n\n"
    exit 0
  fi
  status=$(curl -s --head "${COLLECTION_URL}${COLLECTION_NAMESPACE}" | head -n 1 | grep "HTTP/1.[01] [23]..")
  sleep 1
  if [[ -z $status ]]; then
    echo -e "${COLLECTION_URL}${COLLECTION_NAMESPACE} has timed out, trying again. Retry $count out of 5"
    ((count++))
    sleep 1
    connect_to_collection
  else
    ((count++))
    echo -e "\t\t\e[32mCollection check complete${ENDCOLORIZE}\n"
  fi
}
(connect_to_collection)

echo -e "\n\tGetting PIDs and count of all of the objects within the '$COLLECTION_PARENT_NAME' collection"
SOLR_COUNT=$(curl -X GET --silent "$SOLR_DOMAIN_AND_PORT/solr/collection1/select?q=PID%3A${COLLECTION_NAMESPACE}%5C%3A*${CONTENT_MODEL}&rows=0&fl=PID&wt=xml&indent=true" | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d' )
SOLR_PIDS=$(curl -X GET --silent "$SOLR_DOMAIN_AND_PORT/solr/collection1/select?q=PID%3A${COLLECTION_NAMESPACE}%5C%3A*&sort=PID+asc${CONTENT_MODEL}&rows=100000&fl=PID&wt=csv&indent=true" | tail -n +2)
echo -e "\t\t\e[32m Count: ${SOLR_COUNT}${ENDCOLORIZE}\n"

if [[ $SOLR_COUNT == '' ]]; then
  echo "No PIDS found in Solr"
  echo "$SOLR_DOMAIN_AND_PORT/solr/#/collection1/select?q=PID%3A${COLLECTION_NAMESPACE}%5C%3A*${CONTENT_MODEL}&rows=0&fl=PID&wt=xml&indent=true | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d'"
  exit
fi

[ -f $LOG_PATH_DOWNLOADED_HASH_LIST ] || touch $LOG_PATH_DOWNLOADED_HASH_LIST
[ -f $LOG_PATH_DOWNLOAD_HASHES ] || touch $LOG_PATH_DOWNLOAD_HASHES

SOLR_PIDS=(${SOLR_PIDS//\\n/})
CHECKSUM_TYPE_FIRST=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${SOLR_PIDS[0]}/datastreams/OBJ?format=xml | grep "<dsChecksumType>" | sed -e 's/<[^>]*>//g' | tr -d '\r\n')

case "$CHECKSUM_TYPE_FIRST" in
  SHA-1)
    CHECKSUM_TYPE_TO_USE="sha1sum"
    ;;
  SHA-256)
    CHECKSUM_TYPE_TO_USE="sha256sum"
    ;;
  SHA-512)
    CHECKSUM_TYPE_TO_USE="sha512sum"
    ;;
  md5)
    CHECKSUM_TYPE_TO_USE="md5sum"
    ;;
  *)
    CHECKSUM_TYPE_TO_USE="sha256sum"
esac


while true; do
  if [[ -f $LOG_PATH_LOCAL_HASHES ]] ; then
    echo -e "\n\n\e[96m"
    read -p "        A hash log file already exist for these. Would you like to regerate the local hashes? " yn
    echo -e "${ENDCOLORIZE}"
  else
    yn=y
  fi
  case $yn in
    [Yy]* )
      [[ -f $LOG_PATH_LOCAL_HASHES ]] && rm -f $LOG_PATH_LOCAL_HASHES
      [[ -f $LOG_PATH_LOCAL_HASH_LIST ]] && rm -f $LOG_PATH_LOCAL_HASH_LIST
      COUNTER=0
      BIGCOUNTER=0
      hash_it(){
        hash_check="$($CHECKSUM_TYPE_TO_USE $1)"
        echo "${hash_check}" >> $LOG_PATH_LOCAL_HASH_LIST
        echo "${hash_check%%[[:space:]]*}" >> $LOG_PATH_LOCAL_HASHES
      }
      echo -e "\n\tHashing local files:"
      for file in $CHECK_COLLECTION_LOCAL_FILES; do
        let COUNTER+=1
        let BIGCOUNTER+=1
        echo -ne "\t#${BIGCOUNTER} \e[96m${file}${ENDCOLORIZE} \033[0K\r"
        if [ $COUNTER -gt $CORE_COUNT ]; then
          wait
          let COUNTER=0
        fi
        hash_it "${file}" &
        [ "${3}" == video ] && sleep 1
      done; break ;;
    [Nn]* ) echo -e "\t\tUsing existing hashes."; break ;;
    * ) echo "Please answer yes or no." ;;
  esac
done

echo -e "\n\t\tWaiting for the last to write to log."
wait
echo -e "\t\t\tHashing local files complete.\n\n"

COUNTER="${#SOLR_PIDS[@]}"
ORIGINAL_STARTTIME=$(date +%s)
AVERAGE=0
sort -o $LOG_PATH_LOCAL_HASHES $LOG_PATH_LOCAL_HASHES
sed -i '/^$/d' $LOG_PATH_LOCAL_HASHES
sort -u -o $LOG_PATH_LOCAL_HASH_LIST $LOG_PATH_LOCAL_HASH_LIST

echo -e "\n\n\tHashing files from the '\e[96m${COLLECTION_NAMESPACE}${ENDCOLORIZE}' collection on \e[96m${DOMAIN}${ENDCOLORIZE}\n\n\n"
CHECKED=0
for i in "${SOLR_PIDS[@]}"; do
  STARTTIME=$(date +%s)
  echo -e "\t${COUNTER} of ${#SOLR_PIDS[@]} PIDS."
  [[ -f download ]] && rm -f download
  if [ $CHECKED == 0 ]; then
    let CHECKED=CHECKED-1
  PAGE_STATUS=$(curl -L --write-out %{http_code} --silent --output /dev/null "${OBJECT_URL}/${i} | head -n 1 | cut -d$' ' -f2")
  [ ! $PAGE_STATUS == 200 ] && echo "PID ${i} came back with a status code of ${PAGE_STATUS}"
  FEDORA_PAGE_STATUS=$(curl -L -u ${FEDORAUSERNAME}:${FEDORAPASS} --write-out %{http_code} --silent --output /dev/null "${SOLR_DOMAIN_AND_PORT}/fedora/objects/${i}/datastreams/OBJ?format=xml" | head -n 1 | cut -d$' ' -f2)
  if [ ! $FEDORA_PAGE_STATUS == 200 ]; then
    echo -e "\n\n Check Fedora Username | Password\n\n\n"
    exit
  fi
  fi
  CHECKSUM_TYPE=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${i}/datastreams/OBJ?format=xml | grep "<dsChecksumType>" | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
  if [[ ! $CHECKSUM_TYPE == $CHECKSUM_TYPE_FIRST ]]; then
    echo -e "\tDownloading Object for PID ${i} via ${OBJECT_URL}/${i}/datastream/OBJ/download"
    $(curl -O -L "${OBJECT_URL}/${i}/datastream/OBJ/download" --silent)
    echo -e "\tDownloaded PAGE PID ${i}"
    echo -e "\tHashing downloaded file."
    declare regex="$($CHECKSUM_TYPE_TO_USE download)"
    echo -e "\t${CHECKSUM_TYPE} hashing downloaded file complete."
  else
    declare regex=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${i}/datastreams/OBJ?format=xml | grep "<dsChecksum>" | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
    echo -e "\t${CHECKSUM_TYPE} hash download from fedora complete."
  fi
  declare regex_m="${regex%%[[:space:]]*}"
  declare local_file_hashes="$LOG_PATH_LOCAL_HASHES"
  echo "${OBJECT_URL}/${i} ${regex_m}" >> $LOG_PATH_DOWNLOADED_HASH_LIST
  echo "$regex_m" >> $LOG_PATH_DOWNLOAD_HASHES
  echo -e "\tHash processing complete."
  if grep -Fxq $regex_m $local_file_hashes
  then
    echo -e "${OBJECT_URL}/${i}/ $(grep -r $regex_m $LOG_PATH_LOCAL_HASH_LIST) $regex_m \n" >> $LOG_PATH_FINAL_REPORT
    echo -e "\t\e[32m Hash matches original${ENDCOLORIZE}\n\t\t${regex_m}"
  else
    echo -e "Warning:\t${i}'s hash does not match any local hashes.\n\t${OBJECT_URL}/${i}" >> $LOG_PATH_ERRORS
    echo -e "\t\e[31m ${i}'s hash does not match any local hashes.${ENDCOLORIZE}\n\t\t${regex_m}"
  fi
  let COUNTER=COUNTER-1
  ENDTIME=$(date +%s)
  [ $AVERAGE -eq 0 ] && AVERAGE=$(bc <<< "($ENDTIME - $STARTTIME)");
  CURRENT_POSITION_AVERAGE=$AVERAGE
  [ $COUNTER -lt "${#SOLR_PIDS[@]}" ] && CURRENT_POSITION_AVERAGE=$(bc <<< "($ENDTIME - $ORIGINAL_STARTTIME) / (${#SOLR_PIDS[@]} - $COUNTER)");
  AVERAGE=$(bc <<< "(($ENDTIME - $STARTTIME) + $AVERAGE + $CURRENT_POSITION_AVERAGE) / 3");
  REMAINING=$(bc <<< "($AVERAGE * $COUNTER) / 60");
  [ $REMAINING -lt 2 ] && REMAINING="~1"
  echo -e "\t    Roughly ${REMAINING} minutes remaining for hashing.\n\n"
  [[ -f download ]] && rm -f download
done

let COUNTER=0

[ -f 'check_collection_logs/last_check_collection_report.log' ] && rm -f check_collection_logs/last_check_collection_report.log
exec > >(tee -a "check_collection_logs/last_check_collection_report.log" | sed -e "s/\x1b\[.\{1,5\}m//g") 2>&1

echo -e "\n\n"
center_text " ==== === == =   Report   =  == === ==== "
echo -e "\n"


if [ ! "$SOLR_COUNT" -eq "$CHECK_COUNTING_FILES_COUNT" ]; then
  COLORIZE="\e[31m"
  echo -e "Numbers ${COLORIZE}don't${ENDCOLORIZE} match: file count to Solr count."
  echo -e "\t${COLORIZE}$(< $LOG_PATH_LOCAL_HASHES wc -l)${ENDCOLORIZE} local files to ${COLORIZE}${SOLR_COUNT}${ENDCOLORIZE} web hosted objects."
else
  COLORIZE="\e[32m"
  echo -e "Solr count ${COLORIZE}matches${ENDCOLORIZE} the number of files in the specified directory."
  echo -e "\tThis doesn't mean that it's correct, this could always be a false positive by itself\n but with the hash checks this could be a good indicator everything is in the Fedora/Islandora.\n"
fi
echo -e "\n${COLORIZE}$(< $LOG_PATH_LOCAL_HASHES wc -l)${ENDCOLORIZE} hashes were generated for the ${COLORIZE}${CHECK_COUNTING_FILES_COUNT}${ENDCOLORIZE} local files."
echo -e "${COLORIZE}$(< $LOG_PATH_DOWNLOAD_HASHES wc -l)${ENDCOLORIZE} hashes were generated for the ${COLORIZE}${SOLR_COUNT}${ENDCOLORIZE} web hosted objects."

[[ -f $LOG_PATH_MISSING ]] && rm -f $LOG_PATH_MISSING
echo "$(comm -23 <(sort $LOG_PATH_LOCAL_HASHES) <(sort $LOG_PATH_DOWNLOAD_HASHES) | cut -f1 -d" ")" > $LOG_PATH_MISSING_HASHES

sort -u -o $LOG_PATH_MISSING_HASHES $LOG_PATH_MISSING_HASHES
while IFS= read -r -u13 line; do
  if [[ ! "${line}" == '' ]]; then
    this_hash=$(grep "$line" $LOG_PATH_LOCAL_HASH_LIST)
    echo "${this_hash##*[[:space:]]}" >> $LOG_PATH_MISSING
  fi
done 13<"$LOG_PATH_MISSING_HASHES"

[[ -f $LOG_PATH_MISSING ]] && echo -e "\n\n${COLORIZE} > > > > > > Item missing from collection or duplicate local copy < < < < < < ${ENDCOLORIZE}\n$(cat $LOG_PATH_MISSING)\n\n\t${COLORIZE}- - - - - - End of missing - - - - - -${ENDCOLORIZE}"
[[ -f $LOG_PATH_MISSING ]] || echo -e "\n\n\n${COLORIZE}All local hashes have a matching hash online!${ENDCOLORIZE}\n\n"

echo -e "\n\n\nLooking at local file system hashes for duplicates."
if has_duplicates "${LOG_PATH_LOCAL_HASHES}"; then
  while IFS= read -r fsline; do
    this_hash=$(grep "$fsline" $LOG_PATH_LOCAL_HASH_LIST)
    echo -e "$this_hash\n" >> $LOG_PATH_LOCAL_HASHES_DUPLICATES
  done < <(sort $LOG_PATH_LOCAL_HASHES | uniq -d)
  echo -e "\n${COLORIZE} > > > > > > Found local file duplicates < < < < < < ${ENDCOLORIZE}\n\nHASH Values \t\t\t\t File Path\n\e[95m$(cat $LOG_PATH_LOCAL_HASHES_DUPLICATES)${ENDCOLORIZE}\n\n\t${COLORIZE}- - - - - - End of duplicates - - - - - -${ENDCOLORIZE}\n"
else
  echo -e "\t${COLORIZE}- - - - - - No duplicates found - - - - - -${ENDCOLORIZE}\n\n"
fi

echo -e "\n\n\nLooking at hashes from the web hosted images for duplicates."
if has_duplicates "${LOG_PATH_DOWNLOAD_HASHES}"; then
  while IFS= read -r nline; do
    this_hash=$(grep "$nline" $LOG_PATH_DOWNLOADED_HASH_LIST)
    echo -e "$this_hash\n" >> $LOG_PATH_DUPLICATES
  done < <(sort $LOG_PATH_DOWNLOAD_HASHES | uniq -d)
  echo -e "${COLORIZE}Duplicates${ENDCOLORIZE}:\n\e[95m$(cat $LOG_PATH_DUPLICATES)${ENDCOLORIZE}\n\n\t- - - - - - End of duplicates - - - - - -\n"
else
  echo -e "\t${COLORIZE}- - - - - - No duplicates found - - - - - -${ENDCOLORIZE}\n\n"
fi

[[ -f $LOG_PATH_ERRORS ]] && echo -e "\n\nCollection Errors/Warnings: \n\n$(cat $LOG_PATH_ERRORS)"
echo -e "\n\n"
center_text " ==== === == =   Done   =  == === ==== "
echo -e "\n\n\n"
cleanup_files

# Removes ascii formatting from report
tr -cd '\11\12\15\40-\176' < check_collection_logs/last_check_collection_report.log > check_collection_logs/last_check_collection_report2.log
sed -e "s/\[3m//g" -i check_collection_logs/last_check_collection_report2.log
sed -e "s/\[31m//g" -i check_collection_logs/last_check_collection_report2.log
sed -e "s/\[32m//g" -i check_collection_logs/last_check_collection_report2.log
sed -e "s/\[0m//g" -i check_collection_logs/last_check_collection_report2.log
mv check_collection_logs/last_check_collection_report2.log check_collection_logs/last_check_collection_report.log
echo -e "Report can be found at ${COLORIZE}${DIR}/check_collection_logs/last_check_collection_report.log${ENDCOLORIZE}"
