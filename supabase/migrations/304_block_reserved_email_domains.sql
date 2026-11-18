-- Google's automated pre-launch testing signs up with test@example.com. The
-- reserved example domains and special-use TLDs (RFC 2606 / RFC 6761) can
-- never receive mail, so every such attempt sent a sign-in code that bounced,
-- which counts against the sender reputation that keeps real codes out of
-- spam. Blocking them at sign-up (hook_before_user_created via
-- is_disposable_email_domain, which also matches subdomains) stops the sends.
-- No real member can use these addresses.

INSERT INTO public.disposable_email_domains(domain)
VALUES
  ('example.com'),
  ('example.org'),
  ('example.net'),
  ('example'),
  ('test'),
  ('invalid'),
  ('localhost')
ON CONFLICT (domain) DO NOTHING;
