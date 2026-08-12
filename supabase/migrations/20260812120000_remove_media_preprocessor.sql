drop trigger if exists handle_message_to_media_preprocessor on public.messages;

select cron.unschedule('preprocess-pending-messages');
