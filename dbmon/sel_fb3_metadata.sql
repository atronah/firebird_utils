select
    a.mon$remote_host
    , a.mon$remote_os_user
    , a.mon$remote_process
    , a.mon$client_version
    , a.mon$auth_method

    -- built-in variables
    -- -- CURRENT_ROLE is a context variable containing the role of the currently connected user.
    -- -- If there is no active role, CURRENT_ROLE is 'NONE'.
    , current_role as builtin_var_current_role
    -- -- CURRENT_USER is a context variable containing the name of the currently connected user. It is fully equivalent to USER.
    , current_user as builtin_var_current_user
    -- -- CURRENT_CONNECTION contains the unique identifier of the current connection.
    -- -- Its value is derived from a counter on the database header page, which is incremented for each new connection.
    -- -- When a database is restored, this counter is reset to zero.
    , current_connection as builtin_var_current_connection
    -- -- CURRENT_TRANSACTION contains the unique identifier of the current transaction.
    , current_transaction as builtin_var_current_transaction

    -- Context variables in the SYSTEM namespace
    -- -- For TCP, this is the IP address. For XNET, the local process ID. For all other protocols this variable is NULL.
    , rdb$get_context('SYSTEM', 'CLIENT_ADDRESS') as CLIENT_ADDRESS
    -- -- The wire protocol host name of remote client. Value is returned for all supported protocols
    , rdb$get_context('SYSTEM', 'CLIENT_HOST') as CLIENT_HOST
    -- -- Process ID of remote client application.
    , rdb$get_context('SYSTEM', 'CLIENT_PID') as CLIENT_PID
    -- -- Process name of remote client application.
    , rdb$get_context('SYSTEM', 'CLIENT_PROCESS') as CLIENT_PROCESS
    -- -- Same as global CURRENT_ROLE variable.
    , rdb$get_context('SYSTEM', 'CURRENT_ROLE') as context_CURRENT_ROLE
    -- -- Same as global CURRENT_USER variable
    , rdb$get_context('SYSTEM', 'CURRENT_USER') as context_CURRENT_USER
    -- -- Either the full path to the database or — if connecting via the path is disallowed — its alias
    , rdb$get_context('SYSTEM', 'DB_NAME') as DB_NAME
    -- -- The Firebird engine (server) version
    , rdb$get_context('SYSTEM', 'ENGINE_VERSION') as ENGINE_VERSION
    -- -- The isolation level of the current transaction: 'READ COMMITTED', 'SNAPSHOT' or 'CONSISTENCY'.
    , rdb$get_context('SYSTEM', 'ISOLATION_LEVEL') as ISOLATION_LEVEL
    -- -- Lock timeout of the current transaction.
    , rdb$get_context('SYSTEM', 'LOCK_TIMEOUT') as LOCK_TIMEOUT
    -- -- The protocol used for the connection: 'TCPv4', 'TCPv6', 'WNET', 'XNET' or NULL.
    , rdb$get_context('SYSTEM', 'NETWORK_PROTOCOL') as NETWORK_PROTOCOL
    -- -- Returns 'TRUE' if current transaction is read-only and 'FALSE' otherwise.
    , rdb$get_context('SYSTEM', 'READ_ONLY') as READ_ONLY
    -- -- Same as global CURRENT_CONNECTION variable.
    , rdb$get_context('SYSTEM', 'SESSION_ID') as SESSION_ID
    -- -- Same as global CURRENT_TRANSACTION variable
    , rdb$get_context('SYSTEM', 'TRANSACTION_ID') as TRANSACTION_ID

    -- -- Compression status of the current connection. If the connection is compressed, returns TRUE; if it
    -- -- is not compressed, returns FALSE. Returns NULL if the connection is embedded.
    -- -- Introduced in Firebird 3.0.4
    , rdb$get_context('SYSTEM', 'WIRE_COMPRESSED') as WIRE_COMPRESSED
    -- -- Encryption status of the current connection. If the connection is encrypted, returns TRUE; if it is
    -- -- not encrypted, returns FALSE. Returns NULL if the connection is embedded.
    -- -- Introduced in Firebird 3.0.4.
    , rdb$get_context('SYSTEM', 'WIRE_ENCRYPTED') as WIRE_ENCRYPTED

    -- The DDL_TRIGGER namespace is valid only when a DDL trigger is running. Its use is also valid in
    -- stored procedures and functions called by DDL triggers.
    /*
    -- -- event type (CREATE, ALTER, DROP)
    , rdb$get_context('DDL_TRIGGER', 'EVENT_TYPE') as EVENT_TYPE
    -- -- object type (TABLE, VIEW, etc)
    , rdb$get_context('DDL_TRIGGER', 'OBJECT_TYPE') as OBJECT_TYPE
    -- -- event name (<ddl event item>), where <ddl_event_item> is EVENT_TYPE || ' ' || OBJECT_TYPE
    , rdb$get_context('DDL_TRIGGER', 'DDL_EVENT') as DDL_EVENT
    -- -- metadata object name
    -- -- ALTER DOMAIN old-name TO new-name sets OLD_OBJECT_NAME and NEW_OBJECT_NAME in both BEFORE and AFTER triggers.
    -- -- For this command, OBJECT_NAME will have the old object name in BEFORE triggers, and the new object name in AFTER triggers
    , rdb$get_context('DDL_TRIGGER', 'OBJECT_NAME') as OBJECT_NAME
    -- -- for tracking the renaming of a domain (see note)
    , rdb$get_context('DDL_TRIGGER', 'OLD_OBJECT_NAME') as OLD_OBJECT_NAME
    -- -- for tracking the renaming of a domain (see note)
    , rdb$get_context('DDL_TRIGGER', 'NEW_OBJECT_NAME') as NEW_OBJECT_NAME
    -- -- sql statement text
    , rdb$get_context('DDL_TRIGGER', 'SQL_TEXT') as SQL_TEXT
    */
from mon$attachments as a
where a.mon$attachment_id = current_connection