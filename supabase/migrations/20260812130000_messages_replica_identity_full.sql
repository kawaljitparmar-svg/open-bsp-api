-- Supabase realtime cannot filter UPDATE events by non-primary-key columns
-- (e.g. organization_id) without REPLICA IDENTITY FULL. Without it, message
-- status updates (delivered/read) never reach the browser in real-time —
-- the client sees the blue tick only after a full page refresh.
alter table public.messages replica identity full;
alter table public.conversations replica identity full;
