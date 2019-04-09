# Automated-Ingest-for-Continuing-Publications
This is a mostly automated script for handling the final stage of ingesting into Islandora.

```
  -- Expected Folder Structure
            Folder Structure

            ./automated_ingesting
01.            ├── completed
02.            ├── errors
03.            ├── final_check
04.            └── ready_for_processing
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
12.                │           ├── PRESERVATION.pdf
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

```
## How to use this
First will need to install "https://github.com/SFULibrary/islandora_datastream_crud" into drupal.
1) vagrant ssh
2) cd /var/www/drupal/sites/all/modules
3) git clone https://github.com/SFULibrary/islandora_datastream_crud
4) drush en -y islandora_datastream_crud
5) cd /vagrant
6) ./run.sh

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
