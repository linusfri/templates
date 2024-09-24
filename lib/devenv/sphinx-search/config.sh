#!/bin/bash

if [[ "$SPHINX_DB_NAMES" == "" ]]; then
    echo "SPHINX_DB_NAMES not set"
    exit 1
fi

[[ "$SPHINX_DB_HOST" == "" ]] && SPHINX_DB_HOST="localhost"
[[ "$SPHINX_DB_USER" == "" ]] && SPHINX_DB_USER="root"
[[ "$SPHINX_DB_PASS" == "" ]] && SPHINX_DB_PASS="secret"
[[ "$SPHINX_DB_PORT" == "" ]] && SPHINX_DB_PORT="3306"
[[ "$SPHINX_DB_ENCODING" == "" ]] && SPHINX_DB_ENCODING="utf8mb4"
[[ "$SPHINX_LISTEN_PORT" == "" ]] && SPHINX_LISTEN_PORT="9312"
[[ "$SPHINX_READ_TIMEOUT" == "" ]] && SPHINX_READ_TIMEOUT="5"
[[ "$SPHINX_MAX_CHILDREN" == "" ]] && SPHINX_MAX_CHILDREN="30"
[[ "$SPHINX_LOG" == "" ]] && SPHINX_LOG="/dev/stdout"
[[ "$SPHINX_QUERY_LOG" == "" ]] && SPHINX_QUERY_LOG="/dev/stdout"
[[ "$SPHINX_PID" == "" ]] && SPHINX_PID="/var/run/sphinxsearch/searchd.pid"
[[ "$SPHINX_DATA" == "" ]] && SPHINX_DATA="/var/lib/sphinxsearch/data"

SPHINX_DB_NAMES="${SPHINX_DB_NAMES//,/ }"

cat << EOF

  searchd
  {
    listen              = $SPHINX_LISTEN_PORT
    listen              = 9306:mysql41
    log                 = $SPHINX_LOG
    query_log           = $SPHINX_QUERY_LOG
    query_log_format    = sphinxql
    read_timeout        = $SPHINX_READ_TIMEOUT
    max_children        = $SPHINX_MAX_CHILDREN
    pid_file            = $SPHINX_PID
    workers             = threads
    collation_server    = utf8_general_ci
  }

  source base
  {
    type                = mysql
    sql_host            = $SPHINX_DB_HOST
    sql_user            = $SPHINX_DB_USER
    sql_pass            = $SPHINX_DB_PASS
    sql_port            = $SPHINX_DB_PORT
    sql_query_pre       = SET NAMES $SPHINX_DB_ENCODING
  }

  index base
  {
    html_strip          = 1
    expand_keywords     = 1
    min_prefix_len      = 0
    min_infix_len       = 2
    min_word_len        = 2
    index_exact_words   = 1
    charset_type        = utf-8
    charset_table       = 0..9, A..Z->a..z, _, a..z, U+410..U+42F->U+430..U+44F, U+430..U+44F
  }

EOF

for opts in $SPHINX_DB_NAMES; do
  db="$(echo "$opts" | cut -d ':' -f 1)"
  db_opts="$(echo "$opts::" | cut -d ':' -f 2)"
  db_opts="${db_opts//;/ }"
  db_type=""
  db_prefix=""

  eval "$db_opts"
  echo "  # db_type=$db_type"
  echo "  # db_prefix=$db_prefix"

  inc="config.$db_type.sh"

  if [[ ! -f "$inc" ]]; then
    echo "$inc not found"
    exit 1
  fi

  source "$inc"

done
