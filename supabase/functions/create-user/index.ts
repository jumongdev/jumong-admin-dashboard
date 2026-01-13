// create-user Edge Function
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';
import { decode } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';
console.info('create-user function starting');
Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing Authorization header');

    const token = authHeader.replace('Bearer ', '');
    const decoded = decode(token) as any;
    const payload = decoded[1] ?? decoded.payload ?? decoded;
    const callingUserId = payload.sub as string;

    if (!callingUserId) throw new Error('Invalid token');

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: adminProfile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('user_role')
      .eq('id', callingUserId)
      .single();

    if (profileError) throw profileError;

    if (adminProfile?.user_role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Permission denied' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Parse body for new user details
    const body = await req.json();
    const email = body.email as string;
    const password = body.password as string;
    const metadata = body.metadata ?? {};

    if (!email || !password) throw new Error('email and password are required.');
    if (password.length < 6) throw new Error('Password must be at least 6 characters long.');

    // Create user via admin client
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      user_metadata: metadata,
    });

    if (createError) throw new Error(`Failed to create user: ${createError.message}`);

    return new Response(JSON.stringify({ message: 'User created successfully.', user: newUser }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
