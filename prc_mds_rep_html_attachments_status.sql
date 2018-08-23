set term ^ ;

create or alter procedure mds_rep_html_attachments_status
returns(
    html blob sub_type text
)
as
begin
    for with summary as (
            select
                a.mon$remote_process as remote_process
                , count(distinct a.mon$attachment_id) as attachments_count
                , list(distinct a.mon$remote_address, ', ') as addresses_list
            from mon$attachments as a
            where a.mon$state = 1  -- только активные
            group by 1
        )
        , details as (
            select
                a.mon$remote_address as remote_address
                , a.mon$remote_process as remote_process
                , a.mon$attachment_name as name
                , a.mon$attachment_id as attachment_id
                , a.mon$server_pid as server_pid
                , a.mon$remote_pid as remote_pid
                , a.mon$timestamp as established_at
                , r.mon$record_seq_reads as non_indexed_reads
                , r.mon$record_idx_reads as indexed_reads
                , r.mon$record_inserts as records_inserted
                , r.mon$record_updates as records_updated
                , r.mon$record_deletes as records_deleted
                , count(distinct iif(tr.mon$lock_timeout = -1, tr.mon$transaction_id, null)) as infinite_waits
                , count(distinct iif(tr.mon$lock_timeout = 0, tr.mon$transaction_id, null)) as no_waits
                , count(distinct iif(tr.mon$lock_timeout > 0, tr.mon$transaction_id, null)) as waits
            from mon$attachments as a
                inner join rdb$character_sets as cs on a.mon$character_set_id = cs.rdb$character_set_id
                left join mon$record_stats as r on a.mon$stat_id = r.mon$stat_id
                left join mon$transactions as tr on tr.mon$attachment_id = a.mon$attachment_id
                                                        and tr.mon$state = 1 -- 'STARTED'
            where a.mon$state = 1  -- только активные
            group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
        )
        select list(html) 
        from (
            select
                '
                <p>
                    <table border="1">
                        <caption>Details</caption>
                        <tr>
                            <th>Remote process</th>
                            <th>Active attachments count</th>
                            <th>Remote addresses of attachments</th>
                        </tr>
                        '
                            || list('<tr>
                                        <td>' || remote_process || '</td>'
                                        || '<td>' || attachments_count || '</td>'
                                        || '<td>' || addresses_list || '</td>
                                    </tr>', '
    '                           ) ||
                        '
                    </table>
                </p>
                </br>' as html
            from summary
            union all
            select
            
                '
                <p>
                    <table border="1">
                        <caption>Summary attachments info</caption>
                        <tr>
                            <th>Remote address</th>
                            <th>Remote process</th>
                            <th>DB</th>
                            <th>Att.ID</th>
                            <th>Server PID</th>
                            <th>Remote PID</th>
                            <th>Established At</th>
                            <th>NIR</th>
                            <th>IR</th>
                            <th>Ins</th>
                            <th>Upd</th>
                            <th>Del</th>
                            <th>InfWaits</th>
                            <th>NoWaits</th>
                            <th>Waits</th>
                        </tr>
                        '
                            || list('<tr>'
                                        || '<td>' || remote_address || '</td>'
                                        || '<td>' || remote_process || '</td>'
                                        || '<td>' || name || '</td>'
                                        || '<td>' || attachment_id || '</td>'
                                        || '<td>' || server_pid || '</td>'
                                        || '<td>' || remote_pid || '</td>'
                                        || '<td>' || established_at || '</td>'
                                        || '<td>' || non_indexed_reads || '</td>'
                                        || '<td>' || indexed_reads || '</td>'
                                        || '<td>' || records_inserted || '</td>'
                                        || '<td>' || records_updated || '</td>'
                                        || '<td>' || records_deleted || '</td>'
                                        || '<td>' || infinite_waits || '</td>'
                                        || '<td>' || no_waits || '</td>'
                                        || '<td>' || waits || '</td>'
                                || '</tr>', '
    '                           ) ||
                        '
                    </table>
                </p>
                </br>' as html
            from details
        )
        into html
    do suspend;
end^

set term ; ^