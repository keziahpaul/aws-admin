FROM python:3.12-bookworm AS build

ENV AWSCLI_VERSION=1.33.32
ENV SCHEMACHANGE_VERSION=3.6.2
ARG snowflake_user=snowflake_user

# Make sure the build environment has the latest code to build things
# Install a Python virtual environment
# Install Python build tools
RUN apt-get update \
 && apt-get upgrade  --yes \
 && apt-get install --no-install-suggests --no-install-recommends --yes python3-venv gcc libpython3-dev \
 && python3 -m venv /venv \
 && /venv/bin/pip install --upgrade pip setuptools wheel

FROM build AS build-venv
# Now we have a build environment to leverage
# Install schemachange and awscli into the Python venv
RUN /venv/bin/pip --no-cache-dir install --disable-pip-version-check --upgrade schemachange==${SCHEMACHANGE_VERSION}
RUN /venv/bin/pip --no-cache-dir install --disable-pip-version-check --upgrade awscli==${AWSCLI_VERSION}

# Install project requirements
# Uninstall the Python toolchain from venv
COPY requirements.txt /requirements.txt
RUN /venv/bin/pip install --disable-pip-version-check -r /requirements.txt \
 && /venv/bin/pip uninstall --disable-pip-version-check --yes pip setuptools wheel \
 && rm -rf /venv/share

FROM python:3.12-slim-bookworm
# Make sure our "slim" version is up to date
RUN apt-get update \
 && apt-get upgrade --yes \
 && apt-get install -y zip unzip make git


# Copy our pre-built Python virtual environment
COPY --from=build-venv /venv /venv
WORKDIR /project

# Make the Python virtual environment path first
ENV PATH=/venv/bin:$PATH

CMD [ "schemachange", "-h" ]
