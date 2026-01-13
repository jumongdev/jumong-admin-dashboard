// Import via URL to prevent bundling errors
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';
import { decode } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface UpdatePayload {
  user_id: string; // The ID of the user to update
  new_role: string;  // The new role to set
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. --- Security Check: Verify the CALLER is an admin ---
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing Authorization header');

    const token = authHeader.replace('Bearer ', '');
    const [_header, payload, _signature] = decode(token);
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

    // 2. --- Main Logic: Update the target user's role ---
    const { user_id, new_role }: UpdatePayload = await req.json();

    if (!user_id || !new_role) {
      throw new Error('user_id and new_role are required.');
    }

    // Ensure the role is one of the allowed values
    const allowedRoles = ['admin', 'manager', 'cashier'];
    if (!allowedRoles.includes(new_role)) {
        throw new Error(`Invalid role. Must be one of: ${allowedRoles.join(', ')}`);
    }

    // Use the admin client to update the user's role in the profiles table
    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({ user_role: new_role })
      .eq('id', user_id);

    if (updateError) {
      throw new Error(`Failed to update role: ${updateError.message}`);
    }

    // 3. --- Success Response ---
    return new Response(JSON.stringify({ message: 'User role updated successfully.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
