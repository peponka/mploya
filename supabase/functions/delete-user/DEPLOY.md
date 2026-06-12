# 🚀 Deploy Edge Function: delete-user

## Opción A: Desde la CLI de Supabase (recomendado)

```bash
# 1. Instalar Supabase CLI si no la tenés
npm install -g supabase

# 2. Login (te va a pedir un access token de supabase.com/dashboard/account/tokens)
supabase login

# 3. Linkear al proyecto
supabase link --project-ref TU_PROJECT_REF

# 4. Deploy
supabase functions deploy delete-user
```

## Opción B: Desde el Dashboard (más fácil)

1. Ir a **supabase.com/dashboard** → tu proyecto
2. Menú lateral → **Edge Functions**
3. Click **"New Function"**
4. Nombre: `delete-user`
5. Pegar el contenido de `supabase/functions/delete-user/index.ts`
6. Click **Deploy**

## Verificar que funciona

```bash
# Test con curl (reemplazar valores)
curl -X POST 'https://TU_PROJECT_REF.supabase.co/functions/v1/delete-user' \
  -H 'Authorization: Bearer TU_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "UN_USER_ID_DE_TEST"}'
```

Respuesta esperada:
```json
{"success": true, "message": "Cuenta eliminada permanentemente."}
```

## ⚠️ IMPORTANTE

- La `SUPABASE_SERVICE_ROLE_KEY` ya está disponible automáticamente como secret en todas las Edge Functions.
- NO necesitás configurarla manualmente.
- La función verifica que el JWT del caller coincida con el `user_id` del body (un usuario solo puede eliminarse a sí mismo).
