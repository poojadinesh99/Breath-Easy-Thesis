import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// Use the correct import for v4 from uuid module
import { v4 } from "https://deno.land/std@0.168.0/uuid/mod.ts";



const supabaseUrl = "https://fjxofvxbujivsqyfbldu.supabase.co";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseServiceRoleKey) {
  throw new Error("Missing SUPABASE_SERVICE_ROLE_KEY environment variable");
}
const backendPredictUrl = "https://render-backend-url/predict";  // Update this after deploy

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

serve(async (req: Request) => {
  try {
    const event = await req.json();

    if (
      event.type === "INSERT" &&
      event.table === "storage.objects" &&
      event.record.bucket_id === "recordings" &&
      event.record.name.includes("/cough/")
    ) {
      const { user_id, id: recording_id, name: filePath } = event.record;

      const { data: publicUrlData } = supabase.storage
        .from("recordings")
        .getPublicUrl(filePath);

      if (!publicUrlData?.publicUrl) {
        console.error("Failed to get public URL");
        return new Response("Failed to get public URL", { status: 500 });
      }

      const publicUrl = publicUrlData.publicUrl;

      const response = await fetch(backendPredictUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ file_url: publicUrl }),
      });

      if (!response.ok) {
        console.error("Backend predict request failed:", await response.text());
        return new Response("Backend predict request failed", { status: 500 });
      }

      const result = await response.json();
      const covidProb = result.covid_prob;

      const { error: insertError } = await supabase
        .from("diagnosis")
        .insert({
          id: v4,
          user_id,
          recording_id,
          covid_probability: covidProb,
          created_at: new Date().toISOString(),
        });

      if (insertError) {
        console.error("Failed to insert diagnosis record:", insertError);
        return new Response("Failed to insert diagnosis record", { status: 500 });
      }

      return new Response("Diagnosis recorded", { status: 200 });
    }

    return new Response("Event ignored", { status: 200 });
  } catch (error) {
    console.error("Error processing event:", error);
    return new Response("Internal server error", { status: 500 });
  }
});