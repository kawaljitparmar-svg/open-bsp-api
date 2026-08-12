set check_function_bodies = off;

-- Fix: PostgreSQL fires BOTH the BEFORE INSERT and BEFORE UPDATE triggers for
-- INSERT ... ON CONFLICT DO UPDATE when the row already exists. The BEFORE
-- INSERT path (old=null) was unconditionally creating a contact, which became
-- an orphan once the BEFORE UPDATE path created the real contact. Skip contact
-- creation in the INSERT path if a row already exists for this address.
CREATE OR REPLACE FUNCTION public.manage_contact_on_address_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  -- Case 1: Synced Action = ADD
  if new.extra->'synced'->>'action' = 'add' then
    if old is not null and old.contact_id is not null then
      -- Preserve existing link: the upsert payload doesn't include contact_id,
      -- so new.contact_id would be null and overwrite the existing link.
      new.contact_id := old.contact_id;
    elsif new.contact_id is null then
      -- For INSERT ... ON CONFLICT DO UPDATE, PostgreSQL fires both the BEFORE
      -- INSERT trigger (old=null) and then the BEFORE UPDATE trigger. Skip
      -- contact creation in the INSERT path if the row already exists — the
      -- BEFORE UPDATE trigger will run next and handle it, avoiding an orphan.
      if old is null and exists (
        select 1 from public.contacts_addresses
        where organization_id = new.organization_id
          and service = new.service
          and address = new.address
      ) then
        return new;
      end if;

      -- No contact linked from either side, create one
      insert into public.contacts (
        organization_id,
        name
      ) values (
        new.organization_id,
        new.extra->'synced'->>'name'
      ) returning id into new.contact_id;
    end if;
  end if;

  -- Case 2: Synced Action = REMOVE
  if new.extra->'synced'->>'action' = 'remove' then
    new.contact_id := null;
  end if;

  return new;
end;
$function$
;

-- Clean up orphaned contacts left by the double-trigger bug.
-- Contacts with no linked contacts_addresses are always accidental;
-- all legitimately created contacts have at least one address row.
DELETE FROM public.contacts c
WHERE NOT EXISTS (
  SELECT 1 FROM public.contacts_addresses ca
  WHERE ca.contact_id = c.id
);
