# Automated-Ingest-for-Continuing-Publications
This is a mostly automated script for handling the final stage of ingesting into Islandora.

## Files
```shell
    Automated-Ingest-for-Continuing-Publications
      ├── README.md
1.    ├── collection_templates
2.    │   ├── islandora__bookCollection.xml
3.    │   └── islandora__bookCollection.yml
4.    ├── create_mods.sh
5.    └── run.sh
```
1. Collection templates for generating MODS
2. A generic MODS file by collection name. Variables are embedded in the file to be replaced with the yml file variables.
3. YAML file by collection name for the specific object (only working for books at this time). This is to be copied manually into the collection folder next to the cmodel directory with the same name as the issue. Using the example below the islandora__bookCollection.yml file needs to be coppied into the "book" directory and rename to match the folder (example issue1.yml).
4. Creates a MODS file from the collection_templates XML file and the YAML file inside of the content model folder.
5. The main script to execute.


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
9. PDF generated for display (this is the PDF-UA accessible version)
10. YAML file to generate MODS for book object.
11. 3_errors is the folder where collection level will be moved to when an error is detected.
12. EXAMPLE of #3's collection level folder when a collection like islandora__bookCollection has an error.
13. The log file of the issue with the same name as the collection folder.
15. The folder where a collection folder is moved to when everything ingests as expected.

```
## How to use this
First will need to install "https://github.com/SFULibrary/islandora_datastream_crud" into drupal.
1) vagrant ssh
2) cd /var/www/drupal/sites/all/modules
3) git clone https://github.com/SFULibrary/islandora_datastream_crud
4) drush en -y islandora_datastream_crud
5) cd /vagrant
6) ./run.sh

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
