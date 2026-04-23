import { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { supabase, StoreItem, StoreItemType, Rarity } from "@/lib/supabase";
import { toast } from "sonner";
import {
  Plus, Trash2, Pencil, CheckCircle2, AlertCircle, Loader2,
  Search, Upload, X, Save, ShoppingBag, Star, Zap, Package,
  Eye, EyeOff
} from "lucide-react";

const TYPE_LABELS: Record<StoreItemType, string> = {
  avatar_frame: "Moldura",
  chat_bubble: "Chat Bubble",
  sticker_pack: "Stickers",
  profile_background: "Fundo Perfil",
  chat_background: "Fundo Chat",
};

const TYPE_COLORS: Record<StoreItemType, { hex: string; rgb: string }> = {
  avatar_frame: { hex: "#F59E0B", rgb: "245,158,11" },
  chat_bubble: { hex: "#A78BFA", rgb: "167,139,250" },
  sticker_pack: { hex: "#10B981", rgb: "16,185,129" },
  profile_background: { hex: "#EC4899", rgb: "236,72,153" },
  chat_background: { hex: "#06B6D4", rgb: "6,182,212" },
};

const RARITY_CONFIG: Record<Rarity, { label: string; color: string; rgb: string; glow: string }> = {
  common:    { label: "Comum",    color: "#94A3B8", rgb: "148,163,184", glow: "rgba(148,163,184,0.2)" },
  rare:      { label: "Raro",     color: "#60A5FA", rgb: "96,165,250",  glow: "rgba(96,165,250,0.25)" },
  epic:      { label: "Épico",    color: "#A78BFA", rgb: "167,139,250", glow: "rgba(167,139,250,0.3)" },
  legendary: { label: "Lendário", color: "#FBBF24", rgb: "251,191,36",  glow: "rgba(251,191,36,0.35)" },
};

type ItemForm = {
  name: string; description: string; type: StoreItemType;
  price_coins: number; price_real_cents: number | null;
  is_premium_only: boolean; is_limited_edition: boolean;
  is_active: boolean; sort_order: number; rarity: Rarity; tags: string;
};

const DEFAULT_FORM: ItemForm = {
  name: "", description: "", type: "chat_bubble", price_coins: 150,
  price_real_cents: null, is_premium_only: false, is_limited_edition: false,
  is_active: true, sort_order: 0, rarity: "common", tags: "",
};

const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: (i: number) => ({ opacity: 1, y: 0, transition: { delay: i * 0.04, duration: 0.25, ease: "easeOut" } }),
};

export default function StoreItemsPage() {
  const [items, setItems] = useState<StoreItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [filterType, setFilterType] = useState<StoreItemType | "all">("all");
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "inactive">("all");
  const [showForm, setShowForm] = useState(false);
  const [editingItem, setEditingItem] = useState<StoreItem | null>(null);
  const [form, setForm] = useState<ItemForm>(DEFAULT_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [assetFile, setAssetFile] = useState<File | null>(null);
  const [assetUrl, setAssetUrl] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const previewInputRef = useRef<HTMLInputElement>(null);
  const assetInputRef = useRef<HTMLInputElement>(null);

  async function loadItems() {
    setLoading(true);
    const { data, error } = await supabase.from("store_items").select("*").order("sort_order", { ascending: true });
    if (!error && data) setItems(data as StoreItem[]);
    setLoading(false);
  }

  useEffect(() => { loadItems(); }, []);

  function openCreate() {
    setEditingItem(null); setForm(DEFAULT_FORM);
    setPreviewFile(null); setPreviewUrl(null);
    setAssetFile(null); setAssetUrl(null); setShowForm(true);
  }

  function openEdit(item: StoreItem) {
    setEditingItem(item);
    setForm({
      name: item.name, description: item.description ?? "", type: item.type,
      price_coins: item.price_coins, price_real_cents: item.price_real_cents,
      is_premium_only: item.is_premium_only, is_limited_edition: item.is_limited_edition,
      is_active: item.is_active, sort_order: item.sort_order,
      rarity: item.rarity ?? "common", tags: (item.tags ?? []).join(", "),
    });
    setPreviewUrl(item.preview_url); setAssetUrl(item.asset_url);
    setPreviewFile(null); setAssetFile(null); setShowForm(true);
  }

  function closeForm() { setShowForm(false); setEditingItem(null); }

  async function uploadFile(file: File, path: string): Promise<string | null> {
    const { data, error } = await supabase.storage.from("store-assets").upload(path, file, { upsert: true });
    if (error) { toast.error(`Erro no upload: ${error.message}`); return null; }
    const { data: urlData } = supabase.storage.from("store-assets").getPublicUrl(data.path);
    return urlData.publicUrl;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim()) { toast.error("Nome é obrigatório."); return; }
    setSubmitting(true);
    try {
      let finalPreviewUrl = previewUrl;
      let finalAssetUrl = assetUrl;
      if (previewFile) {
        const ext = previewFile.name.split(".").pop();
        finalPreviewUrl = await uploadFile(previewFile, `previews/${Date.now()}_${form.name.replace(/\s+/g, "_")}.${ext}`);
        if (!finalPreviewUrl) return;
      }
      if (assetFile) {
        const ext = assetFile.name.split(".").pop();
        finalAssetUrl = await uploadFile(assetFile, `assets/${form.type}/${Date.now()}_${form.name.replace(/\s+/g, "_")}.${ext}`);
        if (!finalAssetUrl) return;
      }
      const payload = {
        name: form.name.trim(), description: form.description.trim(), type: form.type,
        price_coins: form.price_coins, price_real_cents: form.price_real_cents,
        is_premium_only: form.is_premium_only, is_limited_edition: form.is_limited_edition,
        is_active: form.is_active, sort_order: form.sort_order, rarity: form.rarity,
        tags: form.tags.split(",").map((t) => t.trim()).filter(Boolean),
        preview_url: finalPreviewUrl, asset_url: finalAssetUrl,
      };
      if (editingItem) {
        const { error } = await supabase.from("store_items").update(payload).eq("id", editingItem.id);
        if (error) throw error;
        toast.success("Item atualizado!");
      } else {
        const { error } = await supabase.from("store_items").insert(payload);
        if (error) throw error;
        toast.success("Item criado!");
      }
      closeForm(); loadItems();
    } catch (err: unknown) {
      toast.error(`Erro: ${err instanceof Error ? err.message : String(err)}`);
    } finally { setSubmitting(false); }
  }

  async function toggleActive(item: StoreItem) {
    const { error } = await supabase.from("store_items").update({ is_active: !item.is_active }).eq("id", item.id);
    if (error) toast.error("Erro ao alterar status.");
    else { toast.success(item.is_active ? "Item desativado." : "Item ativado!"); loadItems(); }
  }

  async function deleteItem(item: StoreItem) {
    if (!confirm(`Excluir "${item.name}"?`)) return;
    setDeletingId(item.id);
    const { error } = await supabase.from("store_items").delete().eq("id", item.id);
    if (error) toast.error("Erro ao excluir.");
    else { toast.success("Item excluído."); loadItems(); }
    setDeletingId(null);
  }

  function handleFileChange(file: File, type: "preview" | "asset") {
    if (!file.type.startsWith("image/")) { toast.error("Envie uma imagem válida."); return; }
    const reader = new FileReader();
    reader.onload = (e) => {
      if (type === "preview") { setPreviewFile(file); setPreviewUrl(e.target?.result as string); }
      else { setAssetFile(file); setAssetUrl(e.target?.result as string); }
    };
    reader.readAsDataURL(file);
  }

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault(); setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFileChange(file, "preview");
  }, []);

  const filtered = items.filter((item) => {
    const matchSearch = !search || item.name.toLowerCase().includes(search.toLowerCase()) || (item.description ?? "").toLowerCase().includes(search.toLowerCase());
    const matchType = filterType === "all" || item.type === filterType;
    const matchStatus = filterStatus === "all" || (filterStatus === "active" && item.is_active) || (filterStatus === "inactive" && !item.is_active);
    return matchSearch && matchType && matchStatus;
  });

  const activeCount = items.filter(i => i.is_active).length;

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto space-y-5">

      {/* Header */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={0} className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-[20px] font-bold tracking-tight" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
            Produtos da Loja
          </h1>
          <p className="text-[12px] font-mono mt-0.5" style={{ color: "rgba(255,255,255,0.3)" }}>
            {activeCount} ativos · {items.length} total
          </p>
        </div>
        <motion.button
          onClick={openCreate}
          whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.97 }}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-[13px] font-semibold"
          style={{
            background: "linear-gradient(135deg, #7C3AED, #EC4899)",
            boxShadow: "0 0 20px rgba(124,58,237,0.35)",
            color: "white",
            fontFamily: "'Space Grotesk', sans-serif",
          }}
        >
          <Plus size={14} />
          Novo Item
        </motion.button>
      </motion.div>

      {/* Filters */}
      <motion.div variants={fadeUp} initial="hidden" animate="show" custom={1} className="flex flex-col sm:flex-row gap-2">
        <div className="relative flex-1 min-w-0">
          <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "rgba(255,255,255,0.25)" }} />
          <input
            placeholder="Buscar por nome..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-3 py-2 rounded-xl text-[13px] outline-none transition-all duration-150"
            style={{
              background: "rgba(255,255,255,0.04)",
              border: "1px solid rgba(255,255,255,0.08)",
              color: "rgba(255,255,255,0.85)",
              fontFamily: "'Space Grotesk', sans-serif",
            }}
          />
        </div>
        <select
          value={filterType}
          onChange={(e) => setFilterType(e.target.value as StoreItemType | "all")}
          className="px-3 py-2 rounded-xl text-[12px] outline-none"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)", fontFamily: "'Space Mono', monospace" }}
        >
          <option value="all">Todos os tipos</option>
          {Object.entries(TYPE_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
        <select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value as "all" | "active" | "inactive")}
          className="px-3 py-2 rounded-xl text-[12px] outline-none"
          style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)", fontFamily: "'Space Mono', monospace" }}
        >
          <option value="all">Todos os status</option>
          <option value="active">Ativos</option>
          <option value="inactive">Inativos</option>
        </select>
      </motion.div>

      {/* Content */}
      {loading ? (
        <div className="space-y-2">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="h-16 rounded-xl nx-shimmer" style={{ background: "rgba(255,255,255,0.03)" }} />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2}
          className="flex flex-col items-center justify-center py-20 rounded-2xl"
          style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.08)" }}
        >
          <ShoppingBag size={32} style={{ color: "rgba(255,255,255,0.15)" }} />
          <p className="mt-3 text-[13px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>Nenhum item encontrado</p>
        </motion.div>
      ) : (
        <motion.div variants={fadeUp} initial="hidden" animate="show" custom={2} className="rounded-2xl overflow-hidden"
          style={{ background: "rgba(255,255,255,0.025)", border: "1px solid rgba(255,255,255,0.07)" }}
        >
          <div className="overflow-x-auto">
            <table className="w-full nx-table">
              <thead>
                <tr>
                  <th className="text-left">Item</th>
                  <th className="text-left hidden sm:table-cell">Tipo</th>
                  <th className="text-left hidden md:table-cell">Raridade</th>
                  <th className="text-right">Preço</th>
                  <th className="text-center">Status</th>
                  <th className="text-right">Ações</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((item, i) => {
                  const tc = TYPE_COLORS[item.type];
                  const rc = RARITY_CONFIG[item.rarity ?? "common"];
                  return (
                    <motion.tr
                      key={item.id}
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: i * 0.03 }}
                      className="group"
                    >
                      <td>
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl overflow-hidden flex-shrink-0 flex items-center justify-center"
                            style={{ background: `rgba(${tc.rgb},0.1)`, border: `1px solid rgba(${tc.rgb},0.2)` }}
                          >
                            {item.preview_url ? (
                              <img src={item.preview_url} alt={item.name} className="w-full h-full object-cover" />
                            ) : (
                              <Package size={14} style={{ color: tc.hex }} />
                            )}
                          </div>
                          <div>
                            <div className="text-[13px] font-semibold" style={{ color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}>
                              {item.name}
                            </div>
                            {item.description && (
                              <div className="text-[11px] font-mono truncate max-w-[180px]" style={{ color: "rgba(255,255,255,0.3)" }}>
                                {item.description}
                              </div>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="hidden sm:table-cell">
                        <span className="nx-badge" style={{ background: `rgba(${tc.rgb},0.1)`, color: tc.hex, border: `1px solid rgba(${tc.rgb},0.2)` }}>
                          {TYPE_LABELS[item.type]}
                        </span>
                      </td>
                      <td className="hidden md:table-cell">
                        <span className="nx-badge" style={{ background: `rgba(${rc.rgb},0.1)`, color: rc.color, border: `1px solid rgba(${rc.rgb},0.2)` }}>
                          {item.rarity === "legendary" && <Star size={9} fill="currentColor" />}
                          {rc.label}
                        </span>
                      </td>
                      <td className="text-right">
                        <div className="text-[13px] font-mono font-bold" style={{ color: "#F59E0B" }}>
                          {item.price_coins.toLocaleString()} ✦
                        </div>
                        {item.price_real_cents && (
                          <div className="text-[10px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>
                            R$ {(item.price_real_cents / 100).toFixed(2)}
                          </div>
                        )}
                      </td>
                      <td className="text-center">
                        <button
                          onClick={() => toggleActive(item)}
                          className="inline-flex items-center gap-1.5 text-[11px] font-mono px-2.5 py-1 rounded-lg transition-all duration-150"
                          style={{
                            background: item.is_active ? "rgba(16,185,129,0.1)" : "rgba(239,68,68,0.1)",
                            color: item.is_active ? "#34D399" : "#FCA5A5",
                            border: `1px solid ${item.is_active ? "rgba(16,185,129,0.2)" : "rgba(239,68,68,0.2)"}`,
                          }}
                        >
                          {item.is_active ? <Eye size={10} /> : <EyeOff size={10} />}
                          {item.is_active ? "Ativo" : "Inativo"}
                        </button>
                      </td>
                      <td>
                        <div className="flex items-center justify-end gap-1">
                          <button
                            onClick={() => openEdit(item)}
                            className="w-7 h-7 rounded-lg flex items-center justify-center transition-all duration-150"
                            style={{ color: "rgba(255,255,255,0.3)" }}
                            onMouseEnter={e => (e.currentTarget.style.background = "rgba(167,139,250,0.1)", e.currentTarget.style.color = "#A78BFA")}
                            onMouseLeave={e => (e.currentTarget.style.background = "transparent", e.currentTarget.style.color = "rgba(255,255,255,0.3)")}
                          >
                            <Pencil size={13} />
                          </button>
                          <button
                            onClick={() => deleteItem(item)}
                            disabled={deletingId === item.id}
                            className="w-7 h-7 rounded-lg flex items-center justify-center transition-all duration-150"
                            style={{ color: "rgba(255,255,255,0.3)" }}
                            onMouseEnter={e => (e.currentTarget.style.background = "rgba(239,68,68,0.1)", e.currentTarget.style.color = "#FCA5A5")}
                            onMouseLeave={e => (e.currentTarget.style.background = "transparent", e.currentTarget.style.color = "rgba(255,255,255,0.3)")}
                          >
                            {deletingId === item.id ? <Loader2 size={13} className="animate-spin" /> : <Trash2 size={13} />}
                          </button>
                        </div>
                      </td>
                    </motion.tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </motion.div>
      )}

      {/* Modal */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            key="modal-overlay"
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
            style={{ background: "rgba(0,0,0,0.8)", backdropFilter: "blur(8px)" }}
            onClick={closeForm}
          >
            <motion.div
              key="modal-content"
              initial={{ opacity: 0, scale: 0.95, y: 16 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 16 }}
              transition={{ type: "spring", stiffness: 400, damping: 30 }}
              className="relative w-full max-w-2xl max-h-[92vh] overflow-y-auto rounded-2xl"
              style={{
                background: "#0D1117",
                border: "1px solid rgba(255,255,255,0.1)",
                boxShadow: "0 24px 80px rgba(0,0,0,0.8), 0 0 0 1px rgba(124,58,237,0.1)",
              }}
              onClick={e => e.stopPropagation()}
            >
              {/* Modal Header */}
              <div className="sticky top-0 z-10 flex items-center justify-between px-5 py-4"
                style={{ background: "#0D1117", borderBottom: "1px solid rgba(255,255,255,0.07)" }}
              >
                <div className="flex items-center gap-2.5">
                  <div className="w-7 h-7 rounded-lg flex items-center justify-center"
                    style={{ background: "rgba(124,58,237,0.15)", border: "1px solid rgba(124,58,237,0.25)" }}
                  >
                    {editingItem ? <Pencil size={13} style={{ color: "#A78BFA" }} /> : <Plus size={13} style={{ color: "#A78BFA" }} />}
                  </div>
                  <span className="text-[14px] font-bold" style={{ fontFamily: "'Space Grotesk', sans-serif", color: "rgba(255,255,255,0.95)" }}>
                    {editingItem ? "Editar Item" : "Novo Item da Loja"}
                  </span>
                </div>
                <button onClick={closeForm} className="w-7 h-7 rounded-lg flex items-center justify-center transition-all duration-150"
                  style={{ background: "rgba(255,255,255,0.05)", color: "rgba(255,255,255,0.4)" }}
                >
                  <X size={13} />
                </button>
              </div>

              <form onSubmit={handleSubmit} className="p-5 space-y-4">
                {/* Name + Type */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Nome *</label>
                    <input
                      value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })}
                      placeholder="Ex: Glow Bubble"
                      required
                      className="w-full px-3 py-2 rounded-xl text-[13px] outline-none transition-all duration-150"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.9)", fontFamily: "'Space Grotesk', sans-serif" }}
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Tipo *</label>
                    <select
                      value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value as StoreItemType })}
                      className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}
                    >
                      {Object.entries(TYPE_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
                    </select>
                  </div>
                </div>

                {/* Description */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Descrição</label>
                  <textarea
                    value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })}
                    placeholder="Descrição do item..."
                    rows={2}
                    className="w-full px-3 py-2 rounded-xl text-[13px] outline-none resize-none transition-all duration-150"
                    style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}
                  />
                </div>

                {/* Price + Rarity + Sort */}
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Preço (coins)</label>
                    <input
                      type="number" value={form.price_coins}
                      onChange={(e) => setForm({ ...form, price_coins: parseInt(e.target.value) || 0 })}
                      className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "#F59E0B", fontFamily: "'Space Mono', monospace" }}
                    />
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Raridade</label>
                    <select
                      value={form.rarity} onChange={(e) => setForm({ ...form, rarity: e.target.value as Rarity })}
                      className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}
                    >
                      {Object.entries(RARITY_CONFIG).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
                    </select>
                  </div>
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Ordem</label>
                    <input
                      type="number" value={form.sort_order}
                      onChange={(e) => setForm({ ...form, sort_order: parseInt(e.target.value) || 0 })}
                      className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                      style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.7)", fontFamily: "'Space Mono', monospace" }}
                    />
                  </div>
                </div>

                {/* Tags */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Tags (separadas por vírgula)</label>
                  <input
                    value={form.tags} onChange={(e) => setForm({ ...form, tags: e.target.value })}
                    placeholder="glow, neon, premium..."
                    className="w-full px-3 py-2 rounded-xl text-[13px] outline-none"
                    style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.7)", fontFamily: "'Space Mono', monospace" }}
                  />
                </div>

                {/* Toggles */}
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { key: "is_active", label: "Ativo", color: "#10B981" },
                    { key: "is_premium_only", label: "Premium", color: "#F59E0B" },
                    { key: "is_limited_edition", label: "Limitado", color: "#EC4899" },
                  ].map(({ key, label, color }) => {
                    const val = form[key as keyof ItemForm] as boolean;
                    return (
                      <button
                        key={key} type="button"
                        onClick={() => setForm({ ...form, [key]: !val })}
                        className="flex flex-col items-center gap-1.5 p-3 rounded-xl transition-all duration-150"
                        style={{
                          background: val ? `rgba(${color === "#10B981" ? "16,185,129" : color === "#F59E0B" ? "245,158,11" : "236,72,153"},0.1)` : "rgba(255,255,255,0.03)",
                          border: `1px solid ${val ? `rgba(${color === "#10B981" ? "16,185,129" : color === "#F59E0B" ? "245,158,11" : "236,72,153"},0.25)` : "rgba(255,255,255,0.07)"}`,
                        }}
                      >
                        <div className="w-4 h-4 rounded-full flex items-center justify-center" style={{ background: val ? color : "rgba(255,255,255,0.1)" }}>
                          {val && <CheckCircle2 size={10} className="text-white" />}
                        </div>
                        <span className="text-[10px] font-mono" style={{ color: val ? color : "rgba(255,255,255,0.3)" }}>{label}</span>
                      </button>
                    );
                  })}
                </div>

                {/* Preview Upload */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Preview</label>
                  <div
                    onClick={() => previewInputRef.current?.click()}
                    onDrop={onDrop}
                    onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
                    onDragLeave={() => setIsDragging(false)}
                    className="flex items-center gap-4 p-4 rounded-xl cursor-pointer transition-all duration-150"
                    style={{
                      background: isDragging ? "rgba(124,58,237,0.08)" : "rgba(255,255,255,0.03)",
                      border: `2px dashed ${isDragging ? "rgba(124,58,237,0.4)" : "rgba(255,255,255,0.1)"}`,
                    }}
                  >
                    {previewUrl ? (
                      <>
                        <img src={previewUrl} alt="Preview" className="w-14 h-14 rounded-xl object-cover flex-shrink-0" />
                        <div>
                          <p className="text-[13px] font-semibold" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>Preview carregado</p>
                          <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Clique para substituir</p>
                        </div>
                      </>
                    ) : (
                      <>
                        <div className="w-14 h-14 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
                          <Upload size={18} style={{ color: "rgba(255,255,255,0.25)" }} />
                        </div>
                        <div>
                          <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}>Arraste ou clique para enviar</p>
                          <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>PNG, WebP, GIF</p>
                        </div>
                      </>
                    )}
                    <input ref={previewInputRef} type="file" accept="image/*" className="hidden"
                      onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileChange(f, "preview"); }} />
                  </div>
                </div>

                {/* Asset Upload */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-mono tracking-widest uppercase" style={{ color: "rgba(255,255,255,0.3)" }}>Asset Principal</label>
                  <div
                    onClick={() => assetInputRef.current?.click()}
                    className="flex items-center gap-4 p-4 rounded-xl cursor-pointer transition-all duration-150"
                    style={{ background: "rgba(255,255,255,0.03)", border: "2px dashed rgba(255,255,255,0.1)" }}
                  >
                    {assetUrl ? (
                      <>
                        <img src={assetUrl} alt="Asset" className="w-14 h-14 rounded-xl object-cover flex-shrink-0" />
                        <div>
                          <p className="text-[13px] font-semibold" style={{ color: "rgba(255,255,255,0.8)", fontFamily: "'Space Grotesk', sans-serif" }}>Asset carregado</p>
                          <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.3)" }}>Clique para substituir</p>
                        </div>
                      </>
                    ) : (
                      <>
                        <div className="w-14 h-14 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)" }}>
                          <Zap size={18} style={{ color: "rgba(255,255,255,0.25)" }} />
                        </div>
                        <div>
                          <p className="text-[13px]" style={{ color: "rgba(255,255,255,0.5)", fontFamily: "'Space Grotesk', sans-serif" }}>Arraste ou clique para enviar</p>
                          <p className="text-[11px] font-mono" style={{ color: "rgba(255,255,255,0.25)" }}>PNG, WebP, GIF, APNG</p>
                        </div>
                      </>
                    )}
                    <input ref={assetInputRef} type="file" accept="image/*" className="hidden"
                      onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileChange(f, "asset"); }} />
                  </div>
                </div>

                {/* Actions */}
                <div className="flex gap-3 pt-2">
                  <button
                    type="button" onClick={closeForm}
                    className="flex-1 py-2.5 rounded-xl text-[13px] font-semibold transition-all duration-150"
                    style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", color: "rgba(255,255,255,0.6)", fontFamily: "'Space Grotesk', sans-serif" }}
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit" disabled={submitting}
                    className="flex-1 py-2.5 rounded-xl text-[13px] font-semibold flex items-center justify-center gap-2 transition-all duration-150"
                    style={{
                      background: "linear-gradient(135deg, #7C3AED, #EC4899)",
                      boxShadow: submitting ? "none" : "0 0 20px rgba(124,58,237,0.3)",
                      color: "white",
                      fontFamily: "'Space Grotesk', sans-serif",
                      opacity: submitting ? 0.7 : 1,
                    }}
                  >
                    {submitting ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
                    {editingItem ? "Salvar Alterações" : "Criar Item"}
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
