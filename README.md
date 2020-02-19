# Automated Ingest for Continuing Publications (BETA)
This is a script for automating the final checks and ingestion of books, large images and basic images into existing collections. Some collections like "Continuing Publications" frequently need to have an object (book, large image, basic image) ingested. This process can be repetitive and can be automated.

This uses a combination of folder names and YAML files to determine parent collection, content models and page names. When an issue is triggered a process is run to notify the user of the issue and stops the process for the ingest in a way that doesn't block other ingestions.

The script is intended to be run as part of a cron job but can be done manually. The current configuration is setup for [Islandora vagrant](https://github.com/Islandora-Labs/islandora_vagrant) by default. To adapt this for your environment change the __DRUPAL_HOME_DIR__ and __WORKING_HOME_DIR__ in the 'run.sh' file.


## Files
```shell
    Automated-Ingest-for-Continuing-Publications
      ├── README.md
1.    ├── collection_templates
2.    │   ├── islandora__bookCollection.xml
3.    │   ├── islandora__bookCollection.yml
4.    │   └── page_example_DC.xml
5.    ├── create_dc.sh
6.    ├── create_mods.sh
7.    ├── run.sh
8.    ├── config.cfg.defaults
9.    ├── config.cfg
10.   ├── whitelist.txt
11.   ├── PIDS_custom.txt
12.   ├── duplicate_checker.sh
13.   └── contpub.csv
```

1. Collection templates for generating MODS
2. A generic MODS file by collection name. Variables are embedded in the file to be replaced with the yml file variables.
3. YAML file by collection name for the specific object (only working for books at this time). This is to be copied manually into the collection folder next to the cmodel directory with the same name as the issue. Using the example below the islandora__bookCollection.yml file needs to be coppied into the "book" directory and rename to match the folder (example issue1.yml).
4. This is used to create a page level DC file.
5. This is the script the uses #4's file to generate and validate a DC file for each page in a book.
6. Creates a MODS file from the collection_templates XML file and the YAML file inside of the content model folder.
7. The main script to execute.
8. Config file defauls
9. Copy config.cfg.defaults to config.cfg
10. A list of PIDS to skip in the duplicate checker script.
11. Custom list of PIDS to check in the duplicate checker script. This will cause the script to skip the solr query for gathering all of the PIDS.
12. Downloads all of the PIDs in solr, downloads all of the hashes for those pids and loks for duplicates and zero byte files. It outputs several logs including a csv of the `PIDS,Hash Type,Hashes` for later use. This script can be stopped and resumed from where it left off.
13. Duplicate Checker exported a CSV file with all of the PIDS with this HASH type and HASH.
```
  -- Expected Folder Structure
  Folder Structure

            automated_ingesting
1             ├── 1_final_check
2             ├── 2_ready_for_processing
3             │   └── islandora__bookCollection
4             │       └── book
5             │           ├── issue1
6             │           │   ├── 1
7             │           │   │   ├── OBJ.tif
7a            │           │   │   └── OCR.asc
              │           │   ├── 2
              │           │   │   └── OBJ.tif
              │           │   ├── 3
              │           │   │   └── OBJ.tif
8             │           │   ├── ORIGINAL.pdf
8a            │           │   ├── ORIGINAL_EDITED.pdf
9             │           │   └── PDF.pdf
10            │           └── issue1.yml
11            ├── 3_errors
12            │   ├── islandora__bookCollection/
13            │   └── islandora__bookCollection.txt
15            └── 4_completed
                  └── islandora__sp_large_image_collection



1. Final Checks (human) before processing. This is the folder the files are initially dropped into by the digitization department for review from the metadata librarian.
2. When a collection is placed in here it will be processed.
3. This folder's naming convention is the PID of the parent, note the colon is replaced with 2 underscores.
        └── islandora__bookCollection
                       ^^^^^^^^^^^^^^ Name of the parent (PID)
            ^^^^^^^^^ Repository (typically part of the URL Example:.../islandora:bookCollection/...)
4. This folder's naming convention (book) is the string that represents a content model (cModel) of the content being ingested.
        Options are: basic (basic image; jpg, png, gif, bmp), large_image (tif, jp2), book (book: tif, jp2)
            └── book
5. Folder naming for this is arbitrary and is used to match the YAML file with a book (name it whatever you want). This script will attempt to ingest everything in this folder as a book. Any unexpected files could cause a failure.

6. Is the folder for the first page. The folder's name "1" is used to create the page title "Page 1".
  a) Folders must be sequential
  b) Folders must start with 1 or 1 with leading zeros (example: 000001)
7. Is the Page's tif file.
7a. Is the OCR for the tif (OPTIONAL). Readme more https://www.ibm.com/support/knowledgecenter/ca/SSEPGG_9.7.0/com.ibm.db2.luw.admin.dm.doc/doc/r0004663.html

8. Original.pdf (OPTIONAL) is the PDF that was originally created and not accessibly compliant for online access.
8a. ORIGINAL_EDITED.pdf, in case changes were made to the ORIGINAL.pdf but aren't suitable for online viewing (like PDF/UA).
9. PDF generated for display (this is the PDF-UA accessible version)
10. YAML file to generate MODS for book object.
11. 3_errors is the folder where collection level will be moved to when an error is detected.
12. EXAMPLE of #3's collection level folder when a collection like islandora__bookCollection has an error.
13. The log file of the issue with the same name as the collection folder.
15. The folder where a collection folder is moved to when everything ingests as expected.

```

## How to use this
```shell
$ vagrant ssh
$ cd /vagrant
$ git clone https://github.com/utkdigitalinitiatives/Automated-Ingest-for-Continuing-Publications
$ cd Automated-Ingest-for-Continuing-Publications
$ cp config.cfg.defaults config.cfg
# edit values in config.cfg to your needs. The defaults will work with islandora_vagrant

$ ./run.sh
```


## Using YAML
In the folder "collection_templates is half of a MODS in YAML form"
  * [Example of how to convert](https://codebeautify.org/yaml-to-json-xml-csv)
The other half is at the issues level within the book cmodel (7a)
  * For example of this yml file see example_mods.yml

## Workflow
1) After content is prepped, files should be placed into the __final_check__ folder for metadata to check and/or modify.
2) When ready to ingest, move files to __ready_for_processing__
3) Folder will be examined by this script and either ingested and moved to __completed__ or an error file will be created in the __errors__ folder and the collection will be moved there as well.

### TODO
4) If error happens at ingest, a system admin log file should be created instead and the whole process should be evaluated for the collection.

## Overview of what this script does
- Auto correct common mistakes.
  - Cleanup incase of an OSX or Windows mounts create hidden files.
  - Find and correct spaces in the filename.
  - Rename tiff to tif
  - reset errors log file if it exist for the collection.

- Within each content model directory (example: book)
  - Empty directory found alert.
  - Empty file found alert.
  - Correct if filename for MODS/PDF is lowercase or the extension is uppercase.
  - Correct if filename for OBJ/OCR is lowercase or the extension is uppercase.
  - Check if folder is named correctly.
  - Look for unexpected files inside of the ready_to_process folder
  - Look for unexpected files inside of the collection folder.
  - If extra files were found echo a message `automated_ingesting/errors/PID.txt`
    - Example `automated_ingesting/errors/alumnus_2015spring.txt`
  - Only directories (no files) are expected in the collection level folder.
    - Any files here will cause a failure. Checking to verify only directories.
  - Verify the folder's naming convention matches the content model names.

- Page level directory checks.
  - Page level folders should only be numeric.
  - Checking the the files in this Folder match the expected Naming convention.
  - Check files inside a page directory to match expected naming conventions.

- Check to see if the PID exist prior to ingesting.
- Book processing
  - Are the page folders sequential.
  - If no drupal directory was found exit script.
  - Ingest book

- Move collection to error folder when an error occurred.
- Move collection to `automated_ingesting/completed` when successfully ingested with no errors.

## Additional Content Models
Match the file name (excluding the dot extension) with it's mods file.
```
Basic Image
              islandora__sp_basic_image_collection/
                  └── basic
                      ├── OBJ2.jpg   <─┐
                      ├── OBJ2.xml     └── Matching JPG & MODS names
                      ├── OBJ3.bmp
                      ├── OBJ3.xml
                      ├── SunFlowers_Compressed_B44A.gif
                      └── SunFlowers_Compressed_B44A.xml

Large Image
             islandora__sp_large_image_collection
                  └── large_image
                      ├── 001001.tif   <─┐
                      ├── 001001.xml     └── Matching tif & MODS names
                      ├── 001002.tif
                      ├── 001002.xml
                      ├── 001003.jp2   <─┐
                      └── 001003.xml     └── Matching jp2 & MODS names
```

## How to test a new collection template
This example will assume you're using [islandora_vagrant](https://github.com/Islandora-Labs/islandora_vagrant) and you've cloned this into vagrant's /vagrant directory.
```shell
collection_templates
├── islandora__bookCollection.xml
│   ▲▲▲▲▲▲▲▲▲
│   Namespace
│   
└── islandora__bookCollection.yml
               ▲▲▲▲▲▲▲▲▲▲▲▲▲▲
               Collection
# Together they make the collection PID (excluding the ":")
```
1. Create a new pair of template files and put them in the collection_templates folder.
    > test__elephant.xml
    > test__elephant.yml
2. Create a new collection
   - Add an object to this Collection
   - Collection PID
     > test:elephant
   - Collection Title
     > This is a test Collection
   - Ingest
   - Manage
   - Collection
   - Manage collection policy
   - Check __Islandora Internet Archive Book Content Model (islandora:bookCModel)__
   - Change all __NAMESPACE__ fields to _test_
   - Click Update
3. Place book (folder) into a folder called automated_ingesting as described above.
   __OPTIONAL__ : this will create a test book for you.
   - You can download the a test book from https://github.com/DonRichards/Islandora-Book-Batch-Example
   - Run the `build_extended_test_images.sh` to generate a a test folder automated_ingest_test
   ```shell
   automated_ingest_test
    └── book
       ├── seventh_edition
       │   ├── 1
       │   │   └── OBJ.tiff
       │   ├── 2
       │   │   └── OBJ.tif
       │   └── 3
       │       └── OBJ.tif
       └── seventh_edition.yml
   ````
   - Rename `automated_ingest_test/` to `test__elephant`.
   - Replace `seventh_edition.yml` with the `test__elephant.yml` but rename it back to match the folder (seventh_edition.yml).
   - The book subfolder (`seventh_edition/`) & yaml filename (`seventh_edition.yml`) naming is mostly ignored, they just needs to match eachother.
   - copy `test__elephant` into `/vagrant/automated_ingesting/2_ready_for_processing`
4. `git clone https://github.com/utkdigitalinitiatives/Automated-Ingest-for-Continuing-Publications`
5. `cd Automated-Ingest-for-Continuing-Publications`
6. Run script (`./run.sh`)

## How to use check_collection.sh
After ingesting a collection, check if everything went in and wasn't corrupted during the process. Most general setting are retrieved from the config.cfg file, it needs to be filled out completely.
* hashes all of the content  

```shell
./check_collection.sh Parent:PID /path/to/original/files/ contentType

# Example
./check_collection.sh islandora:einstein_oro /vagrant/einstein audio
```
You will have an issue if the parent and pid are the same.

* Parent Name Space is the name space of the parent the objects were ingested into.
* Path needs to be an absolute path.
* Content types can be audio, video, book, pdf, lg OR basic.
    * audio = Audio content model (mp3, wav)
    * video = Video content model (ogg, mp4, mov, qt, m4v, avi, mkv)
    * book = Book content model (tif, jp2)
    * pdf = PDF content model (pdf)
    * lg = Large Image content model (tif, jp2)
    * basic = Basic Image content model (gif, jpg, bmp)

### What this script does
1. Creates a file that contains all of the SHA-256 hashes for all of the files associated with the specified content type. This is a asyncronous proces and can tax a system's performance and is limited to 8 files at a time.
2. If you've ran the already, an existing hash file will exist and this will promp to ask if you'd like to regenerate the hash log for this directory.
3. Verifies the collection is reachable.
4. Call Solr for a __count__ of all the PIDS for the specified name space with the specified content model.
5. Call Solr for a __list__ of all the PIDS for the specified name space with the specified content model.
6. Identify the checksum type for the 1st object online and uses that checksum type for local file system checking and verifies each object uses the same checksum type, if it differs the script will download the object's OBJ file and hash it. But if the type matches it will use the hash value from fedora instead of recreating the value.
7. Checks the the web hosted object's hash is in the list of local file system hashes.
8. Checks the the web hosted object's hash is already in the list of web hosted object hashes (for duplicates).
9. Outputs a report

__Example of the output__
![ScreenShot of check_collection.sh](https://user-images.githubusercontent.com/2738244/60742865-fd6acd80-9f3c-11e9-9f32-e78d821059df.gif)

## To dos
* Check the integrity of the image file prior to ingest.
* Check that each page's URL renders/returns a valid image.
  * Hash the original page image and compare it to the online version.
* Check that title matches the title on the book page.
* Check that the total number of pages match the total number of directories for that issue.
