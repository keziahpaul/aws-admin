IMAGE ?= pexa-one-data-snowflake-image

export DOCKER_IMAGE=${IMAGE}
export AWS_REGION=ap-southeast-2
export GITHUB_ENV=GITHUB_ENV
export GITHUB_WORKFLOW ?= pexa_one_data
export GITHUB_ACTIONS_ID ?= GITHUB_ACTIONS_ID


build:
	docker build --no-cache -t ${IMAGE} .
.PHONY: build

image:
	docker image ls | grep ${DOCKER_IMAGE} || make build
.PHONY: image


common_dry_run:
	DRY_RUN="--dry-run" make common_deploy VAR=${VAR}
.PHONY: dry_run

common_deploy:
		export SF_ENV=${SF_ENV}
		export ACCOUNT_NAME=${ACCOUNT_NAME}
		export AWS_LOGGING_ACCOUNT=${AWS_LOGGING_ACCOUNT}
		export AWS_LOGGING_ROLE=${AWS_LOGGING_ROLE}
		export AWS_LOGGING_KMS_KEY=${AWS_LOGGING_KMS_KEY}
		export SNOWFLAKE_DBT_PUBLIC_KEY
		export SNOWFLAKE_GITHUB_PUBLIC_KEY
		export SNOWFLAKE_FIVETRAN_PUBLIC_KEY
		export SNOWFLAKE_ALATION_PUBLIC_KEY
		export SNOWFLAKE_TABLEAU_PUBLIC_KEY
		export SNOWFLAKE_SAGEMAKER_PUBLIC_KEY
		export SNOWFLAKE_SSA_DBT_PUBLIC_KEY
		export SNOWFLAKE_GLUE_PUBLIC_KEY	
		export SF_ACCOUNT_ID
		export AWS_ACCOUNT_1
		export AWS_S3_BUCKET
		export SF_REGION=${SF_REGION}
		export DATA_AWS_ACCOUNT=${DATA_AWS_ACCOUNT}
		export IN_STATEMENT_TIMEOUT_AT=${IN_STATEMENT_TIMEOUT_AT}
		export PEXAKEY_RDS_NLP_NAME=${PEXAKEY_RDS_NLP_NAME}

		schemachange deploy \
			--config-folder schemachange/config/ \
			--change-history-table ${SF_ENV}_METADATA.SCHEMACHANGE.CHANGE_HISTORY \
			--create-change-history-table \
			${DRY_RUN} \

.PHONY: common_deploy