# Debug Notes - Perfil Global

## Usuários no banco:
- 497ae299-6c0d-46ba-a91b-e7a7497495e1 - CosplayQueen
- a0058b34-5d2e-4958-9a00-8f100c1e7e41 - Sieg (icon_url: NULL)
- 145894ab-cd52-4aa2-a7d0-47cc0242218d - OtakuMaster
- 83cb7112-53dd-4099-abc3-402cd1a4e833 - ProGamer99
- 962a3554-554c-4968-a7ce-fb3943f276d1 - ArtistaSoul

## RPC get_user_profile:
- Existe no banco
- Aceita p_user_id uuid
- Retorna JSONB
- Quando user não existe: {"error":"user_not_found"}
- Quando user existe: preciso testar

## Problema provável:
1. A RPC retorna {"error":"user_not_found"} quando o perfil não é encontrado
2. O app tenta UserModel.fromJson() nesse JSON de erro
3. O campo 'id' não existe no JSON de erro, causando crash
4. OU: O Supabase client retorna o JSONB de forma que o cast falha
