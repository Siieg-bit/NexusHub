/**
 * Dashboard — NexusHub Admin Panel
 * Painel administrativo completo com sidebar e múltiplas seções
 * Dark #111214, surface #1C1E22, accent rosa #E040FB
 */
import { useState, useRef, useCallback, useEffect } from "react";
import { supabase, StoreItem } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  Upload,
  Trash2,
  AlertCircle,
  CheckCircle2,
  Loader2,
  RefreshCw,
} from "lucide-react";

import AdminLayout, { AdminSection } from "@/components/AdminLayout";
import OverviewPage from "./OverviewPage";
import StoreItemsPage from "./StoreItemsPage";
import FramesDashboard from "./FramesDashboard";
import ThemesDashboard from "./ThemesDashboard";
import StickersPage from "./StickersPage";
import UsersPage from "./UsersPage";
import TransactionsPage from "./TransactionsPage";
import SettingsPage from "./SettingsPage";

// ─── Tipos ───────────────────────────────────────────────────────────────────

type BubbleForm = {
  name: string;
  description: string;
  priceCoins: number;
  rarity: "common" | "rare" | "epic" | "legendary";
  isActive: boolean;
};

const RARITY_COLORS: Record<string, string> = {
  common: "#9CA3AF",
  rare: "#60A5FA",
  epic: "#A78BFA",
  legendary: "#FBBF24",
};

const RARITY_LABELS: Record<string, string> = {
  common: "Comum",
  rare: "Raro",
  epic: "Épico",
  legendary: "Lendário",
};

// ─── Componente de Preview de Chat ───────────────────────────────────────────

function ChatPreview({
  imageUrl,
  name,
}: {
  imageUrl: string | null;
  name: string;
}) {
  const messages = [
    { id: 1, mine: false, text: "Oi! Que bubble incrível 👀" },
    { id: 2, mine: true, text: name || "Novo bubble" },
    { id: 3, mine: false, text: "Adorei! Quanto custa?" },
    { id: 4, mine: true, text: "Tá na loja agora 🎉" },
  ];

  return (
    <div className="flex flex-col gap-2 p-4">
      {messages.map((msg) => (
        <div
          key={msg.id}
          className={`flex ${msg.mine ? "justify-end" : "justify-start"}`}
        >
          {imageUrl ? (
            <div
              className="relative max-w-[200px] px-4 py-2.5 text-white text-sm"
              style={{
                backgroundImage: `url(${imageUrl})`,
                backgroundRepeat: "no-repeat",
                backgroundSize: "100% 100%",
                borderImageSource: `url(${imageUrl})`,
                borderImageSlice: "38 fill",
                borderImageWidth: "38px",
                borderImageRepeat: "stretch",
                minHeight: "44px",
                fontFamily: "'DM Sans', sans-serif",
                fontSize: "13px",
              }}
            >
              {msg.text}
            </div>
          ) : (
            <div
              className={`max-w-[200px] px-3.5 py-2 rounded-2xl text-sm text-white ${
                msg.mine ? "bg-[#E040FB]/80" : "bg-[#2A2D34]"
              }`}
              style={{ fontFamily: "'DM Sans', sans-serif", fontSize: "13px" }}
            >
              {msg.text}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

// ─── Painel de Bubbles ────────────────────────────────────────────────────────

function BubblesDashboard() {
  const [form, setForm] = useState<BubbleForm>({
    name: "",
    description: "",
    priceCoins: 150,
    rarity: "common",
    isActive: true,
  });

  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageDimensions, setImageDimensions] = useState<{
    w: number;
    h: number;
  } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [submitting, setSubmitting] = useState(false);
  const [bubbles, setBubbles] = useState<StoreItem[]>([]);
  const [loadingBubbles, setLoadingBubbles] = useState(true);
  const [editingBubble, setEditingBubble] = useState<StoreItem | null>(null);

  async function loadBubbles() {
    setLoadingBubbles(true);
    const { data, error } = await supabase
      .from("store_items")
      .select("*")
      .eq("type", "chat_bubble")
      .order("created_at", { ascending: false });
    if (!error && data) setBubbles(data as StoreItem[]);
    setLoadingBubbles(false);
  }

  useEffect(() => {
    loadBubbles();
  }, []);

  function handleFile(file: File) {
    if (!file.type.startsWith("image/")) {
      toast.error("Arquivo inválido. Envie uma imagem PNG ou WebP.");
      return;
    }
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      setImageDimensions({ w: img.width, h: img.height });
      URL.revokeObjectURL(url);
    };
    img.src = url;
    setImageFile(file);
    const reader = new FileReader();
    reader.onload = (e) => setImagePreview(e.target?.result as string);
    reader.readAsDataURL(file);
  }

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  }, []);

  function openEdit(bubble: StoreItem) {
    setEditingBubble(bubble);
    setForm({
      name: bubble.name,
      description: bubble.description ?? "",
      priceCoins: bubble.price_coins,
      rarity: (bubble.asset_config as Record<string, string>)?.rarity as BubbleForm["rarity"] ?? "common",
      isActive: bubble.is_active,
    });
    setImagePreview(bubble.preview_url);
    setImageFile(null);
  }

  function cancelEdit() {
    setEditingBubble(null);
    setForm({ name: "", description: "", priceCoins: 150, rarity: "common", isActive: true });
    setImageFile(null);
    setImagePreview(null);
    setImageDimensions(null);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!editingBubble && !imageFile) {
      toast.error("Selecione uma imagem para o bubble.");
      return;
    }
    if (!form.name.trim()) {
      toast.error("Defina um nome para o bubble.");
      return;
    }
    setSubmitting(true);
    try {
      let publicUrl = editingBubble?.preview_url ?? null;

      if (imageFile) {
        const ext = imageFile.name.split(".").pop() ?? "png";
        const slug = form.name.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
        const path = `bubbles/${slug}_${Date.now()}.${ext}`;
        const { error: uploadError } = await supabase.storage
          .from("store-assets")
          .upload(path, imageFile, { contentType: imageFile.type, upsert: false });
        if (uploadError) throw new Error(`Upload falhou: ${uploadError.message}`);
        const { data: urlData } = supabase.storage.from("store-assets").getPublicUrl(path);
        publicUrl = urlData.publicUrl;
      }

      const imgW = imageDimensions?.w ?? 128;
      const imgH = imageDimensions?.h ?? 128;
      const sliceRatio = 38 / 128;
      const assetConfig = {
        image_url: publicUrl,
        bubble_url: publicUrl,
        bubble_style: "nine_slice",
        image_width: imgW,
        image_height: imgH,
        slice_top: Math.round(imgH * sliceRatio),
        slice_left: Math.round(imgW * sliceRatio),
        slice_right: Math.round(imgW * sliceRatio),
        slice_bottom: Math.round(imgH * sliceRatio),
        content_padding_h: 20,
        content_padding_v: 14,
        rarity: form.rarity,
      };

      const payload = {
        type: "chat_bubble",
        name: form.name.trim(),
        description: form.description.trim() || null,
        preview_url: publicUrl,
        asset_url: publicUrl,
        asset_config: assetConfig,
        price_coins: form.priceCoins,
        price_real_cents: 0,
        is_premium_only: false,
        is_limited_edition: false,
        is_active: form.isActive,
        sort_order: 0,
      };

      if (editingBubble) {
        const { error } = await supabase.from("store_items").update(payload).eq("id", editingBubble.id);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" atualizado!`);
      } else {
        const { error } = await supabase.from("store_items").insert(payload);
        if (error) throw new Error(`DB error: ${error.message}`);
        toast.success(`"${form.name}" publicado na loja! 🎉`);
      }

      cancelEdit();
      loadBubbles();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.error(msg);
    } finally {
      setSubmitting(false);
    }
  }

  async function toggleActive(item: StoreItem) {
    const { error } = await supabase
      .from("store_items")
      .update({ is_active: !item.is_active })
      .eq("id", item.id);
    if (error) {
      toast.error("Erro ao atualizar status.");
      return;
    }
    setBubbles((prev) =>
      prev.map((b) => (b.id === item.id ? { ...b, is_active: !b.is_active } : b))
    );
    toast.success(`"${item.name}" ${!item.is_active ? "ativado" : "desativado"}.`);
  }

  async function deleteBubble(item: StoreItem) {
    if (!confirm(`Deletar "${item.name}"? Esta ação não pode ser desfeita.`)) return;
    const { error } = await supabase.from("store_items").delete().eq("id", item.id);
    if (error) {
      toast.error("Erro ao deletar.");
      return;
    }
    setBubbles((prev) => prev.filter((b) => b.id !== item.id));
    toast.success(`"${item.name}" removido da loja.`);
  }

  return (
    <div className="relative z-10 max-w-7xl mx-auto px-6 py-8">
      {/* Formulário de criação/edição */}
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-1">
          <div className="w-1 h-5 rounded-full bg-[#E040FB]" />
          <h2 className="text-white font-bold text-base">
            {editingBubble ? `Editando: ${editingBubble.name}` : "Novo Chat Bubble"}
          </h2>
        </div>
        <p className="text-[#6B7280] text-sm mb-5 pl-3">
          {editingBubble ? "Atualize as informações do bubble." : "Faça upload de um PNG/WebP nine-slice e configure o item."}
        </p>

        <form
          onSubmit={handleSubmit}
          className="bg-[#1C1E22] border border-[#2A2D34] rounded-2xl p-6 grid grid-cols-1 lg:grid-cols-2 gap-6"
        >
          {/* Upload */}
          <div className="flex flex-col gap-4">
            <div
              onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={onDrop}
              onClick={() => fileInputRef.current?.click()}
              className={`relative border-2 border-dashed rounded-xl overflow-hidden cursor-pointer transition-all duration-200 ${
                isDragging ? "border-[#E040FB] bg-[#E040FB]/5" : "border-[#2A2D34] hover:border-[#E040FB]/50"
              }`}
              style={{ minHeight: "200px" }}
            >
              {imagePreview ? (
                <div className="flex flex-col items-center gap-3 p-4">
                  <div className="bg-[#111214] rounded-xl overflow-hidden border border-[#2A2D34]">
                    <ChatPreview imageUrl={imagePreview} name={form.name} />
                  </div>
                  {imageDimensions && (
                    <span className="text-[#6B7280] text-xs" style={{ fontFamily: "'DM Mono', monospace" }}>
                      {imageDimensions.w}×{imageDimensions.h}px
                    </span>
                  )}
                </div>
              ) : (
                <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 text-[#4B5563]">
                  <Upload className="w-8 h-8" />
                  <p className="text-sm text-center px-4">
                    Arraste uma imagem ou clique para selecionar
                  </p>
                  <p className="text-xs">PNG, WebP — recomendado 128×128px</p>
                </div>
              )}
              <input
                ref={fileInputRef}
                type="file"
                accept="image/png,image/webp,image/gif"
                className="hidden"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); }}
              />
            </div>
          </div>

          {/* Campos */}
          <div className="flex flex-col gap-4">
            <div className="space-y-1.5">
              <Label className="text-[#9CA3AF] text-xs uppercase tracking-wide" style={{ fontFamily: "'DM Mono', monospace" }}>
                Nome *
              </Label>
              <Input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Ex: Glow Neon"
                className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-10"
                required
              />
            </div>

            <div className="space-y-1.5">
              <Label className="text-[#9CA3AF] text-xs uppercase tracking-wide" style={{ fontFamily: "'DM Mono', monospace" }}>
                Descrição
              </Label>
              <Input
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder="Descrição opcional"
                className="bg-[#111214] border-[#2A2D34] text-white placeholder:text-[#4B5563] h-10"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs uppercase tracking-wide" style={{ fontFamily: "'DM Mono', monospace" }}>
                  Preço (Coins)
                </Label>
                <Input
                  type="number"
                  min={0}
                  value={form.priceCoins}
                  onChange={(e) => setForm({ ...form, priceCoins: parseInt(e.target.value) || 0 })}
                  className="bg-[#111214] border-[#2A2D34] text-white h-10"
                />
              </div>
              <div className="space-y-1.5">
                <Label className="text-[#9CA3AF] text-xs uppercase tracking-wide" style={{ fontFamily: "'DM Mono', monospace" }}>
                  Raridade
                </Label>
                <select
                  value={form.rarity}
                  onChange={(e) => setForm({ ...form, rarity: e.target.value as BubbleForm["rarity"] })}
                  className="w-full bg-[#111214] border border-[#2A2D34] text-white text-sm rounded-md px-3 h-10 focus:outline-none focus:border-[#E040FB]"
                >
                  {Object.entries(RARITY_LABELS).map(([k, v]) => (
                    <option key={k} value={k}>{v}</option>
                  ))}
                </select>
              </div>
            </div>

            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={form.isActive}
                onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
                className="w-4 h-4 rounded border-[#2A2D34] bg-[#111214] accent-[#E040FB]"
              />
              <span className="text-[#9CA3AF] text-sm">Ativo na loja</span>
            </label>

            <div className="flex gap-3 pt-2">
              {editingBubble && (
                <Button
                  type="button"
                  variant="ghost"
                  onClick={cancelEdit}
                  className="flex-1 border border-[#2A2D34] text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-10"
                >
                  Cancelar
                </Button>
              )}
              <Button
                type="submit"
                disabled={submitting}
                className="flex-1 bg-[#E040FB] hover:bg-[#D030EB] text-white h-10 font-semibold"
              >
                {submitting ? (
                  <Loader2 className="w-4 h-4 animate-spin mr-2" />
                ) : (
                  <Upload className="w-4 h-4 mr-2" />
                )}
                {editingBubble ? "Salvar Alterações" : "Publicar Bubble"}
              </Button>
            </div>
          </div>
        </form>
      </div>

      {/* Lista de bubbles */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <div className="w-1 h-5 rounded-full bg-[#E040FB]" />
            <h2 className="text-white font-bold text-base">
              Bubbles Publicados
            </h2>
            <span className="text-[#4B5563] text-sm ml-1">({bubbles.length})</span>
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={loadBubbles}
            className="text-[#4B5563] hover:text-white hover:bg-[#2A2D34] h-8"
          >
            <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
            Atualizar
          </Button>
        </div>

        {loadingBubbles ? (
          <div className="flex items-center justify-center h-32">
            <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
          </div>
        ) : bubbles.length === 0 ? (
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-8 text-center">
            <p className="text-[#4B5563] text-sm">Nenhum bubble publicado ainda.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {bubbles.map((bubble) => {
              const rarity = (bubble.asset_config as Record<string, string>)?.rarity ?? "common";
              return (
                <div
                  key={bubble.id}
                  className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden hover:border-[#3A3D44] transition-colors"
                >
                  <div className="bg-[#111214] border-b border-[#2A2D34]">
                    <ChatPreview imageUrl={bubble.preview_url} name={bubble.name} />
                  </div>
                  <div className="p-4">
                    <div className="flex items-start justify-between gap-2 mb-2">
                      <div>
                        <h3 className="text-white font-semibold text-sm">{bubble.name}</h3>
                        {bubble.description && (
                          <p className="text-[#6B7280] text-xs mt-0.5">{bubble.description}</p>
                        )}
                      </div>
                      <span
                        className="text-[10px] px-1.5 py-0.5 rounded-full font-medium flex-shrink-0"
                        style={{
                          color: RARITY_COLORS[rarity],
                          background: `${RARITY_COLORS[rarity]}20`,
                          border: `1px solid ${RARITY_COLORS[rarity]}40`,
                        }}
                      >
                        {RARITY_LABELS[rarity] ?? rarity}
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-[#FBBF24] text-sm font-medium">
                        {bubble.price_coins} coins
                      </span>
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() => toggleActive(bubble)}
                          className={`flex items-center gap-1 text-xs px-2 py-1 rounded-full border transition-colors ${
                            bubble.is_active
                              ? "bg-[#4ADE80]/10 text-[#4ADE80] border-[#4ADE80]/30 hover:bg-[#4ADE80]/20"
                              : "bg-red-500/10 text-red-400 border-red-500/30 hover:bg-red-500/20"
                          }`}
                        >
                          {bubble.is_active ? (
                            <CheckCircle2 className="w-3 h-3" />
                          ) : (
                            <AlertCircle className="w-3 h-3" />
                          )}
                          {bubble.is_active ? "Ativo" : "Inativo"}
                        </button>
                        <button
                          onClick={() => openEdit(bubble)}
                          className="p-1.5 rounded-md text-[#4B5563] hover:text-[#E040FB] hover:bg-[#E040FB]/10 transition-colors"
                          title="Editar"
                        >
                          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                          </svg>
                        </button>
                        <button
                          onClick={() => deleteBubble(bubble)}
                          className="p-1.5 rounded-md text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors"
                          title="Deletar"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Dashboard Principal ──────────────────────────────────────────────────────

export default function Dashboard() {
  const [activeSection, setActiveSection] = useState<AdminSection>("overview");

  function renderSection() {
    switch (activeSection) {
      case "overview":
        return <OverviewPage />;
      case "store-items":
        return <StoreItemsPage />;
      case "bubbles":
        return <BubblesDashboard />;
      case "frames":
        return <FramesDashboard />;
      case "stickers":
        return <StickersPage />;
      case "themes":
        return <ThemesDashboard />;
      case "users":
        return <UsersPage />;
      case "transactions":
        return <TransactionsPage />;
      case "settings":
        return <SettingsPage />;
      default:
        return <OverviewPage />;
    }
  }

  return (
    <AdminLayout
      activeSection={activeSection}
      onSectionChange={setActiveSection}
    >
      {renderSection()}
    </AdminLayout>
  );
}
