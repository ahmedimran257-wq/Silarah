-- Chat translation was retired (translate-message answers 410) and the app no
-- longer stores translations. The writer stayed callable and accepted any
-- language-shaped key up to 4,000 characters, so a member could pad their own
-- messages with thousands of entries and grow the database toward its cap.
REVOKE EXECUTE ON FUNCTION public.store_message_translation(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
