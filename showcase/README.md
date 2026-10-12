# Showcase information

This folder is incomplete. It relates to the information demonstrated in the showcase with respect to using schemachange.

## layout

```text
README.md           - how this all works
.gitignore          - because we don't want to store junk in the repo
.github/            - where the workflows for this repo live
  workflows/
    deploy.yaml     - build everything - maybe
    initialise.yaml - initialise an account with default databases and RBAC
accounts/           - somewhere to store the account initialisation
apply/
  action.yaml       - the action to apply schemachange to snowflake. Dry-run is the default
  Dockerfile        - definition for the schemachange container
  Makefile          - build the schemachange container
  requirements.txt  - python requirements for schemachange
schemachange/       - this is the schemachange common module space
  action.yaml       - the action to install the modules into another repo. Fail if there is a name clash, default
  config/
  modules/
  scripts/
```

## Changes that cause a rebuild

Any change to the `apply` folder or `deploy.yaml` will rebuild the docker container.
Merging to the develop branch, will tag the build as `latest_dev`.
Merging to the main branch, will tag the build as `latest_prod`.

## Creating a new Snowflake account

Create a file in `accounts` with the following format:

```yaml
# filename "product.yaml"
account:
  name: product
  environments:
    nonprod:
      snowflake-account: AZ12345
      names:
        - dev
        - tst
        - uat
        - prf
    prod:
      snowflake-account: ZA54321
      names:
        - pst
        - prd
```

This will trigger the `initialise.yaml` workflow and create a private key pair and publish them to:

* onedata/nonprod/${{ account.name }}/snowflake-github-admin-user-private-key
* onedata/nonprod/${{ account.name }}/snowflake-github-admin-user-passphrase
* onedata/prod/${{ account.name }}/snowflake-github-admin-user-private-key
* onedata/prod/${{ account.name }}/snowflake-github-admin-user-passphrase

After the secrets have been installed, it will update the account role with the new secret (_how_).
Then it will apply the default setup, creating databases, roles and permissions.

Changing an account definition does not remove existing accounts, but it can cause re-applying of the schangechange folder.

## Changes that will cause Schema updates to pre-existing accounts

Any change to the `schemachange` folder will cause all existing accounts to be updated with the changes.

## Installing this repo into your workflow

To make use of the modules and Schemachange itself in your own repo, you will need to install it as part of your workflow.
This can be done with the following step:

```yaml
- name: Install Schemachange
  uses: actions/checkout@v3
  with:
    repository: PEXA-AU/pexa-one-data-snowflake-au-common-lib
    ref: main  # or a particular release
    path: .github/actions/schemachange
```

### Provided schemachange actions

After checking out this repo into your workspace, the following actions become available.

#### apply action

Usage:

```yaml
- name: Step name
  uses: .github/actions/schemachange/apply
  with:
    schemachange-folder: relative/schemachange
    dry-run: (Optional) true|false    # default: true
```

#### schemachange action

Usage:

```yaml
- name: Step name
  uses: .github/actions/schemachange/schemachange
  with:
    schemachange-folder: relative/schemachange
    modules-only: (Optional) true|false # default: true
    overwrite: (Optional) true|false    # default: true
    ignore-fail: (Optional) false|true  # default: false
```

### Typical use

```yaml
jobs:
  deploy-changes:
    name: Deploy the changes
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Install Schemachange repo
        uses: actions/checkout@v3
        with:
          repository: PEXA-AU/pexa-one-data-snowflake-au-common-lib
          ref: main
          path: .github/actions/schemachange

      - name: Inject modules
        uses: .github/actions/schemachange/schemachange
        with:
          schemachange-folder: schemachange
          overwrite: true

      - name: Do a dry run first
        uses: .github/actions/schemachange/apply
        with:
          schemachange-folder: schemachange
          dry-run: true

      - name: Actually apply the changes
        uses: .github/actions/schemachange/apply
        with:
          schemachange-folder: schemachange
          dry-run: false
```
