import { useState, useRef, useCallback, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase, StoreItem } from "@/lib/supabase";
import { toast } from "sonner";
import { Upload, Trash2, AlertCircle, CheckCircle2, Loader2, RefreshCw, Pencil } from "lucide-react";
import AdminLayout, { AdminSection } from "@/components/AdminLayout";
import OverviewPage from "./OverviewPage";
import StoreItemsPage from "./StoreItemsPage";
import FramesDashboard from "./FramesDashboard";
import ThemesDashboard from "./ThemesDashboard";
import StickersPage from "./StickersPage";
import UsersPage from "./UsersPage";
import TransactionsPage from "./TransactionsPage";
import SettingsPage from "./SettingsPage";
import ModerationPage from "./ModerationPage";
import CommunitiesPage from "./CommunitiesPage";
import AchievementsPage from "./AchievementsPage";
import BroadcastPage from "./BroadcastPage";

// ─── Tipos ────────────────────────────────────────────────────────────────────
type BubbleForm = {
  name: string; description: string; priceCoins: number;
  rarity: "common" | "rare" | "epic" | "legendary";
  isActive: boolean; isAnimated: boolean;
  sliceTop: number; sliceLeft: number; sliceRight: number; sliceBottom: number;
  textColor: string;
};

function detectBubbleIsAnimated(file: File): boolean {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  if (file.type === "image/gif" || ext === "gif") return true;
  if (ext === "apng") return true;
  return false;
}

const RARITY_COLORS: Record<string, { color: string; rgb: string }> = {
  common:    { color: "#94A3B8", rgb: "148,163,184" },
  rare:      { color: "#60A5FA", rgb: "96,165,250" },
  epic:      { color: "#A78BFA", rgb: "167,139,250" },
  legendary: { color: "#FBBF24", rgb: "251,191,36" },
};

const RARITY_LABELS: Record<string, string> = {
  common: "Comum", rare: "Raro", epic: "Épico", legendary: "Lendário",
};

const fadeUp = {
  hidden: { opacity: 0, y: 10 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

// ─── Chat Preview ─────────────────────────────────────────────────────────────
function ChatPreview({ imageUrl, name }: { imageUrl: string | null; name: string }) {
  const messages = [
    { id: 1, mine: false, text: "Que bubble incrível 👀" },
    { id: 2, mine: true, text: name || "Novo bubble" },
    { id: 3, mine: false, text: "Adorei! Quanto custa?" },
    { id: 4, mine: true, text: "Tá na loja! 🎉" },
  ];
  return (
    <div className="flex flex-col gap-2 p-4">
      {messages.map((msg) => (
        <div key={msg.id} className={`flex ${msg.mine ? "justify-end" : "justify-start"}`}>
          {imageUrl ? (
            <div
              className="relative max-w-[180px] px-4 py-2.5 text-[13px]"
              style={{
                backgroundImage: `url(${imageUrl})`,
                backgroundRepeat: "no-repeat",
                backgroundSize: "100% 100%",
                borderImageSource: `url(${imageUrl})`,
                borderImageSlice: "38 fill",
                borderImageWidth: "38px",
                borderImageRepeat: "stretch",
                minHeight: "40px",
                color: "rgba(255,255,255,0.9)",
                fontFamily: "'Space Grotesk', sans-serif",
              }}
            >
              {msg.text}
            </div>
          ) : (
            <div
              className="max-w-[180px] px-3.5 py-2 rounded-2xl text-[13px]"
              style={{
                background: msg.mine ? "rgba(124,58,237,0.4)" : "rgba(255,255,255,0.07)",
                color: "rgba(255,255,255,0.85)",
                fontFamily: "'Space Grotesk', sans-serif",
              }}
            >
              {msg.text}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

// ─── Bubbles Dashboard ────────────────────────────────────────────────────────
function BubblesDashboard() {
  const [bubbles, setBubbles] = useState<StoreItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editingBubble, setEditingBubble] = useState<StoreItem | null>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageDimensions, setImageDimensions] = useState<{ w: number; h: number } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [form, setForm] = useState<BubbleForm>({
    name: "", description: "", priceCoins: 150, rarity: "common",
    isActive: true, isAnimated: false,
    sliceTop: 38, sliceLeft: 38, sliceRight: 38, sliceBottom: 38, textColor: "",
  });

  async function loadBubbles() {
    setLoading(true);
    const { data, error } = await supabase
      .from("store_items").select("*").eq("type", "chat_bubble").order("created_at", { ascending: false });
    if (!error && data) setBubbles(data as StoreItem[]);
    setLoading(false);
  }

  useEffect(() => { loadBubbles(); }, []);

  const handleFile = useCallback((file: File) => {
    if (!file.type.startsWith("image/")) { toast.error("Selecione uma imagem."); return; }
    setImageFile(file);
    const url = URL.createObjectURL(file);
    setImagePreview(url);
    const img = new Image();
    img.onload = () => setImageDimensions({ w: img.naturalWidth, h: img.naturalHeight });
    img.src = url;
    const isAnim = detectBubbleIsAnimated(file);
    setForm(f => ({ ...f, isAnimated: isAnim }));
  }, []);

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault(); setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, [handleFile]);

  function openEdit(item: StoreItem) {
    const cfg = (item.asset_config as Record<string, unknown>) ?? {};
    setEditingBubble(item);
    setForm({
      name: item.name, description: item.description ?? "",
      priceCoins: item.price_coins, rarity: (cfg.rarity as BubbleForm["rarity"]) ?? "common",
      isActive: item.is_active, isAnimated: (cfg.is_animated as boolean) ?? false,
      sliceTop: (cfg.slice_top as number) ?? 38, sliceLeft: (cfg.slice_left as number) ?? 38,
      sliceRight: (cfg.slice_right as number) ?? 38, sliceBottom: (cfg.slice_bottom as number) ?? 38,
      textColor: (cfg.text_color as string) ?? "",
    });
    setImagePreview(item.preview_url);
    setShowForm(true);
  }

  function cancelEdit() {
    setEditingBubble(null); setShowForm(false);
    setForm({ name: "", description: "", priceCoins: 150, rarity: "common", isActive: true, isAnimated: false, sliceTop: 38, sliceLeft: 38, sliceRight: 38, sliceBottom: 38, textColor: "" });
    setImageFile(null); setImagePreview(null); setImageDimensions(null);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!editingBubble && !imageFile) { toast.error("Selecione uma imagem para o bubble."); return; }
    if (!form.name.trim()) { toast.error("Defina um nome para o bubble."); return; }
    setSubmitting(true);
    try {
      let publicUrl = editingBubble?.preview_url ?? null;
      if (imageFile) {
        const ext = imageFile.name.split(".").pop() ?? "png";
        const slug = form.name.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
        const path = `bubbles/${slug}_${Date.now()}.${ext}`;
        const { error: uploadError } = await supabase.storage.from("store-assets").upload(path, imageFile, { contentType: imageFile.type, upsert: false });
        if (uploadError) throw new Error(`Upload falhou: ${uploadError.message}`);
        const { data: urlData } = supabase.storage.from("store-assets").getPublicUrl(path);
        publicUrl = urlData.publicUrl;
      }
      const imgW = imageDimensions?.w ?? 128;
      const imgH = imageDimensions?.h ?? 128;
      const assetConfig = form.isAnimated
        ? { image_url: publicUrl, bubble_url: publicUrl, bubble_style: "animated", image_width: imgW, image_height: imgH, content_padding_h: 20, content_padding_v: 14, is_animated: true, rarity: form.rarity, ...(form.textColor.trim() ? { text_color: form.textColor.trim() } : {}) }
        : { image_url: publicUrl, bubble_url: publicUrl, bubble_style: "nine_slice", image_width: imgW, image_height: imgH, slice_top: form.sliceTop, slice_left: form.sliceLeft, slice_right: form.sliceRight, slice_bottom: form.sliceBottom, content_padding_h: 20, content_padding_v: 14, is_animated: false, rarity: form.rarity, ...(form.textColor.trim() ? { text_color: form.textColor.trim() } : {}) };
      const payload = { type: "chat_bubble", name: form.name.trim(), description: form.description.trim() || null, preview_url: publicUrl, asset_url: publicUrl, asset_config: assetConfig, price_coins: form.priceCoins, price_real_cents: 0, is_premium_only: false, is_limited_edition: false, is_active: form.isActive, sort_order: 0 };
      if (editingBubble) {
        const { error } = await supabase.from("store_items").update(payload).eq("id", editingBubble.id);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" atualizado!`);
      } else {
        const { error } = await supabase.from("store_items").insert(payload);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" publicado na loja! 🎉`);
      }
      cancelEdit(); loadBubbles();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : String(err));
    } finally { setSubmitting(false); }
  }

  async function toggleActive(item: StoreItem) {
    const { error } = await supabase.from("store_items").update({ is_active: !item.is_active }).eq("id", item.id);
    if (error) { toast.error("Erro ao atualizar status."); return; }
    setBubbles(prev => prev.map(b => b.id === item.id ? { ...b, is_active: !b.is_active } : b));
    toast.success(`"${item.name}" ${!item.is_active ? "ativado" : "desativado"}.`);
  }

  async function deleteBubble(item: StoreItem) {
    if (!confirm(`Deletar "${item.name}"? Esta ação não pode ser desfeita.`)) return;
    const { error } = await supabase.from("store_items").delete().eq("id", item.id);
    if (error) { toast.error("Erro ao deletar."); return; }
    setBubbles(prev => prev.filter(b => b.id !== item.id));
    toast.success(`"${item.name}" removido da loja.`);
  }

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">
      {/* Header */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0} className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
            Chat Bubbles
          </h1>
          <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
            {bubbles.length} bubble{bubbles.length !== 1 ? "s" : ""} cadastrado{bubbles.length !== 1 ? "s" : ""}
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={loadBubbles} className="w-8 h-8 rounded-xl flex items-center justify-center transition-all duration-150"
            style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
            <RefreshCw size={13} />
          </button>
          <button onClick={() => { cancelEdit(); setShowForm(true); }}
            className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold transition-all duration-150"
            style={{ background: "linear-gradient(135deg, rgba(124,58,237,0.8), rgba(236,72,153,0.6))", color: "white", fontFamily: "'Space Grotesk', sans-serif", boxShadow: "0 0 20px rgba(124,58,237,0.3)" }}>
            + Novo Bubble
          </button>
        </div>
      </motion.div>

      {/* Form Modal */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
            style={{ background: "rgba(0,0,0,0.7)", backdropFilter: "blur(8px)" }}
            onClick={(e) => e.target === e.currentTarget && cancelEdit()}
          >
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-2xl"
              style={{ background: "rgba(13,17,23,0.95)", border: "1px solid rgba(255,255,255,0.1)", boxShadow: "0 40px 120px rgba(0,0,0,0.8)" }}
            >
              <div className="p-5 md:p-6">
                <div className="flex items-center justify-between mb-5">
                  <h2 className="text-[16px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
                    {editingBubble ? `Editar: ${editingBubble.name}` : "Novo Chat Bubble"}
                  </h2>
                  <button onClick={cancelEdit} className="w-7 h-7 rounded-lg flex items-center justify-center text-[18px] transition-all duration-150"
                    style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}>×</button>
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                  {/* Upload */}
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-2" style={{ color: "rgba(255,255,255,0.3)" }}>Imagem</label>
                    <div
                      onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
                      onDragLeave={() => setIsDragging(false)}
                      onDrop={onDrop}
                      onClick={() => fileInputRef.current?.click()}
                      className="cursor-pointer rounded-xl transition-all duration-200"
                      style={{ border: `1px dashed ${isDragging ? "rgba(124,58,237,0.6)" : "rgba(255,255,255,0.1)"}`, background: isDragging ? "rgba(124,58,237,0.05)" : "rgba(255,255,255,0.02)" }}
                    >
                      {imagePreview ? (
                        <div className="flex items-center gap-4 p-4">
                          <div className="w-16 h-16 rounded-xl overflow-hidden flex-shrink-0" style={{ background: "rgba(255,255,255,0.05)" }}>
                            <img src={imagePreview} alt="preview" className="w-full h-full object-contain" />
                          </div>
                          <div>
                            <p className="text-[12px] font-semibold" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              {imageFile?.name ?? "Imagem atual"}
                            </p>
                            {imageDimensions && (
                              <p className="text-[11px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{imageDimensions.w}×{imageDimensions.h}px</p>
                            )}
                            <p className="text-[10px] font-mono mt-1" style={{ color: "rgba(124,58,237,0.7)" }}>Clique para trocar</p>
                          </div>
                        </div>
                      ) : (
                        <div className="py-8 text-center">
                          <Upload size={20} className="mx-auto mb-2" style={{ color: "rgba(255,255,255,0.2)" }} />
                          <p className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Arraste ou clique para selecionar</p>
                          <p className="text-[10px] font-mono mt-1" style={{ color: "rgba(255,255,255,0.15)" }}>PNG · GIF · WebP · APNG</p>
                        </div>
                      )}
                    </div>
                    <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); }} />
                  </div>

                  {/* Nome + Descrição */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Nome *</label>
                      <input value={form.name} onChange={(e) => setForm(f => ({ ...f, name: e.target.value }))} required placeholder="Ex: Bubble Neon"
                        className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.85)", fontFamily: "'Space Grotesk', sans-serif" }} />
                    </div>
                    <div>
                      <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Preço (coins)</label>
                      <input type="number" min={0} value={form.priceCoins} onChange={(e) => setForm(f => ({ ...f, priceCoins: parseInt(e.target.value) || 0 }))}
                        className="w-full px-3 py-2 rounded-xl text-[13px] outline-none font-mono"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "#F59E0B" }} />
                    </div>
                  </div>

                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Descrição</label>
                    <input value={form.description} onChange={(e) => setForm(f => ({ ...f, description: e.target.value }))} placeholder="Descrição opcional"
                      className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.7)", fontFamily: "'Space Grotesk', sans-serif" }} />
                  </div>

                  {/* Raridade */}
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Raridade</label>
                    <select value={form.rarity} onChange={(e) => setForm(f => ({ ...f, rarity: e.target.value as BubbleForm["rarity"] }))}
                      className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: RARITY_COLORS[form.rarity]?.color ?? "white", fontFamily: "'Space Mono', monospace" }}>
                      {Object.entries(RARITY_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                    </select>
                  </div>

                  {/* Cor do texto */}
                  <div>
                    <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Cor do Texto do Balão</label>
                    <div className="flex items-center gap-2">
                      <input type="color" value={form.textColor || "#FFFFFF"} onChange={(e) => setForm(f => ({ ...f, textColor: e.target.value }))}
                        className="w-9 h-9 rounded-xl cursor-pointer flex-shrink-0 p-0.5"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.1)" }} />
                      <input value={form.textColor} onChange={(e) => setForm(f => ({ ...f, textColor: e.target.value }))} placeholder="#FFFFFF (vazio = padrão do app)"
                        className="flex-1 px-3 py-2 rounded-xl text-[13px] outline-none font-mono"
                        style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.7)" }} />
                      {form.textColor && (
                        <button type="button" onClick={() => setForm(f => ({ ...f, textColor: "" }))}
                          className="px-2 py-1.5 rounded-lg text-[10px] font-mono transition-all"
                          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.4)" }}>
                          Limpar
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Nine-slice borders (only for static) */}
                  {!form.isAnimated && (
                    <div>
                      <label className="text-[10px] font-mono tracking-widest uppercase block mb-1.5" style={{ color: "rgba(255,255,255,0.3)" }}>Bordas Nine-Slice (px)</label>
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                        {[["Topo", "sliceTop"], ["Base", "sliceBottom"], ["Esq.", "sliceLeft"], ["Dir.", "sliceRight"]].map(([label, key]) => (
                          <div key={key}>
                            <label className="text-[9px] font-mono block mb-1" style={{ color: "rgba(255,255,255,0.25)" }}>{label}</label>
                            <input type="number" min={0} value={(form as any)[key]}
                              onChange={(e) => setForm(f => ({ ...f, [key]: parseInt(e.target.value) || 0 }))}
                              className="w-full px-2 py-1.5 rounded-lg text-[12px] outline-none font-mono text-center"
                              style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.7)" }} />
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Toggles */}
                  <div className="flex flex-col sm:flex-row gap-3">
                    {[
                      { label: "Bubble Animado (GIF/APNG)", key: "isAnimated", color: "#A78BFA" },
                      { label: "Ativo na Loja", key: "isActive", color: "#34D399" },
                    ].map(({ label, key, color }) => (
                      <label key={key} className="flex items-center gap-3 cursor-pointer flex-1 p-3 rounded-xl"
                        style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.06)" }}>
                        <div
                          onClick={() => setForm(f => ({ ...f, [key]: !(f as any)[key] }))}
                          className="w-9 h-5 rounded-full relative transition-all duration-200 flex-shrink-0"
                          style={{ background: (form as any)[key] ? color : "rgba(255,255,255,0.1)", cursor: "pointer" }}
                        >
                          <div className="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-all duration-200"
                            style={{ left: (form as any)[key] ? "18px" : "2px" }} />
                        </div>
                        <span className="text-[12px] font-mono" style={{ color: "rgba(255,255,255,0.5)" }}>{label}</span>
                      </label>
                    ))}
                  </div>

                  {/* Actions */}
                  <div className="flex gap-3 pt-1">
                    <button type="button" onClick={cancelEdit}
                      className="flex-1 py-2.5 rounded-xl text-[13px] font-semibold transition-all duration-150"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}>
                      Cancelar
                    </button>
                    <button type="submit" disabled={submitting}
                      className="flex-1 py-2.5 rounded-xl text-[13px] font-bold flex items-center justify-center gap-2 transition-all duration-150"
                      style={{ background: submitting ? "rgba(124,58,237,0.4)" : "linear-gradient(135deg, #7C3AED, #EC4899)", color: "white", fontFamily: "'Space Grotesk', sans-serif", boxShadow: submitting ? "none" : "0 0 20px rgba(124,58,237,0.3)" }}>
                      {submitting ? <Loader2 size={13} className="animate-spin" /> : null}
                      {submitting ? "Salvando..." : editingBubble ? "Salvar" : "Publicar"}
                    </button>
                  </div>
                </form>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Bubbles Grid */}
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[...Array(6)].map((_, i) => <div key={i} className="h-52 rounded-2xl nx-shimmer" style={{ background: "rgba(255,255,255,0.03)" }} />)}
        </div>
      ) : bubbles.length === 0 ? (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1}
          className="py-16 text-center rounded-2xl"
          style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}
        >
          <div className="text-3xl mb-3">💬</div>
          <p className="text-[13px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Nenhum bubble cadastrado ainda</p>
          <button onClick={() => setShowForm(true)} className="mt-4 px-4 py-2 rounded-xl text-[12px] font-semibold"
            style={{ background: "rgba(124,58,237,0.1)", border: "1px solid rgba(124,58,237,0.2)", color: "#A78BFA", fontFamily: "'Space Grotesk', sans-serif" }}>
            Criar primeiro bubble
          </button>
        </motion.div>
      ) : (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {bubbles.map((bubble, i) => {
            const rarity = (bubble.asset_config as Record<string, string>)?.rarity ?? "common";
            const rc = RARITY_COLORS[rarity] ?? RARITY_COLORS.common;
            return (
              <motion.div key={bubble.id} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.04 }}
                className="rounded-2xl overflow-hidden"
                style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
              >
                {/* Preview */}
                <div className="relative" style={{ background: "rgba(0,0,0,0.3)", borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
                  <ChatPreview imageUrl={bubble.preview_url} name={bubble.name} />
                  <div className="absolute top-2 right-2">
                    <span className="text-[9px] font-mono px-2 py-0.5 rounded-full"
                      style={{ background: `rgba(${rc.rgb},0.12)`, color: rc.color, border: `1px solid rgba(${rc.rgb},0.25)` }}>
                      {RARITY_LABELS[rarity] ?? rarity}
                    </span>
                  </div>
                </div>
                {/* Info */}
                <div className="p-3">
                  <div className="flex items-start justify-between gap-2 mb-2">
                    <div className="min-w-0">
                      <h3 className="text-[13px] font-semibold truncate" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.9)" }}>{bubble.name}</h3>
                      {bubble.description && <p className="text-[11px] font-mono truncate mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>{bubble.description}</p>}
                    </div>
                    <span className="text-[12px] font-mono font-bold flex-shrink-0" style={{ color: "#F59E0B" }}>{bubble.price_coins} ✦</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <button onClick={() => toggleActive(bubble)}
                      className="flex items-center gap-1 text-[10px] font-mono px-2 py-1 rounded-lg transition-all duration-150"
                      style={{ background: bubble.is_active ? "rgba(52,211,153,0.1)" : "rgba(239,68,68,0.1)", color: bubble.is_active ? "#34D399" : "#FCA5A5", border: `1px solid ${bubble.is_active ? "rgba(52,211,153,0.2)" : "rgba(239,68,68,0.2)"}` }}>
                      {bubble.is_active ? <CheckCircle2 size={9} /> : <AlertCircle size={9} />}
                      {bubble.is_active ? "Ativo" : "Inativo"}
                    </button>
                    <div className="flex gap-1">
                      <button onClick={() => openEdit(bubble)} className="w-7 h-7 rounded-lg flex items-center justify-center transition-all duration-150"
                        style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.3)" }}
                        onMouseEnter={e => { e.currentTarget.style.background = "rgba(124,58,237,0.15)"; e.currentTarget.style.color = "#A78BFA"; }}
                        onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; e.currentTarget.style.color = "rgba(255,255,255,0.3)"; }}>
                        <Pencil size={11} />
                      </button>
                      <button onClick={() => deleteBubble(bubble)} className="w-7 h-7 rounded-lg flex items-center justify-center transition-all duration-150"
                        style={{ background: "rgba(255,255,255,0.04)", color: "rgba(255,255,255,0.3)" }}
                        onMouseEnter={e => { e.currentTarget.style.background = "rgba(239,68,68,0.15)"; e.currentTarget.style.color = "#FCA5A5"; }}
                        onMouseLeave={e => { e.currentTarget.style.background = "rgba(255,255,255,0.04)"; e.currentTarget.style.color = "rgba(255,255,255,0.3)"; }}>
                        <Trash2 size={11} />
                      </button>
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </motion.div>
      )}
    </div>
  );
}

// ─── Dashboard Principal ──────────────────────────────────────────────────────
export default function Dashboard() {
  const [activeSection, setActiveSection] = useState<AdminSection>("overview");

  function renderSection() {
    switch (activeSection) {
      case "overview":       return <OverviewPage />;
      case "store-items":    return <StoreItemsPage />;
      case "bubbles":        return <BubblesDashboard />;
      case "frames":         return <FramesDashboard />;
      case "stickers":       return <StickersPage />;
      case "themes":         return <ThemesDashboard />;
      case "users":          return <UsersPage />;
      case "moderation":     return <ModerationPage />;
      case "communities":    return <CommunitiesPage />;
      case "achievements":   return <AchievementsPage />;
      case "broadcast":      return <BroadcastPage />;
      case "transactions":   return <TransactionsPage />;
      case "settings":       return <SettingsPage />;
      default:               return <OverviewPage />;
    }
  }

  return (
    <AdminLayout activeSection={activeSection} onSectionChange={setActiveSection}>
      {renderSection()}
    </AdminLayout>
  );
}
