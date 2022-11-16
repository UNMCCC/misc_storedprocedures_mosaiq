# Miscellaneous Stored Procedures that create datamarts out of Mosaiq DB
This repo versions some of the store procedures (SP) that the clinical informatics group uses to 
conduct routine and infrequent data extractions from the Mosaiq backend SQL server.

In general, there will be information about what each SP does in code and in this repository Wiki pages.

Can you use them for your own clinic or oncological practice? Possible, but not without proper adaptations.
When would it be appropriate:
- Your practice uses Mosaiq, quite up-to-date systems
- You are knowledgeable on the actual backend structures
- You can read and interpret this code

In addition to SPs, we are including some standalone SQL queries invoked outside the DB scheduler. 
These small project are used to meet clinical needs of specialties, operations, patient services and others.
