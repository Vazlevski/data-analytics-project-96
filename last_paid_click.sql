WITH paid_sessions AS (
    SELECT 
        s.visitor_id,
        s.visit_date,
        s.landing_page,
        s.source,
        s.medium,
        s.campaign,
        s.content
    FROM 
        sessions s
    WHERE 
        s.medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
last_paid_clicks AS (
    SELECT 
        ps.visitor_id,
        MAX(ps.visit_date) AS last_paid_click_date
    FROM 
        paid_sessions ps
    GROUP BY 
        ps.visitor_id
),
custom_leads AS (
    SELECT 
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
    FROM 
        paid_sessions ps
    LEFT JOIN 
        leads l ON ps.visitor_id = l.visitor_id AND ps.visit_date <= l.created_at
    JOIN 
        last_paid_clicks lpc ON ps.visitor_id = lpc.visitor_id AND ps.visit_date = lpc.last_paid_click_date
)
SELECT 
    cl.visitor_id,
    cl.visit_date,
    cl.source AS utm_source,
    cl.medium AS utm_medium,
    cl.campaign AS utm_campaign,
    cl.lead_id,
    cl.created_at,
    cl.amount,
    cl.closing_reason,
    cl.status_id
FROM 
    custom_leads cl
ORDER BY 
    cl.amount DESC NULLS LAST,
    cl.visit_date ASC,
    cl.source ASC,
    cl.medium ASC,
    cl.campaign asc
   	limit 10;
