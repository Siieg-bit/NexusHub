import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Brain, ThumbsUp, ThumbsDown, CheckCircle2, XCircle,
  Trash2, Edit3, Plus, RefreshCw, Bot, Zap, BarChart3,
  MessageSquare, Layers, ToggleLeft, ToggleRight, AlertTriangle,
  BookOpen, Sparkles, TrendingUp, Clock, Filter, ChevronDown,
  Save, X, Info, Activity, Eye,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type LearningMemory = {
  id: string;
  character_id: string;
  character_name: string;
  character_avatar: string | null;
  memory_type: "example" | "fact" | "preference" | "rule" | "tone";
  trigger_pattern: string;
  ideal_response: string;
  topic_tags: string[];
  approval_score: number;
  use_count: number;
  hit_count: number;
  status: "pending" | "approved" | "rejected" | "archived";
  admin_notes: string | null;
  created_at: string;
  approved_at: string | null;
  original_user_message?: string;
  original_rating?: number;
};

type FeedbackItem = {
  id: string;
  character_id: string;
  character_name: string;
  character_avatar: string | null;
  user_id: string;
  user_nickname: string | null;
  user_avatar: string | null;
  user_message: string;
  ai_response: string;
  rating: 1 | -1;
  topic_tags: string[];
  processed: boolean;
  created_at: string;
};

type BehaviorPattern = {
  id: string;
  character_id: string;
  character_name: string;
  character_avatar: string | null;
  pattern_key: string;
  pattern_label: string;
  pattern_rule: string;
  category: "style" | "length" | "format" | "topic" | "tone" | "custom";
  approval_rate: number;
  sample_count: number;
  is_active: boolean;
  is_auto: boolean;
  created_at: string;
};

type LearningStats = {
  total_feedbacks: number;
  positive_feedbacks: number;
  negative_feedbacks: number;
  memory_count: number;
  approval_rate: number;
  characters_learning: number;
  pending_queue: number;
  pending_memories: number;
};

type AICharacterBasic = {
  id: string;
  name: string;
  avatar_url: string | null;
  learning_enabled: boolean;
  auto_approve: boolean;
  min_approval_score: number;
  total_feedbacks: number;
  positive_feedbacks: number;
  memory_count: number;
};

type PageTab = "memories" | "queue" | "patterns" | "stats";

const MEMORY_TYPE_CONFIG = {
  example:    { label: "Exemplo",    color: "#8B5CF6", bg: "139,92,246",  icon: "💡" },
  fact:       { label: "Fato",       color: "#60A5FA", bg: "96,165,250",  icon: "📌" },
  preference: { label: "Preferência",color: "#F59E0B", bg: "245,158,11",  icon: "⭐" },
  rule:       { label: "Regra",      color: "#EF4444", bg: "239,68,68",   icon: "📏" },
  tone:       { label: "Tom",        color: "#34D399", bg: "52,211,153",  icon: "🎭" },
};

const PATTERN_CATEGORY_CONFIG = {
  style:   { label: "Estilo",   color: "#8B5CF6" },
  length:  { label: "Tamanho",  color: "#60A5FA" },
  format:  { label: "Formato",  color: "#F59E0B" },
  topic:   { label: "Tópico",   color: "#34D399" },
  tone:    { label: "Tom",      color: "#F472B6" },
  custom:  { label: "Customizado", color: "#94A3B8" },
};

const fadeUp = {
  hidden: { opacity: 0, y: 8 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.2 } }),
};

// ─── Modal de Edição de Memória ───────────────────────────────────────────────
function EditMemoryModal({
  memory,
  onClose,
  onSave,
}: {
  memory: LearningMemory | null;
  isNew?: boolean;
  characterId?: string;
  onClose: () => void;
  onSave: () => void;
}) {
  const [triggerPattern, setTriggerPattern] = useState(memory?.trigger_pattern ?? "");
  const [idealResponse, setIdealResponse] = useState(memory?.ideal_response ?? "");
  const [memoryType, setMemoryType] = useState<LearningMemory["memory_type"]>(memory?.memory_type ?? "example");
  const [topicTags, setTopicTags] = useState<string[]>(memory?.topic_tags ?? []);
  const [adminNotes, setAdminNotes] = useState(memory?.admin_notes ?? "");
  const [tagInput, setTagInput] = useState("");
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    if (!triggerPattern.trim() || !idealResponse.trim()) {
      toast.error("Padrão e resposta são obrigatórios");
      return;
    }
    setSaving(true);
    try {
      const { error } = await supabase.rpc("admin_edit_memory", {
        p_memory_id: memory!.id,
        p_trigger_pattern: triggerPattern.trim(),
        p_ideal_response: idealResponse.trim(),
        p_topic_tags: topicTags,
        p_memory_type: memoryType,
        p_admin_notes: adminNotes || null,
      });
      if (error) throw error;
      toast.success("Memória atualizada");
      onSave();
      onClose();
    } catch (e: unknown) {
      toast.error((e as Error).message ?? "Erro ao salvar");
    } finally {
      setSaving(false);
    }
  }

  function addTag() {
    const t = tagInput.trim().toLowerCase();
    if (t && !topicTags.includes(t)) setTopicTags([...topicTags, t]);
    setTagInput("");
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,0.85)", backdropFilter: "blur(10px)" }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 10 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="w-full max-w-2xl rounded-2xl overflow-hidden flex flex-col"
        style={{ background: "#0d1117", border: "1px solid rgba(255,255,255,0.1)", maxHeight: "90vh" }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ background: "rgba(139,92,246,0.15)" }}>
              <Edit3 size={15} style={{ color: "#8B5CF6" }} />
            </div>
            <h2 className="text-white font-semibold text-sm">Editar Memória</h2>
          </div>
          <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.06)" }}>
            <X size={13} style={{ color: "rgba(255,255,255,0.5)" }} />
          </button>
        </div>

        <div className="overflow-y-auto flex-1 p-5 space-y-4">
          {/* Tipo */}
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-2" style={{ color: "rgba(255,255,255,0.35)" }}>Tipo de Memória</label>
            <div className="flex flex-wrap gap-2">
              {(Object.entries(MEMORY_TYPE_CONFIG) as [LearningMemory["memory_type"], typeof MEMORY_TYPE_CONFIG[keyof typeof MEMORY_TYPE_CONFIG]][]).map(([key, cfg]) => (
                <button
                  key={key}
                  onClick={() => setMemoryType(key)}
                  className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                  style={{
                    background: memoryType === key ? `rgba(${cfg.bg},0.2)` : "rgba(255,255,255,0.04)",
                    color: memoryType === key ? cfg.color : "rgba(255,255,255,0.4)",
                    border: `1px solid ${memoryType === key ? `rgba(${cfg.bg},0.4)` : "rgba(255,255,255,0.08)"}`,
                  }}
                >
                  {cfg.icon} {cfg.label}
                </button>
              ))}
            </div>
          </div>

          {/* Padrão de ativação */}
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
              Padrão de Ativação <span style={{ color: "#EF4444" }}>*</span>
            </label>
            <p className="text-[10px] mb-2" style={{ color: "rgba(255,255,255,0.25)" }}>
              Tipo de mensagem do usuário que ativa esta memória (ex: "perguntas sobre culinária italiana")
            </p>
            <textarea
              value={triggerPattern}
              onChange={(e) => setTriggerPattern(e.target.value)}
              rows={2}
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>

          {/* Resposta ideal */}
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>
              Resposta Exemplar <span style={{ color: "#EF4444" }}>*</span>
            </label>
            <p className="text-[10px] mb-2" style={{ color: "rgba(255,255,255,0.25)" }}>
              A resposta ideal que a IA deve usar como referência neste contexto
            </p>
            <textarea
              value={idealResponse}
              onChange={(e) => setIdealResponse(e.target.value)}
              rows={5}
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>

          {/* Tags */}
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Tags de Tópico</label>
            <div className="flex flex-wrap gap-1.5 mb-2">
              {topicTags.map((tag) => (
                <span
                  key={tag}
                  className="flex items-center gap-1 px-2 py-0.5 rounded-md text-xs"
                  style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.25)" }}
                >
                  #{tag}
                  <button onClick={() => setTopicTags(topicTags.filter(t => t !== tag))} className="opacity-60 hover:opacity-100">
                    <X size={10} />
                  </button>
                </span>
              ))}
            </div>
            <div className="flex gap-2">
              <input
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && addTag()}
                placeholder="Adicionar tag..."
                className="flex-1 rounded-lg px-3 py-1.5 text-xs text-white outline-none"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)" }}
              />
              <button onClick={addTag} className="px-3 py-1.5 rounded-lg text-xs" style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA" }}>+</button>
            </div>
          </div>

          {/* Notas do admin */}
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Notas do Admin (opcional)</label>
            <input
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              placeholder="Observações internas..."
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>
        </div>

        {/* Footer */}
        <div className="flex gap-3 px-5 py-4" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
          <button onClick={onClose} className="flex-1 py-2.5 rounded-xl text-sm" style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}>
            Cancelar
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex-1 py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2"
            style={{ background: "rgba(139,92,246,0.8)", color: "white" }}
          >
            {saving ? <RefreshCw size={14} className="animate-spin" /> : <Save size={14} />}
            Salvar
          </button>
        </div>
      </motion.div>
    </div>
  );
}

// ─── Modal de Criação de Memória Manual ───────────────────────────────────────
function CreateMemoryModal({
  characters,
  onClose,
  onSave,
}: {
  characters: AICharacterBasic[];
  onClose: () => void;
  onSave: () => void;
}) {
  const [characterId, setCharacterId] = useState(characters[0]?.id ?? "");
  const [triggerPattern, setTriggerPattern] = useState("");
  const [idealResponse, setIdealResponse] = useState("");
  const [memoryType, setMemoryType] = useState<LearningMemory["memory_type"]>("example");
  const [topicTags, setTopicTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState("");
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    if (!characterId || !triggerPattern.trim() || !idealResponse.trim()) {
      toast.error("Personagem, padrão e resposta são obrigatórios");
      return;
    }
    setSaving(true);
    try {
      const { error } = await supabase.rpc("admin_create_memory", {
        p_character_id: characterId,
        p_memory_type: memoryType,
        p_trigger_pattern: triggerPattern.trim(),
        p_ideal_response: idealResponse.trim(),
        p_topic_tags: topicTags,
        p_approval_score: 5.0,
      });
      if (error) throw error;
      toast.success("Memória criada e aprovada");
      onSave();
      onClose();
    } catch (e: unknown) {
      toast.error((e as Error).message ?? "Erro ao criar");
    } finally {
      setSaving(false);
    }
  }

  function addTag() {
    const t = tagInput.trim().toLowerCase();
    if (t && !topicTags.includes(t)) setTopicTags([...topicTags, t]);
    setTagInput("");
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,0.85)", backdropFilter: "blur(10px)" }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 10 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="w-full max-w-2xl rounded-2xl overflow-hidden flex flex-col"
        style={{ background: "#0d1117", border: "1px solid rgba(255,255,255,0.1)", maxHeight: "90vh" }}
      >
        <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ background: "rgba(34,197,94,0.15)" }}>
              <Plus size={15} style={{ color: "#22C55E" }} />
            </div>
            <h2 className="text-white font-semibold text-sm">Nova Memória Manual</h2>
          </div>
          <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.06)" }}>
            <X size={13} style={{ color: "rgba(255,255,255,0.5)" }} />
          </button>
        </div>

        <div className="overflow-y-auto flex-1 p-5 space-y-4">
          {/* Personagem */}
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Personagem *</label>
            <select
              value={characterId}
              onChange={(e) => setCharacterId(e.target.value)}
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            >
              {characters.map(c => (
                <option key={c.id} value={c.id} style={{ background: "#0d1117" }}>{c.name}</option>
              ))}
            </select>
          </div>

          {/* Tipo */}
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-2" style={{ color: "rgba(255,255,255,0.35)" }}>Tipo</label>
            <div className="flex flex-wrap gap-2">
              {(Object.entries(MEMORY_TYPE_CONFIG) as [LearningMemory["memory_type"], typeof MEMORY_TYPE_CONFIG[keyof typeof MEMORY_TYPE_CONFIG]][]).map(([key, cfg]) => (
                <button
                  key={key}
                  onClick={() => setMemoryType(key)}
                  className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                  style={{
                    background: memoryType === key ? `rgba(${cfg.bg},0.2)` : "rgba(255,255,255,0.04)",
                    color: memoryType === key ? cfg.color : "rgba(255,255,255,0.4)",
                    border: `1px solid ${memoryType === key ? `rgba(${cfg.bg},0.4)` : "rgba(255,255,255,0.08)"}`,
                  }}
                >
                  {cfg.icon} {cfg.label}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Padrão de Ativação *</label>
            <textarea
              value={triggerPattern}
              onChange={(e) => setTriggerPattern(e.target.value)}
              rows={2}
              placeholder="Ex: quando o usuário perguntar sobre receitas italianas..."
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>

          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Resposta Exemplar *</label>
            <textarea
              value={idealResponse}
              onChange={(e) => setIdealResponse(e.target.value)}
              rows={5}
              placeholder="A resposta ideal que a IA deve usar como referência..."
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>

          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Tags</label>
            <div className="flex flex-wrap gap-1.5 mb-2">
              {topicTags.map((tag) => (
                <span key={tag} className="flex items-center gap-1 px-2 py-0.5 rounded-md text-xs" style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA" }}>
                  #{tag}
                  <button onClick={() => setTopicTags(topicTags.filter(t => t !== tag))}><X size={10} /></button>
                </span>
              ))}
            </div>
            <div className="flex gap-2">
              <input
                value={tagInput}
                onChange={(e) => setTagInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && addTag()}
                placeholder="Adicionar tag..."
                className="flex-1 rounded-lg px-3 py-1.5 text-xs text-white outline-none"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)" }}
              />
              <button onClick={addTag} className="px-3 py-1.5 rounded-lg text-xs" style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA" }}>+</button>
            </div>
          </div>
        </div>

        <div className="flex gap-3 px-5 py-4" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
          <button onClick={onClose} className="flex-1 py-2.5 rounded-xl text-sm" style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}>
            Cancelar
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex-1 py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2"
            style={{ background: "rgba(34,197,94,0.8)", color: "white" }}
          >
            {saving ? <RefreshCw size={14} className="animate-spin" /> : <Plus size={14} />}
            Criar Memória
          </button>
        </div>
      </motion.div>
    </div>
  );
}

// ─── Modal de Criação de Padrão ───────────────────────────────────────────────
function CreatePatternModal({
  characters,
  onClose,
  onSave,
}: {
  characters: AICharacterBasic[];
  onClose: () => void;
  onSave: () => void;
}) {
  const [characterId, setCharacterId] = useState(characters[0]?.id ?? "");
  const [patternKey, setPatternKey] = useState("");
  const [patternLabel, setPatternLabel] = useState("");
  const [patternRule, setPatternRule] = useState("");
  const [category, setCategory] = useState<BehaviorPattern["category"]>("custom");
  const [saving, setSaving] = useState(false);

  async function handleSave() {
    if (!characterId || !patternKey.trim() || !patternLabel.trim() || !patternRule.trim()) {
      toast.error("Todos os campos são obrigatórios");
      return;
    }
    setSaving(true);
    try {
      const { data, error } = await supabase.rpc("admin_create_behavior_pattern", {
        p_character_id: characterId,
        p_pattern_key: patternKey.trim().toLowerCase().replace(/\s+/g, "_"),
        p_pattern_label: patternLabel.trim(),
        p_pattern_rule: patternRule.trim(),
        p_category: category,
      });
      if (error) throw error;
      const result = data as { success: boolean; error?: string };
      if (!result.success) throw new Error(result.error ?? "Erro desconhecido");
      toast.success("Padrão criado");
      onSave();
      onClose();
    } catch (e: unknown) {
      toast.error((e as Error).message ?? "Erro ao criar");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,0.85)", backdropFilter: "blur(10px)" }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 10 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="w-full max-w-lg rounded-2xl overflow-hidden"
        style={{ background: "#0d1117", border: "1px solid rgba(255,255,255,0.1)" }}
      >
        <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <h2 className="text-white font-semibold text-sm">Novo Padrão de Comportamento</h2>
          <button onClick={onClose} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.06)" }}>
            <X size={13} style={{ color: "rgba(255,255,255,0.5)" }} />
          </button>
        </div>

        <div className="p-5 space-y-4">
          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Personagem *</label>
            <select
              value={characterId}
              onChange={(e) => setCharacterId(e.target.value)}
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            >
              {characters.map(c => (
                <option key={c.id} value={c.id} style={{ background: "#0d1117" }}>{c.name}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-2" style={{ color: "rgba(255,255,255,0.35)" }}>Categoria</label>
            <div className="flex flex-wrap gap-2">
              {(Object.entries(PATTERN_CATEGORY_CONFIG) as [BehaviorPattern["category"], typeof PATTERN_CATEGORY_CONFIG[keyof typeof PATTERN_CATEGORY_CONFIG]][]).map(([key, cfg]) => (
                <button
                  key={key}
                  onClick={() => setCategory(key)}
                  className="px-3 py-1 rounded-lg text-xs font-medium transition-all"
                  style={{
                    background: category === key ? `${cfg.color}22` : "rgba(255,255,255,0.04)",
                    color: category === key ? cfg.color : "rgba(255,255,255,0.4)",
                    border: `1px solid ${category === key ? `${cfg.color}44` : "rgba(255,255,255,0.08)"}`,
                  }}
                >
                  {cfg.label}
                </button>
              ))}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Chave (ID) *</label>
              <input
                value={patternKey}
                onChange={(e) => setPatternKey(e.target.value)}
                placeholder="ex: use_emojis"
                className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
              />
            </div>
            <div>
              <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Nome Legível *</label>
              <input
                value={patternLabel}
                onChange={(e) => setPatternLabel(e.target.value)}
                placeholder="ex: Usar emojis"
                className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
              />
            </div>
          </div>

          <div>
            <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Regra (injetada no system prompt) *</label>
            <textarea
              value={patternRule}
              onChange={(e) => setPatternRule(e.target.value)}
              rows={3}
              placeholder="Ex: Use emojis moderadamente para tornar as respostas mais expressivas e amigáveis."
              className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>
        </div>

        <div className="flex gap-3 px-5 py-4" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
          <button onClick={onClose} className="flex-1 py-2.5 rounded-xl text-sm" style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}>
            Cancelar
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex-1 py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2"
            style={{ background: "rgba(139,92,246,0.8)", color: "white" }}
          >
            {saving ? <RefreshCw size={14} className="animate-spin" /> : <Plus size={14} />}
            Criar Padrão
          </button>
        </div>
      </motion.div>
    </div>
  );
}

// ─── Aba: Memórias ────────────────────────────────────────────────────────────
function MemoriesTab({ characters }: { characters: AICharacterBasic[] }) {
  const [memories, setMemories] = useState<LearningMemory[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<"pending" | "approved" | "rejected" | "all">("pending");
  const [charFilter, setCharFilter] = useState<string>("all");
  const [editTarget, setEditTarget] = useState<LearningMemory | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_learning_memories", {
        p_character_id: charFilter === "all" ? null : charFilter,
        p_status: statusFilter,
        p_limit: 100,
        p_offset: 0,
      });
      if (error) throw error;
      const result = data as { data: LearningMemory[]; total: number };
      setMemories(result?.data ?? []);
    } catch {
      toast.error("Erro ao carregar memórias");
    } finally {
      setLoading(false);
    }
  }, [statusFilter, charFilter]);

  useEffect(() => { load(); }, [load]);

  async function handleApprove(id: string) {
    try {
      const { error } = await supabase.rpc("admin_approve_memory", { p_memory_id: id });
      if (error) throw error;
      toast.success("Memória aprovada");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  async function handleReject(id: string) {
    try {
      const { error } = await supabase.rpc("admin_reject_memory", { p_memory_id: id });
      if (error) throw error;
      toast.success("Memória rejeitada");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  async function handleDelete(id: string) {
    try {
      const { error } = await supabase.rpc("admin_delete_memory", { p_memory_id: id });
      if (error) throw error;
      toast.success("Memória excluída");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  const STATUS_TABS = [
    { id: "pending" as const,  label: "Pendentes",  color: "#F59E0B" },
    { id: "approved" as const, label: "Aprovadas",  color: "#22C55E" },
    { id: "rejected" as const, label: "Rejeitadas", color: "#EF4444" },
    { id: "all" as const,      label: "Todas",      color: "#94A3B8" },
  ];

  return (
    <div className="space-y-4">
      {/* Filtros */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex rounded-xl overflow-hidden" style={{ border: "1px solid rgba(255,255,255,0.08)" }}>
          {STATUS_TABS.map(s => (
            <button
              key={s.id}
              onClick={() => setStatusFilter(s.id)}
              className="px-3 py-1.5 text-xs font-medium transition-all"
              style={{
                background: statusFilter === s.id ? `${s.color}22` : "rgba(255,255,255,0.02)",
                color: statusFilter === s.id ? s.color : "rgba(255,255,255,0.35)",
              }}
            >
              {s.label}
            </button>
          ))}
        </div>

        <select
          value={charFilter}
          onChange={(e) => setCharFilter(e.target.value)}
          className="rounded-xl px-3 py-1.5 text-xs text-white outline-none"
          style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <option value="all" style={{ background: "#0d1117" }}>Todos os personagens</option>
          {characters.map(c => (
            <option key={c.id} value={c.id} style={{ background: "#0d1117" }}>{c.name}</option>
          ))}
        </select>

        <div className="ml-auto flex gap-2">
          <button
            onClick={() => setCreateOpen(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold"
            style={{ background: "rgba(34,197,94,0.15)", color: "#22C55E", border: "1px solid rgba(34,197,94,0.25)" }}
          >
            <Plus size={12} /> Nova Memória
          </button>
          <button onClick={load} className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
            <RefreshCw size={13} style={{ color: "rgba(255,255,255,0.4)" }} className={loading ? "animate-spin" : ""} />
          </button>
        </div>
      </div>

      {/* Lista */}
      {loading ? (
        <div className="flex items-center justify-center h-32">
          <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : memories.length === 0 ? (
        <div className="rounded-xl p-10 flex flex-col items-center gap-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
          <BookOpen size={28} style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>
            {statusFilter === "pending" ? "Nenhuma memória pendente de revisão." : "Nenhuma memória encontrada."}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {memories.map((m, i) => {
            const typeCfg = MEMORY_TYPE_CONFIG[m.memory_type];
            const isExpanded = expandedId === m.id;
            return (
              <motion.div
                key={m.id}
                custom={i}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                className="rounded-xl overflow-hidden"
                style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
              >
                {/* Header do card */}
                <div className="flex items-start gap-3 p-4">
                  {/* Avatar do personagem */}
                  <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 overflow-hidden" style={{ background: "rgba(139,92,246,0.15)" }}>
                    {m.character_avatar ? (
                      <img src={m.character_avatar} alt="" className="w-full h-full object-cover" />
                    ) : (
                      <Bot size={14} style={{ color: "#8B5CF6" }} />
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <span className="text-xs font-semibold text-white">{m.character_name}</span>
                      <span className="px-1.5 py-0.5 rounded text-[10px] font-medium" style={{ background: `rgba(${typeCfg.bg},0.15)`, color: typeCfg.color }}>
                        {typeCfg.icon} {typeCfg.label}
                      </span>
                      {m.topic_tags.slice(0, 3).map(tag => (
                        <span key={tag} className="px-1.5 py-0.5 rounded text-[10px]" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.35)" }}>
                          #{tag}
                        </span>
                      ))}
                      <span className="ml-auto text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
                        ⭐ {m.approval_score.toFixed(1)} · {m.use_count} usos
                      </span>
                    </div>
                    <p className="text-xs leading-relaxed" style={{ color: "rgba(255,255,255,0.55)" }}>
                      <span className="font-medium" style={{ color: "rgba(255,255,255,0.35)" }}>Padrão: </span>
                      {m.trigger_pattern.length > 120 ? m.trigger_pattern.slice(0, 120) + "..." : m.trigger_pattern}
                    </p>
                  </div>

                  <button
                    onClick={() => setExpandedId(isExpanded ? null : m.id)}
                    className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 transition-transform"
                    style={{ background: "rgba(255,255,255,0.05)", transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}
                  >
                    <ChevronDown size={13} style={{ color: "rgba(255,255,255,0.4)" }} />
                  </button>
                </div>

                {/* Conteúdo expandido */}
                <AnimatePresence>
                  {isExpanded && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.2 }}
                      className="overflow-hidden"
                    >
                      <div className="px-4 pb-4 space-y-3" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
                        <div className="pt-3">
                          <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.25)" }}>Resposta Exemplar</p>
                          <div className="rounded-lg p-3 text-xs leading-relaxed" style={{ background: "rgba(255,255,255,0.03)", color: "rgba(255,255,255,0.6)", whiteSpace: "pre-wrap" }}>
                            {m.ideal_response}
                          </div>
                        </div>
                        {m.original_user_message && (
                          <div>
                            <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.25)" }}>Mensagem Original do Usuário</p>
                            <div className="rounded-lg p-3 text-xs" style={{ background: "rgba(255,255,255,0.02)", color: "rgba(255,255,255,0.4)" }}>
                              {m.original_user_message}
                            </div>
                          </div>
                        )}
                        {m.admin_notes && (
                          <div className="flex items-start gap-2 p-2 rounded-lg" style={{ background: "rgba(245,158,11,0.08)", border: "1px solid rgba(245,158,11,0.15)" }}>
                            <Info size={12} style={{ color: "#F59E0B", flexShrink: 0, marginTop: 1 }} />
                            <p className="text-xs" style={{ color: "rgba(245,158,11,0.8)" }}>{m.admin_notes}</p>
                          </div>
                        )}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>

                {/* Ações */}
                <div className="flex items-center gap-2 px-4 py-2.5" style={{ borderTop: "1px solid rgba(255,255,255,0.05)", background: "rgba(0,0,0,0.15)" }}>
                  {m.status === "pending" && (
                    <>
                      <button
                        onClick={() => handleApprove(m.id)}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                        style={{ background: "rgba(34,197,94,0.15)", color: "#22C55E", border: "1px solid rgba(34,197,94,0.2)" }}
                      >
                        <CheckCircle2 size={12} /> Aprovar
                      </button>
                      <button
                        onClick={() => handleReject(m.id)}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                        style={{ background: "rgba(239,68,68,0.12)", color: "#EF4444", border: "1px solid rgba(239,68,68,0.2)" }}
                      >
                        <XCircle size={12} /> Rejeitar
                      </button>
                    </>
                  )}
                  {m.status === "rejected" && (
                    <button
                      onClick={() => handleApprove(m.id)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium"
                      style={{ background: "rgba(34,197,94,0.12)", color: "#22C55E" }}
                    >
                      <CheckCircle2 size={12} /> Reativar
                    </button>
                  )}
                  <button
                    onClick={() => setEditTarget(m)}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium ml-auto"
                    style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.5)" }}
                  >
                    <Edit3 size={12} /> Editar
                  </button>
                  <button
                    onClick={() => handleDelete(m.id)}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium"
                    style={{ background: "rgba(239,68,68,0.08)", color: "rgba(239,68,68,0.6)" }}
                  >
                    <Trash2 size={12} />
                  </button>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}

      <AnimatePresence>
        {editTarget && (
          <EditMemoryModal memory={editTarget} onClose={() => setEditTarget(null)} onSave={load} />
        )}
        {createOpen && (
          <CreateMemoryModal characters={characters} onClose={() => setCreateOpen(false)} onSave={load} />
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── Aba: Fila de Feedbacks ───────────────────────────────────────────────────
function FeedbackQueueTab({ characters }: { characters: AICharacterBasic[] }) {
  const [feedbacks, setFeedbacks] = useState<FeedbackItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [charFilter, setCharFilter] = useState<string>("all");
  const [ratingFilter, setRatingFilter] = useState<"all" | "positive" | "negative">("all");
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_feedback_queue", {
        p_character_id: charFilter === "all" ? null : charFilter,
        p_processed: false,
        p_limit: 100,
        p_offset: 0,
      });
      if (error) throw error;
      const result = data as { data: FeedbackItem[]; total: number };
      let items = result?.data ?? [];
      if (ratingFilter === "positive") items = items.filter(f => f.rating === 1);
      if (ratingFilter === "negative") items = items.filter(f => f.rating === -1);
      setFeedbacks(items);
    } catch {
      toast.error("Erro ao carregar fila de feedbacks");
    } finally {
      setLoading(false);
    }
  }, [charFilter, ratingFilter]);

  useEffect(() => { load(); }, [load]);

  async function handlePromote(feedback: FeedbackItem) {
    try {
      const { error } = await supabase.rpc("admin_promote_feedback_to_memory", {
        p_feedback_id: feedback.id,
        p_memory_type: "example",
      });
      if (error) throw error;
      toast.success("Feedback promovido para memória aprovada");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  return (
    <div className="space-y-4">
      {/* Info banner */}
      <div className="flex items-start gap-3 p-3 rounded-xl" style={{ background: "rgba(96,165,250,0.08)", border: "1px solid rgba(96,165,250,0.15)" }}>
        <Info size={14} style={{ color: "#60A5FA", flexShrink: 0, marginTop: 1 }} />
        <p className="text-xs" style={{ color: "rgba(96,165,250,0.8)" }}>
          Feedbacks positivos (👍) dos usuários ficam aqui aguardando revisão. Você pode promovê-los para memórias aprovadas que a IA usará como referência.
        </p>
      </div>

      {/* Filtros */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex rounded-xl overflow-hidden" style={{ border: "1px solid rgba(255,255,255,0.08)" }}>
          {[
            { id: "all" as const, label: "Todos" },
            { id: "positive" as const, label: "👍 Positivos" },
            { id: "negative" as const, label: "👎 Negativos" },
          ].map(f => (
            <button
              key={f.id}
              onClick={() => setRatingFilter(f.id)}
              className="px-3 py-1.5 text-xs font-medium transition-all"
              style={{
                background: ratingFilter === f.id ? "rgba(139,92,246,0.2)" : "rgba(255,255,255,0.02)",
                color: ratingFilter === f.id ? "#A78BFA" : "rgba(255,255,255,0.35)",
              }}
            >
              {f.label}
            </button>
          ))}
        </div>

        <select
          value={charFilter}
          onChange={(e) => setCharFilter(e.target.value)}
          className="rounded-xl px-3 py-1.5 text-xs text-white outline-none"
          style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <option value="all" style={{ background: "#0d1117" }}>Todos os personagens</option>
          {characters.map(c => (
            <option key={c.id} value={c.id} style={{ background: "#0d1117" }}>{c.name}</option>
          ))}
        </select>

        <button onClick={load} className="ml-auto w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
          <RefreshCw size={13} style={{ color: "rgba(255,255,255,0.4)" }} className={loading ? "animate-spin" : ""} />
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : feedbacks.length === 0 ? (
        <div className="rounded-xl p-10 flex flex-col items-center gap-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
          <MessageSquare size={28} style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Fila de feedbacks vazia.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {feedbacks.map((f, i) => {
            const isPositive = f.rating === 1;
            const isExpanded = expandedId === f.id;
            return (
              <motion.div
                key={f.id}
                custom={i}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                className="rounded-xl overflow-hidden"
                style={{ background: "rgba(255,255,255,0.03)", border: `1px solid ${isPositive ? "rgba(34,197,94,0.12)" : "rgba(239,68,68,0.12)"}` }}
              >
                <div className="flex items-start gap-3 p-4">
                  <div
                    className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                    style={{ background: isPositive ? "rgba(34,197,94,0.15)" : "rgba(239,68,68,0.15)" }}
                  >
                    {isPositive ? <ThumbsUp size={14} style={{ color: "#22C55E" }} /> : <ThumbsDown size={14} style={{ color: "#EF4444" }} />}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-xs font-semibold" style={{ color: isPositive ? "#22C55E" : "#EF4444" }}>
                        {isPositive ? "👍 Positivo" : "👎 Negativo"}
                      </span>
                      <span className="text-xs text-white">{f.character_name}</span>
                      {f.user_nickname && (
                        <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>por @{f.user_nickname}</span>
                      )}
                      <span className="ml-auto text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                        {new Date(f.created_at).toLocaleDateString("pt-BR")}
                      </span>
                    </div>
                    <p className="text-xs" style={{ color: "rgba(255,255,255,0.5)" }}>
                      <span style={{ color: "rgba(255,255,255,0.3)" }}>Usuário: </span>
                      {f.user_message.length > 100 ? f.user_message.slice(0, 100) + "..." : f.user_message}
                    </p>
                  </div>

                  <button
                    onClick={() => setExpandedId(isExpanded ? null : f.id)}
                    className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 transition-transform"
                    style={{ background: "rgba(255,255,255,0.05)", transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}
                  >
                    <ChevronDown size={13} style={{ color: "rgba(255,255,255,0.4)" }} />
                  </button>
                </div>

                <AnimatePresence>
                  {isExpanded && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.2 }}
                      className="overflow-hidden"
                    >
                      <div className="px-4 pb-4 space-y-3" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
                        <div className="pt-3 grid grid-cols-2 gap-3">
                          <div>
                            <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.25)" }}>Mensagem do Usuário</p>
                            <div className="rounded-lg p-3 text-xs leading-relaxed" style={{ background: "rgba(255,255,255,0.03)", color: "rgba(255,255,255,0.6)" }}>
                              {f.user_message}
                            </div>
                          </div>
                          <div>
                            <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.25)" }}>Resposta da IA</p>
                            <div className="rounded-lg p-3 text-xs leading-relaxed" style={{ background: "rgba(255,255,255,0.03)", color: "rgba(255,255,255,0.6)" }}>
                              {f.ai_response}
                            </div>
                          </div>
                        </div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>

                {isPositive && (
                  <div className="flex items-center gap-2 px-4 py-2.5" style={{ borderTop: "1px solid rgba(255,255,255,0.05)", background: "rgba(0,0,0,0.15)" }}>
                    <button
                      onClick={() => handlePromote(f)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium"
                      style={{ background: "rgba(34,197,94,0.15)", color: "#22C55E", border: "1px solid rgba(34,197,94,0.2)" }}
                    >
                      <Sparkles size={12} /> Promover para Memória
                    </button>
                    <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>
                      Isso aprovará automaticamente como exemplo de resposta ideal
                    </span>
                  </div>
                )}
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ─── Aba: Padrões de Comportamento ────────────────────────────────────────────
function PatternsTab({ characters }: { characters: AICharacterBasic[] }) {
  const [patterns, setPatterns] = useState<BehaviorPattern[]>([]);
  const [loading, setLoading] = useState(true);
  const [charFilter, setCharFilter] = useState<string>("all");
  const [createOpen, setCreateOpen] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_behavior_patterns", {
        p_character_id: charFilter === "all" ? null : charFilter,
      });
      if (error) throw error;
      setPatterns(Array.isArray(data) ? data as BehaviorPattern[] : []);
    } catch {
      toast.error("Erro ao carregar padrões");
    } finally {
      setLoading(false);
    }
  }, [charFilter]);

  useEffect(() => { load(); }, [load]);

  async function handleToggle(p: BehaviorPattern) {
    try {
      const { error } = await supabase.rpc("admin_toggle_pattern", { p_pattern_id: p.id, p_active: !p.is_active });
      if (error) throw error;
      toast.success(p.is_active ? "Padrão desativado" : "Padrão ativado");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  async function handleDelete(id: string) {
    try {
      const { error } = await supabase.rpc("admin_delete_behavior_pattern", { p_pattern_id: id });
      if (error) throw error;
      toast.success("Padrão excluído");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  return (
    <div className="space-y-4">
      {/* Info */}
      <div className="flex items-start gap-3 p-3 rounded-xl" style={{ background: "rgba(139,92,246,0.08)", border: "1px solid rgba(139,92,246,0.15)" }}>
        <Info size={14} style={{ color: "#8B5CF6", flexShrink: 0, marginTop: 1 }} />
        <p className="text-xs" style={{ color: "rgba(139,92,246,0.8)" }}>
          Padrões ativos são injetados no system prompt da IA antes de cada resposta. Use para definir regras de comportamento baseadas no que os usuários mais aprovam.
        </p>
      </div>

      {/* Filtros */}
      <div className="flex items-center gap-3">
        <select
          value={charFilter}
          onChange={(e) => setCharFilter(e.target.value)}
          className="rounded-xl px-3 py-1.5 text-xs text-white outline-none"
          style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)" }}
        >
          <option value="all" style={{ background: "#0d1117" }}>Todos os personagens</option>
          {characters.map(c => (
            <option key={c.id} value={c.id} style={{ background: "#0d1117" }}>{c.name}</option>
          ))}
        </select>

        <div className="ml-auto flex gap-2">
          <button
            onClick={() => setCreateOpen(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold"
            style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.25)" }}
          >
            <Plus size={12} /> Novo Padrão
          </button>
          <button onClick={load} className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
            <RefreshCw size={13} style={{ color: "rgba(255,255,255,0.4)" }} className={loading ? "animate-spin" : ""} />
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32">
          <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : patterns.length === 0 ? (
        <div className="rounded-xl p-10 flex flex-col items-center gap-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
          <Layers size={28} style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhum padrão de comportamento definido.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {patterns.map((p, i) => {
            const catCfg = PATTERN_CATEGORY_CONFIG[p.category];
            return (
              <motion.div
                key={p.id}
                custom={i}
                variants={fadeUp}
                initial="hidden"
                animate="show"
                className="rounded-xl p-4 flex items-start gap-3"
                style={{
                  background: "rgba(255,255,255,0.03)",
                  border: `1px solid ${p.is_active ? "rgba(255,255,255,0.07)" : "rgba(255,255,255,0.03)"}`,
                  opacity: p.is_active ? 1 : 0.5,
                }}
              >
                <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 overflow-hidden" style={{ background: "rgba(139,92,246,0.12)" }}>
                  {p.character_avatar ? (
                    <img src={p.character_avatar} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <Bot size={14} style={{ color: "#8B5CF6" }} />
                  )}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap mb-1">
                    <span className="text-xs font-semibold text-white">{p.pattern_label}</span>
                    <span className="px-1.5 py-0.5 rounded text-[10px]" style={{ background: `${catCfg.color}22`, color: catCfg.color }}>
                      {catCfg.label}
                    </span>
                    {!p.is_auto && (
                      <span className="px-1.5 py-0.5 rounded text-[10px]" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.3)" }}>
                        Manual
                      </span>
                    )}
                    <span className="text-xs font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                      {p.character_name}
                    </span>
                    <span className="ml-auto text-xs font-mono" style={{ color: p.approval_rate >= 0.7 ? "#22C55E" : p.approval_rate >= 0.4 ? "#F59E0B" : "#EF4444" }}>
                      {(p.approval_rate * 100).toFixed(0)}% aprovação
                    </span>
                  </div>
                  <p className="text-xs leading-relaxed" style={{ color: "rgba(255,255,255,0.45)" }}>
                    {p.pattern_rule}
                  </p>
                </div>

                <div className="flex items-center gap-2 flex-shrink-0">
                  <button onClick={() => handleToggle(p)} className="transition-opacity hover:opacity-80">
                    {p.is_active
                      ? <ToggleRight size={22} style={{ color: "#22C55E" }} />
                      : <ToggleLeft size={22} style={{ color: "rgba(255,255,255,0.2)" }} />
                    }
                  </button>
                  <button
                    onClick={() => handleDelete(p.id)}
                    className="w-7 h-7 rounded-lg flex items-center justify-center"
                    style={{ background: "rgba(239,68,68,0.08)" }}
                  >
                    <Trash2 size={12} style={{ color: "rgba(239,68,68,0.6)" }} />
                  </button>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}

      <AnimatePresence>
        {createOpen && (
          <CreatePatternModal characters={characters} onClose={() => setCreateOpen(false)} onSave={load} />
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── Aba: Estatísticas ────────────────────────────────────────────────────────
function StatsTab({ characters }: { characters: AICharacterBasic[] }) {
  const [stats, setStats] = useState<LearningStats | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_learning_stats");
      if (error) throw error;
      setStats(data as LearningStats);
    } catch {
      toast.error("Erro ao carregar estatísticas");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function handleUpdateConfig(charId: string, field: "learning_enabled" | "auto_approve", value: boolean) {
    try {
      const { error } = await supabase.rpc("admin_update_learning_config", {
        p_character_id: charId,
        p_learning_enabled: field === "learning_enabled" ? value : undefined,
        p_auto_approve: field === "auto_approve" ? value : undefined,
      });
      if (error) throw error;
      toast.success("Configuração atualizada");
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-40">
        <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Stats globais */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[
            { label: "Total Feedbacks", value: stats.total_feedbacks, icon: MessageSquare, color: "#60A5FA", bg: "96,165,250" },
            { label: "Taxa de Aprovação", value: `${stats.approval_rate}%`, icon: TrendingUp, color: "#22C55E", bg: "34,197,94" },
            { label: "Memórias Ativas", value: stats.memory_count, icon: BookOpen, color: "#8B5CF6", bg: "139,92,246" },
            { label: "Pendentes Revisão", value: stats.pending_memories + stats.pending_queue, icon: Clock, color: "#F59E0B", bg: "245,158,11" },
          ].map((s) => (
            <div
              key={s.label}
              className="rounded-xl p-4 flex items-center gap-3"
              style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
            >
              <div className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: `rgba(${s.bg},0.15)` }}>
                <s.icon size={16} style={{ color: s.color }} />
              </div>
              <div>
                <p className="text-xl font-bold text-white leading-none">{s.value}</p>
                <p className="text-[10px] font-mono tracking-widest uppercase mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{s.label}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Barra de aprovação */}
      {stats && stats.total_feedbacks > 0 && (
        <div className="rounded-xl p-4" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}>
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs font-semibold text-white">Distribuição de Feedbacks</p>
            <p className="text-xs font-mono" style={{ color: "rgba(255,255,255,0.35)" }}>
              {stats.positive_feedbacks} positivos · {stats.negative_feedbacks} negativos
            </p>
          </div>
          <div className="h-3 rounded-full overflow-hidden" style={{ background: "rgba(239,68,68,0.3)" }}>
            <div
              className="h-full rounded-full transition-all"
              style={{
                width: `${stats.approval_rate}%`,
                background: "linear-gradient(90deg, #22C55E, #34D399)",
              }}
            />
          </div>
          <div className="flex justify-between mt-1">
            <span className="text-[10px]" style={{ color: "#22C55E" }}>👍 {stats.approval_rate}%</span>
            <span className="text-[10px]" style={{ color: "#EF4444" }}>👎 {(100 - stats.approval_rate).toFixed(1)}%</span>
          </div>
        </div>
      )}

      {/* Configuração por personagem */}
      <div>
        <h3 className="text-sm font-semibold text-white mb-3">Configuração por Personagem</h3>
        <div className="space-y-2">
          {characters.map((c, i) => (
            <motion.div
              key={c.id}
              custom={i}
              variants={fadeUp}
              initial="hidden"
              animate="show"
              className="rounded-xl p-4 flex items-center gap-3"
              style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
            >
              <div className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 overflow-hidden" style={{ background: "rgba(139,92,246,0.12)" }}>
                {c.avatar_url ? (
                  <img src={c.avatar_url} alt="" className="w-full h-full object-cover" />
                ) : (
                  <Bot size={15} style={{ color: "#8B5CF6" }} />
                )}
              </div>

              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-white">{c.name}</p>
                <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                  {c.total_feedbacks} feedbacks · {c.memory_count} memórias ·{" "}
                  {c.total_feedbacks > 0 ? Math.round((c.positive_feedbacks / c.total_feedbacks) * 100) : 0}% aprovação
                </p>
              </div>

              <div className="flex items-center gap-4">
                <div className="flex flex-col items-center gap-1">
                  <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Aprendizado</p>
                  <button
                    onClick={() => handleUpdateConfig(c.id, "learning_enabled", !c.learning_enabled)}
                    className="transition-opacity hover:opacity-80"
                  >
                    {c.learning_enabled
                      ? <ToggleRight size={22} style={{ color: "#22C55E" }} />
                      : <ToggleLeft size={22} style={{ color: "rgba(255,255,255,0.2)" }} />
                    }
                  </button>
                </div>
                <div className="flex flex-col items-center gap-1">
                  <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Auto-Aprovar</p>
                  <button
                    onClick={() => handleUpdateConfig(c.id, "auto_approve", !c.auto_approve)}
                    className="transition-opacity hover:opacity-80"
                  >
                    {c.auto_approve
                      ? <ToggleRight size={22} style={{ color: "#F59E0B" }} />
                      : <ToggleLeft size={22} style={{ color: "rgba(255,255,255,0.2)" }} />
                    }
                  </button>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Página Principal ─────────────────────────────────────────────────────────
export default function AILearningPage() {
  const { canModerate } = useAuth();
  const [activeTab, setActiveTab] = useState<PageTab>("memories");
  const [characters, setCharacters] = useState<AICharacterBasic[]>([]);
  const [loadingChars, setLoadingChars] = useState(true);

  const loadCharacters = useCallback(async () => {
    setLoadingChars(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_ai_characters");
      if (error) throw error;
      const list = Array.isArray(data) ? data : (data ? [data] : []);
      setCharacters(list as AICharacterBasic[]);
    } catch {
      toast.error("Erro ao carregar personagens");
    } finally {
      setLoadingChars(false);
    }
  }, []);

  useEffect(() => { loadCharacters(); }, [loadCharacters]);

  if (!canModerate) {
    return (
      <div className="flex items-center justify-center h-full min-h-[60vh]">
        <div className="text-center">
          <Brain size={32} className="mx-auto mb-3" style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm font-semibold" style={{ color: "rgba(255,255,255,0.4)" }}>Acesso Restrito</p>
        </div>
      </div>
    );
  }

  const TABS: { id: PageTab; label: string; icon: React.ElementType; color: string }[] = [
    { id: "memories", label: "Memórias",          icon: BookOpen,     color: "#8B5CF6" },
    { id: "queue",    label: "Fila de Feedbacks",  icon: MessageSquare, color: "#60A5FA" },
    { id: "patterns", label: "Padrões",            icon: Layers,       color: "#F59E0B" },
    { id: "stats",    label: "Estatísticas",       icon: BarChart3,    color: "#22C55E" },
  ];

  return (
    <div className="p-5 md:p-7 max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <motion.div initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} className="flex items-center gap-4">
        <div
          className="w-11 h-11 rounded-2xl flex items-center justify-center flex-shrink-0"
          style={{ background: "rgba(139,92,246,0.12)", border: "1.5px solid rgba(139,92,246,0.3)" }}
        >
          <Brain size={20} style={{ color: "#8B5CF6" }} />
        </div>
        <div>
          <h1 className="text-[18px] font-bold text-white" style={{ fontFamily: "'Space Grotesk', sans-serif" }}>
            Auto-Aprendizado
          </h1>
          <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
            Gerencie memórias, feedbacks e padrões de comportamento das IAs
          </p>
        </div>
      </motion.div>

      {/* Como funciona */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.05 }}
        className="rounded-xl p-4"
        style={{ background: "rgba(139,92,246,0.06)", border: "1px solid rgba(139,92,246,0.15)" }}
      >
        <div className="flex items-center gap-2 mb-3">
          <Sparkles size={14} style={{ color: "#8B5CF6" }} />
          <p className="text-xs font-semibold" style={{ color: "#A78BFA" }}>Como funciona o Auto-Aprendizado</p>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
          {[
            { step: "1", label: "Usuário avalia", desc: "Usuários dão 👍/👎 nas respostas da IA durante conversas", color: "#60A5FA" },
            { step: "2", label: "Fila de feedbacks", desc: "Feedbacks positivos entram na fila aguardando revisão do admin", color: "#F59E0B" },
            { step: "3", label: "Admin aprova", desc: "Admin revisa e aprova os melhores como memórias de aprendizado", color: "#8B5CF6" },
            { step: "4", label: "IA aprende", desc: "Memórias aprovadas são injetadas no contexto antes de cada resposta", color: "#22C55E" },
          ].map((s) => (
            <div key={s.step} className="flex items-start gap-2">
              <div
                className="w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 text-[10px] font-bold mt-0.5"
                style={{ background: `${s.color}22`, color: s.color }}
              >
                {s.step}
              </div>
              <div>
                <p className="text-xs font-semibold" style={{ color: s.color }}>{s.label}</p>
                <p className="text-[10px] leading-relaxed" style={{ color: "rgba(255,255,255,0.35)" }}>{s.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </motion.div>

      {/* Tabs */}
      <div className="flex gap-1 rounded-xl p-1" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
        {TABS.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-xs font-medium transition-all"
              style={{
                background: isActive ? `${tab.color}18` : "transparent",
                color: isActive ? tab.color : "rgba(255,255,255,0.35)",
                border: isActive ? `1px solid ${tab.color}30` : "1px solid transparent",
              }}
            >
              <Icon size={13} />
              <span className="hidden sm:inline">{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* Conteúdo da aba */}
      {loadingChars ? (
        <div className="flex items-center justify-center h-32">
          <RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} />
        </div>
      ) : (
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.15 }}
          >
            {activeTab === "memories"  && <MemoriesTab characters={characters} />}
            {activeTab === "queue"     && <FeedbackQueueTab characters={characters} />}
            {activeTab === "patterns"  && <PatternsTab characters={characters} />}
            {activeTab === "stats"     && <StatsTab characters={characters} />}
          </motion.div>
        </AnimatePresence>
      )}
    </div>
  );
}
