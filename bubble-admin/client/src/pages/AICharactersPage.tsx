import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Bot, Plus, Trash2, Eye, EyeOff, Search, RefreshCw,
  Globe, X, Save, ChevronDown, Sparkles, Brain, Activity,
  Sliders, Shield, Zap, Info, CheckCircle2,
  ToggleLeft, ToggleRight, AlertTriangle,
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
  updated_at?: string;
  // Campos avançados
  model?: string;
  temperature?: number;
  max_tokens?: number;
  persona_style?: string;
  restrictions?: string[];
  greeting_message?: string | null;
  context_window?: number;
  usage_count?: number;
};

type CharacterForm = {
  name: string;
  avatar_url: string | null;
  description: string;
  system_prompt: string;
  tags: string[];
  language: string;
  is_active: boolean;
  model: string;
  temperature: number;
  max_tokens: number;
  persona_style: string;
  restrictions: string[];
  greeting_message: string;
  context_window: number;
};

const EMPTY_FORM: CharacterForm = {
  name: "",
  avatar_url: null,
  description: "",
  system_prompt: "",
  tags: [],
  language: "pt",
  is_active: true,
  model: "gpt-4.1-mini",
  temperature: 0.8,
  max_tokens: 512,
  persona_style: "casual",
  restrictions: [],
  greeting_message: "",
  context_window: 10,
};

const LANGUAGES = [
  { code: "pt", label: "Português (BR)", flag: "🇧🇷" },
  { code: "en", label: "English", flag: "🇺🇸" },
  { code: "es", label: "Español", flag: "🇪🇸" },
  { code: "ja", label: "日本語", flag: "🇯🇵" },
  { code: "fr", label: "Français", flag: "🇫🇷" },
  { code: "de", label: "Deutsch", flag: "🇩🇪" },
  { code: "ko", label: "한국어", flag: "🇰🇷" },
  { code: "it", label: "Italiano", flag: "🇮🇹" },
];

const MODELS = [
  {
    id: "gpt-4.1-mini",
    label: "GPT-4.1 Mini",
    description: "Rápido, econômico e inteligente. Ideal para a maioria dos casos.",
    badge: "RECOMENDADO",
    badgeColor: "#22C55E",
    icon: "⚡",
  },
  {
    id: "gpt-4.1-nano",
    label: "GPT-4.1 Nano",
    description: "Ultra-rápido e leve. Perfeito para respostas curtas e objetivas.",
    badge: "RÁPIDO",
    badgeColor: "#60A5FA",
    icon: "🚀",
  },
  {
    id: "gemini-2.5-flash",
    label: "Gemini 2.5 Flash",
    description: "Modelo Google com excelente raciocínio e contexto longo.",
    badge: "GOOGLE",
    badgeColor: "#F59E0B",
    icon: "✨",
  },
];

const PERSONA_STYLES = [
  { id: "casual",   label: "Casual",       desc: "Informal, amigável e descontraído",         icon: "😊" },
  { id: "formal",   label: "Formal",       desc: "Profissional, respeitoso e preciso",         icon: "👔" },
  { id: "rpg",      label: "RPG / Ficção", desc: "Imersivo, dramático e narrativo",            icon: "⚔️" },
  { id: "academic", label: "Acadêmico",    desc: "Técnico, detalhado e baseado em evidências", icon: "📚" },
  { id: "humor",    label: "Humorístico",  desc: "Engraçado, criativo e descontraído",         icon: "😂" },
  { id: "mentor",   label: "Mentor",       desc: "Motivador, paciente e orientador",           icon: "🎯" },
];

const RESTRICTION_OPTIONS = [
  { id: "no_violence",       label: "Sem violência explícita",     icon: "🚫" },
  { id: "no_adult",          label: "Sem conteúdo adulto",         icon: "🔞" },
  { id: "no_politics",       label: "Sem política partidária",     icon: "🏛️" },
  { id: "no_religion",       label: "Sem debate religioso",        icon: "⛪" },
  { id: "no_hate",           label: "Sem discurso de ódio",        icon: "❌" },
  { id: "safe_for_kids",     label: "Seguro para crianças",        icon: "👶" },
  { id: "no_spoilers",       label: "Sem spoilers",                icon: "🙈" },
  { id: "stay_in_character", label: "Manter personagem sempre",    icon: "🎭" },
];

const TAG_SUGGESTIONS = [
  "fantasia", "humor", "educação", "ciência", "história", "roleplay",
  "filosofia", "culinária", "motivação", "mistério", "poesia", "tecnologia",
  "espiritualidade", "aventura", "ficção científica", "romance",
];

const fadeUp = {
  hidden: { opacity: 0, y: 10 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.22 } }),
};

// ─── Modal de Edição ──────────────────────────────────────────────────────────
type ModalTab = "identity" | "behavior" | "technical";

function CharacterModal({
  character,
  onClose,
  onSave,
}: {
  character: AICharacter | null;
  onClose: () => void;
  onSave: () => void;
}) {
  const [activeTab, setActiveTab] = useState<ModalTab>("identity");
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
          model: character.model ?? "gpt-4.1-mini",
          temperature: character.temperature ?? 0.8,
          max_tokens: character.max_tokens ?? 512,
          persona_style: character.persona_style ?? "casual",
          restrictions: character.restrictions ?? [],
          greeting_message: character.greeting_message ?? "",
          context_window: character.context_window ?? 10,
        }
      : { ...EMPTY_FORM }
  );
  const [tagInput, setTagInput] = useState("");
  const [saving, setSaving] = useState(false);

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

  function toggleRestriction(id: string) {
    setForm((f) => ({
      ...f,
      restrictions: f.restrictions.includes(id)
        ? f.restrictions.filter((r) => r !== id)
        : [...f.restrictions, id],
    }));
  }

  async function handleSave() {
    if (!form.name.trim() || !form.description.trim() || !form.system_prompt.trim()) {
      toast.error("Nome, descrição e prompt são obrigatórios.");
      setActiveTab("identity");
      return;
    }
    setSaving(true);
    try {
      const params = {
        p_name: form.name.trim(),
        p_description: form.description.trim(),
        p_system_prompt: form.system_prompt.trim(),
        p_tags: form.tags,
        p_language: form.language,
        p_avatar_url: form.avatar_url || null,
        p_is_active: form.is_active,
        p_model: form.model,
        p_temperature: form.temperature,
        p_max_tokens: form.max_tokens,
        p_persona_style: form.persona_style,
        p_restrictions: form.restrictions,
        p_greeting_message: form.greeting_message.trim() || null,
        p_context_window: form.context_window,
      };
      if (character) {
        const { error } = await supabase.rpc("admin_update_ai_character", { p_id: character.id, ...params });
        if (error) throw error;
        toast.success("Personagem atualizado!");
      } else {
        const { error } = await supabase.rpc("admin_create_ai_character", params);
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

  const tabs: { id: ModalTab; label: string; icon: React.ElementType }[] = [
    { id: "identity",  label: "Identidade",    icon: Bot },
    { id: "behavior",  label: "Comportamento", icon: Brain },
    { id: "technical", label: "Técnico",        icon: Sliders },
  ];

  const inputStyle = {
    background: "rgba(255,255,255,0.05)",
    border: "1px solid rgba(255,255,255,0.1)",
    color: "white",
  } as const;

  const labelStyle: React.CSSProperties = {
    display: "block",
    fontSize: "10px",
    fontFamily: "monospace",
    letterSpacing: "0.1em",
    textTransform: "uppercase",
    marginBottom: "6px",
    color: "rgba(255,255,255,0.35)",
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(0,0,0,0.82)", backdropFilter: "blur(10px)" }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.96, y: 12 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.96, y: 12 }}
        className="w-full max-w-2xl rounded-2xl overflow-hidden flex flex-col"
        style={{
          background: "#0f1117",
          border: "1px solid rgba(139,92,246,0.3)",
          maxHeight: "90vh",
        }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 flex-shrink-0" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
          <div className="flex items-center gap-3">
            {form.avatar_url ? (
              <img src={form.avatar_url} alt="" className="w-9 h-9 rounded-xl object-cover" style={{ border: "1px solid rgba(139,92,246,0.4)" }} />
            ) : (
              <div className="w-9 h-9 rounded-xl flex items-center justify-center" style={{ background: "rgba(139,92,246,0.2)", border: "1px solid rgba(139,92,246,0.4)" }}>
                <Bot size={16} style={{ color: "#8B5CF6" }} />
              </div>
            )}
            <div>
              <p className="font-semibold text-white text-sm">{form.name || (character ? "Editar Personagem" : "Novo Personagem de IA")}</p>
              <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                {MODELS.find(m => m.id === form.model)?.label ?? form.model} · temp {form.temperature.toFixed(1)} · {form.max_tokens} tokens
              </p>
            </div>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-xl flex items-center justify-center hover:bg-white/10 transition-all" style={{ color: "rgba(255,255,255,0.4)" }}>
            <X size={15} />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 px-6 pt-4 pb-0 flex-shrink-0">
          {tabs.map(tab => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className="flex items-center gap-1.5 px-3.5 py-2 rounded-t-lg text-[11px] font-semibold transition-all"
                style={{
                  background: isActive ? "rgba(139,92,246,0.15)" : "transparent",
                  color: isActive ? "#A78BFA" : "rgba(255,255,255,0.35)",
                  borderBottom: isActive ? "2px solid #8B5CF6" : "2px solid transparent",
                }}
              >
                <Icon size={12} />
                {tab.label}
              </button>
            );
          })}
        </div>
        <div style={{ height: "1px", background: "rgba(255,255,255,0.06)", marginTop: "-1px" }} />

        {/* Body */}
        <div className="overflow-y-auto flex-1 p-6">
          <AnimatePresence mode="wait">
            {/* ─── ABA: IDENTIDADE ─────────────────────────────────── */}
            {activeTab === "identity" && (
              <motion.div key="identity" initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 8 }} className="space-y-5">
                {/* Nome + Avatar */}
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label style={labelStyle}>Nome *</label>
                    <input
                      value={form.name}
                      onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                      placeholder="Ex: Detetive Noir"
                      className="w-full rounded-xl px-3 py-2.5 text-sm placeholder-white/25 outline-none"
                      style={inputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>URL do Avatar</label>
                    <input
                      value={form.avatar_url ?? ""}
                      onChange={(e) => setForm((f) => ({ ...f, avatar_url: e.target.value || null }))}
                      placeholder="https://..."
                      className="w-full rounded-xl px-3 py-2.5 text-sm placeholder-white/25 outline-none"
                      style={inputStyle}
                    />
                  </div>
                </div>

                {/* Descrição */}
                <div>
                  <label style={labelStyle}>Descrição *</label>
                  <textarea
                    value={form.description}
                    onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                    placeholder="Uma frase curta que descreve a personalidade do personagem..."
                    rows={2}
                    className="w-full rounded-xl px-3 py-2.5 text-sm placeholder-white/25 outline-none resize-none"
                    style={inputStyle}
                  />
                </div>

                {/* System Prompt */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label style={{ ...labelStyle, marginBottom: 0 }}>System Prompt *</label>
                    <span className="text-[10px] font-mono" style={{ color: form.system_prompt.length > 3000 ? "#EF4444" : "rgba(255,255,255,0.25)" }}>
                      {form.system_prompt.length}/3000
                    </span>
                  </div>
                  <textarea
                    value={form.system_prompt}
                    onChange={(e) => setForm((f) => ({ ...f, system_prompt: e.target.value }))}
                    placeholder="Você é um personagem que... Responda sempre em... Seu estilo é..."
                    rows={7}
                    className="w-full rounded-xl px-3 py-2.5 text-sm placeholder-white/25 outline-none resize-none font-mono"
                    style={{ ...inputStyle, background: "rgba(139,92,246,0.06)", border: "1px solid rgba(139,92,246,0.2)", lineHeight: "1.6" }}
                  />
                  <p className="text-[10px] mt-1.5" style={{ color: "rgba(255,255,255,0.2)" }}>
                    Instrução de sistema enviada ao modelo. Seja específico sobre personalidade, estilo de fala e limitações.
                  </p>
                </div>

                {/* Mensagem de boas-vindas */}
                <div>
                  <label style={labelStyle}>Mensagem de boas-vindas <span style={{ textTransform: "none", color: "rgba(255,255,255,0.2)" }}>(opcional)</span></label>
                  <textarea
                    value={form.greeting_message}
                    onChange={(e) => setForm((f) => ({ ...f, greeting_message: e.target.value }))}
                    placeholder="Olá! Sou o Detetive Noir. Como posso ajudá-lo hoje?"
                    rows={2}
                    className="w-full rounded-xl px-3 py-2.5 text-sm placeholder-white/25 outline-none resize-none"
                    style={inputStyle}
                  />
                </div>

                {/* Tags */}
                <div>
                  <label style={labelStyle}>Tags</label>
                  <div className="flex flex-wrap gap-1.5 mb-2">
                    {form.tags.map((tag) => (
                      <span
                        key={tag}
                        className="flex items-center gap-1 text-[11px] font-mono px-2 py-0.5 rounded-full"
                        style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.25)" }}
                      >
                        #{tag}
                        <button onClick={() => removeTag(tag)} className="hover:text-white transition-colors"><X size={9} /></button>
                      </span>
                    ))}
                  </div>
                  <div className="flex gap-2">
                    <input
                      value={tagInput}
                      onChange={(e) => setTagInput(e.target.value)}
                      onKeyDown={(e) => { if (e.key === "Enter" || e.key === ",") { e.preventDefault(); addTag(tagInput); } }}
                      placeholder="Adicionar tag..."
                      className="flex-1 rounded-xl px-3 py-2 text-sm placeholder-white/25 outline-none"
                      style={inputStyle}
                    />
                    <button
                      onClick={() => addTag(tagInput)}
                      className="px-3 py-2 rounded-xl text-sm font-semibold"
                      style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.2)" }}
                    >
                      +
                    </button>
                  </div>
                  <div className="flex flex-wrap gap-1 mt-2">
                    {TAG_SUGGESTIONS.filter(t => !form.tags.includes(t)).slice(0, 8).map(t => (
                      <button
                        key={t}
                        onClick={() => addTag(t)}
                        className="text-[10px] font-mono px-2 py-0.5 rounded-full transition-all"
                        style={{ background: "rgba(255,255,255,0.03)", color: "rgba(255,255,255,0.3)", border: "1px solid rgba(255,255,255,0.07)" }}
                      >
                        +{t}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Idioma + Status */}
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label style={labelStyle}>Idioma principal</label>
                    <div className="relative">
                      <select
                        value={form.language}
                        onChange={(e) => setForm((f) => ({ ...f, language: e.target.value }))}
                        className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none appearance-none"
                        style={inputStyle}
                      >
                        {LANGUAGES.map((l) => (
                          <option key={l.code} value={l.code} style={{ background: "#1a1a2e" }}>
                            {l.flag} {l.label}
                          </option>
                        ))}
                      </select>
                      <ChevronDown size={13} className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" style={{ color: "rgba(255,255,255,0.3)" }} />
                    </div>
                  </div>
                  <div>
                    <label style={labelStyle}>Status</label>
                    <button
                      onClick={() => setForm((f) => ({ ...f, is_active: !f.is_active }))}
                      className="w-full rounded-xl px-3 py-2.5 text-sm font-medium flex items-center gap-2 transition-all"
                      style={{
                        background: form.is_active ? "rgba(34,197,94,0.1)" : "rgba(239,68,68,0.1)",
                        border: `1px solid ${form.is_active ? "rgba(34,197,94,0.3)" : "rgba(239,68,68,0.3)"}`,
                        color: form.is_active ? "#22C55E" : "#EF4444",
                      }}
                    >
                      {form.is_active ? <ToggleRight size={16} /> : <ToggleLeft size={16} />}
                      {form.is_active ? "Ativo — visível aos usuários" : "Inativo — oculto"}
                    </button>
                  </div>
                </div>
              </motion.div>
            )}

            {/* ─── ABA: COMPORTAMENTO ──────────────────────────────── */}
            {activeTab === "behavior" && (
              <motion.div key="behavior" initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 8 }} className="space-y-6">
                {/* Estilo de Persona */}
                <div>
                  <label style={labelStyle}>Estilo de Persona</label>
                  <p className="text-[11px] mb-3" style={{ color: "rgba(255,255,255,0.3)" }}>Define o tom geral de comunicação do personagem.</p>
                  <div className="grid grid-cols-2 gap-2">
                    {PERSONA_STYLES.map(style => {
                      const isSelected = form.persona_style === style.id;
                      return (
                        <button
                          key={style.id}
                          onClick={() => setForm(f => ({ ...f, persona_style: style.id }))}
                          className="flex items-center gap-3 px-3.5 py-3 rounded-xl text-left transition-all"
                          style={{
                            background: isSelected ? "rgba(139,92,246,0.15)" : "rgba(255,255,255,0.02)",
                            border: `1px solid ${isSelected ? "rgba(139,92,246,0.4)" : "rgba(255,255,255,0.06)"}`,
                          }}
                        >
                          <span className="text-lg flex-shrink-0">{style.icon}</span>
                          <div className="min-w-0">
                            <p className="text-[12px] font-semibold" style={{ color: isSelected ? "#A78BFA" : "rgba(255,255,255,0.8)" }}>{style.label}</p>
                            <p className="text-[10px] font-mono truncate" style={{ color: "rgba(255,255,255,0.3)" }}>{style.desc}</p>
                          </div>
                          {isSelected && <CheckCircle2 size={13} style={{ color: "#A78BFA", flexShrink: 0, marginLeft: "auto" }} />}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Restrições de Conteúdo */}
                <div>
                  <div className="flex items-center gap-2 mb-1.5">
                    <Shield size={13} style={{ color: "rgba(239,68,68,0.7)" }} />
                    <label style={{ ...labelStyle, marginBottom: 0 }}>Restrições de Conteúdo</label>
                  </div>
                  <p className="text-[11px] mb-3" style={{ color: "rgba(255,255,255,0.3)" }}>Selecione o que este personagem não deve fazer ou discutir.</p>
                  <div className="grid grid-cols-2 gap-2">
                    {RESTRICTION_OPTIONS.map(opt => {
                      const isActive = form.restrictions.includes(opt.id);
                      return (
                        <button
                          key={opt.id}
                          onClick={() => toggleRestriction(opt.id)}
                          className="flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-left transition-all"
                          style={{
                            background: isActive ? "rgba(239,68,68,0.08)" : "rgba(255,255,255,0.02)",
                            border: `1px solid ${isActive ? "rgba(239,68,68,0.3)" : "rgba(255,255,255,0.06)"}`,
                          }}
                        >
                          <span className="text-base flex-shrink-0">{opt.icon}</span>
                          <p className="text-[11px] font-mono" style={{ color: isActive ? "#FCA5A5" : "rgba(255,255,255,0.5)" }}>{opt.label}</p>
                          {isActive && <CheckCircle2 size={11} style={{ color: "#FCA5A5", flexShrink: 0, marginLeft: "auto" }} />}
                        </button>
                      );
                    })}
                  </div>
                  {form.restrictions.length > 0 && (
                    <p className="text-[10px] font-mono mt-2" style={{ color: "rgba(239,68,68,0.6)" }}>
                      {form.restrictions.length} restrição(ões) ativa(s)
                    </p>
                  )}
                </div>
              </motion.div>
            )}

            {/* ─── ABA: TÉCNICO ────────────────────────────────────── */}
            {activeTab === "technical" && (
              <motion.div key="technical" initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 8 }} className="space-y-6">
                {/* Modelo de IA */}
                <div>
                  <label style={labelStyle}>Modelo de IA</label>
                  <p className="text-[11px] mb-3" style={{ color: "rgba(255,255,255,0.3)" }}>Escolha o modelo de linguagem que alimenta este personagem.</p>
                  <div className="space-y-2">
                    {MODELS.map(model => {
                      const isSelected = form.model === model.id;
                      return (
                        <button
                          key={model.id}
                          onClick={() => setForm(f => ({ ...f, model: model.id }))}
                          className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-left transition-all"
                          style={{
                            background: isSelected ? "rgba(139,92,246,0.12)" : "rgba(255,255,255,0.02)",
                            border: `1px solid ${isSelected ? "rgba(139,92,246,0.35)" : "rgba(255,255,255,0.06)"}`,
                          }}
                        >
                          <span className="text-xl flex-shrink-0">{model.icon}</span>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2">
                              <p className="text-[13px] font-semibold" style={{ color: isSelected ? "#A78BFA" : "rgba(255,255,255,0.85)" }}>{model.label}</p>
                              <span className="text-[9px] font-mono px-1.5 py-0.5 rounded" style={{ background: `${model.badgeColor}20`, color: model.badgeColor }}>{model.badge}</span>
                            </div>
                            <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.35)" }}>{model.description}</p>
                          </div>
                          {isSelected && <CheckCircle2 size={15} style={{ color: "#A78BFA", flexShrink: 0 }} />}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Temperatura */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label style={{ ...labelStyle, marginBottom: 0 }}>Temperatura (criatividade)</label>
                    <span className="text-[13px] font-mono font-bold" style={{ color: form.temperature < 0.5 ? "#60A5FA" : form.temperature > 1.2 ? "#F97316" : "#A78BFA" }}>
                      {form.temperature.toFixed(1)}
                    </span>
                  </div>
                  <input
                    type="range"
                    min={0}
                    max={2}
                    step={0.1}
                    value={form.temperature}
                    onChange={(e) => setForm(f => ({ ...f, temperature: parseFloat(e.target.value) }))}
                    className="w-full"
                    style={{ accentColor: "#8B5CF6" }}
                  />
                  <div className="flex justify-between mt-1">
                    <span className="text-[10px] font-mono" style={{ color: "#60A5FA" }}>0.0 — Preciso</span>
                    <span className="text-[10px] font-mono" style={{ color: "#A78BFA" }}>0.8 — Balanceado</span>
                    <span className="text-[10px] font-mono" style={{ color: "#F97316" }}>2.0 — Criativo</span>
                  </div>
                  <p className="text-[10px] mt-1.5" style={{ color: "rgba(255,255,255,0.2)" }}>
                    Valores baixos tornam as respostas mais determinísticas. Valores altos aumentam a criatividade e variação.
                  </p>
                </div>

                {/* Max Tokens */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label style={{ ...labelStyle, marginBottom: 0 }}>Máximo de tokens por resposta</label>
                    <span className="text-[13px] font-mono font-bold" style={{ color: "#A78BFA" }}>{form.max_tokens}</span>
                  </div>
                  <input
                    type="range"
                    min={50}
                    max={4096}
                    step={50}
                    value={form.max_tokens}
                    onChange={(e) => setForm(f => ({ ...f, max_tokens: parseInt(e.target.value) }))}
                    className="w-full"
                    style={{ accentColor: "#8B5CF6" }}
                  />
                  <div className="flex justify-between mt-1">
                    <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>50 — Curto</span>
                    <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>512 — Padrão</span>
                    <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>4096 — Longo</span>
                  </div>
                  <div className="grid grid-cols-4 gap-1.5 mt-2">
                    {[128, 256, 512, 1024].map(v => (
                      <button
                        key={v}
                        onClick={() => setForm(f => ({ ...f, max_tokens: v }))}
                        className="py-1.5 rounded-lg text-[11px] font-mono transition-all"
                        style={{
                          background: form.max_tokens === v ? "rgba(139,92,246,0.2)" : "rgba(255,255,255,0.04)",
                          color: form.max_tokens === v ? "#A78BFA" : "rgba(255,255,255,0.35)",
                          border: `1px solid ${form.max_tokens === v ? "rgba(139,92,246,0.3)" : "rgba(255,255,255,0.06)"}`,
                        }}
                      >
                        {v}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Janela de Contexto */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <div className="flex items-center gap-2">
                      <label style={{ ...labelStyle, marginBottom: 0 }}>Janela de contexto</label>
                      <Info size={11} style={{ color: "rgba(255,255,255,0.2)" }} />
                    </div>
                    <span className="text-[13px] font-mono font-bold" style={{ color: "#A78BFA" }}>{form.context_window} msgs</span>
                  </div>
                  <input
                    type="range"
                    min={1}
                    max={50}
                    step={1}
                    value={form.context_window}
                    onChange={(e) => setForm(f => ({ ...f, context_window: parseInt(e.target.value) }))}
                    className="w-full"
                    style={{ accentColor: "#8B5CF6" }}
                  />
                  <div className="flex justify-between mt-1">
                    <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>1 — Sem memória</span>
                    <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>50 — Memória longa</span>
                  </div>
                  <p className="text-[10px] mt-1.5" style={{ color: "rgba(255,255,255,0.2)" }}>
                    Quantas mensagens anteriores são enviadas ao modelo. Valores altos consomem mais tokens.
                  </p>
                </div>

                {/* Resumo de configuração */}
                <div className="p-4 rounded-xl" style={{ background: "rgba(139,92,246,0.06)", border: "1px solid rgba(139,92,246,0.15)" }}>
                  <p className="text-[10px] font-mono tracking-widest uppercase mb-3" style={{ color: "rgba(139,92,246,0.7)" }}>RESUMO DA CONFIGURAÇÃO</p>
                  <div className="grid grid-cols-2 gap-2">
                    {[
                      { label: "Modelo", value: MODELS.find(m => m.id === form.model)?.label ?? form.model },
                      { label: "Temperatura", value: form.temperature.toFixed(1) },
                      { label: "Max Tokens", value: form.max_tokens.toString() },
                      { label: "Contexto", value: `${form.context_window} msgs` },
                      { label: "Persona", value: PERSONA_STYLES.find(p => p.id === form.persona_style)?.label ?? form.persona_style },
                      { label: "Restrições", value: `${form.restrictions.length} ativa(s)` },
                    ].map(item => (
                      <div key={item.label} className="flex justify-between items-center">
                        <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>{item.label}</span>
                        <span className="text-[11px] font-semibold" style={{ color: "rgba(255,255,255,0.7)" }}>{item.value}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 flex-shrink-0 flex justify-between items-center" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-sm transition-colors"
            style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}
          >
            Cancelar
          </button>
          <div className="flex items-center gap-2">
            {activeTab !== "technical" && (
              <button
                onClick={() => setActiveTab(activeTab === "identity" ? "behavior" : "technical")}
                className="px-4 py-2 rounded-xl text-sm font-medium flex items-center gap-1.5"
                style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.5)", border: "1px solid rgba(255,255,255,0.08)" }}
              >
                Próximo <ChevronDown size={13} style={{ transform: "rotate(-90deg)" }} />
              </button>
            )}
            <button
              onClick={handleSave}
              disabled={saving}
              className="px-5 py-2 rounded-xl text-sm font-semibold flex items-center gap-2 transition-all"
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
  const model = MODELS.find(m => m.id === character.model);
  const persona = PERSONA_STYLES.find(p => p.id === character.persona_style);

  return (
    <motion.div
      custom={index}
      variants={fadeUp}
      initial="hidden"
      animate="show"
      className="rounded-xl overflow-hidden"
      style={{
        background: "rgba(255,255,255,0.02)",
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
            <div className="flex items-center gap-2 mb-1">
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
            </div>
            <p className="text-xs leading-relaxed mb-2" style={{ color: "rgba(255,255,255,0.45)" }}>
              {character.description}
            </p>
            {/* Badges de configuração */}
            <div className="flex flex-wrap gap-1.5">
              {model && (
                <span className="text-[9px] font-mono px-1.5 py-0.5 rounded flex items-center gap-1" style={{ background: "rgba(139,92,246,0.1)", color: "rgba(139,92,246,0.8)", border: "1px solid rgba(139,92,246,0.15)" }}>
                  <Zap size={8} /> {model.label}
                </span>
              )}
              {persona && (
                <span className="text-[9px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.35)", border: "1px solid rgba(255,255,255,0.07)" }}>
                  {persona.icon} {persona.label}
                </span>
              )}
              {character.temperature !== undefined && (
                <span className="text-[9px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.35)", border: "1px solid rgba(255,255,255,0.07)" }}>
                  🌡 {character.temperature.toFixed(1)}
                </span>
              )}
              {character.max_tokens !== undefined && (
                <span className="text-[9px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.35)", border: "1px solid rgba(255,255,255,0.07)" }}>
                  📝 {character.max_tokens} tok
                </span>
              )}
              {(character.restrictions?.length ?? 0) > 0 && (
                <span className="text-[9px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(239,68,68,0.08)", color: "rgba(239,68,68,0.6)", border: "1px solid rgba(239,68,68,0.15)" }}>
                  🛡 {character.restrictions!.length} restr.
                </span>
              )}
              {character.tags?.slice(0, 3).map(tag => (
                <span key={tag} className="text-[9px] font-mono px-1.5 py-0.5 rounded" style={{ background: "rgba(255,255,255,0.03)", color: "rgba(255,255,255,0.25)" }}>
                  #{tag}
                </span>
              ))}
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-1 flex-shrink-0">
            <button
              onClick={() => setExpanded((e) => !e)}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors hover:bg-white/10"
              style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)" }}
              title="Ver prompt"
            >
              <Brain size={12} style={{ color: "rgba(255,255,255,0.4)" }} />
            </button>
            <button
              onClick={onToggle}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors hover:bg-white/10"
              style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.07)" }}
              title={character.is_active ? "Desativar" : "Ativar"}
            >
              {character.is_active
                ? <EyeOff size={12} style={{ color: "rgba(255,255,255,0.4)" }} />
                : <Eye size={12} style={{ color: "rgba(255,255,255,0.4)" }} />
              }
            </button>
            <button
              onClick={onEdit}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors hover:bg-purple-500/20"
              style={{ background: "rgba(139,92,246,0.08)", border: "1px solid rgba(139,92,246,0.15)" }}
              title="Editar"
            >
              <Sparkles size={12} style={{ color: "#8B5CF6" }} />
            </button>
            <button
              onClick={onDelete}
              className="w-7 h-7 rounded-lg flex items-center justify-center transition-colors hover:bg-red-500/20"
              style={{ background: "rgba(239,68,68,0.06)", border: "1px solid rgba(239,68,68,0.12)" }}
              title="Excluir"
            >
              <Trash2 size={12} style={{ color: "rgba(239,68,68,0.6)" }} />
            </button>
          </div>
        </div>
      </div>

      {/* Expandido: System Prompt */}
      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden"
          >
            <div className="px-4 pb-4 pt-0">
              <div className="p-3 rounded-xl" style={{ background: "rgba(139,92,246,0.06)", border: "1px solid rgba(139,92,246,0.12)" }}>
                <p className="text-[9px] font-mono tracking-widest uppercase mb-2" style={{ color: "rgba(139,92,246,0.6)" }}>SYSTEM PROMPT</p>
                <p className="text-[11px] font-mono leading-relaxed whitespace-pre-wrap" style={{ color: "rgba(255,255,255,0.55)" }}>
                  {character.system_prompt}
                </p>
                {character.greeting_message && (
                  <>
                    <div style={{ height: "1px", background: "rgba(139,92,246,0.15)", margin: "12px 0" }} />
                    <p className="text-[9px] font-mono tracking-widest uppercase mb-2" style={{ color: "rgba(139,92,246,0.6)" }}>MENSAGEM DE BOAS-VINDAS</p>
                    <p className="text-[11px] font-mono leading-relaxed" style={{ color: "rgba(255,255,255,0.55)" }}>
                      {character.greeting_message}
                    </p>
                  </>
                )}
              </div>
              {(character.usage_count ?? 0) > 0 && (
                <p className="text-[10px] font-mono mt-2" style={{ color: "rgba(255,255,255,0.2)" }}>
                  <Activity size={9} className="inline mr-1" />
                  {(character.usage_count ?? 0).toLocaleString()} interações registradas
                </p>
              )}
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
  const [editTarget, setEditTarget] = useState<AICharacter | "new" | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<AICharacter | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_ai_characters");
      if (error) throw error;
      const list = Array.isArray(data) ? data : (data ? [data] : []);
      setCharacters(list as AICharacter[]);
    } catch {
      toast.error("Erro ao carregar personagens");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function handleToggle(char: AICharacter) {
    try {
      const { error } = await supabase.rpc("admin_toggle_ai_character", { p_id: char.id, p_active: !char.is_active });
      if (error) throw error;
      toast.success(char.is_active ? `${char.name} desativado` : `${char.name} ativado`);
      load();
    } catch (e: unknown) {
      toast.error((e as Error).message ?? "Erro ao alternar status");
    }
  }

  async function handleDelete(char: AICharacter) {
    try {
      const { error } = await supabase.rpc("admin_delete_ai_character", { p_id: char.id });
      if (error) throw error;
      toast.success(`${char.name} excluído`);
      setDeleteTarget(null);
      load();
    } catch (e: unknown) {
      toast.error((e as Error).message ?? "Erro ao excluir");
    }
  }

  const filtered = characters.filter((c) => {
    const matchSearch = !search || c.name.toLowerCase().includes(search.toLowerCase()) || c.description.toLowerCase().includes(search.toLowerCase());
    const matchActive = filterActive === "all" || (filterActive === "active" ? c.is_active : !c.is_active);
    return matchSearch && matchActive;
  });

  const activeCount = characters.filter(c => c.is_active).length;

  if (!canModerate) {
    return (
      <div className="flex items-center justify-center h-full min-h-[60vh]">
        <div className="text-center">
          <Bot size={32} className="mx-auto mb-3" style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm font-semibold" style={{ color: "rgba(255,255,255,0.4)" }}>Acesso Restrito</p>
          <p className="text-xs font-mono mt-1" style={{ color: "rgba(255,255,255,0.2)" }}>Apenas moderadores podem gerenciar personagens de IA.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="p-5 md:p-7 max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <motion.div initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div
            className="w-11 h-11 rounded-2xl flex items-center justify-center flex-shrink-0"
            style={{ background: "rgba(139,92,246,0.12)", border: "1.5px solid rgba(139,92,246,0.3)" }}
          >
            <Brain size={20} style={{ color: "#8B5CF6" }} />
          </div>
          <div>
            <h1 className="text-[18px] font-bold text-white" style={{ fontFamily: "'Space Grotesk', sans-serif" }}>AI Studio</h1>
            <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
              {characters.length} personagens · {activeCount} ativos
            </p>
          </div>
        </div>
        <button
          onClick={() => setEditTarget("new")}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold transition-all hover:bg-purple-500/25"
          style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.3)" }}
        >
          <Plus size={15} />
          Novo Personagem
        </button>
      </motion.div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-3">
        {[
          { label: "Total", value: characters.length, icon: Bot, color: "#8B5CF6", bg: "139,92,246" },
          { label: "Ativos", value: activeCount, icon: Activity, color: "#22C55E", bg: "34,197,94" },
          { label: "Inativos", value: characters.length - activeCount, icon: EyeOff, color: "#EF4444", bg: "239,68,68" },
          { label: "Idiomas", value: Array.from(new Set(characters.map(c => c.language))).length, icon: Globe, color: "#60A5FA", bg: "96,165,250" },
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

      {/* Filtros */}
      <div className="flex items-center gap-3">
        <div className="flex-1 flex items-center gap-2 px-3 py-2 rounded-xl" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
          <Search size={13} style={{ color: "rgba(255,255,255,0.3)" }} />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar personagem..."
            className="flex-1 bg-transparent text-sm text-white placeholder-white/25 outline-none"
          />
          {search && <button onClick={() => setSearch("")} style={{ color: "rgba(255,255,255,0.2)" }}><X size={12} /></button>}
        </div>
        <div className="flex gap-1 p-1 rounded-xl" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}>
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
            style={{ background: "rgba(0,0,0,0.8)", backdropFilter: "blur(8px)" }}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="rounded-2xl p-6 w-full max-w-sm text-center"
              style={{ background: "#0f1117", border: "1px solid rgba(239,68,68,0.3)" }}
            >
              <div className="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4" style={{ background: "rgba(239,68,68,0.15)" }}>
                <AlertTriangle size={22} style={{ color: "#EF4444" }} />
              </div>
              <h3 className="text-white font-semibold mb-2">Excluir personagem?</h3>
              <p className="text-sm mb-5" style={{ color: "rgba(255,255,255,0.4)" }}>
                <strong className="text-white">{deleteTarget.name}</strong> será removido permanentemente. Sessões ativas serão encerradas.
              </p>
              <div className="flex gap-3">
                <button
                  onClick={() => setDeleteTarget(null)}
                  className="flex-1 py-2 rounded-xl text-sm"
                  style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}
                >
                  Cancelar
                </button>
                <button
                  onClick={() => handleDelete(deleteTarget)}
                  className="flex-1 py-2 rounded-xl text-sm font-semibold"
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
