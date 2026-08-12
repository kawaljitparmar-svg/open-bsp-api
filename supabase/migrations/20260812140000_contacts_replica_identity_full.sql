-- Same realtime filter requirement as messages/conversations: without
-- REPLICA IDENTITY FULL, UPDATE and DELETE events on contacts are silently
-- dropped by the server-side column filter, so contact renames and deletions
-- never reach the browser without a full page refresh.
alter table public.contacts replica identity full;
