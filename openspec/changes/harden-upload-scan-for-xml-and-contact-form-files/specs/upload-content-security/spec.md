## ADDED Requirements

### Requirement: The re-examination task scans the contact form uploads

The task SHALL also scan the whole folder `public/contact_form`. The contact form plugin stores the
files of visitors there, under the id of each site, and a visitor gets the upload scan. A report
without that folder leaves out the files of the users that the scan trusts least. The scan SHALL
include a folder whose id belongs to no site, because the folder of a deleted site can stay.

#### Scenario: A flagged contact form file is reported
- **WHEN** the task runs with a file under `public/contact_form/<site id>` that the current rules refuse
- **THEN** the file is listed in the report, with the id of its site in its path

#### Scenario: A contact form file that passes is counted
- **WHEN** the task runs with a file under `public/contact_form/<site id>` that the current rules accept
- **THEN** the report counts the file as scanned and does not list it

#### Scenario: A file in the folder of a deleted site is reported
- **WHEN** the task runs with a file that the current rules refuse, under `public/contact_form/<id>` with an id that no site has
- **THEN** the file is listed in the report

#### Scenario: A site with no contact form folder is scanned
- **WHEN** the task runs for a site that has no folder under `public/contact_form`
- **THEN** the task reports the media files of that site and raises no error
