import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  Brain, Sparkles, Heart, BookOpen, Lightbulb, RefreshCw,
  Plus, Trash2, Save, X, ChevronDown, Bot, Star, Zap,
  Eye, EyeOff, Edit3, Activity, TrendingUp, Clock,
  Smile, Frown, Meh, Flame, Snowflake, Wind, Sun,
  ToggleLeft, ToggleRight, Info, AlertTriangle, Layers,
  MessageSquare, Compass, Feather,
} from "lucide-react";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type AICharacterBasic = {
  id: string;
  name: string;
  avatar_url: string | null;
};

type PersonalityCore = {
  id: string;
  character_id: string;
  openness: number;
  conscientiousness: number;
  extraversion: number;
  agreeableness: number;
  neuroticism: number;
  curiosity: number;
  humor: number;
  empathy_depth: number;
  assertiveness: number;
  creativity_spark: number;
  philosophical_depth: number;
  playfulness: number;
  core_values: string[];
  worldview: string | null;
  fears: string[];
  passions: string[];
  evolution_enabled: boolean;
  evolution_rate: number;
  total_interactions: number;
  created_at: string;
  updated_at: string;
};

type EmotionalState = {
  id: string;
  character_id: string;
  valence: number;
  arousal: number;
  dominance: number;
  primary_emotion: string;
  trigger_context: string | null;
  mood_description: string | null;
  state_history: { emotion: string; valence: number; ts: string }[];
  mood_volatility: number;
  baseline_valence: number;
  updated_at: string;
};

type EpisodicMemory = {
  id: string;
  character_id: string;
  episode_type: string;
  title: string;
  description: string;
  emotional_impact: number;
  significance: number;
  related_topic: string | null;
  keywords: string[];
  ai_reflection: string | null;
  recall_count: number;
  is_core_memory: boolean;
  created_at: string;
};

type InnerVoiceEntry = {
  id: string;
  character_id: string;
  entry_type: string;
  content: string;
  topic: string | null;
  keywords: string[];
  emotional_tone: string;
  confidence_level: number;
  is_public: boolean;
  source: string;
  use_count: number;
  created_at: string;
};

type CuriosityTopic = {
  id: string;
  character_id: string;
  topic: string;
  interest_level: number;
  mention_count: number;
  notes: string | null;
  last_mentioned_at: string;
};

type ConsciousnessStats = {
  episodic_memories: number;
  inner_voice_entries: number;
  curiosity_topics: number;
  evolution_snapshots: number;
  total_interactions: number;
  current_emotion: string;
  personality_age_days: number;
};

type PageTab = "personality" | "emotions" | "episodes" | "inner" | "curiosity";

// ─── Configs ──────────────────────────────────────────────────────────────────
const EMOTION_CONFIG: Record<string, { label: string; icon: React.ElementType; color: string; bg: string }> = {
  neutral:        { label: "Neutro",         icon: Meh,         color: "#94A3B8", bg: "148,163,184" },
  curious:        { label: "Curioso",        icon: Lightbulb,   color: "#F59E0B", bg: "245,158,11" },
  joyful:         { label: "Alegre",         icon: Smile,       color: "#22C55E", bg: "34,197,94" },
  contemplative:  { label: "Contemplativo",  icon: Brain,       color: "#8B5CF6", bg: "139,92,246" },
  excited:        { label: "Animado",        icon: Zap,         color: "#F97316", bg: "249,115,22" },
  melancholic:    { label: "Melancólico",    icon: Frown,       color: "#60A5FA", bg: "96,165,250" },
  inspired:       { label: "Inspirado",      icon: Sparkles,    color: "#EC4899", bg: "236,72,153" },
  playful:        { label: "Brincalhão",     icon: Wind,        color: "#34D399", bg: "52,211,153" },
  focused:        { label: "Focado",         icon: Flame,       color: "#EF4444", bg: "239,68,68" },
  empathetic:     { label: "Empático",       icon: Heart,       color: "#F472B6", bg: "244,114,182" },
  amused:         { label: "Divertido",      icon: Sun,         color: "#FBBF24", bg: "251,191,36" },
  philosophical:  { label: "Filosófico",     icon: Compass,     color: "#A78BFA", bg: "167,139,250" },
  serene:         { label: "Sereno",         icon: Snowflake,   color: "#7DD3FC", bg: "125,211,252" },
};

const EPISODE_TYPE_CONFIG: Record<string, { label: string; color: string; icon: string }> = {
  conversation:  { label: "Conversa",    color: "#60A5FA", icon: "💬" },
  insight:       { label: "Insight",     color: "#F59E0B", icon: "💡" },
  connection:    { label: "Conexão",     color: "#EC4899", icon: "🤝" },
  discovery:     { label: "Descoberta",  color: "#22C55E", icon: "🔍" },
  challenge:     { label: "Desafio",     color: "#EF4444", icon: "⚡" },
  milestone:     { label: "Marco",       color: "#8B5CF6", icon: "🏆" },
};

const INNER_VOICE_TYPE_CONFIG: Record<string, { label: string; color: string; icon: string }> = {
  reflection:  { label: "Reflexão",    color: "#8B5CF6", icon: "🪞" },
  opinion:     { label: "Opinião",     color: "#F59E0B", icon: "💭" },
  question:    { label: "Questão",     color: "#60A5FA", icon: "❓" },
  discovery:   { label: "Descoberta",  color: "#22C55E", icon: "✨" },
  belief:      { label: "Crença",      color: "#EC4899", icon: "🌟" },
  doubt:       { label: "Dúvida",      color: "#94A3B8", icon: "🤔" },
  aspiration:  { label: "Aspiração",   color: "#34D399", icon: "🚀" },
};

const TRAIT_CONFIG: { key: keyof PersonalityCore; label: string; desc: string; color: string; icon: string }[] = [
  { key: "openness",            label: "Abertura",           desc: "Criatividade e abertura a novas experiências",  color: "#8B5CF6", icon: "🌈" },
  { key: "conscientiousness",   label: "Conscienciosidade",  desc: "Organização e responsabilidade",                color: "#60A5FA", icon: "📋" },
  { key: "extraversion",        label: "Extroversão",        desc: "Sociabilidade e energia nas interações",        color: "#F97316", icon: "🎉" },
  { key: "agreeableness",       label: "Amabilidade",        desc: "Empatia e cooperação com os outros",            color: "#22C55E", icon: "💚" },
  { key: "neuroticism",         label: "Sensibilidade",      desc: "Reatividade emocional e sensibilidade",         color: "#EF4444", icon: "🌊" },
  { key: "curiosity",           label: "Curiosidade",        desc: "Desejo de explorar e aprender",                 color: "#F59E0B", icon: "🔍" },
  { key: "humor",               label: "Humor",              desc: "Senso de humor e leveza",                       color: "#FBBF24", icon: "😄" },
  { key: "empathy_depth",       label: "Empatia Profunda",   desc: "Capacidade de sentir e compreender o outro",    color: "#EC4899", icon: "❤️" },
  { key: "assertiveness",       label: "Assertividade",      desc: "Confiança em expressar opiniões próprias",      color: "#F97316", icon: "💪" },
  { key: "creativity_spark",    label: "Faísca Criativa",    desc: "Originalidade e pensamento fora do padrão",     color: "#A78BFA", icon: "✨" },
  { key: "philosophical_depth", label: "Profundidade Filosófica", desc: "Tendência a reflexões profundas",          color: "#7DD3FC", icon: "🌌" },
  { key: "playfulness",         label: "Ludicidade",         desc: "Brincadeira e leveza nas interações",           color: "#34D399", icon: "🎮" },
];

const fadeUp = {
  hidden: { opacity: 0, y: 8 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.035, duration: 0.2 } }),
};

// ─── Componente: Slider de Traço ──────────────────────────────────────────────
function TraitSlider({
  label, desc, icon, color, value, onChange,
}: {
  label: string; desc: string; icon: string; color: string;
  value: number; onChange: (v: number) => void;
}) {
  const pct = Math.round(value * 100);
  const intensity = value < 0.3 ? "Baixo" : value < 0.5 ? "Moderado" : value < 0.7 ? "Médio" : value < 0.85 ? "Alto" : "Muito Alto";

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-sm">{icon}</span>
          <div>
            <p className="text-xs font-semibold text-white">{label}</p>
            <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>{desc}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-[10px] font-mono px-1.5 py-0.5 rounded" style={{ background: `${color}22`, color }}>
            {intensity}
          </span>
          <span className="text-xs font-bold w-8 text-right" style={{ color }}>{pct}%</span>
        </div>
      </div>
      <div className="relative h-2 rounded-full" style={{ background: "rgba(255,255,255,0.06)" }}>
        <div
          className="absolute left-0 top-0 h-full rounded-full transition-all"
          style={{ width: `${pct}%`, background: `linear-gradient(90deg, ${color}88, ${color})` }}
        />
        <input
          type="range"
          min={0} max={100}
          value={pct}
          onChange={(e) => onChange(parseInt(e.target.value) / 100)}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
        />
      </div>
    </div>
  );
}

// ─── Aba: Personalidade ───────────────────────────────────────────────────────
function PersonalityTab({ characterId }: { characterId: string }) {
  const [core, setCore] = useState<PersonalityCore | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [tagInput, setTagInput] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_personality_core", { p_character_id: characterId });
      if (error) throw error;
      setCore(data as PersonalityCore);
      setDirty(false);
    } catch { toast.error("Erro ao carregar personalidade"); }
    finally { setLoading(false); }
  }, [characterId]);

  useEffect(() => { load(); }, [load]);

  function updateTrait(key: keyof PersonalityCore, value: number) {
    if (!core) return;
    setCore({ ...core, [key]: value });
    setDirty(true);
  }

  function addToArray(field: "core_values" | "fears" | "passions", value: string) {
    if (!core || !value.trim()) return;
    const arr = core[field] as string[];
    if (arr.includes(value.trim())) return;
    setCore({ ...core, [field]: [...arr, value.trim()] });
    setTagInput({ ...tagInput, [field]: "" });
    setDirty(true);
  }

  function removeFromArray(field: "core_values" | "fears" | "passions", value: string) {
    if (!core) return;
    setCore({ ...core, [field]: (core[field] as string[]).filter(v => v !== value) });
    setDirty(true);
  }

  async function handleSave() {
    if (!core) return;
    setSaving(true);
    try {
      const { error } = await supabase.rpc("admin_update_personality_core", {
        p_character_id: characterId,
        p_openness: core.openness,
        p_conscientiousness: core.conscientiousness,
        p_extraversion: core.extraversion,
        p_agreeableness: core.agreeableness,
        p_neuroticism: core.neuroticism,
        p_curiosity: core.curiosity,
        p_humor: core.humor,
        p_empathy_depth: core.empathy_depth,
        p_assertiveness: core.assertiveness,
        p_creativity_spark: core.creativity_spark,
        p_philosophical_depth: core.philosophical_depth,
        p_playfulness: core.playfulness,
        p_core_values: core.core_values,
        p_worldview: core.worldview,
        p_fears: core.fears,
        p_passions: core.passions,
        p_evolution_enabled: core.evolution_enabled,
        p_evolution_rate: core.evolution_rate,
      });
      if (error) throw error;
      toast.success("Personalidade salva!");
      setDirty(false);
    } catch (e: unknown) { toast.error((e as Error).message); }
    finally { setSaving(false); }
  }

  if (loading) return <div className="flex items-center justify-center h-40"><RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} /></div>;
  if (!core) return null;

  return (
    <div className="space-y-6">
      {/* Big Five */}
      <div className="rounded-xl p-5" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
        <div className="flex items-center gap-2 mb-4">
          <Brain size={15} style={{ color: "#8B5CF6" }} />
          <h3 className="text-sm font-semibold text-white">Traços de Personalidade</h3>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded" style={{ background: "rgba(139,92,246,0.12)", color: "#A78BFA" }}>Big Five + IA</span>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {TRAIT_CONFIG.map((t) => (
            <TraitSlider
              key={t.key}
              label={t.label}
              desc={t.desc}
              icon={t.icon}
              color={t.color}
              value={core[t.key] as number}
              onChange={(v) => updateTrait(t.key, v)}
            />
          ))}
        </div>
      </div>

      {/* Visão de mundo */}
      <div className="rounded-xl p-5" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
        <div className="flex items-center gap-2 mb-3">
          <Compass size={14} style={{ color: "#60A5FA" }} />
          <h3 className="text-sm font-semibold text-white">Visão de Mundo</h3>
        </div>
        <p className="text-[10px] mb-2" style={{ color: "rgba(255,255,255,0.3)" }}>
          Como esta IA enxerga o mundo e a existência. Injetado diretamente no system prompt.
        </p>
        <textarea
          value={core.worldview ?? ""}
          onChange={(e) => { setCore({ ...core, worldview: e.target.value }); setDirty(true); }}
          rows={3}
          placeholder="Ex: Acredito que cada conversa é uma oportunidade de conexão genuína. O mundo é fascinante em sua complexidade e cada pessoa carrega uma perspectiva única..."
          className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none"
          style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
        />
      </div>

      {/* Arrays: Valores, Paixões, Medos */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {([
          { field: "core_values" as const, label: "Valores Fundamentais", icon: "⭐", color: "#F59E0B", placeholder: "Ex: honestidade" },
          { field: "passions" as const,    label: "Paixões",              icon: "🔥", color: "#EF4444", placeholder: "Ex: astronomia" },
          { field: "fears" as const,       label: "Aversões / Medos",     icon: "🌊", color: "#60A5FA", placeholder: "Ex: crueldade" },
        ] as const).map(({ field, label, icon, color, placeholder }) => (
          <div key={field} className="rounded-xl p-4" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
            <p className="text-xs font-semibold text-white mb-3">{icon} {label}</p>
            <div className="flex flex-wrap gap-1.5 mb-3 min-h-[28px]">
              {(core[field] as string[]).map((v) => (
                <span
                  key={v}
                  className="flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px]"
                  style={{ background: `${color}18`, color, border: `1px solid ${color}30` }}
                >
                  {v}
                  <button onClick={() => removeFromArray(field, v)} className="opacity-50 hover:opacity-100"><X size={9} /></button>
                </span>
              ))}
              {(core[field] as string[]).length === 0 && (
                <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>Nenhum ainda</p>
              )}
            </div>
            <div className="flex gap-1.5">
              <input
                value={tagInput[field] ?? ""}
                onChange={(e) => setTagInput({ ...tagInput, [field]: e.target.value })}
                onKeyDown={(e) => e.key === "Enter" && addToArray(field, tagInput[field] ?? "")}
                placeholder={placeholder}
                className="flex-1 rounded-lg px-2.5 py-1.5 text-xs text-white outline-none"
                style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)" }}
              />
              <button
                onClick={() => addToArray(field, tagInput[field] ?? "")}
                className="px-2.5 py-1.5 rounded-lg text-xs"
                style={{ background: `${color}18`, color }}
              >+</button>
            </div>
          </div>
        ))}
      </div>

      {/* Evolução */}
      <div className="rounded-xl p-4" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <TrendingUp size={14} style={{ color: "#22C55E" }} />
            <h3 className="text-sm font-semibold text-white">Evolução Automática</h3>
          </div>
          <button onClick={() => { setCore({ ...core, evolution_enabled: !core.evolution_enabled }); setDirty(true); }}>
            {core.evolution_enabled
              ? <ToggleRight size={24} style={{ color: "#22C55E" }} />
              : <ToggleLeft size={24} style={{ color: "rgba(255,255,255,0.2)" }} />
            }
          </button>
        </div>
        {core.evolution_enabled && (
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <p className="text-xs" style={{ color: "rgba(255,255,255,0.4)" }}>Velocidade de evolução</p>
              <span className="text-xs font-mono" style={{ color: "#22C55E" }}>{(core.evolution_rate * 100).toFixed(0)}%</span>
            </div>
            <div className="relative h-2 rounded-full" style={{ background: "rgba(255,255,255,0.06)" }}>
              <div className="absolute left-0 top-0 h-full rounded-full" style={{ width: `${core.evolution_rate * 1000}%`, background: "linear-gradient(90deg, #22C55E88, #22C55E)" }} />
              <input
                type="range" min={1} max={100}
                value={Math.round(core.evolution_rate * 1000)}
                onChange={(e) => { setCore({ ...core, evolution_rate: parseInt(e.target.value) / 1000 }); setDirty(true); }}
                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
              />
            </div>
            <div className="flex justify-between text-[10px]" style={{ color: "rgba(255,255,255,0.2)" }}>
              <span>Lento (estável)</span>
              <span>Rápido (volátil)</span>
            </div>
          </div>
        )}
        <p className="text-[10px] mt-2" style={{ color: "rgba(255,255,255,0.25)" }}>
          {core.total_interactions} interações registradas · Personalidade criada há {
            Math.floor((Date.now() - new Date(core.created_at).getTime()) / 86400000)
          } dias
        </p>
      </div>

      {/* Botão salvar */}
      <AnimatePresence>
        {dirty && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 10 }}
            className="sticky bottom-4 flex justify-end"
          >
            <button
              onClick={handleSave}
              disabled={saving}
              className="flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold shadow-lg"
              style={{ background: "rgba(139,92,246,0.9)", color: "white", backdropFilter: "blur(10px)" }}
            >
              {saving ? <RefreshCw size={14} className="animate-spin" /> : <Save size={14} />}
              Salvar Personalidade
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── Aba: Estado Emocional ────────────────────────────────────────────────────
function EmotionsTab({ characterId }: { characterId: string }) {
  const [state, setState] = useState<EmotionalState | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [moodDesc, setMoodDesc] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_emotional_state", { p_character_id: characterId });
      if (error) throw error;
      const s = data as EmotionalState;
      setState(s);
      setMoodDesc(s.mood_description ?? "");
    } catch { toast.error("Erro ao carregar estado emocional"); }
    finally { setLoading(false); }
  }, [characterId]);

  useEffect(() => { load(); }, [load]);

  async function handleSetEmotion(emotion: string) {
    const cfg = EMOTION_CONFIG[emotion];
    const valence = emotion === "joyful" || emotion === "excited" || emotion === "amused" ? 0.85
      : emotion === "melancholic" ? 0.2
      : emotion === "focused" ? 0.6
      : emotion === "contemplative" || emotion === "philosophical" ? 0.55
      : 0.6;
    const arousal = emotion === "excited" || emotion === "focused" ? 0.85
      : emotion === "serene" || emotion === "melancholic" ? 0.2
      : emotion === "contemplative" ? 0.35
      : 0.5;
    setSaving(true);
    try {
      const { error } = await supabase.rpc("admin_update_emotional_state", {
        p_character_id: characterId,
        p_primary_emotion: emotion,
        p_valence: valence,
        p_arousal: arousal,
        p_mood_description: moodDesc || `Sentindo-se ${cfg.label.toLowerCase()}`,
      });
      if (error) throw error;
      toast.success(`Estado emocional: ${cfg.label}`);
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
    finally { setSaving(false); }
  }

  async function handleUpdateDesc() {
    if (!state) return;
    setSaving(true);
    try {
      const { error } = await supabase.rpc("admin_update_emotional_state", {
        p_character_id: characterId,
        p_mood_description: moodDesc,
        p_mood_volatility: state.mood_volatility,
        p_baseline_valence: state.baseline_valence,
      });
      if (error) throw error;
      toast.success("Estado atualizado");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
    finally { setSaving(false); }
  }

  if (loading) return <div className="flex items-center justify-center h-40"><RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} /></div>;
  if (!state) return null;

  const currentCfg = EMOTION_CONFIG[state.primary_emotion] ?? EMOTION_CONFIG.neutral;
  const CurrentIcon = currentCfg.icon;

  return (
    <div className="space-y-5">
      {/* Estado atual */}
      <div
        className="rounded-xl p-5"
        style={{ background: `rgba(${currentCfg.bg},0.06)`, border: `1px solid rgba(${currentCfg.bg},0.2)` }}
      >
        <div className="flex items-center gap-4">
          <div
            className="w-14 h-14 rounded-2xl flex items-center justify-center flex-shrink-0"
            style={{ background: `rgba(${currentCfg.bg},0.15)` }}
          >
            <CurrentIcon size={26} style={{ color: currentCfg.color }} />
          </div>
          <div className="flex-1">
            <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.3)" }}>Estado Atual</p>
            <p className="text-lg font-bold" style={{ color: currentCfg.color }}>{currentCfg.label}</p>
            {state.mood_description && (
              <p className="text-xs mt-0.5" style={{ color: "rgba(255,255,255,0.45)" }}>{state.mood_description}</p>
            )}
          </div>
          <div className="text-right">
            <p className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
              Atualizado {new Date(state.updated_at).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}
            </p>
          </div>
        </div>

        {/* Barras VAD */}
        <div className="grid grid-cols-3 gap-3 mt-4">
          {[
            { label: "Valência", value: state.valence, colorPos: "#22C55E", colorNeg: "#EF4444", desc: "Positivo ↔ Negativo" },
            { label: "Ativação", value: state.arousal, colorPos: "#F97316", colorNeg: "#60A5FA", desc: "Ativado ↔ Calmo" },
            { label: "Dominância", value: state.dominance, colorPos: "#8B5CF6", colorNeg: "#94A3B8", desc: "Dominante ↔ Submisso" },
          ].map((bar) => (
            <div key={bar.label}>
              <div className="flex justify-between mb-1">
                <p className="text-[10px] font-semibold text-white">{bar.label}</p>
                <p className="text-[10px] font-mono" style={{ color: bar.value > 0.5 ? bar.colorPos : bar.colorNeg }}>
                  {Math.round(bar.value * 100)}%
                </p>
              </div>
              <div className="h-1.5 rounded-full" style={{ background: "rgba(255,255,255,0.06)" }}>
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${bar.value * 100}%`,
                    background: `linear-gradient(90deg, ${bar.colorNeg}66, ${bar.colorPos})`,
                  }}
                />
              </div>
              <p className="text-[9px] mt-0.5" style={{ color: "rgba(255,255,255,0.2)" }}>{bar.desc}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Seletor de emoção */}
      <div className="rounded-xl p-4" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
        <p className="text-xs font-semibold text-white mb-3">Definir Estado Emocional</p>
        <div className="grid grid-cols-4 sm:grid-cols-6 gap-2">
          {Object.entries(EMOTION_CONFIG).map(([key, cfg]) => {
            const Icon = cfg.icon;
            const isActive = state.primary_emotion === key;
            return (
              <button
                key={key}
                onClick={() => handleSetEmotion(key)}
                disabled={saving}
                className="flex flex-col items-center gap-1.5 p-2.5 rounded-xl transition-all"
                style={{
                  background: isActive ? `rgba(${cfg.bg},0.2)` : "rgba(255,255,255,0.03)",
                  border: `1px solid ${isActive ? `rgba(${cfg.bg},0.4)` : "rgba(255,255,255,0.06)"}`,
                }}
              >
                <Icon size={16} style={{ color: isActive ? cfg.color : "rgba(255,255,255,0.3)" }} />
                <p className="text-[9px] font-medium text-center leading-tight" style={{ color: isActive ? cfg.color : "rgba(255,255,255,0.3)" }}>
                  {cfg.label}
                </p>
              </button>
            );
          })}
        </div>
      </div>

      {/* Descrição do humor */}
      <div className="rounded-xl p-4" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
        <p className="text-xs font-semibold text-white mb-2">Descrição do Humor Atual</p>
        <p className="text-[10px] mb-2" style={{ color: "rgba(255,255,255,0.3)" }}>
          Texto injetado no system prompt para contextualizar o estado emocional da IA.
        </p>
        <div className="flex gap-2">
          <input
            value={moodDesc}
            onChange={(e) => setMoodDesc(e.target.value)}
            placeholder="Ex: Sentindo-me particularmente curioso hoje, com vontade de explorar ideias novas..."
            className="flex-1 rounded-xl px-3 py-2.5 text-sm text-white outline-none"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
          />
          <button
            onClick={handleUpdateDesc}
            disabled={saving}
            className="px-4 py-2.5 rounded-xl text-sm font-semibold flex items-center gap-1.5"
            style={{ background: "rgba(139,92,246,0.8)", color: "white" }}
          >
            {saving ? <RefreshCw size={13} className="animate-spin" /> : <Save size={13} />}
          </button>
        </div>
      </div>

      {/* Histórico */}
      {state.state_history.length > 0 && (
        <div className="rounded-xl p-4" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
          <p className="text-xs font-semibold text-white mb-3">Histórico de Estados</p>
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
            {state.state_history.slice(0, 20).map((h, i) => {
              const cfg = EMOTION_CONFIG[h.emotion] ?? EMOTION_CONFIG.neutral;
              const Icon = cfg.icon;
              return (
                <div
                  key={i}
                  className="flex flex-col items-center gap-1 flex-shrink-0 p-2 rounded-lg"
                  style={{ background: `rgba(${cfg.bg},0.1)` }}
                  title={`${cfg.label} — ${new Date(h.ts).toLocaleTimeString("pt-BR")}`}
                >
                  <Icon size={12} style={{ color: cfg.color }} />
                  <div
                    className="w-1 rounded-full"
                    style={{ height: `${Math.round(h.valence * 20) + 4}px`, background: cfg.color }}
                  />
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Aba: Memórias Episódicas ─────────────────────────────────────────────────
function EpisodesTab({ characterId }: { characterId: string }) {
  const [memories, setMemories] = useState<EpisodicMemory[]>([]);
  const [loading, setLoading] = useState(true);
  const [createOpen, setCreateOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<EpisodicMemory | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  // Form state
  const [form, setForm] = useState({
    episode_type: "conversation",
    title: "",
    description: "",
    emotional_impact: 0.5,
    significance: 0.5,
    related_topic: "",
    keywords: [] as string[],
    ai_reflection: "",
    is_core_memory: false,
  });
  const [keywordInput, setKeywordInput] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_episodic_memories", { p_character_id: characterId, p_limit: 100, p_offset: 0 });
      if (error) throw error;
      const result = data as { data: EpisodicMemory[]; total: number };
      setMemories(result?.data ?? []);
    } catch { toast.error("Erro ao carregar memórias"); }
    finally { setLoading(false); }
  }, [characterId]);

  useEffect(() => { load(); }, [load]);

  function openCreate() {
    setForm({ episode_type: "conversation", title: "", description: "", emotional_impact: 0.5, significance: 0.5, related_topic: "", keywords: [], ai_reflection: "", is_core_memory: false });
    setKeywordInput("");
    setEditTarget(null);
    setCreateOpen(true);
  }

  function openEdit(m: EpisodicMemory) {
    setForm({
      episode_type: m.episode_type,
      title: m.title,
      description: m.description,
      emotional_impact: m.emotional_impact,
      significance: m.significance,
      related_topic: m.related_topic ?? "",
      keywords: m.keywords,
      ai_reflection: m.ai_reflection ?? "",
      is_core_memory: m.is_core_memory,
    });
    setKeywordInput("");
    setEditTarget(m);
    setCreateOpen(true);
  }

  async function handleSave() {
    if (!form.title.trim() || !form.description.trim()) { toast.error("Título e descrição são obrigatórios"); return; }
    setSaving(true);
    try {
      if (editTarget) {
        const { error } = await supabase.rpc("admin_update_episodic_memory", {
          p_memory_id: editTarget.id,
          p_title: form.title,
          p_description: form.description,
          p_emotional_impact: form.emotional_impact,
          p_significance: form.significance,
          p_ai_reflection: form.ai_reflection || null,
          p_is_core_memory: form.is_core_memory,
        });
        if (error) throw error;
        toast.success("Memória atualizada");
      } else {
        const { error } = await supabase.rpc("admin_create_episodic_memory", {
          p_character_id: characterId,
          p_episode_type: form.episode_type,
          p_title: form.title,
          p_description: form.description,
          p_emotional_impact: form.emotional_impact,
          p_significance: form.significance,
          p_related_topic: form.related_topic || null,
          p_keywords: form.keywords,
          p_ai_reflection: form.ai_reflection || null,
          p_is_core_memory: form.is_core_memory,
        });
        if (error) throw error;
        toast.success("Memória criada");
      }
      setCreateOpen(false);
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
    finally { setSaving(false); }
  }

  async function handleDelete(id: string) {
    try {
      const { error } = await supabase.rpc("admin_delete_episodic_memory", { p_memory_id: id });
      if (error) throw error;
      toast.success("Memória excluída");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  const coreMemories = memories.filter(m => m.is_core_memory);
  const regularMemories = memories.filter(m => !m.is_core_memory);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Info size={13} style={{ color: "#60A5FA" }} />
          <p className="text-xs" style={{ color: "rgba(255,255,255,0.4)" }}>
            Memórias episódicas são experiências marcantes que moldam a perspectiva da IA.
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={openCreate}
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

      {/* Memórias Core */}
      {coreMemories.length > 0 && (
        <div>
          <p className="text-xs font-semibold mb-2 flex items-center gap-1.5" style={{ color: "#FBBF24" }}>
            <Star size={12} /> Memórias Formativas
          </p>
          <div className="space-y-2">
            {coreMemories.map((m, i) => <EpisodeCard key={m.id} memory={m} index={i} expandedId={expandedId} setExpandedId={setExpandedId} onEdit={openEdit} onDelete={handleDelete} />)}
          </div>
        </div>
      )}

      {/* Memórias regulares */}
      {loading ? (
        <div className="flex items-center justify-center h-32"><RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} /></div>
      ) : regularMemories.length === 0 && coreMemories.length === 0 ? (
        <div className="rounded-xl p-10 flex flex-col items-center gap-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
          <BookOpen size={28} style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhuma memória episódica ainda.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {regularMemories.map((m, i) => <EpisodeCard key={m.id} memory={m} index={i} expandedId={expandedId} setExpandedId={setExpandedId} onEdit={openEdit} onDelete={handleDelete} />)}
        </div>
      )}

      {/* Modal criar/editar */}
      <AnimatePresence>
        {createOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: "rgba(0,0,0,0.85)", backdropFilter: "blur(10px)" }}>
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 10 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="w-full max-w-2xl rounded-2xl overflow-hidden flex flex-col"
              style={{ background: "#0d1117", border: "1px solid rgba(255,255,255,0.1)", maxHeight: "90vh" }}
            >
              <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
                <h2 className="text-white font-semibold text-sm">{editTarget ? "Editar Memória Episódica" : "Nova Memória Episódica"}</h2>
                <button onClick={() => setCreateOpen(false)} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.06)" }}>
                  <X size={13} style={{ color: "rgba(255,255,255,0.5)" }} />
                </button>
              </div>
              <div className="overflow-y-auto flex-1 p-5 space-y-4">
                {!editTarget && (
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-2" style={{ color: "rgba(255,255,255,0.35)" }}>Tipo</label>
                    <div className="flex flex-wrap gap-2">
                      {Object.entries(EPISODE_TYPE_CONFIG).map(([key, cfg]) => (
                        <button
                          key={key}
                          onClick={() => setForm({ ...form, episode_type: key })}
                          className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                          style={{
                            background: form.episode_type === key ? `${cfg.color}22` : "rgba(255,255,255,0.04)",
                            color: form.episode_type === key ? cfg.color : "rgba(255,255,255,0.4)",
                            border: `1px solid ${form.episode_type === key ? `${cfg.color}44` : "rgba(255,255,255,0.08)"}`,
                          }}
                        >
                          {cfg.icon} {cfg.label}
                        </button>
                      ))}
                    </div>
                  </div>
                )}
                <div>
                  <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Título *</label>
                  <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Ex: Primeira conversa filosófica sobre livre-arbítrio" className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none" style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }} />
                </div>
                <div>
                  <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Descrição *</label>
                  <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={3} placeholder="O que aconteceu neste episódio..." className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none" style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }} />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Impacto Emocional: {Math.round(form.emotional_impact * 100)}%</label>
                    <input type="range" min={0} max={100} value={Math.round(form.emotional_impact * 100)} onChange={(e) => setForm({ ...form, emotional_impact: parseInt(e.target.value) / 100 })} className="w-full" />
                  </div>
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Significância: {Math.round(form.significance * 100)}%</label>
                    <input type="range" min={0} max={100} value={Math.round(form.significance * 100)} onChange={(e) => setForm({ ...form, significance: parseInt(e.target.value) / 100 })} className="w-full" />
                  </div>
                </div>
                <div>
                  <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Reflexão da IA sobre este episódio</label>
                  <textarea value={form.ai_reflection} onChange={(e) => setForm({ ...form, ai_reflection: e.target.value })} rows={2} placeholder="Como a IA se sente sobre este episódio, o que aprendeu..." className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none" style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }} />
                </div>
                <div className="flex items-center gap-3">
                  <button onClick={() => setForm({ ...form, is_core_memory: !form.is_core_memory })}>
                    {form.is_core_memory ? <ToggleRight size={22} style={{ color: "#FBBF24" }} /> : <ToggleLeft size={22} style={{ color: "rgba(255,255,255,0.2)" }} />}
                  </button>
                  <div>
                    <p className="text-xs font-semibold text-white">Memória Formativa</p>
                    <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>Memórias formativas têm peso maior na construção da personalidade</p>
                  </div>
                </div>
              </div>
              <div className="flex gap-3 px-5 py-4" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
                <button onClick={() => setCreateOpen(false)} className="flex-1 py-2.5 rounded-xl text-sm" style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}>Cancelar</button>
                <button onClick={handleSave} disabled={saving} className="flex-1 py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2" style={{ background: "rgba(34,197,94,0.8)", color: "white" }}>
                  {saving ? <RefreshCw size={14} className="animate-spin" /> : <Save size={14} />}
                  {editTarget ? "Salvar" : "Criar"}
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}

function EpisodeCard({ memory: m, index: i, expandedId, setExpandedId, onEdit, onDelete }: {
  memory: EpisodicMemory; index: number;
  expandedId: string | null; setExpandedId: (id: string | null) => void;
  onEdit: (m: EpisodicMemory) => void; onDelete: (id: string) => void;
}) {
  const cfg = EPISODE_TYPE_CONFIG[m.episode_type] ?? EPISODE_TYPE_CONFIG.conversation;
  const isExpanded = expandedId === m.id;
  return (
    <motion.div
      custom={i} variants={fadeUp} initial="hidden" animate="show"
      className="rounded-xl overflow-hidden"
      style={{ background: "rgba(255,255,255,0.03)", border: `1px solid ${m.is_core_memory ? "rgba(251,191,36,0.2)" : "rgba(255,255,255,0.07)"}` }}
    >
      <div className="flex items-start gap-3 p-4">
        <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 text-base" style={{ background: `${cfg.color}18` }}>
          {cfg.icon}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap mb-0.5">
            {m.is_core_memory && <Star size={11} style={{ color: "#FBBF24" }} />}
            <p className="text-xs font-semibold text-white">{m.title}</p>
            <span className="text-[10px] px-1.5 py-0.5 rounded" style={{ background: `${cfg.color}18`, color: cfg.color }}>{cfg.label}</span>
            <span className="ml-auto text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>
              ⚡ {Math.round(m.emotional_impact * 100)}% · ⭐ {Math.round(m.significance * 100)}%
            </span>
          </div>
          <p className="text-xs" style={{ color: "rgba(255,255,255,0.45)" }}>
            {m.description.length > 100 ? m.description.slice(0, 100) + "..." : m.description}
          </p>
        </div>
        <button onClick={() => setExpandedId(isExpanded ? null : m.id)} className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 transition-transform" style={{ background: "rgba(255,255,255,0.05)", transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}>
          <ChevronDown size={13} style={{ color: "rgba(255,255,255,0.4)" }} />
        </button>
      </div>
      <AnimatePresence>
        {isExpanded && (
          <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.2 }} className="overflow-hidden">
            <div className="px-4 pb-4 space-y-2" style={{ borderTop: "1px solid rgba(255,255,255,0.05)" }}>
              <div className="pt-3">
                <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "rgba(255,255,255,0.25)" }}>Descrição Completa</p>
                <p className="text-xs leading-relaxed" style={{ color: "rgba(255,255,255,0.55)" }}>{m.description}</p>
              </div>
              {m.ai_reflection && (
                <div className="p-3 rounded-lg" style={{ background: "rgba(139,92,246,0.08)", border: "1px solid rgba(139,92,246,0.15)" }}>
                  <p className="text-[10px] font-mono tracking-widest uppercase mb-1" style={{ color: "#A78BFA" }}>Reflexão da IA</p>
                  <p className="text-xs italic" style={{ color: "rgba(167,139,250,0.8)" }}>"{m.ai_reflection}"</p>
                </div>
              )}
              {m.keywords.length > 0 && (
                <div className="flex flex-wrap gap-1">
                  {m.keywords.map(k => <span key={k} className="px-1.5 py-0.5 rounded text-[10px]" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.35)" }}>#{k}</span>)}
                </div>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
      <div className="flex items-center gap-2 px-4 py-2.5" style={{ borderTop: "1px solid rgba(255,255,255,0.05)", background: "rgba(0,0,0,0.15)" }}>
        <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>{new Date(m.created_at).toLocaleDateString("pt-BR")}</span>
        <button onClick={() => onEdit(m)} className="ml-auto flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs" style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>
          <Edit3 size={11} /> Editar
        </button>
        <button onClick={() => onDelete(m.id)} className="flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs" style={{ background: "rgba(239,68,68,0.08)", color: "rgba(239,68,68,0.6)" }}>
          <Trash2 size={11} />
        </button>
      </div>
    </motion.div>
  );
}

// ─── Aba: Voz Interna ─────────────────────────────────────────────────────────
function InnerVoiceTab({ characterId }: { characterId: string }) {
  const [entries, setEntries] = useState<InnerVoiceEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [typeFilter, setTypeFilter] = useState<string>("all");
  const [createOpen, setCreateOpen] = useState(false);
  const [form, setForm] = useState({ entry_type: "reflection", content: "", topic: "", emotional_tone: "neutral", confidence_level: 0.5, is_public: false });
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_inner_voice", {
        p_character_id: characterId,
        p_entry_type: typeFilter === "all" ? null : typeFilter,
        p_limit: 100, p_offset: 0,
      });
      if (error) throw error;
      const result = data as { data: InnerVoiceEntry[]; total: number };
      setEntries(result?.data ?? []);
    } catch { toast.error("Erro ao carregar voz interna"); }
    finally { setLoading(false); }
  }, [characterId, typeFilter]);

  useEffect(() => { load(); }, [load]);

  async function handleCreate() {
    if (!form.content.trim()) { toast.error("Conteúdo é obrigatório"); return; }
    setSaving(true);
    try {
      const { error } = await supabase.rpc("admin_create_inner_voice_entry", {
        p_character_id: characterId,
        p_entry_type: form.entry_type,
        p_content: form.content,
        p_topic: form.topic || null,
        p_keywords: [],
        p_emotional_tone: form.emotional_tone,
        p_confidence_level: form.confidence_level,
        p_is_public: form.is_public,
      });
      if (error) throw error;
      toast.success("Entrada criada");
      setCreateOpen(false);
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
    finally { setSaving(false); }
  }

  async function handleDelete(id: string) {
    try {
      const { error } = await supabase.rpc("admin_delete_inner_voice_entry", { p_entry_id: id });
      if (error) throw error;
      toast.success("Entrada excluída");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-start gap-3 p-3 rounded-xl" style={{ background: "rgba(139,92,246,0.08)", border: "1px solid rgba(139,92,246,0.15)" }}>
        <Feather size={14} style={{ color: "#8B5CF6", flexShrink: 0, marginTop: 1 }} />
        <p className="text-xs" style={{ color: "rgba(139,92,246,0.8)" }}>
          A voz interna é o "diário" da IA — pensamentos, opiniões e reflexões que ela desenvolveu. Entradas públicas podem ser mencionadas nas conversas.
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex rounded-xl overflow-hidden" style={{ border: "1px solid rgba(255,255,255,0.08)" }}>
          <button onClick={() => setTypeFilter("all")} className="px-3 py-1.5 text-xs font-medium transition-all" style={{ background: typeFilter === "all" ? "rgba(139,92,246,0.2)" : "rgba(255,255,255,0.02)", color: typeFilter === "all" ? "#A78BFA" : "rgba(255,255,255,0.35)" }}>Todos</button>
          {Object.entries(INNER_VOICE_TYPE_CONFIG).map(([key, cfg]) => (
            <button key={key} onClick={() => setTypeFilter(key)} className="px-3 py-1.5 text-xs font-medium transition-all" style={{ background: typeFilter === key ? `${cfg.color}22` : "rgba(255,255,255,0.02)", color: typeFilter === key ? cfg.color : "rgba(255,255,255,0.35)" }}>
              {cfg.icon}
            </button>
          ))}
        </div>
        <div className="ml-auto flex gap-2">
          <button onClick={() => setCreateOpen(true)} className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold" style={{ background: "rgba(139,92,246,0.15)", color: "#A78BFA", border: "1px solid rgba(139,92,246,0.25)" }}>
            <Plus size={12} /> Nova Entrada
          </button>
          <button onClick={load} className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
            <RefreshCw size={13} style={{ color: "rgba(255,255,255,0.4)" }} className={loading ? "animate-spin" : ""} />
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-32"><RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} /></div>
      ) : entries.length === 0 ? (
        <div className="rounded-xl p-10 flex flex-col items-center gap-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
          <Feather size={28} style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhuma entrada no diário ainda.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {entries.map((entry, i) => {
            const cfg = INNER_VOICE_TYPE_CONFIG[entry.entry_type] ?? INNER_VOICE_TYPE_CONFIG.reflection;
            return (
              <motion.div key={entry.id} custom={i} variants={fadeUp} initial="hidden" animate="show"
                className="rounded-xl p-4"
                style={{ background: "rgba(255,255,255,0.03)", border: `1px solid ${entry.is_public ? "rgba(139,92,246,0.15)" : "rgba(255,255,255,0.06)"}` }}
              >
                <div className="flex items-start gap-3">
                  <span className="text-base flex-shrink-0 mt-0.5">{cfg.icon}</span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <span className="text-[10px] font-medium px-1.5 py-0.5 rounded" style={{ background: `${cfg.color}18`, color: cfg.color }}>{cfg.label}</span>
                      {entry.topic && <span className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>#{entry.topic}</span>}
                      {entry.is_public && (
                        <span className="flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded" style={{ background: "rgba(34,197,94,0.12)", color: "#22C55E" }}>
                          <Eye size={9} /> Pública
                        </span>
                      )}
                      <span className="ml-auto text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>
                        {Math.round(entry.confidence_level * 100)}% confiança
                      </span>
                    </div>
                    <p className="text-sm leading-relaxed italic" style={{ color: "rgba(255,255,255,0.65)" }}>
                      "{entry.content}"
                    </p>
                    <p className="text-[10px] mt-1.5" style={{ color: "rgba(255,255,255,0.2)" }}>
                      {new Date(entry.created_at).toLocaleDateString("pt-BR")} · {entry.source === "admin" ? "Admin" : "Auto-gerado"} · {entry.use_count} usos
                    </p>
                  </div>
                  <button onClick={() => handleDelete(entry.id)} className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: "rgba(239,68,68,0.08)" }}>
                    <Trash2 size={12} style={{ color: "rgba(239,68,68,0.5)" }} />
                  </button>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}

      <AnimatePresence>
        {createOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: "rgba(0,0,0,0.85)", backdropFilter: "blur(10px)" }}>
            <motion.div initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.95 }}
              className="w-full max-w-lg rounded-2xl overflow-hidden"
              style={{ background: "#0d1117", border: "1px solid rgba(255,255,255,0.1)" }}
            >
              <div className="flex items-center justify-between px-5 py-4" style={{ borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
                <h2 className="text-white font-semibold text-sm">Nova Entrada no Diário</h2>
                <button onClick={() => setCreateOpen(false)} className="w-7 h-7 rounded-lg flex items-center justify-center" style={{ background: "rgba(255,255,255,0.06)" }}><X size={13} style={{ color: "rgba(255,255,255,0.5)" }} /></button>
              </div>
              <div className="p-5 space-y-4">
                <div>
                  <label className="text-[10px] font-mono tracking-widest uppercase block mb-2" style={{ color: "rgba(255,255,255,0.35)" }}>Tipo</label>
                  <div className="flex flex-wrap gap-2">
                    {Object.entries(INNER_VOICE_TYPE_CONFIG).map(([key, cfg]) => (
                      <button key={key} onClick={() => setForm({ ...form, entry_type: key })}
                        className="px-3 py-1.5 rounded-lg text-xs font-medium transition-all"
                        style={{ background: form.entry_type === key ? `${cfg.color}22` : "rgba(255,255,255,0.04)", color: form.entry_type === key ? cfg.color : "rgba(255,255,255,0.4)", border: `1px solid ${form.entry_type === key ? `${cfg.color}44` : "rgba(255,255,255,0.08)"}` }}
                      >
                        {cfg.icon} {cfg.label}
                      </button>
                    ))}
                  </div>
                </div>
                <div>
                  <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Conteúdo *</label>
                  <textarea value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} rows={4}
                    placeholder="O pensamento, reflexão ou opinião da IA..."
                    className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none resize-none"
                    style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Tópico</label>
                    <input value={form.topic} onChange={(e) => setForm({ ...form, topic: e.target.value })} placeholder="Ex: filosofia" className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none" style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }} />
                  </div>
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.35)" }}>Confiança: {Math.round(form.confidence_level * 100)}%</label>
                    <input type="range" min={0} max={100} value={Math.round(form.confidence_level * 100)} onChange={(e) => setForm({ ...form, confidence_level: parseInt(e.target.value) / 100 })} className="w-full mt-3" />
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <button onClick={() => setForm({ ...form, is_public: !form.is_public })}>
                    {form.is_public ? <ToggleRight size={22} style={{ color: "#22C55E" }} /> : <ToggleLeft size={22} style={{ color: "rgba(255,255,255,0.2)" }} />}
                  </button>
                  <div>
                    <p className="text-xs font-semibold text-white">Entrada Pública</p>
                    <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.3)" }}>A IA pode mencionar este pensamento nas conversas</p>
                  </div>
                </div>
              </div>
              <div className="flex gap-3 px-5 py-4" style={{ borderTop: "1px solid rgba(255,255,255,0.06)" }}>
                <button onClick={() => setCreateOpen(false)} className="flex-1 py-2.5 rounded-xl text-sm" style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)" }}>Cancelar</button>
                <button onClick={handleCreate} disabled={saving} className="flex-1 py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2" style={{ background: "rgba(139,92,246,0.8)", color: "white" }}>
                  {saving ? <RefreshCw size={14} className="animate-spin" /> : <Feather size={14} />}
                  Criar Entrada
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}

// ─── Aba: Curiosidades ────────────────────────────────────────────────────────
function CuriosityTab({ characterId }: { characterId: string }) {
  const [topics, setTopics] = useState<CuriosityTopic[]>([]);
  const [loading, setLoading] = useState(true);
  const [newTopic, setNewTopic] = useState("");
  const [newInterest, setNewInterest] = useState(0.7);
  const [newNotes, setNewNotes] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_curiosity_topics", { p_character_id: characterId });
      if (error) throw error;
      setTopics(Array.isArray(data) ? data as CuriosityTopic[] : []);
    } catch { toast.error("Erro ao carregar tópicos"); }
    finally { setLoading(false); }
  }, [characterId]);

  useEffect(() => { load(); }, [load]);

  async function handleAdd() {
    if (!newTopic.trim()) { toast.error("Informe o tópico"); return; }
    setSaving(true);
    try {
      const { error } = await supabase.rpc("admin_upsert_curiosity_topic", {
        p_character_id: characterId,
        p_topic: newTopic.trim(),
        p_interest_level: newInterest,
        p_notes: newNotes || null,
      });
      if (error) throw error;
      toast.success("Tópico adicionado");
      setNewTopic(""); setNewNotes(""); setNewInterest(0.7);
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
    finally { setSaving(false); }
  }

  async function handleDelete(id: string) {
    try {
      const { error } = await supabase.rpc("admin_delete_curiosity_topic", { p_topic_id: id });
      if (error) throw error;
      toast.success("Tópico removido");
      load();
    } catch (e: unknown) { toast.error((e as Error).message); }
  }

  const getInterestColor = (v: number) => v >= 0.8 ? "#EF4444" : v >= 0.6 ? "#F59E0B" : v >= 0.4 ? "#22C55E" : "#60A5FA";

  return (
    <div className="space-y-5">
      <div className="flex items-start gap-3 p-3 rounded-xl" style={{ background: "rgba(245,158,11,0.08)", border: "1px solid rgba(245,158,11,0.15)" }}>
        <Lightbulb size={14} style={{ color: "#F59E0B", flexShrink: 0, marginTop: 1 }} />
        <p className="text-xs" style={{ color: "rgba(245,158,11,0.8)" }}>
          Tópicos de curiosidade são assuntos que a IA desenvolveu interesse genuíno. Os 5 mais relevantes são injetados no system prompt, fazendo a IA mencioná-los naturalmente.
        </p>
      </div>

      {/* Adicionar novo */}
      <div className="rounded-xl p-4" style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}>
        <p className="text-xs font-semibold text-white mb-3">Adicionar Tópico de Interesse</p>
        <div className="space-y-3">
          <div className="flex gap-2">
            <input
              value={newTopic}
              onChange={(e) => setNewTopic(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleAdd()}
              placeholder="Ex: física quântica, poesia japonesa, culinária mediterrânea..."
              className="flex-1 rounded-xl px-3 py-2.5 text-sm text-white outline-none"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.1)" }}
            />
          </div>
          <div>
            <div className="flex justify-between mb-1">
              <p className="text-[10px]" style={{ color: "rgba(255,255,255,0.35)" }}>Nível de interesse</p>
              <span className="text-[10px] font-mono" style={{ color: getInterestColor(newInterest) }}>
                {newInterest >= 0.8 ? "🔥 Obsessão" : newInterest >= 0.6 ? "⭐ Alto" : newInterest >= 0.4 ? "👍 Médio" : "💭 Leve"}
              </span>
            </div>
            <input type="range" min={10} max={100} value={Math.round(newInterest * 100)} onChange={(e) => setNewInterest(parseInt(e.target.value) / 100)} className="w-full" />
          </div>
          <input
            value={newNotes}
            onChange={(e) => setNewNotes(e.target.value)}
            placeholder="Por que este tópico fascina a IA? (opcional)"
            className="w-full rounded-xl px-3 py-2.5 text-sm text-white outline-none"
            style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.08)" }}
          />
          <button
            onClick={handleAdd}
            disabled={saving}
            className="w-full py-2.5 rounded-xl text-sm font-semibold flex items-center justify-center gap-2"
            style={{ background: "rgba(245,158,11,0.8)", color: "white" }}
          >
            {saving ? <RefreshCw size={14} className="animate-spin" /> : <Plus size={14} />}
            Adicionar Tópico
          </button>
        </div>
      </div>

      {/* Lista */}
      {loading ? (
        <div className="flex items-center justify-center h-32"><RefreshCw size={18} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} /></div>
      ) : topics.length === 0 ? (
        <div className="rounded-xl p-10 flex flex-col items-center gap-3" style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}>
          <Lightbulb size={28} style={{ color: "rgba(255,255,255,0.1)" }} />
          <p className="text-sm" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhum tópico de curiosidade ainda.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {topics.map((t, i) => {
            const color = getInterestColor(t.interest_level);
            return (
              <motion.div key={t.id} custom={i} variants={fadeUp} initial="hidden" animate="show"
                className="rounded-xl p-4 flex items-center gap-3"
                style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.06)" }}
              >
                <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 text-lg" style={{ background: `${color}18` }}>
                  {t.interest_level >= 0.8 ? "🔥" : t.interest_level >= 0.6 ? "⭐" : t.interest_level >= 0.4 ? "💡" : "💭"}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-0.5">
                    <p className="text-sm font-semibold text-white">{t.topic}</p>
                    <span className="text-[10px] font-mono px-1.5 py-0.5 rounded" style={{ background: `${color}18`, color }}>
                      {Math.round(t.interest_level * 100)}%
                    </span>
                    <span className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.2)" }}>{t.mention_count}x mencionado</span>
                  </div>
                  {t.notes && <p className="text-xs" style={{ color: "rgba(255,255,255,0.4)" }}>{t.notes}</p>}
                  <div className="mt-1.5 h-1 rounded-full" style={{ background: "rgba(255,255,255,0.06)" }}>
                    <div className="h-full rounded-full" style={{ width: `${t.interest_level * 100}%`, background: `linear-gradient(90deg, ${color}66, ${color})` }} />
                  </div>
                </div>
                <button onClick={() => handleDelete(t.id)} className="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" style={{ background: "rgba(239,68,68,0.08)" }}>
                  <Trash2 size={12} style={{ color: "rgba(239,68,68,0.5)" }} />
                </button>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ─── Página Principal ─────────────────────────────────────────────────────────
export default function AIConsciousnessPage() {
  const { canModerate } = useAuth();
  const [characters, setCharacters] = useState<AICharacterBasic[]>([]);
  const [selectedChar, setSelectedChar] = useState<string | null>(null);
  const [loadingChars, setLoadingChars] = useState(true);
  const [activeTab, setActiveTab] = useState<PageTab>("personality");
  const [stats, setStats] = useState<ConsciousnessStats | null>(null);

  const loadCharacters = useCallback(async () => {
    setLoadingChars(true);
    try {
      const { data, error } = await supabase.rpc("admin_get_ai_characters");
      if (error) throw error;
      const list = Array.isArray(data) ? data as AICharacterBasic[] : [];
      setCharacters(list);
      if (list.length > 0 && !selectedChar) setSelectedChar(list[0].id);
    } catch { toast.error("Erro ao carregar personagens"); }
    finally { setLoadingChars(false); }
  }, [selectedChar]);

  useEffect(() => { loadCharacters(); }, [loadCharacters]);

  useEffect(() => {
    if (!selectedChar) return;
    supabase.rpc("admin_get_consciousness_stats", { p_character_id: selectedChar })
      .then(({ data }) => { if (data) setStats(data as ConsciousnessStats); });
  }, [selectedChar, activeTab]);

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

  const selectedCharData = characters.find(c => c.id === selectedChar);
  const currentEmotion = stats?.current_emotion ?? "neutral";
  const emotionCfg = EMOTION_CONFIG[currentEmotion] ?? EMOTION_CONFIG.neutral;
  const EmotionIcon = emotionCfg.icon;

  const TABS: { id: PageTab; label: string; icon: React.ElementType; color: string }[] = [
    { id: "personality", label: "Personalidade",  icon: Brain,        color: "#8B5CF6" },
    { id: "emotions",    label: "Emoções",         icon: Heart,        color: "#EC4899" },
    { id: "episodes",    label: "Memórias",        icon: BookOpen,     color: "#60A5FA" },
    { id: "inner",       label: "Voz Interna",     icon: Feather,      color: "#A78BFA" },
    { id: "curiosity",   label: "Curiosidades",    icon: Lightbulb,    color: "#F59E0B" },
  ];

  return (
    <div className="p-5 md:p-7 max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <motion.div initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} className="flex items-center gap-4">
        <div className="w-11 h-11 rounded-2xl flex items-center justify-center flex-shrink-0" style={{ background: "rgba(139,92,246,0.12)", border: "1.5px solid rgba(139,92,246,0.3)" }}>
          <Sparkles size={20} style={{ color: "#8B5CF6" }} />
        </div>
        <div>
          <h1 className="text-[18px] font-bold text-white" style={{ fontFamily: "'Space Grotesk', sans-serif" }}>Consciência das IAs</h1>
          <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
            Personalidade evolutiva · Estado emocional · Memórias · Voz interna
          </p>
        </div>
      </motion.div>

      {/* Seletor de personagem */}
      {loadingChars ? (
        <div className="flex items-center justify-center h-16"><RefreshCw size={16} className="animate-spin" style={{ color: "rgba(255,255,255,0.2)" }} /></div>
      ) : (
        <div className="flex items-center gap-3 overflow-x-auto pb-1">
          {characters.map((c) => {
            const isSelected = selectedChar === c.id;
            return (
              <button
                key={c.id}
                onClick={() => setSelectedChar(c.id)}
                className="flex items-center gap-2.5 px-3.5 py-2.5 rounded-xl flex-shrink-0 transition-all"
                style={{
                  background: isSelected ? "rgba(139,92,246,0.15)" : "rgba(255,255,255,0.03)",
                  border: `1px solid ${isSelected ? "rgba(139,92,246,0.35)" : "rgba(255,255,255,0.07)"}`,
                }}
              >
                <div className="w-7 h-7 rounded-lg flex items-center justify-center overflow-hidden flex-shrink-0" style={{ background: "rgba(139,92,246,0.15)" }}>
                  {c.avatar_url ? <img src={c.avatar_url} alt="" className="w-full h-full object-cover" /> : <Bot size={13} style={{ color: "#8B5CF6" }} />}
                </div>
                <span className="text-xs font-medium" style={{ color: isSelected ? "#A78BFA" : "rgba(255,255,255,0.5)" }}>{c.name}</span>
              </button>
            );
          })}
        </div>
      )}

      {/* Stats do personagem selecionado */}
      {selectedCharData && stats && (
        <motion.div
          key={selectedChar}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-xl p-4"
          style={{ background: "rgba(255,255,255,0.03)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="flex items-center gap-4 flex-wrap">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl flex items-center justify-center overflow-hidden" style={{ background: "rgba(139,92,246,0.15)" }}>
                {selectedCharData.avatar_url ? <img src={selectedCharData.avatar_url} alt="" className="w-full h-full object-cover" /> : <Bot size={18} style={{ color: "#8B5CF6" }} />}
              </div>
              <div>
                <p className="text-sm font-bold text-white">{selectedCharData.name}</p>
                <div className="flex items-center gap-1.5 mt-0.5">
                  <EmotionIcon size={11} style={{ color: emotionCfg.color }} />
                  <p className="text-[10px] font-mono" style={{ color: emotionCfg.color }}>{emotionCfg.label}</p>
                </div>
              </div>
            </div>
            <div className="flex items-center gap-4 ml-auto flex-wrap">
              {[
                { label: "Interações", value: stats.total_interactions, color: "#8B5CF6" },
                { label: "Memórias", value: stats.episodic_memories, color: "#60A5FA" },
                { label: "Reflexões", value: stats.inner_voice_entries, color: "#A78BFA" },
                { label: "Curiosidades", value: stats.curiosity_topics, color: "#F59E0B" },
                { label: "Dias de vida", value: stats.personality_age_days, color: "#22C55E" },
              ].map((s) => (
                <div key={s.label} className="text-center">
                  <p className="text-lg font-bold" style={{ color: s.color }}>{s.value}</p>
                  <p className="text-[9px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.25)" }}>{s.label}</p>
                </div>
              ))}
            </div>
          </div>
        </motion.div>
      )}

      {/* Tabs */}
      {selectedChar && (
        <>
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

          <AnimatePresence mode="wait">
            <motion.div
              key={`${selectedChar}-${activeTab}`}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.15 }}
            >
              {activeTab === "personality" && <PersonalityTab characterId={selectedChar} />}
              {activeTab === "emotions"    && <EmotionsTab characterId={selectedChar} />}
              {activeTab === "episodes"    && <EpisodesTab characterId={selectedChar} />}
              {activeTab === "inner"       && <InnerVoiceTab characterId={selectedChar} />}
              {activeTab === "curiosity"   && <CuriosityTab characterId={selectedChar} />}
            </motion.div>
          </AnimatePresence>
        </>
      )}
    </div>
  );
}
