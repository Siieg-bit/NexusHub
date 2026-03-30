-- Migração 030: Tabela de links customizáveis para seção "General" do drawer
-- Permite que líderes de comunidade adicionem links externos personalizados

CREATE TABLE IF NOT EXISTS community_general_links (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  icon_url TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para busca por comunidade
CREATE INDEX IF NOT EXISTS idx_community_general_links_community_id
  ON community_general_links(community_id)
  WHERE is_active = true;

-- RLS
ALTER TABLE community_general_links ENABLE ROW LEVEL SECURITY;

-- Qualquer membro autenticado pode ler
CREATE POLICY "community_general_links_read" ON community_general_links
  FOR SELECT USING (auth.role() = 'authenticated');

-- Apenas líderes/agentes podem inserir/atualizar/deletar
CREATE POLICY "community_general_links_write" ON community_general_links
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM community_members
      WHERE community_members.community_id = community_general_links.community_id
        AND community_members.user_id = auth.uid()
        AND community_members.role IN ('leader', 'agent', 'admin')
        AND community_members.is_banned = false
    )
  );

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_community_general_links_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER community_general_links_updated_at
  BEFORE UPDATE ON community_general_links
  FOR EACH ROW EXECUTE FUNCTION update_community_general_links_updated_at();

COMMENT ON TABLE community_general_links IS 
  'Links customizáveis para a seção General do drawer de cada comunidade. Gerenciados pelos líderes.';
