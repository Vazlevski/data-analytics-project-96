with paid_sessions as (
    select
        s.visitor_id,
        s.source,
        s.medium,
        s.campaign,
        s.content,
        to_char(s.visit_date::date, 'YYYY-MM-DD') as visit_date
    from
        sessions as s
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

last_paid_clicks as (
    select
        ps.visitor_id,
        max(to_char(ps.visit_date::date, 'YYYY-MM-DD')) as last_paid_click_date
    from
        paid_sessions as ps
    group by
        ps.visitor_id
),

custom_leads as (
    select
        ps.visit_date,
        ps.source,
        ps.medium,
        ps.campaign,
        count(distinct ps.visitor_id) as visitors_count,
        count(distinct l.lead_id) as leads_count,
        count(
            distinct case
                when
                    l.closing_reason = 'Успешно реализовано'
                    or l.status_id = 142
                    then l.lead_id
            end
        ) as purchases_count,
        sum(
            case
                when
                    l.closing_reason = 'Успешно реализовано'
                    or l.status_id = 142
                    then l.amount
                else 0
            end
        ) as revenue
    from
        paid_sessions as ps
    left join
        leads as l
        on
            ps.visitor_id = l.visitor_id
            and ps.visit_date <= to_char(l.created_at::date, 'YYYY-MM-DD')
    inner join
        last_paid_clicks as lpc
        on
            ps.visitor_id = lpc.visitor_id
            and ps.visit_date = lpc.last_paid_click_date
    group by
        ps.visit_date, ps.source, ps.medium, ps.campaign
),

vk_ad_spending as (
    select
        utm_source as source,
        utm_medium as medium,
        utm_campaign as campaign,
        to_char(campaign_date::date, 'YYYY-MM-DD') as spend_date,
        sum(daily_spent) as total_cost
    from
        vk_ads
    group by
        utm_source, utm_medium, utm_campaign, campaign_date
),

ya_ad_spending as (
    select
        utm_source as source,
        utm_medium as medium,
        utm_campaign as campaign,
        to_char(campaign_date::date, 'YYYY-MM-DD') as spend_date,
        sum(daily_spent) as total_cost
    from
        ya_ads
    group by
        utm_source, utm_medium, utm_campaign, campaign_date
)

select
    cl.visit_date,
    cl.source as utm_source,
    cl.medium as utm_medium,
    cl.campaign as utm_campaign,
    cl.visitors_count,
    cl.leads_count,
    cl.purchases_count,
    cl.revenue,
    coalesce(vk.total_cost, 0) + coalesce(ya.total_cost, 0) as total_cost
from
    custom_leads as cl
left join
    vk_ad_spending as vk
    on
        cl.source = vk.source
        and cl.medium = vk.medium
        and cl.campaign = vk.campaign
        and cl.visit_date = vk.spend_date
left join
    ya_ad_spending as ya
    on
        cl.source = ya.source
        and cl.medium = ya.medium
        and cl.campaign = ya.campaign
        and cl.visit_date = ya.spend_date
order by
    cl.revenue desc nulls last,
    cl.visit_date asc,
    cl.visitors_count desc,
    cl.source asc,
    cl.medium asc,
    cl.campaign asc;