select
    date(visit_date) as date1,
    count(distinct visitor_id) as visitors_count
from
    sessions
group by
    date(visit_date)
order by
    date(visit_date);

select
    source,
    date(visit_date) as date1,
    count(distinct visitor_id) as visitors_count
from
    sessions
group by
    date(visit_date), source
order by
    date(visit_date), source;

select
    date(created_at) as date1,
    count(distinct lead_id) as leads_count
from
    leads
group by
    date(created_at)
order by
    date(created_at);

select
    date(sessions.visit_date) as date1,
    count(distinct sessions.visitor_id) as visitors_count,
    count(distinct leads.lead_id) as leads_count,
    (count(distinct leads.lead_id) * 1.0 / count(distinct sessions.visitor_id))
    * 100 as click_to_lead_conversion
from
    sessions
left join
    leads
    on
        sessions.visitor_id = leads.visitor_id
        and date(sessions.visit_date) = date(leads.created_at)
group by
    date(sessions.visit_date)
order by
    date(sessions.visit_date);

select
    ads.utm_source as source,
    date(ads.campaign_date) as date1,
    sum(ads.daily_spent) as total_spent
from
    (
        select
            campaign_date,
            utm_source,
            daily_spent
        from
            vk_ads
        union all
        select
            campaign_date,
            utm_source,
            daily_spent
        from
            ya_ads
    ) as ads
group by
    ads.campaign_date, ads.utm_source
order by
    ads.campaign_date, ads.utm_source;

with ads as (
    select
        utm_source,
        campaign_date,
        daily_spent
    from
        vk_ads
    union all
    select
        utm_source,
        campaign_date,
        daily_spent
    from
        ya_ads
)

select
    ads.utm_source as source,
    sum(ads.daily_spent) as total_cost,
    sum(leads.amount) as total_revenue,
    ((sum(leads.amount) - sum(ads.daily_spent)) / sum(ads.daily_spent))
    * 100 as roi
from
    leads
inner join
    ads on date(leads.created_at) = date(ads.campaign_date)
group by
    ads.utm_source
order by
    ads.utm_source;


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
                    cl.status_id = 142 or cl.closing_reason = 'Успешная продажа'
                    then cl.visitor_id
            end
        ) as purchases_count,
        sum(
            case
                when
                    cl.status_id = 142 or cl.closing_reason = 'Успешная продажа'
                    then cl.amount
            end
        ) as revenue
    from
        custom_leads as cl
    group by
        cl.visit_date,
        cl.utm_source,
        cl.utm_medium,
        cl.utm_campaign
),

next_shag as (
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
)

select
    utm_source,
    round(
        sum(coalesce(total_cost, 0)) / sum(coalesce(visitors_count, 0)), 2
    ) as cpu,
    round(
        sum(coalesce(total_cost, 0)) / sum(coalesce(leads_count, 0)), 2
    ) as cpl,
    round(
        sum(coalesce(total_cost, 0)) / sum(coalesce(purchases_count, 0)), 2
    ) as cpuu,
    round(
        (sum(coalesce(revenue, 0)) - sum(coalesce(total_cost, 0)))
        * 100.0
        / sum(coalesce(total_cost, 0)),
        2
    ) as roi
from next_shag
where utm_source in ('vk', 'yandex')
group by utm_source;
