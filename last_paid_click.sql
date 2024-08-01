with paid_sessions as (
    select
        s.visitor_id,
        s.visit_date,
        s.landing_page,
        s.source,
        s.medium,
        s.campaign,
        s.content
    from
        sessions as s
    where
        s.medium != ('organic')
),

last_paid_clicks as (
    select
        ps.visitor_id,
        max(ps.visit_date) as last_paid_click_date
    from
        paid_sessions as ps
    group by
        ps.visitor_id
),

custom_leads as (
    select
        ps.visitor_id,
        ps.visit_date,
        ps.source,
        ps.medium,
        ps.campaign,
        ps.content,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from
        paid_sessions as ps
    left join
        leads as l
        on ps.visitor_id = l.visitor_id and ps.visit_date <= l.created_at
    inner join
        last_paid_clicks as lpc
        on
            ps.visitor_id = lpc.visitor_id
            and ps.visit_date = lpc.last_paid_click_date
)

select
    cl.visitor_id,
    cl.visit_date,
    cl.source as utm_source,
    cl.medium as utm_medium,
    cl.campaign as utm_campaign,
    cl.lead_id,
    cl.created_at,
    cl.amount,
    cl.closing_reason,
    cl.status_id
from
    custom_leads as cl
order by
    cl.amount desc nulls last,
    cl.visit_date asc,
    cl.source asc,
    cl.medium asc,
    cl.campaign asc;
