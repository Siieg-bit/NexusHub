# Checklist Pixel-Perfect: NexusHub → Amino Apps

## Correções Visuais
- [x] 1. Paleta de cores do AppTheme (azul-marinho #0D1B2A, accent #00BCD4, FAB rosa #E91E63) ✓
- [x] 2. Bottom Navigation Bar Global (ícones pena/grid/balão/prédio, cores ciano) ✓
- [x] 3. Bottom Navigation Bar Comunidade (5 tabs, FAB rosa central, avatar no "Me") ✓
- [x] 4. Top Bar Global (pílula de moedas proporcional, espaçamentos exatos) ✓
- [x] 5. Sidebar/Drawer da comunidade (animação push/scale, módulos dinâmicos do ACM) ✓
- [x] 6. Avatar Frames que vazam a borda (overflow visible, não ClipOval) ✓
- [x] 7. Chat Bubbles customizados (9-patch com decorações, não apenas cor de fundo) ✓

## Funcionalidades Faltantes
- [x] 8. Heatmap de Check-in (grid estilo GitHub contributions na tela de Realizações) ✓
- [x] 9. Gravação de Voice Notes no chat (substituir placeholder "em breve") ✓
- [x] 10. Sistema de Tips/Gorjetas no chat (substituir placeholder "em breve") ✓
- [x] 11. Shared Folder — Pasta Compartilhada da comunidade ✓
- [x] 12. Screening Rooms — Assistir vídeos juntos com chat de voz ✓
- [x] 13. Rich Text Editor de Blocos para blogs (imagens inline entre parágrafos) ✓
- [x] 14. Stories reais (conteúdo efêmero estilo Reels, não apenas lista de posts) ✓

## Recomendações de Refatoração Pixel-Perfect
- [x] 15. Rec.1: CustomPainter/AnimatedBuilder (AminoDrawerController push/scale, AminoBottomNavBar com notch, AminoCustomTitle) ✓
- [x] 16. Rec.2: Motor 9-slice real para Chat Bubbles (NineSliceBubble + ProceduralBubbleFrame) ✓
- [x] 17. Rec.3: BlockContentRenderer integrado no PostDetailScreen e PostCard ✓
- [x] 18. Rec.4: Ajuste colorimétrico final (cores roxas → azul-marinho, Custom Titles pixel-perfect) ✓
