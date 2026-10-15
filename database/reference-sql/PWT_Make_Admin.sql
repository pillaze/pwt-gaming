-- Run this AFTER you have created and confirmed your PWT website account.
-- Replace YOUR_EMAIL_HERE with the email you used to sign up.

update public.profiles
set role = 'admin'
where id = (
  select id
  from auth.users
  where email = 'YOUR_EMAIL_HERE'
);

-- Verify:
select p.display_name, p.role, u.email
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'YOUR_EMAIL_HERE';
