import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { FusionSolarAPI } from './fusion-solar-api.ts'
import { syncUserData } from './sync-service.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get all users with FusionSolar credentials
    const { data: users, error: usersError } = await supabaseClient
      .from('users')
      .select('id, fusion_solar_api_username, fusion_solar_api_password, fusion_solar_xsrf_token')
      .not('fusion_solar_api_username', 'is', null)
      .not('fusion_solar_api_password', 'is', null)

    if (usersError) {
      throw new Error(`Error fetching users: ${usersError.message}`)
    }

    const fusionSolarAPI = new FusionSolarAPI()
    const results = []

    for (const user of users || []) {
      try {
        const result = await syncUserData(user, fusionSolarAPI, supabaseClient)
        results.push(result)
      } catch (error) {
        console.error(`Error processing user ${user.id}:`, error)
        results.push({ 
          userId: user.id, 
          status: 'error', 
          error: error.message 
        })
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        processed: results.length,
        results 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )
  } catch (error) {
    console.error('Sync error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})