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
        ps.source as utm_source,
        ps.medium as utm_medium,
        ps.campaign as utm_campaign,
        ps.content,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        date(ps.visit_date) as visit_date
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
),
ad_spending as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(campaign_date) as spend_date,
        sum(daily_spent) as total_cost
    from
        vk_ads
    group by
        utm_source, utm_medium, utm_campaign, campaign_date
    union all
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(campaign_date) as spend_date,
        sum(daily_spent) as total_cost
    from
        ya_ads
    group by
        utm_source, utm_medium, utm_campaign, campaign_date
),
prom_shag as (
    select
        cl.visit_date,
        cl.utm_source,
        cl.utm_medium,
        cl.utm_campaign,
        count(distinct cl.visitor_id) as visitors_count,
        count(
            case when cl.created_at is not null then cl.visitor_id end
        ) as leads_count,
        count(
            case
                when
                    cl.status_id = 142 or closing_reason = 'Успешная продажа'
                    then cl.visitor_id
            end
        ) as purchases_count,
        sum(
            case
                when
                    cl.status_id = 142 or closing_reason = 'Успешная продажа'
                    then amount
            end
        ) as revenue
    from
        custom_leads as cl
    group by
        cl.visit_date,
        cl.utm_source,
        cl.utm_medium,
        cl.utm_campaign
)
select
    ps.visit_date,
    ps.visitors_count,
    ps.utm_source,
    ps.utm_medium,
    ps.utm_campaign,
    ad.total_cost,
    ps.leads_count,
    ps.purchases_count,
    ps.revenue
from
    prom_shag as ps
left join ad_spending as ad
    on
        ps.utm_source = ad.utm_source
        and ps.utm_medium = ad.utm_medium
        and ps.utm_campaign = ad.utm_campaign
        and ps.visit_date = ad.spend_date
order by
    ps.revenue desc nulls last,
    ps.visit_date asc,
    ps.visitors_count desc,
    ps.utm_source asc,
    ps.utm_medium asc,
    ps.utm_campaign asc
limit 15;