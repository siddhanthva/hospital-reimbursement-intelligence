# dbt runtime for this project, pinned to the exact versions verified
# locally and in CI (.github/workflows/dbt-ci.yml) on Day 9 --
# dbt-core 1.12.0rc3 / dbt-postgres 1.10.2 -- so a model that passes here
# behaves the same way it does everywhere else this project runs dbt.
FROM python:3.11-slim

WORKDIR /usr/app

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# The project itself (dbt/cms_spine) is bind-mounted at runtime, not baked
# into the image, so local model edits are picked up without a rebuild.
ENTRYPOINT ["entrypoint.sh"]
CMD ["dbt", "--version"]
