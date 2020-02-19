#!/bin/sh

clear

esc=$(printf '\033')
echo "$(cat <<'EOT'




.......................... duplicate checker ...............................................

                                                   `@@@%
                                                     (@ (@@
                                                      @@   @@
                                                 /    .@    *@(
                                    .*,          /@@.  @@     @%  *
                              /##(      ##        @   .**.    /@
                          ###           /,         }&          @&  @
                      .##*                            @*       @@   *
              ########,                *                 @     @(   %
          (#########                  /                   .   %@   &|
          /######          (         /                     &  @/   @
           / ##         #          #                       ( @&   %@
           ##        #          #/                          @%   ,@  @
         ##       ##         ###                          %@    /@  ,@
        #.      #.       .#####,                        .@}    @@   @.
       #     .#.      (#, ####                 @,     (@*     @,   $@
      #     #*     (#,   (##.                @@@@   @@      @@    .@
     #,   ##     ##                        *@@@@.@&       @@     .@
     #   #*    ##                         /@@@@.        @&      &@
    **  #    *#                           &@         .@       ,@(
    /  #    ##                          @          @*       .@@
      #/   ## *                      .$         &.        (@%,@ @
      #   *#  .                     @        /          @@@@@@@@@
     .#   #(   /                                     /@@@@@@@@@
     .(  .#      #                *               .@@@@@@&
      #  ,#         #.           /             /@@,
      (   #,          #.        ,@         *@@&
       /  ##    (####( #,        @@@@@@@@&
           ##     #    ##
            ##    ##
              ##   #
                (##(#
                    ./(#
EOT
)" | sed "s,#,${esc}[31m&${esc}[0m,g" | sed "s,\@,${esc}[34m&${esc}[0m,g"

: [Code Documentation] '
Suggested way to run this script.
  $ ./duplicate_checker.sh
  $ nice -n17 duplicate_checker.sh

INPUT:
  PIDS.txt
  If no PIDS.txt file is found this script will download the entire repository"s PID list.

OUTPUT:
  ALL_DOWNLOAD_HASHES.log
  ALL_DOWNLOADED_HASH_LIST.log
  ALL_LOG_PATH_DOWNLOAD_PID_LIST.log
  ALL_DOWNLOADED_HASH_LIST_DUPLICATES.log
  Duplicate_Summary.log
  Zero_byte_OBJ_Summary.log
  error.log
  COMPLETED_PID_HASH_LIST.log

Configuration settings.

'

[[ -f PIDS.log ]] && rm -f PIDS.log

# OUTPUT Files
LOG_PATH_DOWNLOAD_HASHES=$(pwd)/ALL_DOWNLOAD_HASHES.log
LOG_PATH_DOWNLOAD_HASH_LIST=$(pwd)/ALL_DOWNLOADED_HASH_LIST.log
LOG_PATH_DOWNLOAD_HASHES_DUPLICATES=$(pwd)/ALL_DOWNLOADED_HASH_LIST_DUPLICATES.log
LOG_PATH_DOWNLOAD_PID_LIST=$(pwd)/ALL_LOG_PATH_DOWNLOAD_PID_LIST.log
LOG_PATH_DOWNLOAD_PIDHASH_LIST=$(pwd)/COMPLETED_PID_HASH_LIST.log
PREVIOUSLY_HASHED_PIDS=$(pwd)/PREVIOUSLY_HASHED_PIDS.log
WHITELISTED=$(pwd)/whitelist.txt
[ -f $LOG_PATH_DOWNLOAD_HASHES ] || touch $LOG_PATH_DOWNLOAD_HASHES
[ -f $LOG_PATH_DOWNLOAD_HASH_LIST ] || touch $LOG_PATH_DOWNLOAD_HASH_LIST
[ -f $PREVIOUSLY_HASHED_PIDS ] || touch $PREVIOUSLY_HASHED_PIDS
[ -f PIDS.log.bak ] || rm -f PIDS.log.bak
[ -f $WHITELISTED ] || touch $WHITELISTED

echo "Dupl Check Started $(date +%F)" >> error.log
border()
{
    title="| $1 |"
    edge=$(echo -e "${title}" | sed 's/./-/g')
    echo -e "\e[35m${edge}"
    echo -e "$title"
    echo -e "$edge"
    echo -e "\033[0m\n"
}

cp $LOG_PATH_DOWNLOAD_HASH_LIST $PREVIOUSLY_HASHED_PIDS

# Setting up a CSV to be utilized but run.sh
CSV_ALL_DOWNLOADED_HASH_LIST=contpub.csv
echo "PID,TYPE,HASH" > $CSV_ALL_DOWNLOADED_HASH_LIST

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${DIR}

if [[ ! -f config.cfg ]]; then
  echo -e "\n\n\n"
  echo "No Config, it's required."
  exit
fi

# In case process is terminated.
cleanup_files() {
  echo -e "\n\n\n"
  border "Tail from Last Hashes                                               "
  tail $LOG_PATH_DOWNLOAD_HASHES
  echo -e "\n------------------"
  cp $LOG_PATH_DOWNLOAD_HASH_LIST $LOG_PATH_DOWNLOAD_PIDHASH_LIST
  [[ -f ALLPIDSLIST.log ]] && rm -f ALLPIDSLIST.log
  [[ -f dupls.log ]] && rm -f dupls.log
  file=error.log
  maxsize=90000
  actualsize=$(wc -c <"$file")
  if [ $actualsize -ge $maxsize ]; then
    echo "size is over $maxsize bytes"
    mv $file `date '+%Y_%m_%d__%H_%M_%S'`_$file
  fi
}

for arg in "$@"; do
  if [ "$arg" == "--help" ] || [ "$arg" == "-h" ]; then
    echo "$(cat <<'EOT'
.......................... help ............................................................

Custom PIDS files

  To use a custom list of PIDS create a PIDS_custom.txt file and use 1 PID per line.
  Example:
      yrb:75
      yrb:314
      yrb:2718
      yrb:90
      alpha:3

For help
  $ ./duplicate_checker.sh --help

To run it without inputs.
  $ ./duplicate_checker.sh --automate

  This will remove the PIDs file. If a PIDS_custom.txt exist it will use it then reset the hash history and start without prompting the user.

To run it as normal.
$ ./duplicate_checker.sh


EOT
)" | sed "s,\$.*,${esc}[35m&${esc}[0m,g"
echo -e "\n\n\n"
    exit
  fi

  # Check existence of an input argument
  if [ !"$arg" == "--automate" ] || [ !"$arg" == "-automate" ]; then

    if [[ -f PIDS_custom.txt ]]; then
      read -p "Use custom PID list? [y/n]  " -n 1 -r ;
    fi

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      cp PIDS_custom.txt PIDS.log
      sed -i 's/%3A/:/g' PIDS.log
    fi
    echo -e "\n"

    # If $PREVIOUSLY_HASHED_PIDS is missing or empty, start fresh.
    if [[ -f $PREVIOUSLY_HASHED_PIDS ]] && [ ! -s $PREVIOUSLY_HASHED_PIDS ]; then
      REPLY=y
    else
      sed -i 's/\s.*$//' $PREVIOUSLY_HASHED_PIDS
      read -p "Reset and hash check the entire site? [y/n]  " -n 1 -r ;
      (cleanup_files)
    fi

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo '' > $LOG_PATH_DOWNLOAD_HASHES
      echo '' > $LOG_PATH_DOWNLOAD_HASH_LIST
      echo '' > Duplicate_Summary.log
      echo '' > $LOG_PATH_DOWNLOAD_HASH_LIST
      echo '' > $LOG_PATH_DOWNLOAD_PIDHASH_LIST
      echo '' > $PREVIOUSLY_HASHED_PIDS
    fi

  else
    # If automate is passed reset and use custom PIDS if available.
    if [[ -f PIDS_custom.txt ]]; then
      cp PIDS_custom.txt PIDS.log
      sed -i 's/%3A/:/g' PIDS.log
    fi
    echo '' > $LOG_PATH_DOWNLOAD_HASHES
    echo '' > $LOG_PATH_DOWNLOAD_HASH_LIST
    echo '' > Duplicate_Summary.log
    echo '' > $LOG_PATH_DOWNLOAD_HASH_LIST
    echo '' > $LOG_PATH_DOWNLOAD_PIDHASH_LIST
    echo '' > $PREVIOUSLY_HASHED_PIDS
  fi
done
# Files that need to be cleared upon start for accurate reporting.
reset_files() {
  [[ -f $LOG_PATH_DOWNLOAD_HASH_LIST ]] || touch $LOG_PATH_DOWNLOAD_HASH_LIST
  [[ -f $LOG_PATH_DOWNLOAD_PID_LIST ]] || touch $LOG_PATH_DOWNLOAD_PID_LIST
  [[ -f $LOG_PATH_DOWNLOAD_HASHES ]] || touch $LOG_PATH_DOWNLOAD_HASHES
  [[ -f $LOG_PATH_DOWNLOAD_PIDHASH_LIST ]] || touch $LOG_PATH_DOWNLOAD_PIDHASH_LIST
  [[ -f error.log ]] || touch error.log
  echo '' > Duplicate_Summary.log
  echo '' > Zero_byte_OBJ_Summary.log
  echo '' > error.log
}
(reset_files)

# If interrupted this will fire.
trap cleanup_files EXIT

config_read_file() {
  (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

config_get() {
  val="$(config_read_file config.cfg "${1}")";
  printf -- "%s" "${val}";
}

DOMAIN=$(config_get CHECK_COLLECTION_DOMAIN)
SOLR_DOMAIN_AND_PORT=$(config_get CHECK_COLLECTION_SOLR_DOMAIN_AND_PORT)
COLLECTION_URL=$(config_get CHECK_COLLECTION_COLLECTION_URL)
OBJECT_URL=$(config_get BASE_URL)
FEDORAUSERNAME=$(config_get CHECK_COLLECTION_FEDORAUSERNAME)
FEDORAPASS=$(config_get CHECK_COLLECTION_FEDORAPASS)
DEBUG=$(config_get DEBUG_PROCESS)
MAXJOBS=$(config_get MAXJOBS)


: [ddddd] '
* Download all PIDS
* Check for Duplicates
  - Out to log file
* Check a video stream from a randomly selected array item of possible videos
* Randomly check the OBJ
  - Audio & Video plays
  - Images are viewable
'

echo -e "\nStart time: \n\t$(date)\n"

border "Solr                                                                  "

echo "Checking if solr is available."
solr_status_code=$(curl --write-out %{http_code} --silent --output /dev/null ${SOLR_DOMAIN_AND_PORT}/solr)
if [[ "$solr_status_code" -ne 200 ]] && [[ "$solr_status_code" -ne 302 ]] ; then
  echo -e "\t\033[41m Solr is unreachable and is returning a $solr_status_code code \033[0m \n\t\t${SOLR_DOMAIN_AND_PORT}/solr\n"
  exit 0
else
  echo -e "\t\033[92m Site status is $solr_status_code \033[0m \n\t\t${SOLR_DOMAIN_AND_PORT}/solr\n"
fi

# Count the total number of objects in solr.
SOLR_COUNT=$(nice -17 curl -X GET --silent "${SOLR_DOMAIN_AND_PORT}/solr/collection1/select?q=PID%3A*%5C%3A*&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AbookCModel&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&rows=0&fl=PID&wt=xml&indent=true" | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d' )
SOLR_SECOND_COUNT=$(nice -17 curl -X GET --silent "${SOLR_DOMAIN_AND_PORT}/solr/collection1/select?q=PID%3A*%5C%3A*&fq=+RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AbookCModel&fq=+RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&rows=0&fl=PID&wt=xml&indent=true" | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d' )
SOLR_SECOND_COUNT=$(( $SOLR_SECOND_COUNT + $(nice -17 curl -X GET --silent "${SOLR_DOMAIN_AND_PORT}/solr/collection1/select?q=PID%3A*%5C%3A*&fq=+RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&rows=0&fl=PID&wt=xml&indent=true" | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d' ) ))
echo -e "\n\033[36m$(echo ${SOLR_COUNT} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')\033[0m records found (images, videos, pages, etc.)\n\t\033[36m$(echo ${SOLR_SECOND_COUNT} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')\033[0m compound & book objects excluded.\n"

border "Create PIDS file                                                      "
# Breaks solr querys up to chunks of 10,000 and steps through the results.
STEP=10000
if [[ ! -f PIDS.log ]]; then
  for (( i = 0; i < $SOLR_COUNT; i += $STEP )); do
     END=$(($i+$STEP))
     # Outputs 10,000 PIDs at a time into text file.
     echo $(curl -X GET --silent "${SOLR_DOMAIN_AND_PORT}/solr/collection1/select?q=PID%3A*%5C%3A*&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AbookCModel&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&sort=fgs_createdDate_dt+asc&start=${i}&rows=${END}&fl=PID&wt=csv&indent=true" | tail -n +2) >> PIDS.log
     RESULT=$(awk "BEGIN {printf \"%.2f\",100*${i}/$SOLR_COUNT}")
     echo -ne " Fetched \033[95m$(echo ${i} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')\033[0m records <-> ${RESULT}%                     \033[0K\r"
  done
  echo -ne " Fetched \033[95m$(echo ${SOLR_COUNT} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')\033[0m records <-> 100%                     \033[0K\r\n"
  echo -e "\n"
fi

_file="$(cat PIDS.log | wc -l)"
if [ $_file -eq 0 ]; then
  echo "failed creating PID.log file, please try again"
  exit
fi

# Sorts the PIDs and removes blank lines and spaces.
sed -i 's/ /\n/g' PIDS.log
sort -u PIDS.log > PIDS.log.bak
mv PIDS.log.bak PIDS.log
sed -i '/^$/d' PIDS.log
sed -i '/^[[:blank:]]*$/ d' PIDS.log
echo -e "\t\033[92m done. \033[0m\n"

JOBSRUNNING=0

# Downloads hashes from fedora directly for each object.
function download_hash() {
   local pid=$1
   if grep -Fxq "${pid%%:*}" $WHITELISTED; then
     local it=''
   elif [[ "${pid%%:*}" == "collections" ]]; then
     local it=''
   else
   # If the HASH for this PID is missing download it.
   isInFile=$(cat $PREVIOUSLY_HASHED_PIDS | grep -c "$1")
   if [ $isInFile -eq 0 ]; then
     local regeh=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/OBJ?format=xml)
     [[ $DEBUG == true ]] && echo "${regeh}" >> debug.log

     # Remove everything after the space (isolating the hash) "islandora:1002 726478bb080109bc0f927dadf949f741ca021dcd8a929265234c5fe466356471"
     local regex=$(echo "$regeh" | grep "<dsChecksum>" | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
     local regex_m="${regex%%[[:space:]]*}"

     # Check if this is a PDF object.
     if [ "${regex_m}" == 'none' ]; then
       local regex=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/PDF?format=xml | grep "<dsChecksum>" | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
       # Remove all trailing space characters
       local regex_m="${regex%%[[:space:]]*}"
     fi

     # if the HASH is less than 63 characters
     if [[ "${#regex_m}" -lt 63 ]]; then
       local regex_cmodel=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}?format=xml | grep "<model>info:fedora/islandora:" | sed -e 's/<[^>]*>//g' | tr -d "\r\n")
       local regex_cmodel="${regex_cmodel##*fedora/islandora:}"
       local regex_cmodel="${regex_cmodel%cmodel*}"
       local regex_cmodel="${regex_cmodel%CModel*}"
       local regex_cmodel="${regex_cmodel##*fedora/islandora:}"
       local regex_cmodel_m="${regex_cmodel%%[[:space:]]*}"

       case "${regex_cmodel_m}" in
         "book"* )
          local OBJ='TN'
          ;;
          "sp_large_image_" )
            local OBJ='OBJ'
            ;;
          "page"* )
            local OBJ='OBJ'
            ;;
          "" )
            local OBJ='OBJ'
            [[ $DEBUG == true ]] && echo "EMPTY? ${pid} | Cmodel:${regex_cmodel_m}"
            ;;
         * )
          local OBJ='OBJ'
          [[ $DEBUG == true ]] && echo "Defaulting to OBJ Content Model ${regex_cmodel%CModel*}"
          ;;
       esac

       # Checking to see if checksum type exist or file is missing from fedora (outdated Solr index).
       local regex_with_obj=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/${OBJ}?format=xml)
       local regex_type=$(echo "${regex_with_obj}" | grep "<dsChecksumType>\|Object not found in low-level storage" | sed -e 's/<[^>]*>//g' | tr -d "\r\n")
       local regex_size=$(echo "${regex_with_obj}" | grep "<dsSize>" | sed -e 's/<[^>]*>//g' | tr -d "\r\n")

       case "$regex_type" in
         "DISABLED"* )
          local regex='DISABLED'
          ;;
         "Object not found in low-level storage"* )
          local regex='MISSING'
          ;;
          * )
           local regex=$(echo "${regex_with_obj}" | sed -n '/<dsChecksum>/,/<\\dsChecksum>/p' | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
           if [[ $regex_size -lt 100 ]]; then
             echo -e "  ${pid} ${regex_size}" >> Zero_byte_OBJ_Summary.log
           fi
          ;;
       esac
     fi

     local regex_m="${regex%%[[:space:]]*}"
     JOBSRUNNING=$(($JOBSRUNNING - 1))
     local regex_type=$(echo "$regeh" | grep "<dsChecksumType>\|Object not found in low-level storage" | sed -e 's/<[^>]*>//g' | tr -d "\r\n")
     # Check to see the OBJ is too small.
     if [ "${#regex_m}" -lt 64 ]; then
      if [[ ! "${OBJ}" == 'TN' ]]; then
       echo -e "${pid} \t ${#regex_m} \t ${regex_type}" >> error.log
      fi
     else
       echo "${pid} ${regex_m}" >> $LOG_PATH_DOWNLOAD_HASH_LIST
       echo "${pid},${regex_type},${regex_m}" >> $CSV_ALL_DOWNLOADED_HASH_LIST
       echo "${pid}" >> $LOG_PATH_DOWNLOAD_PID_LIST
       echo "$regex_m" >> $LOG_PATH_DOWNLOAD_HASHES
     fi

 else
   JOBSRUNNING=$(($JOBSRUNNING - 1))
 fi
fi
 }

echo -e "\n"
border "Processing PIDS file into array                                       "
declare -a ALLPIDS
readarray -t ALLPIDS < PIDS.log
echo -e "\t\033[92m done. \033[0m\n"

border "Copying previous hashes into array                                    "
declare -a HASHES
readarray -t HASHES < $PREVIOUSLY_HASHED_PIDS
declare -a ALLPIDSLIST
echo ${HASHES[@]} ${ALLPIDS[@]} | tr ' ' '\n' | sort | uniq -u > ALLPIDSLIST.log
echo -e "\t\033[92m done. \033[0m\n"

border "Removing any duplicated PIDs                                          "
# Probably not needed.
sed -i 's/ /\n/g' ALLPIDSLIST.log
sort -u ALLPIDSLIST.log > ALLPIDSLIST.log.bak
mv ALLPIDSLIST.log.bak ALLPIDSLIST.log
sed -i '/^$/d' ALLPIDSLIST.log
sed -i '/^[[:blank:]]*$/ d' ALLPIDSLIST.log
readarray -t ALLPIDSLIST < ALLPIDSLIST.log
echo -e "\t\033[92m done. \033[0m\n"

border "Summary before starting                                               "
echo -e "\e[34m $(echo ${#ALLPIDSLIST[@]} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')\033[0m pids found. Resuming from last iteration....\n\tdetermining which PIDS are missing."
echo -e "\n\tPulling the \e[34m$(echo ${#ALLPIDSLIST[@]} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')\033[0m hash values stored in fedora if possible, otherwise \n downloading then hashing the main object datastream individually.\n"
echo -e "\t\t\033[92m summary complete. \033[0m\n"

CURRENTJOB=1
len=${#ALLPIDSLIST[@]}

echo -e "
┌---------------------------------------------------------------------------------------------------------------┐
| \e[35mKey\033[0m                                                                                                           |
|---------------------------------------------------------------------------------------------------------------|"
echo -e "|\t\033[31m[❙❙]\033[0m : Paused/Waiting for the number of jobs running to drop below \e[92m$((${MAXJOBS}+1))\033[0m                                   |\n|\t\033[92m[▶ ]\033[0m : Job is running as normal. Downloading the \e[1mFOXML\033[0m file and extracting the HASH (if it exist)       |"
echo -e "└---------------------------------------------------------------------------------------------------------------┘\n"

for pid in ${ALLPIDSLIST[@]}; do
   JOBSRUNNING=$(jobs | wc -l)
   PERCENT=$(awk "BEGIN {printf \"%.2f\",100*${CURRENTJOB}/${len}}")

   LOOPIT=1
   while [ $(jobs | wc -l) -gt $MAXJOBS ]; do
     printf '\r \033[31m[❙❙]\033[0m Job #%s of %s | Currently running %s jobs  | %s percent | %d background processes running. | PID %s                                                  ' "${CURRENTJOB}" "${#ALLPIDSLIST[@]}" "${JOBSRUNNING}" "${PERCENT}" "${JOBSRUNNING}" "${pid}"
     printf '\r%0.s' {0..900}

     # Check if fedora is returning a 500 errors here.
     if [[ $LOOPIT -gt 20 ]]; then
      fedora_status_code=$(curl -u ${FEDORAUSERNAME}:${FEDORAPASS} --write-out %{http_code} --silent --output /dev/null ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}?format=xml)
      if [[ "$fedora_status_code" -eq 500 ]] ; then
        echo -e "\n\n\n Ooops! Fedora: ${fedora_status_code} is not reachable. We may have just overloaded it. You might need to restart fedora and lower the max jobs(currently at ${MAXJOBS})."
        echo -e "${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}?format=xml \n\tis throwing a ${fedora_status_code} code." >> error.log
        exit
      fi
      let LOOOPIT=1
      else
        let LOOOPIT+=1
     fi
   done;

   # Start the download function and move on the next threat execution.
   # This is a multithreaded approach
   download_hash $pid &

   # Make sure it's not out of control.
   if [[ $JOBSRUNNING -gt $(( $MAXJOBS + 10 )) ]]; then
     echo "Runaway process, exiting script. Please run again."
     exit 0
   fi
   printf '\r \033[92m[▶ ]\033[0m Job #%s of %s | Currently running %s jobs  | %s percent | %d background processes running. | PID %s                                                  ' "${CURRENTJOB}" "${#ALLPIDSLIST[@]}" "${JOBSRUNNING}" "${PERCENT}" "${JOBSRUNNING}" "${pid}"
   printf '\r%0.s' {0..900}
   let CURRENTJOB+=1
   unset PERCENT
 done


 # Waiting for the last ones to finish.
 while [ $(jobs | wc -l) -gt 1 ]; do
   printf '\r \033[92m[▶]\033[0m #%s Jobs still running.' "$(jobs | wc -l)"
   printf '\r%0.s' {0..900}
 done;

 # Removes blank lines
 sed -i '/^$/d' $LOG_PATH_DOWNLOAD_HASHES
 # Removes lines with string 'none'.
 sed -i '/^none/d' $LOG_PATH_DOWNLOAD_HASHES

 # Shows the time/date to indicate the process hasn't locked up.
 date

 # If no HASHes, no reason to continue.
 [ -s $LOG_PATH_DOWNLOAD_HASHES ] || exit
 border "Reading the downloaded hashes into an array                          "
 readarray ALL_DOWNLOAD_HASHES < $LOG_PATH_DOWNLOAD_HASHES
 echo -e "\tdone.\n"
 # If duplicates found find the PID(s).
 echo ${ALL_DOWNLOAD_HASHES[@]} | tr ' ' '\n' | sort | uniq -d > dupls.log
 border "Read duplicates into an array                                        "
 readarray DUPLICATES < dupls.log
 echo -e "\tdone.\n"

 if [[ "${#DUPLICATES[@]}" -gt 0  ]]; then
   border "Duplicate found and now counting.                                    "
   for duphashes in ${DUPLICATES[@]}; do
       this_hash=$(cat $LOG_PATH_DOWNLOAD_HASH_LIST | grep $duphashes)
       echo -e "$this_hash\n" >> $LOG_PATH_DOWNLOAD_HASHES_DUPLICATES
   done
   echo -e "\n > > > > > > Found duplicates < < < < < < \n\n"
 else
   echo -e "\t- - - - - - No duplicates found - - - - - -\n\n"
 fi

 border "Retrying the PIDS that are missing HASHES                            "
 cat $LOG_PATH_DOWNLOAD_HASH_LIST >> $PREVIOUSLY_HASHED_PIDS
 sed -i 's/\s.*$//' $PREVIOUSLY_HASHED_PIDS
 readarray -t HASHES < $PREVIOUSLY_HASHED_PIDS
 readarray -t PID_LIST < PIDS.log
 # Magic way of finding a pid not found in both.
 echo ${HASHES[@]} ${PID_LIST[@]} | tr ' ' '\n' | sort | uniq -u > missing.log
 readarray missinghashes < missing.log
 for mspid in ${missinghashes[@]}; do
   # This is a single threaded approach
   download_hash $mspid
 done
echo -e "\tdone.\n"

border "Reading the PIDs of the duplicate hashes into an array.              "
readarray duplicatepids < $LOG_PATH_DOWNLOAD_HASHES_DUPLICATES
for duplpid in ${duplicatepids[@]}; do
  echo "Duplicate HASHES found for PID: ${duplpid}"
done
echo -e "\tdone.\n"

cat << "EOF" >> Duplicate_Summary.log
| PID           | HASH                                                             | User        |
|---------------|------------------------------------------------------------------|-------------|
EOF

echo "| PID           | HASH                                                             | User        |"
echo "|---------------|------------------------------------------------------------------|-------------|"

border "Using Solr to check if a file is known to have 0 bytes as a file size"
# Zero byte files all have the same HASH and therefore identify as duplicates. This isolates those file into a single list.
count=1
connect_to_solr(){
  # try up to five times before timing out.
  if [ $count -gt 5 ]; then
    echo -e "\t  ${SOLR_DOMAIN_AND_PORT}/solr/ is unreachable.\n Please verify this URL is reachable by $(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p') or modify the conf.cfg file.\n\n"
    exit 0
  fi
  status=$(curl -s --head "${SOLR_DOMAIN_AND_PORT}/solr/#/collection1" | head -n 1 | grep "HTTP/1.[01] [23]..")
  sleep 1
  if [[ -z $status ]]; then
    echo -e "${SOLR_DOMAIN_AND_PORT}/solr/ has timed out, trying again. Retry $count out of 5"
    ((count++))
    sleep 1
    connect_to_solr
  else
    ((count++))
    LOOPCOUNT=0
    while read line; do
      checkpid=$(echo "${line%%[[:space:]]*}" | sed -e 's/\:/\%5C\%3A/g')
      if [[ $line == '' ]]; then
        echo "|---------------|------------------------------------------------------------------|-------------|"
        echo "|--------------|------------------------------------------------------------------|-------------|" >> Duplicate_Summary.log
      else
        checkpid=$(echo "${line%%[[:space:]]*}" | sed -e 's/\:/\%5C\%3A/g')
        # if OBJ has a field "size" and is a PAGE. Solr transform must include fedora_datastream_version_OBJ_SIZE_ms and RELS_EXT_isPageOf_uri_s
        # +fgs_ownerId_s+fedora_datastream_version_OBJ_SIZE_ms+RELS_EXT_isPageOf_uri_s
        solrquery=$(curl -X GET --silent "$SOLR_DOMAIN_AND_PORT/solr/collection1/select?q=PID%3A${checkpid}&fl=PID%2C+fedora_datastream_version_OBJ_SIZE_ms+RELS_EXT_isPageOf_uri_s&wt=csv&indent=true" | tail -n +2)
        solrquerypid="$(cut -d',' -f1 <<<$solrquery)"
        solrqueryowner="$(cut -d',' -f2 <<<$solrquery)"
        solrquerysize="$(cut -d',' -f3 <<<$solrquery)"
        solrqueryparent="$(cut -d',' -f4 <<<$solrquery)"

        if [[ $(expr length ${line%%[[:space:]]*}) -lt 12 ]]; then
          formatted_pid="${line%%[[:space:]]*} \t"
        else
          formatted_pid="${line%%[[:space:]]*}"
        fi
        if [[ "${solrquerysize}" == "-1" ]]; then
          solrqueryowner+=" -1"
          echo -e "  ${formatted_pid}  ${line##*[[:space:]]}\t${solrqueryowner}\t${solrqueryparent}" >> Zero_byte_OBJ_Summary.log
        fi
        echo -e "  ${formatted_pid}  ${line##*[[:space:]]}\t${solrqueryowner}\t${solrqueryparent}"
        echo -e "  ${formatted_pid}  ${line##*[[:space:]]}\t${solrqueryowner}\t${solrqueryparent}" >> Duplicate_Summary.log
        unset checkpid
        unset solrquery
        unset solrquerypid
        unset solrqueryowner
        unset solrquerysize
        unset solrqueryparent
      fi
      # Limit for debugging
      if [[ $DEBUG == true ]] && [[ LOOPCOUNT -gt 100  ]]; then
        exit
      fi
      let LOOPCOUNT+=1
    done < $LOG_PATH_DOWNLOAD_HASHES_DUPLICATES
  fi
}
echo "Starting the Solr Query"
(connect_to_solr)

echo -e "Zero Bytes were found for these PIDS:\n\n$(cat Zero_byte_OBJ_Summary.log)"
echo "Dupl Check Stopped $(date +%F)" >> error.log
