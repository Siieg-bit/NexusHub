# Amino Nexus (NexusHub) - Documentação do Projeto

## 1. Visão Geral
O Amino Nexus (código-fonte NexusHub) é um aplicativo de comunidades e comunicação, focado em conectar pessoas através de chats, fóruns e mídias ricas.

## 2. Tecnologias Utilizadas
- **Frontend:** Flutter (Dart) com Riverpod para gerência de estado e GoRouter para navegação.
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Edge Functions).
- **Integrações:** Firebase (Push Notifications), Agora (Voice/Video - substituído por Screening Room), RevenueCat (IAP), AdMob (Ads), Giphy (GIFs).

## 3. Estrutura do Projeto
- `frontend/lib/features/`: Módulos principais do app (auth, chat, communities, feed, profile, stickers, etc).
- `frontend/lib/core/`: Serviços globais, utilitários e temas.
- `backend/supabase/migrations/`: Scripts SQL para criação de tabelas, RLS e RPCs.

## 4. Correções Recentes
- **Bug Fix #059:** Correção do loop infinito no botão de envio de mídia (imagem, vídeo, sticker) no chat, separando o controle de estado síncrono do callback de frame assíncrono.

## 5. Credenciais de Desenvolvimento (Supabase)
- **URL:** https://ylvzqqvcanzzswjkqeya.supabase.co
- **Anon Key:** sb_publishable_HYsYzaF8DuBgXpqJAICJ1Q_b73GLUeb

*(Esta documentação está em construção e será expandida)*
