FROM postgres:15

COPY init-db.sh /docker-entrypoint-initdb.d

USER postgres
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD psql -c 'select 1' -d ccd_data -U ${DB_USERNAME}

EXPOSE 5432