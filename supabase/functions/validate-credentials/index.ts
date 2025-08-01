const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
Deno.serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    // Validate input
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({
        success: false,
        message: 'Only POST method is allowed'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 405
      });
    }
    const { userName, systemCode } = await req.json();
    // Validate required fields
    if (!userName || !systemCode) {
      return new Response(JSON.stringify({
        success: false,
        message: 'userName and systemCode are required'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 400
      });
    }
    // External API call with timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(()=>controller.abort(), 5000); // 5-second timeout
    try {
      const response = await fetch('https://eu5.fusionsolar.huawei.com/thirdData/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          userName,
          systemCode
        }),
        signal: controller.signal
      });
      clearTimeout(timeoutId);
      if (!response.ok) {
        return new Response(JSON.stringify({
          success: false,
          message: `External API returned status: ${response.status}`
        }), {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          },
          status: 502
        });
      }
      const data = await response.json();
      return new Response(JSON.stringify(data), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: 200
      });
    } catch (fetchError) {
      clearTimeout(timeoutId);
      return new Response(JSON.stringify({
        success: false,
        message: fetchError.name === 'AbortError' ? 'Request to external API timed out' : `Fetch error: ${fetchError.message}`
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        },
        status: fetchError.name === 'AbortError' ? 408 : 500
      });
    }
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      message: `Server error: ${error.message}`
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 500
    });
  }
});
