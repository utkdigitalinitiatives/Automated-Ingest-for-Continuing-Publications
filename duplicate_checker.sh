#!/bin/sh
clear
cat << "EOT"




.......................... duplicate checker ...............................................
                                                                                
                                                   &@@@%                        
                                                     #@ #@@                     
                                                      @@   @@                   
                                                 /    .@    *@(                 
                                    .*,          /@@.  @@     @%  *             
                              /##(      ##        @   .**.    /@                
                          ###           /,         #&          @&  @            
                      .##*                            @*       @@   *           
              ########,                *                 @     @(   %           
          (#########                  /                   .   %@   &#           
          /######          (         /                     &  @/   @            
           / ##         #          #                       ( @&   %@            
           ##        #          #/                          @%   ,@  @          
         ##       ##         ###                          %@    /@  ,@          
        #.      #.       .#####,                        .@#    @@   @.          
       #     .#.      (#, ####                 @,     (@*     @,   #@           
      #     #*     (#,   (##.                @@@@   @@      @@    .@            
     #,   ##     ##                        *@@@@.@&       @@     .@             
     #   #*    ##                         /@@@@.        @&      &@              
    **  #    *#                           &@         .@       ,@(               
    /  #    ##                          @          @*       .@@                 
      #/   ## *                      .#         &.        (@%,@ @               
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

: [intro] '
Suggested way to run this script.
  $ ./duplicate_checker.sh
  $ nice -n17 duplicate_checker.sh
 
INPUT:
  PIDS.txt
  If no PIDS.txt file is found this script will download the entire repository`s PID list.

OUTPUT:
  ALL_DOWNLOAD_HASHES.log
  ALL_DOWNLOADED_HASH_LIST.log
  ALL_LOG_PATH_DOWNLOAD_PID_LIST.log
  ALL_DOWNLOADED_HASH_LIST_DUPLICATES.log
  Duplicate_Summary.log
  Zero_byte_OBJ_Summary.log
  error.log
  COMPLETED_PID_HASH_LIST.log
'

# Set parameters
DEBUG=0
MAXJOBS=9

# OUTPUT Files
LOG_PATH_DOWNLOAD_HASHES=$(pwd)/ALL_DOWNLOAD_HASHES.log
LOG_PATH_DOWNLOAD_HASH_LIST=$(pwd)/ALL_DOWNLOADED_HASH_LIST.log
LOG_PATH_DOWNLOAD_HASHES_DUPLICATES=$(pwd)/ALL_DOWNLOADED_HASH_LIST_DUPLICATES.log
LOG_PATH_DOWNLOAD_PID_LIST=$(pwd)/ALL_LOG_PATH_DOWNLOAD_PID_LIST.log
LOG_PATH_DOWNLOAD_PIDHASH_LIST=$(pwd)/COMPLETED_PID_HASH_LIST.log
PREVIOUSLY_HASHED_PIDS=$(pwd)/PREVIOUSLY_HASHED_PIDS.log
[ -f PIDS.log ] || touch $(pwd)/PIDS.log
[ -f $LOG_PATH_DOWNLOAD_HASHES ] || touch $LOG_PATH_DOWNLOAD_HASHES
[ -f $LOG_PATH_DOWNLOAD_HASH_LIST ] || touch $LOG_PATH_DOWNLOAD_HASH_LIST
[ -f $PREVIOUSLY_HASHED_PIDS ] || touch $PREVIOUSLY_HASHED_PIDS

cp $LOG_PATH_DOWNLOAD_HASH_LIST $PREVIOUSLY_HASHED_PIDS
sed -i 's/\s.*$//' $PREVIOUSLY_HASHED_PIDS

# Setting up a CSV to be utilized but run.sh
CSV_ALL_DOWNLOADED_HASH_LIST=contpub.csv
echo "PID,TYPE,HASH" > $CSV_ALL_DOWNLOADED_HASH_LIST

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${DIR}

echo -e "\n\n\n"

# In case process is terminated.
cleanup_files() {
  echo -e "\n------------------\n\nTail from Last Hashes\n"
  tail $LOG_PATH_DOWNLOAD_HASHES
  echo -e "\n------------------"
  cp $LOG_PATH_DOWNLOAD_HASH_LIST $LOG_PATH_DOWNLOAD_PIDHASH_LIST  
}


# if $PREVIOUSLY_HASHED_PIDS then there is nothing to resume.
if [[ -f $PREVIOUSLY_HASHED_PIDS ]] && [ ! -s $PREVIOUSLY_HASHED_PIDS ]; then
  REPLY=y
else
  read -p "Reset and hash check the entire site? [y/n]  " -n 1 -r ;
  (cleanup_files)
fi

if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  echo '' > $LOG_PATH_DOWNLOAD_HASHES
  echo '' > $LOG_PATH_DOWNLOAD_HASH_LIST
  echo '' > PIDS.log
  echo '' > Duplicate_Summary.log
  echo '' > $LOG_PATH_DOWNLOAD_HASH_LIST
  echo '' > $LOG_PATH_DOWNLOAD_PIDHASH_LIST
  echo '' > $PREVIOUSLY_HASHED_PIDS
fi

# If the PIDS.log file is empty it removes it.
_file="$(cat PIDS.log | wc -l)"
[ $_file -eq 0 ] && rm -f PIDS.log


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
  rm -f dupls.log
}
(reset_files)

# If interrupted either through error or CTRL C this will fire.
trap cleanup_files EXIT

# Check if config exists
if [[ ! -f config.cfg ]]; then
  echo "No Config, it's required."
  exit
fi

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

: [ddddd] '
* Download all PIDS
* Check for Duplicates
  - Out to log file(s)
* Check a video stream from a randomly selected array item of possible videos
'

echo -e "\n\nStart time: \n\t$(date)"

# Count the total number of objects in solr.
SOLR_COUNT=$(nice -17 curl -X GET --silent "http://porter.lib.utk.edu:8080/solr/collection1/select?q=PID%3A*%5C%3A*&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AbookCModel&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&rows=0&fl=PID&wt=xml&indent=true" | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d' )
SOLR_SECOND_COUNT=$(nice -17 curl -X GET --silent "http://porter.lib.utk.edu:8080/solr/collection1/select?q=PID%3A*%5C%3A*&fq=+RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AbookCModel&fq=+RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&rows=0&fl=PID&wt=xml&indent=true" | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d' )
SOLR_SECOND_COUNT=$(( $SOLR_SECOND_COUNT + $(nice -17 curl -X GET --silent "http://porter.lib.utk.edu:8080/solr/collection1/select?q=PID%3A*%5C%3A*&fq=+RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&rows=0&fl=PID&wt=xml&indent=true" | sed -n '/numFound="/,/?.*"/p' | grep -o -E '[0-9]+' | sed -e 's/^0\+//' | sed '/^$/d' ) ))
echo -e "\n$(echo ${SOLR_COUNT} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') records found (images, videos, pages, etc.)\n\t$(echo ${SOLR_SECOND_COUNT} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') compound & book objects excluded.\n"

# Breaks solr querys up to chunks of 10,000 and steps through the results.
STEP=10000
if [[ ! -f PIDS.log ]]; then
  for (( i = 0; i < $SOLR_COUNT; i += $STEP )); do
     END=$(($i+$STEP))
     # Outputs 10,000 PIDs at a time into text file.
     echo "$(curl -X GET --silent "http://porter.lib.utk.edu:8080/solr/collection1/select?q=PID%3A*%5C%3A*&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AbookCModel&fq=-RELS_EXT_hasModel_uri_s%3Ainfo%5C%3Afedora%2Fislandora%5C%3AcompoundCModel&sort=fgs_createdDate_dt+asc&start=${i}&rows=${END}&fl=PID&wt=csv&indent=true" | tail -n +2)" >> PIDS.log
     RESULT=$(awk "BEGIN {printf \"%.2f\",100*$i/$SOLR_COUNT}")
     echo -ne " Fetched $(echo ${i} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta') records ${RESULT}%                \033[0K\r"
  done
fi

# Sorts the PIDs and removes blank lines and spaces.
sort -u PIDS.log > PIDS.log.bak && mv PIDS.log.bak PIDS.log
sed -i '/^$/d' PIDS.log
sed -i '/^[[:blank:]]*$/ d' PIDS.log

JOBSRUNNING=0

# Downloads hashes from fedora directly for each object.
function download_hash() {
   local pid=$1
   if [[ "${pid%%:*}" == "fbpro" ]]; then
     local it=''
   elif [[ "${pid%%:*}" == "collections" ]]; then
     local it=''
   else
   # If the HASH for this PID is missing download it.
   isInFile=$(cat $PREVIOUSLY_HASHED_PIDS | grep -c "$1")
   if [ $isInFile -eq 0 ]; then
     [[ $DEBUG -eq 1 ]] && curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/OBJ?format=xml >> debug.log
     local regeh=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/OBJ?format=xml)
     
     local regex=$(echo "$regeh" | grep "<dsChecksum>" | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
     local regex_m="${regex%%[[:space:]]*}"

     if [ "${regex_m}" == 'none' ]; then
       local regex=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/PDF?format=xml | grep "<dsChecksum>" | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
     fi
     local regex_m="${regex%%[[:space:]]*}"

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
            [[ $DEBUG -eq 1 ]] && echo "EMPTY? ${pid} | Cmodel:${regex_cmodel_m}"
            ;;
         * )
          local OBJ='OBJ'
          [[ $DEBUG -eq 1 ]] && echo "Defaulting to OBJ Content Model ${regex_cmodel%CModel*}"
          ;;
       esac

       # Checking to see if checksum type exist or file is missing from fedora (outdated Solr index).
       local regex_type=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/${OBJ}?format=xml | grep "<dsChecksumType>\|Object not found in low-level storage" | sed -e 's/<[^>]*>//g' | tr -d "\r\n")

       case "$regex_type" in
         "DISABLED"* )
          local regex='DISABLED'
          ;;
         "Object not found in low-level storage"* )
          local regex='MISSING'
          ;;
          * )
           local regex=$(curl --silent -u ${FEDORAUSERNAME}:${FEDORAPASS} ${SOLR_DOMAIN_AND_PORT}/fedora/objects/${pid}/datastreams/${OBJ}?format=xml | sed -n '/<dsChecksum>/,/<\\dsChecksum>/p' | sed -e 's/<[^>]*>//g' | tr -d '\r\n')
           # echo "x--> $pid $regex $regex_type"
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

has_duplicates() {
  {
    sort | uniq -d | grep . -qc
  } < "$1"
}

echo -e "\n\n\n"

echo "Main function to download all hashes"
readarray allpids < PIDS.log
echo -e "${#allpids} pids found. Resuming from last iteration....\n\n\tdetermining which PIDS are missing...."
readarray -t HASHES < $PREVIOUSLY_HASHED_PIDS
declare -a allpidslist
echo ${HASHES[@]} ${allpids[@]} | tr ' ' '\n' | sort | uniq -u > allpidslist.log
echo -e "\n\n\t\t$(cat allpidslist.log | wc -l) PIDS found.\n\n"
allpidslist=$(cat allpidslist.log && echo .) || exit
allpidslisti=${i%.}
echo -e "\nOK, ready.\n\n\n"
currentjob=0

echo -e "Pulling the hash values stored in fedora if possible, otherwise \n downloading then hashing the main object datastream individually.\n\n"

for pid in ${allpidslist[@]}; do
   JOBSRUNNING=$(jobs | wc -l)
   let currentjob+=1
   percent=$(( 100*$currentjob/${#allpids[@]} ))

   while [ $(jobs | wc -l) -gt $MAXJOBS ]; do
     printf '\r[X] Job #%s | Currently running %s # of jobs \t | %s percent | \t %d background processes running.\t\t' "${currentjob}" "${JOBSRUNNING}" "${percent}" "$(jobs | wc -l)"
     printf '\r%0.s' {0..900}
   done;

   # Make sure it's not out of control.
   [[ $JOBSRUNNING -gt $(( $MAXJOBS + 4 )) ]] && exit
   
   # Start the download function and move on the next threat execution.
   download_hash $pid &

   printf '\r[ ] Job #%s | Currently running %s # of jobs \t | %s percent | \t %d background processes running.\t' "${currentjob}" "${JOBSRUNNING}" "${percent}" "$(jobs | wc -l)"
   printf '\r%0.s' {0..900}

   unset percent
 done
 echo -e "\n\n\tPress [CTRL+C] to stop..\n\n"

 # Removes blank lines
 sed -i '/^$/d' $LOG_PATH_DOWNLOAD_HASHES
 # Removes lines with string 'none'.
 sed -i '/^none/d' $LOG_PATH_DOWNLOAD_HASHES

 # Shows the time/date to indicate the process hasn't locked up.
 date

 # If no HASHes, no reason to continue.
 [ -s $LOG_PATH_DOWNLOAD_HASHES ] || exit

 echo "Reading the downloaded hashes into an array."
 readarray ALL_DOWNLOAD_HASHES < $LOG_PATH_DOWNLOAD_HASHES
 echo -e "\tdone.\n"

 # If duplicates found find the PID(s).
 echo ${ALL_DOWNLOAD_HASHES[@]} | tr ' ' '\n' | sort | uniq -d > dupls.log
 echo "Read duplicates into an array."
 readarray DUPLICATES < dupls.log
 echo -e "\tdone.\n"

 if [[ "${#DUPLICATES[@]}" -gt 0  ]]; then
   echo "Duplicate found and now counting."

   for duphashes in ${DUPLICATES[@]}; do
       this_hash=$(cat ALL_DOWNLOADED_HASH_LIST.log | grep $duphashes)
       echo -e "$this_hash\n" >> $LOG_PATH_DOWNLOAD_HASHES_DUPLICATES
   done
   echo -e "\n > > > > > > Found duplicates < < < < < < \n\nHASH Values \t\t\t\t File Path\n$(cat $LOG_PATH_DOWNLOAD_HASHES_DUPLICATES)\n\n\t- - - - - - End of duplicates - - - - - -\n"
 else
   echo -e "\t- - - - - - No duplicates found - - - - - -\n\n"
 fi

 echo "Retrying the PIDS that are missing HASHES."
 readarray -t HASHES < $PREVIOUSLY_HASHED_PIDS
 readarray -t PID_LIST < PIDS.log
 # Magic way of finding a pid not found in both.
 echo ${HASHES[@]} ${PID_LIST[@]} | tr ' ' '\n' | sort | uniq -u > missing.log
 readarray missinghashes < missing.log
 for mspid in ${missinghashes[@]}; do
   download_hash $mspid
 done
echo -e "\tdone.\n"

echo "Reading the PIDs of the duplicate hashes into an array."
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

# Zero byte files all have the same HASH and therefore identify as duplicates. This isolates those file into a single list.
count=1
connect_to_solr(){
  # try up to five times before timing out.
  if [ $count -gt 5 ]; then
    echo -e "\t  Can not find http://porter.lib.utk.edu:8080/solr/ \n\n\n"
    exit 0
  fi
  status=$(curl -s --head "http://porter.lib.utk.edu:8080/solr/#/collection1" | head -n 1 | grep "HTTP/1.[01] [23]..")
  sleep 1
  if [[ -z $status ]]; then
    echo -e "http://porter.lib.utk.edu:8080/solr/ has timed out, trying again. Retry $count out of 5"
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
        solrquery=$(curl -X GET --silent "$SOLR_DOMAIN_AND_PORT/solr/collection1/select?q=PID%3A${checkpid}&fl=PID%2C+fgs_ownerId_s+fedora_datastream_version_OBJ_SIZE_ms+RELS_EXT_isPageOf_uri_s&wt=csv&indent=true" | tail -n +2)
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
      if [[ LOOPCOUNT -gt 100 ]] && [ $DEBUG == 1 ]; then
        exit
      fi
      let LOOPCOUNT+=1
    done < $LOG_PATH_DOWNLOAD_HASHES_DUPLICATES
  fi
}
echo "Starting the Solr Query"
(connect_to_solr)

echo -e "Zero Bytes were found for these PIDS:\n\n$(cat Zero_byte_OBJ_Summary.log)"