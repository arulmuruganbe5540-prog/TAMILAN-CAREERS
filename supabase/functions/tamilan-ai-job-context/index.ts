// TAMILAN AI read-only job context endpoint. Fail-closed and source-only.
import { createClient } from "npm:@supabase/supabase-js@2";
import { createJobContextHandler, type RetrievalClient } from "./handler.ts";

Deno.serve(createJobContextHandler(
  (name) => Deno.env.get(name),
  (url, anonKey, authorization) => createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  }) as unknown as RetrievalClient,
));
