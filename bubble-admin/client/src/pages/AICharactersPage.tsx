import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Bot, Plus, Pencil, Trash2, Eye, EyeOff, Search, RefreshCw,
  Tag, Globe, Zap, MessageSquare, X, Save, ChevronDown,
  Sparkles, Brain, Activity, Users, Hash,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type AICharacter = {
  id: string;
  name: string;
  avatar_url: string | null;
  description: string;
  system_prompt: string;
  tags: string[];
  language: string;
  is_active: boolean;
  created_at: string;
};

type CharacterForm = Omit<AICharacter, "id" | "created_at">;

const EMPTY_FORM: CharacterForm = {
  name: "",
  avatar_url: null,
  description: "",
  system_prompt: "",
  tags: [],
  language: "pt",
  is_active: true,
};

const LANGUAGES = [
  { code: "pt", label: "Português (BR)" },
  { code: "en", label: "English" },
  { code: "es", label: "Español" },
  { code: "ja", label: "日本語" },
];

const TAG_SUGGESTIONS = [
  "fantasia", "humor", "educação", "ciência", "história", "roleplay",
  "filosofia", "culinária", "motivação", "mistério", "poesia", "tecnologia",
  "espiritualidade", "artes marciais", "ficção científica", "aventura",
];

const fadeUp = {
  hidden: { opacity: 0, y: 10 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.22 } }),
};

// ─── Modal de Edição ──────────────────────────────────────────────────────────
function CharacterModal({
  character,
  onClose,
  onSave,
}: {
  character: AICharacter | null;
  onClose: () => void;
  onSave: () => void;
}) {
  const [form, setForm] = useState<CharacterForm>(
    character
      ? {
          name: character.name,
          avatar_url: character.avatar_url,
          description: character.description,
          system_prompt: character.system_prompt,
          tags: character.tags ?? [],
          language: character.language ?? "pt",
          is_active: character.is_active,
        }
      : { ...EMPTY_FORM }
  );
  const [tagInput, setTagInput] = useState("");
  const [saving, setSaving] = useState(false);
  const [promptChars, setPromptChars] = useState(form.system_prompt.length);

  function addTag(tag: string) {
    const clean = tag.trim().toLowerCase();
    if (clean && !form.tags.includes(clean)) {
      setForm((f) => ({ ...f, tags: [...f.tags, clean] }));
    }
    setTagInput("");
  }

  function removeTag(tag: string) {
    setForm((f) => ({ ...f, tags: f.tags.filter((t) => t !== tag) }));
  }

  async function handleSave() {
    if (!form.name.trim() || !form.description.trim() || !form.system_prompt.trim()) {
      toast.error("Nome, descrição e prompt são obrigatórios.");
      return;
    }
    setSaving(true);
    try {
      if (character) {
        const { error } = await supabase.rpc("admin_update_ai_character", {
          p_id: character.id,
          p_name: form.name.trim(),
          p_description: form.description.trim(),
          p_system_prompt: form.system_prompt.trim(),
          p_tags: form.tags,
          p_language: form.language,
          p_avatar_url: form.avatar_url || null,
          p_is_active: form.is_active,
        });
        if (error) throw error;
        toast.success("Personagem atualizado!");
      } else {
        const { error } = await supabase.rpc("admin_create_ai_character", {
          p_name: form.name.trim(),
          p_description: form.description.trim(),
          p_system_prompt: form.system_prompt.trim(),
          p_tags: form.tags,
          p_language: form.language,
          p_avatar_url: form.avatar_url || null,
          p_is_active: form.is_active,
        });
        if (error) throw error;
        toast.success("Personagem criado!");
      }
      onSave();
      onClose();
    } catch (e: unknown) {
      toast.error((e as Error).message ?? "Erro ao salvar.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(6px)" }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.96, y: 12 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.96, y: 12 }}
        className="w-full max-w-2xl rounded-2xl overflow-hidden flex flex-col"
        style={{
          background: "linear-gradient(145deg, #1a1a2e 0%, #16213e 100%)",
          border: "1px solid rgba(139,92,246,0.25)",
          maxHeight: "90vh",
        }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-white/[0.06]">
          <div className="flex items-center gap-3">
            <div
              className="w-8 h-8 rounded-lg flex items-center justify-center"
              style={{ background: "rgba(139,92,246,0.2)", border: "1px solid rgba(139,92,246,0.4)" }}
            >
              <Bot size={16} style={{ color: "#8B5CF6" }} />
            </div>
            <span className="font-semibold text-white text-sm">
              {character ? "Editar Personagem" : "Novo Personagem de IA"}
            </span>
          </div>
          <button onClick={onClose} className="text-white/40 hover:text-white/70 transition-colors">
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <div className="overflow-y-auto flex-1 p-6 space-y-5">
          {/* Nome + Avatar */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-[10px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
                Nome *
              </label>
              <input
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="Ex: Detetive Noir"
                className="w-full rounded-lg px-3 py-2 text-sm text-white placeholder-white/25 outline-none focus:ring-1"
                style={{
                  background: "rgba(255,255,255,0.05)",
                  border: "1px solid rgba(255,255,255,0.1)",
                  focusRingColor: "#8B5CF6",
                }}
              />
            </div>
            <div>
              <label className="block text-[10px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
                URL do Avatar
              </label>
              <input
                value={form.avatar_url ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, avatar_url: e.target.value || null }))}
                placeholder="https://..."
                className="w-full rounded-lg px-3 py-2 text-sm text-white placeholder-white/25 outline-none"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
              />
            </div>
          </div>

          {/* Descrição */}
          <div>
            <label className="block text-[10px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
              Descrição * <span style={{ color: "rgba(255,255,255,0.2)" }}>(exibida na seleção)</span>
            </label>
            <textarea
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              placeholder="Uma frase curta que descreve a personalidade do personagem..."
              rows={2}
              className="w-full rounded-lg px-3 py-2 text-sm text-white placeholder-white/25 outline-none resize-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>

          {/* System Prompt */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.35)" }}>
                System Prompt * <span style={{ color: "rgba(255,255,255,0.2)" }}>(instrução para a IA)</span>
              </label>
              <span
                className="text-[10px] font-mono"
                style={{ color: promptChars > 2000 ? "#EF4444" : "rgba(255,255,255,0.25)" }}
              >
                {promptChars}/2000
              </span>
            </div>
            <textarea
              value={form.system_prompt}
              onChange={(e) => {
                setForm((f) => ({ ...f, system_prompt: e.target.value }));
                setPromptChars(e.target.value.length);
              }}
              placeholder="Você é um personagem que... Responda sempre em... Seu estilo é..."
              rows={6}
              className="w-full rounded-lg px-3 py-2 text-sm text-white placeholder-white/25 outline-none resize-none font-mono"
              style={{
                background: "rgba(139,92,246,0.06)",
                border: "1px solid rgba(139,92,246,0.2)",
                lineHeight: "1.6",
              }}
            />
            <p className="text-[10px] mt-1" style={{ color: "rgba(255,255,255,0.2)" }}>
              Este texto é enviado como instrução de sistema para o modelo de linguagem. Seja específico sobre personalidade, estilo de fala e limitações.
            </p>
          </div>

          {/* Tags */}
          <div>
            <label className="block text-[10px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
              Tags
            </label>
            <div className="flex flex-wrap gap-1.5 mb-2">
              {form.tags.map((tag) => (
                <span
                  key={tag}
                  className="flex items-center gap-1 px-2 py-0.5 rounded-full text-xs cursor-pointer"
                  style={{ background: "rgba(139,92,246,0.15)", border: "1px solid rgba(139,92,246,0.3)", color: "#A78BFA" }}
                  onClick={() => removeTag(tag)}
                >
                  {tag} <X size={10} />
                </span>
              ))}
            </div>
            <div className="flex gap-2">
              <input
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter" || e.key === ",") { e.preventDefault(); addTag(tagInput); } }}
                placeholder="Digite uma tag e pressione Enter..."
                className="flex-1 rounded-lg px-3 py-2 text-sm text-white placeholder-white/25 outline-none"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
              />
            </div>
            <div className="flex flex-wrap gap-1 mt-2">
              {TAG_SUGGESTIONS.filter((t) => !form.tags.includes(t)).slice(0, 8).map((tag) => (
                <button
                  key={tag}
                  onClick={() => addTag(tag)}
                  className="px-2 py-0.5 rounded-full text-[10px] transition-colors"
                  style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.35)" }}
                >
                  + {tag}
                </button>
              ))}
            </div>
          </div>

          {/* Idioma + Ativo */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-[10px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
                Idioma
              </label>
              <div className="relative">
                <select
                  value={form.language}
                  onChange={(e) => setForm((f) => ({ ...f, language: e.target.value }))}
                  className="w-full rounded-lg px-3 py-2 text-sm text-white outline-none appearance-none"
                  style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
                >
                  {LANGUAGES.map((l) => (
                    <option key={l.code} value={l.code} style={{ background: "#1a1a2e" }}>
                      {l.label}
                    </option>
                  ))}
                </select>
                <ChevronDown size={14} className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: "rgba(255,255,255,0.3)" }} />
              </div>
            </div>
            <div>
              <label className="block text-[10px] font-mono tracking-widest uppercase mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
                Status
              </label>
              <button
                onClick={() => setForm((f) => ({ ...f, is_active: !f.is_active }))}
                className="w-full rounded-lg px-3 py-2 text-sm font-medium flex items-center gap-2 transition-all"
                style={{
                  background: form.is_active ? "rgba(34,197,94,0.1)" : "rgba(239,68,68,0.1)",
                  border: `1px solid ${form.is_active ? "rgba(34,197,94,0.3)" : "rgba(239,68,68,0.3)"}`,
                  color: form.is_active ? "#22C55E" : "#EF4444",
                }}
              >
                {form.is_active ? <Eye size={14} /> : <EyeOff size={14} />}
                {form.is_active ? "Ativo (visível)" : "Inativo (oculto)"}
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-white/[0.06] flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-lg text-sm transition-colors"
            style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}
          >
            Cancelar
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="px-5 py-2 rounded-lg text-sm font-semibold flex items-center gap-2 transition-all"
            style={{
              background: saving ? "rgba(139,92,246,0.3)" : "rgba(139,92,246,0.85)",
              color: "white",
              opacity: saving ? 0.7 : 1,
            }}
          >
            {saving ? <RefreshCw size={14} className="animate-spin" /> : <Save size={14} />}
            {saving ? "Salvando..." : character ? "Salvar Alterações" : "Criar Personagem"}
          </button>
        </div>
      </motion.div>
    </div>
  );
}

// ─── Card de Personagem ───────────────────────────────────────────────────────
function CharacterCard({
  character,
  index,
  onEdit,
  onToggle,
  onDelete,
}: {
  character: AICharacter;
  index: number;
  onEdit: () => void;
  onToggle: () => void;
  onDelete: () => void;
}) {
  const [expanded, setExpanded] = useState(false);

  return (
    <motion.div
      custom={index}
      variants={fadeUp}
      initial="hidden"
      animate="show"
      className="rounded-xl overflow-hidden"
      style={{
        background: "rgba(255,255,255,0.03)",
        border: character.is_active
          ? "1px solid rgba(139,92,246,0.2)"
          : "1px solid rgba(255,255,255,0.06)",
      }}
    >
      <div className="p-4">
        <div className="flex items-start gap-3">
          {/* Avatar */}
          <div
            className="w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0 overflow-hidden"
            style={{
              background: character.is_active
                ? "linear-gradient(135deg, rgba(139,92,246,0.3), rgba(59,130,246,0.3))"
                : "rgba(255,255,255,0.05)",
              border: character.is_active
                ? "1px solid rgba(139,92,246,0.4)"
                : "1px solid rgba(255,255,255,0.08)",
            }}
          >
            {character.avatar_url ? (
              <img src={character.avatar_url} alt={character.name} className="w-full h-full object-cover" />
            ) : (
              <Bot size={22} style={{ color: character.is_active ? "#8B5CF6" : "rgba(255,255,255,0.2)" }} />
            )}
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-0.5">
              <span className="font-semibold text-sm text-white truncate">{character.name}</span>
              <span
                className="text-[9px] font-mono px-1.5 py-0.5 rounded-full flex-shrink-0"
                style={{
                  background: character.is_active ? "rgba(34,197,94,0.15)" : "rgba(239,68,68,0.12)",
                  color: character.is_active ? "#22C55E" : "#EF4444",
                  border: `1px solid ${character.is_active ? "rgba(34,197,94,0.25)" : "rgba(239,68,68,0.2)"}`,
                }}
              >
                {character.is_active ? "ATIVO" : "INATIVO"}
              </span>
              <span
                className="text-[9px] font-mono px-1.5 py-0.5 rounded-full flex-shrink-0"
                style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.3)" }}
              >
                {LANGUAGES.find((l) => l.code === character.language)?.label ?? character.language}
              </span>
            </div>
            <p className="text-xs leading-relaxed" style={{ color: "rgba(255,255,255,0.45)" }}>
              {character.description}
            </p>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-1 flex-shrink-0">
            <button
              onClick={() => setExpanded((e) => !e)}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors"
              style={{ background: "rgba(255,255,255,0.05)" }}
              title="Ver prompt"
            >
              <Brain size={13} style={{ color: "rgba(255,255,255,0.4)" }} />
            </button>
            <button
              onClick={onToggle}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors"
              style={{ background: "rgba(255,255,255,0.05)" }}
              title={character.is_active ? "Desativar" : "Ativar"}
            >
              {character.is_active ? (
                <EyeOff size={13} style={{ color: "#F97316" }} />
              ) : (
                <Eye size={13} style={{ color: "#22C55E" }} />
              )}
            </button>
            <button
              onClick={onEdit}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors"
              style={{ background: "rgba(255,255,255,0.05)" }}
              title="Editar"
            >
              <Pencil size={13} style={{ color: "#60A5FA" }} />
            </button>
            <button
              onClick={onDelete}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors"
              style={{ background: "rgba(255,255,255,0.05)" }}
              title="Excluir"
            >
              <Trash2 size={13} style={{ color: "#EF4444" }} />
            </button>
          </div>
        </div>

        {/* Tags */}
        {character.tags && character.tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-3">
            {character.tags.map((tag) => (
              <span
                key={tag}
                className="text-[10px] px-2 py-0.5 rounded-full"
                style={{ background: "rgba(139,92,246,0.1)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.2)" }}
              >
                {tag}
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Prompt expandido */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-hidden"
          >
            <div
              className="px-4 pb-4 pt-0"
              style={{ borderTop: "1px solid rgba(139,92,246,0.1)" }}
            >
              <p className="text-[10px] font-mono tracking-widest uppercase mb-2 mt-3" style={{ color: "rgba(255,255,255,0.25)" }}>
                System Prompt
              </p>
              <pre
                className="text-xs leading-relaxed whitespace-pre-wrap font-mono rounded-lg p-3"
                style={{
                  background: "rgba(139,92,246,0.06)",
                  border: "1px solid rgba(139,92,246,0.15)",
                  color: "rgba(255,255,255,0.6)",
                }}
              >
                {character.system_prompt}
              </pre>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

// ─── Página Principal ─────────────────────────────────────────────────────────
export default function AICharactersPage() {
  const { canModerate } = useAuth();
  const [characters, setCharacters] = useState<AICharacter[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [filterActive, setFilterActive] = useState<"all" | "active" | "inactive">("all");
  const [editTarget, setEditTarget] = useState<AICharacter | null | "new">(null);
  const [deleteTarget, setDeleteTarget] = useState<AICharacter | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .rpc("admin_get_ai_characters");
    if (!error && data) setCharacters(data as AICharacter[]);
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  async function handleToggle(char: AICharacter) {
    const { error } = await supabase
      .rpc("admin_toggle_ai_character", { p_id: char.id, p_active: !char.is_active });
    if (error) { toast.error("Erro ao alterar status."); return; }
    toast.success(char.is_active ? "Personagem desativado." : "Personagem ativado!");
    load();
  }

  async function handleDelete(char: AICharacter) {
    const { error } = await supabase.rpc("admin_delete_ai_character", { p_id: char.id });
    if (error) { toast.error("Erro ao excluir."); return; }
    toast.success("Personagem excluído.");
    setDeleteTarget(null);
    load();
  }

  const filtered = characters.filter((c) => {
    const matchSearch =
      !search ||
      c.name.toLowerCase().includes(search.toLowerCase()) ||
      c.description.toLowerCase().includes(search.toLowerCase()) ||
      c.tags?.some((t) => t.toLowerCase().includes(search.toLowerCase()));
    const matchFilter =
      filterActive === "all" ||
      (filterActive === "active" && c.is_active) ||
      (filterActive === "inactive" && !c.is_active);
    return matchSearch && matchFilter;
  });

  const stats = {
    total: characters.length,
    active: characters.filter((c) => c.is_active).length,
    inactive: characters.filter((c) => !c.is_active).length,
    languages: [...new Set(characters.map((c) => c.language))].length,
  };

  if (!canModerate) {
    return (
      <div className="flex items-center justify-center h-64">
        <p style={{ color: "rgba(255,255,255,0.3)" }}>Acesso restrito.</p>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <div
              className="w-9 h-9 rounded-xl flex items-center justify-center"
              style={{ background: "rgba(139,92,246,0.2)", border: "1px solid rgba(139,92,246,0.4)" }}
            >
              <Sparkles size={18} style={{ color: "#8B5CF6" }} />
            </div>
            <h1 className="text-xl font-bold text-white">AI Characters Studio</h1>
          </div>
          <p className="text-sm ml-12" style={{ color: "rgba(255,255,255,0.35)" }}>
            Crie e gerencie as personas de inteligência artificial da plataforma
          </p>
        </div>
        <button
          onClick={() => setEditTarget("new")}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold transition-all hover:scale-105"
          style={{
            background: "linear-gradient(135deg, rgba(139,92,246,0.8), rgba(59,130,246,0.8))",
            border: "1px solid rgba(139,92,246,0.5)",
            color: "white",
          }}
        >
          <Plus size={15} />
          Novo Personagem
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-3">
        {[
          { label: "Total", value: stats.total, icon: Bot, color: "#8B5CF6" },
          { label: "Ativos", value: stats.active, icon: Activity, color: "#22C55E" },
          { label: "Inativos", value: stats.inactive, icon: EyeOff, color: "#EF4444" },
          { label: "Idiomas", value: stats.languages, icon: Globe, color: "#60A5FA" },
        ].map((s) => (
          <div
            key={s.label}
            className="rounded-xl p-4 flex items-center gap-3"
            style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
          >
            <div
              className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0"
              style={{ background: `rgba(${s.color === "#8B5CF6" ? "139,92,246" : s.color === "#22C55E" ? "34,197,94" : s.color === "#EF4444" ? "239,68,68" : "96,165,250"},0.15)` }}
            >
              <s.icon size={16} style={{ color: s.color }} />
            </div>
            <div>
              <p className="text-xl font-bold text-white leading-none">{s.value}</p>
              <p className="text-[10px] font-mono tracking-widest uppercase mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
                {s.label}
              </p>
            </div>
          </div>
        ))}
      </div>

      {/* Filtros */}
      <div className="flex items-center gap-3">
        <div
          className="flex-1 flex items-center gap-2 rounded-xl px-3 py-2"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <Search size={14} style={{ color: "rgba(255,255,255,0.3)" }} />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nome, descrição ou tag..."
            className="flex-1 bg-transparent text-sm text-white placeholder-white/25 outline-none"
          />
        </div>
        <div className="flex gap-1 rounded-xl p-1" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
          {(["all", "active", "inactive"] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilterActive(f)}
              className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
              style={{
                background: filterActive === f ? "rgba(139,92,246,0.25)" : "transparent",
                color: filterActive === f ? "#A78BFA" : "rgba(255,255,255,0.35)",
                border: filterActive === f ? "1px solid rgba(139,92,246,0.3)" : "1px solid transparent",
              }}
            >
              {f === "all" ? "Todos" : f === "active" ? "Ativos" : "Inativos"}
            </button>
          ))}
        </div>
        <button
          onClick={load}
          className="w-9 h-9 rounded-xl flex items-center justify-center transition-colors"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <RefreshCw size={14} style={{ color: "rgba(255,255,255,0.4)" }} className={loading ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Lista */}
      {loading ? (
        <div className="flex items-center justify-center h-40">
          <RefreshCw size={20} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : filtered.length === 0 ? (
        <div
          className="rounded-xl p-12 flex flex-col items-center justify-center gap-3"
          style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}
        >
          <Bot size={36} style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>
            {search ? "Nenhum personagem encontrado." : "Nenhum personagem criado ainda."}
          </p>
          {!search && (
            <button
              onClick={() => setEditTarget("new")}
              className="mt-2 px-4 py-2 rounded-lg text-sm font-medium"
              style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.25)" }}
            >
              Criar primeiro personagem
            </button>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3">
          {filtered.map((char, i) => (
            <CharacterCard
              key={char.id}
              character={char}
              index={i}
              onEdit={() => setEditTarget(char)}
              onToggle={() => handleToggle(char)}
              onDelete={() => setDeleteTarget(char)}
            />
          ))}
        </div>
      )}

      {/* Modal de edição */}
      <AnimatePresence>
        {editTarget !== null && (
          <CharacterModal
            character={editTarget === "new" ? null : editTarget}
            onClose={() => setEditTarget(null)}
            onSave={load}
          />
        )}
      </AnimatePresence>

      {/* Confirm Delete */}
      <AnimatePresence>
        {deleteTarget && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
            style={{ background: "rgba(0,0,0,0.75)", backdropFilter: "blur(6px)" }}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="rounded-2xl p-6 w-full max-w-sm text-center"
              style={{ background: "#1a1a2e", border: "1px solid rgba(239,68,68,0.3)" }}
            >
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4"
                style={{ background: "rgba(239,68,68,0.15)" }}
              >
                <Trash2 size={22} style={{ color: "#EF4444" }} />
              </div>
              <h3 className="text-white font-semibold mb-2">Excluir personagem?</h3>
              <p className="text-sm mb-5" style={{ color: "rgba(255,255,255,0.4)" }}>
                <strong className="text-white">{deleteTarget.name}</strong> será removido permanentemente. Sessões de roleplay ativas serão encerradas.
              </p>
              <div className="flex gap-3">
                <button
                  onClick={() => setDeleteTarget(null)}
                  className="flex-1 py-2 rounded-lg text-sm"
                  style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}
                >
                  Cancelar
                </button>
                <button
                  onClick={() => handleDelete(deleteTarget)}
                  className="flex-1 py-2 rounded-lg text-sm font-semibold"
                  style={{ background: "rgba(239,68,68,0.8)", color: "white" }}
                >
                  Excluir
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
