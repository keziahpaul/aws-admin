# Snowflake Common Library

This is the common resource repo for everything Snowflake. All the database changes are powered by
[Schemachange](https://github.com/Snowflake-Labs/schemachange?tab=readme-ov-file#schemachange).
Schemachange uses a very similar approach to Flyway when it comes to applying changes to a database.
It supports the following:

## ***V***ersion scripts

These scripts are applied once. If the file's contents changes after it has been applied, schemachange
will throw an error. These scripts are named `Vm.n.o__description.sql`, where `m`, `n`, and `o` are
semantic version number parts. If a version number is reused, this is also an error.

```text
example:
V1.1.0__A_minor_patch_to_the_database.sql
```

These scripts are applied in version order. You could think of it as:

```sql
SELECT fullpathname
FROM LIST_DIRECTORY('schemachange/scripts') AS ld
WHERE isfile
  AND filename LIKE 'V%.%.%__%.sql'
  AND NOT EXISTS (
    SELECT 1
    FROM CHANGE_HISTORY AS ch
    WHERE ch.SCRIPT_TYPE = 'V'
      AND ch.VERSION = (ld.m, ld.n, ld.o)
  )
ORDER BY m, n, o
```

## ***R***epeatable scripts

After any pending ***V***ersion scripts have been applied, the ***R***epeatable scripts get applied.
These scripts only get applied if they are new, or they have changed. These scripts are named
`R__description.sql`.

```text
example:
R__Create_notification_alert.sql
```

These scripts are applied in description order. You could think of it as:

```sql
SELECT fullpathname
FROM LIST_DIRECTORY('schemachange/scripts') AS ld
WHERE isfile
  AND filename LIKE 'R__%.sql'
  AND NOT EXISTS (
    SELECT 1
    FROM CHANGE_HISTORY AS ch
    WHERE ch.SCRIPT_TYPE = 'R'
      AND ch.SCRIPT = ld.filename
      AND ch.CHECKSUM = ld.checksum
  )
ORDER BY description
```

## ***A***lways scripts

After any pending ***V***ersion and ***R***epeatable scripts have been applied, the ***A***lways
scripts get applied. These scripts are applied *everytime* schemachange is run. These scripts are
named `A__description.sql`.

```text
example:
A__Fix_grants.sql
```

These scripts are applied in description order. You could think of it as:

```sql
SELECT fullpathname
FROM LIST_DIRECTORY('schemachange/scripts') AS ld
WHERE isfile
  AND filename LIKE 'A__%.sql'
ORDER BY description
```

## Folder Layout

This is the structure other repositories should use

<pre>
ROOT
|_ <a href="#github-folder">.github</a>
|_ <a href="#schemachange-folder">schemachange</a>
   |_ <a href="#schemachange-config-folder">config</a>
   |_ <a href="#schemachange-modules-folder">modules</a>
   |_ <a href="#schemachange-scripts-folder">scripts</a>
</pre>

### Github folder

Any workflows or actions should reside in here. This repositories modules folder will get copied
into the current project to provide standardised macros.

### Schemachange folder

This is the top level folder for the schemachange jinja macros and general configuration to be used
by all projects. It should not apply any project specific configuration with this structure. It is
purely a support framework.

### Schemachange config folder

This contains the default configuration file which schemachange will use to run the project version
files. It does not contain database connection details. Those details should be held in the location
project's `connections.toml` file. The configuration file should be named is `schemachange-config.yml`.

### Schemachange modules folder

This contains all the [Jinja](https://jinja.palletsprojects.com/en/stable/templates/) macros to
facilitate consistent SQL for common objects. Great care should be taken not to change the emitted
SQL for existing functions, as this will have the side effect of changing the content of any
***V***ersion or ***R***epeatable script. In the case of the former, it breaks the contract of applying
a ***V***ersion file once only. In the latter case, there may be unexpected side-effects.

### Schemachange scripts folder

This contains any scripts that all projects should expect to run. Most likely there will only be
***A***lways scripts in here, which are applied after any new ***V***ersion scripts and ***R***epeatable
scripts have been run.
