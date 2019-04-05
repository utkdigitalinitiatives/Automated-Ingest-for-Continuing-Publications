# Automated-Ingest-for-Continuing-Publications
This is a mostly automated script for handling the final stage of ingesting into Islandora. 

```
  -- Expected Folder Structure

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
```


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
