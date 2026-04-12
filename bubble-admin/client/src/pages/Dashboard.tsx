/**
 * Dashboard — Stark Admin Precision
 * Split 60/40: formulário | preview de chat em tempo real
 * Dark #111214, surface #1C1E22, accent rosa #E040FB
 * DM Sans (títulos) + DM Mono (labels técnicos)
 */
import { useState, useRef, useCallback, useEffect } from "react";
import { supabase, StoreItem } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import {
  Upload,
  Sparkles,
  LogOut,
  Trash2,
  Eye,
  EyeOff,
  AlertCircle,
  CheckCircle2,
  MessageCircle,
  Loader2,
  ImagePlus,
  Package,
  RefreshCw,
} from "lucide-react";

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
            /* Nine-slice simulado com border-image */
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

// ─── Componente principal ─────────────────────────────────────────────────────

export default function Dashboard() {
  const { auth, signOut } = useAuth();
  const profile =
    auth.status === "authenticated" ? auth.profile : null;

  // Form state
  const [form, setForm] = useState<BubbleForm>({
    name: "",
    description: "",
    priceCoins: 150,
    rarity: "common",
    isActive: true,
  });

  // Upload state
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageDimensions, setImageDimensions] = useState<{
    w: number;
    h: number;
  } | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Submission state
  const [submitting, setSubmitting] = useState(false);

  // Existing bubbles
  const [bubbles, setBubbles] = useState<StoreItem[]>([]);
  const [loadingBubbles, setLoadingBubbles] = useState(true);

  // ── Load existing bubbles ──────────────────────────────────────────────────

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

  // ── Image handling ─────────────────────────────────────────────────────────

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

  // ── Submit ─────────────────────────────────────────────────────────────────

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!imageFile) {
      toast.error("Selecione uma imagem para o bubble.");
      return;
    }
    if (!form.name.trim()) {
      toast.error("Defina um nome para o bubble.");
      return;
    }

    setSubmitting(true);

    try {
      // 1. Upload da imagem para store-assets/bubbles/
      const ext = imageFile.name.split(".").pop() ?? "png";
      const slug = form.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "_")
        .replace(/^_|_$/g, "");
      const path = `bubbles/${slug}_${Date.now()}.${ext}`;

      const { error: uploadError } = await supabase.storage
        .from("store-assets")
        .upload(path, imageFile, {
          contentType: imageFile.type,
          upsert: false,
        });

      if (uploadError) throw new Error(`Upload falhou: ${uploadError.message}`);

      // 2. Obter URL pública
      const { data: urlData } = supabase.storage
        .from("store-assets")
        .getPublicUrl(path);
      const publicUrl = urlData.publicUrl;

      // 3. Calcular parâmetros nine-slice
      // Para imagem 128x128: slice = 38px (padrão do NexusHub)
      // Para imagens maiores: proporcional
      const imgW = imageDimensions?.w ?? 128;
      const imgH = imageDimensions?.h ?? 128;
      const sliceRatio = 38 / 128;
      const sliceTop = Math.round(imgH * sliceRatio);
      const sliceLeft = Math.round(imgW * sliceRatio);
      const sliceRight = Math.round(imgW * sliceRatio);
      const sliceBottom = Math.round(imgH * sliceRatio);

      const assetConfig = {
        image_url: publicUrl,
        bubble_url: publicUrl,
        bubble_style: "nine_slice",
        image_width: imgW,
        image_height: imgH,
        slice_top: sliceTop,
        slice_left: sliceLeft,
        slice_right: sliceRight,
        slice_bottom: sliceBottom,
        content_padding_h: 20,
        content_padding_v: 14,
        rarity: form.rarity,
      };

      // 4. Inserir na tabela store_items
      const { error: insertError } = await supabase
        .from("store_items")
        .insert({
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
        });

      if (insertError) throw new Error(`DB error: ${insertError.message}`);

      toast.success(`"${form.name}" publicado na loja! 🎉`);

      // Reset form
      setForm({
        name: "",
        description: "",
        priceCoins: 150,
        rarity: "common",
        isActive: true,
      });
      setImageFile(null);
      setImagePreview(null);
      setImageDimensions(null);

      loadBubbles();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      toast.error(msg);
    } finally {
      setSubmitting(false);
    }
  }

  // ── Toggle active ──────────────────────────────────────────────────────────

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
      prev.map((b) =>
        b.id === item.id ? { ...b, is_active: !b.is_active } : b
      )
    );
    toast.success(`"${item.name}" ${!item.is_active ? "ativado" : "desativado"}.`);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  async function deleteBubble(item: StoreItem) {
    if (!confirm(`Deletar "${item.name}"? Esta ação não pode ser desfeita.`))
      return;

    const { error } = await supabase
      .from("store_items")
      .delete()
      .eq("id", item.id);

    if (error) {
      toast.error("Erro ao deletar.");
      return;
    }
    setBubbles((prev) => prev.filter((b) => b.id !== item.id));
    toast.success(`"${item.name}" removido da loja.`);
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <div
      className="min-h-screen bg-[#111214] text-white"
      style={{ fontFamily: "'DM Sans', sans-serif" }}
    >
      {/* Background grid */}
      <div
        className="fixed inset-0 pointer-events-none"
        style={{
          backgroundImage:
            "radial-gradient(circle, #2A2D34 1px, transparent 1px)",
          backgroundSize: "28px 28px",
          opacity: 0.35,
        }}
      />

      {/* Header */}
      <header className="relative z-10 border-b border-[#2A2D34] bg-[#111214]/80 backdrop-blur-sm">
        <div className="max-w-7xl mx-auto px-6 h-14 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-7 h-7 rounded-lg bg-[#E040FB]/20 border border-[#E040FB]/40 flex items-center justify-center">
              <Sparkles className="w-3.5 h-3.5 text-[#E040FB]" />
            </div>
            <span className="font-bold text-white tracking-tight">
              Bubble Studio
            </span>
            <Badge
              className="text-[10px] px-1.5 py-0 h-4 bg-[#E040FB]/15 text-[#E040FB] border-[#E040FB]/30 animate-pulse"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              TEAM ONLY
            </Badge>
          </div>

          <div className="flex items-center gap-3">
            {profile && (
              <span
                className="text-[#9CA3AF] text-sm"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {profile.nickname}
              </span>
            )}
            <Button
              variant="ghost"
              size="sm"
              onClick={signOut}
              className="text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-8 px-2"
            >
              <LogOut className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </header>

      <div className="relative z-10 max-w-7xl mx-auto px-6 py-8">
        {/* ── Top: Criar novo bubble ── */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-1">
            <div className="w-1 h-5 bg-[#E040FB] rounded-full" />
            <h2 className="text-lg font-bold text-white">
              Criar novo Chat Bubble
            </h2>
          </div>
          <p
            className="text-[#9CA3AF] text-sm ml-3"
            style={{ fontFamily: "'DM Mono', monospace" }}
          >
            Envie uma imagem 128×128 PNG. O sistema configura o nine-slice
            automaticamente.
          </p>
        </div>

        {/* ── Split layout: form | preview ── */}
        <form onSubmit={handleSubmit}>
          <div className="grid grid-cols-1 lg:grid-cols-5 gap-6 mb-10">
            {/* Formulário — 3/5 */}
            <div className="lg:col-span-3 space-y-5">
              {/* Upload zone */}
              <div
                className={`border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-all duration-200 ${
                  isDragging
                    ? "border-[#E040FB] bg-[#E040FB]/5"
                    : imageFile
                    ? "border-[#E040FB]/50 bg-[#E040FB]/5"
                    : "border-[#2A2D34] bg-[#1C1E22] hover:border-[#E040FB]/40 hover:bg-[#E040FB]/5"
                }`}
                onClick={() => fileInputRef.current?.click()}
                onDragOver={(e) => {
                  e.preventDefault();
                  setIsDragging(true);
                }}
                onDragLeave={() => setIsDragging(false)}
                onDrop={onDrop}
              >
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/png,image/webp,image/gif"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) handleFile(f);
                  }}
                />

                {imagePreview ? (
                  <div className="flex items-center gap-4">
                    <img
                      src={imagePreview}
                      alt="Preview"
                      className="w-16 h-16 rounded-lg object-contain bg-[#111214] border border-[#2A2D34]"
                    />
                    <div className="text-left">
                      <p className="text-white font-medium text-sm">
                        {imageFile?.name}
                      </p>
                      <p
                        className="text-[#9CA3AF] text-xs mt-0.5"
                        style={{ fontFamily: "'DM Mono', monospace" }}
                      >
                        {imageDimensions
                          ? `${imageDimensions.w}×${imageDimensions.h}px`
                          : "Calculando..."}
                        {imageDimensions &&
                          (imageDimensions.w !== 128 ||
                            imageDimensions.h !== 128) && (
                            <span className="text-yellow-400 ml-2">
                              ⚠ Recomendado: 128×128
                            </span>
                          )}
                      </p>
                      <p className="text-[#E040FB] text-xs mt-1">
                        Clique para trocar
                      </p>
                    </div>
                  </div>
                ) : (
                  <div>
                    <ImagePlus className="w-8 h-8 text-[#4B5563] mx-auto mb-2" />
                    <p className="text-[#9CA3AF] text-sm">
                      Arraste ou clique para enviar
                    </p>
                    <p
                      className="text-[#4B5563] text-xs mt-1"
                      style={{ fontFamily: "'DM Mono', monospace" }}
                    >
                      PNG / WebP · 128×128px recomendado
                    </p>
                  </div>
                )}
              </div>

              {/* Nome */}
              <div className="space-y-1.5">
                <Label
                  className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  Nome do Bubble *
                </Label>
                <Input
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="Ex: Heart Bubble, Galaxy Frame..."
                  required
                  className="bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] h-10"
                />
              </div>

              {/* Descrição */}
              <div className="space-y-1.5">
                <Label
                  className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  Descrição (opcional)
                </Label>
                <Input
                  value={form.description}
                  onChange={(e) =>
                    setForm({ ...form, description: e.target.value })
                  }
                  placeholder="Descrição breve para a loja..."
                  className="bg-[#1C1E22] border-[#2A2D34] text-white placeholder:text-[#4B5563] focus:border-[#E040FB] h-10"
                />
              </div>

              {/* Preço + Raridade */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label
                    className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    Preço (coins) *
                  </Label>
                  <Input
                    type="number"
                    min={0}
                    value={form.priceCoins}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        priceCoins: parseInt(e.target.value) || 0,
                      })
                    }
                    className="bg-[#1C1E22] border-[#2A2D34] text-white focus:border-[#E040FB] h-10"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  />
                </div>

                <div className="space-y-1.5">
                  <Label
                    className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    Raridade
                  </Label>
                  <select
                    value={form.rarity}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        rarity: e.target.value as BubbleForm["rarity"],
                      })
                    }
                    className="w-full h-10 rounded-md bg-[#1C1E22] border border-[#2A2D34] text-white px-3 text-sm focus:border-[#E040FB] focus:outline-none"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    <option value="common">Common</option>
                    <option value="rare">Rare</option>
                    <option value="epic">Epic</option>
                    <option value="legendary">Legendary</option>
                  </select>
                </div>
              </div>

              {/* Status */}
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  onClick={() =>
                    setForm({ ...form, isActive: !form.isActive })
                  }
                  className={`relative w-10 h-5 rounded-full transition-colors duration-200 ${
                    form.isActive ? "bg-[#E040FB]" : "bg-[#2A2D34]"
                  }`}
                >
                  <span
                    className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform duration-200 ${
                      form.isActive ? "translate-x-5" : "translate-x-0.5"
                    }`}
                  />
                </button>
                <span
                  className="text-[#9CA3AF] text-sm"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  {form.isActive
                    ? "Publicar na loja imediatamente"
                    : "Salvar como rascunho"}
                </span>
              </div>

              {/* Submit */}
              <Button
                type="submit"
                disabled={submitting || !imageFile || !form.name.trim()}
                className="w-full h-11 bg-[#E040FB] hover:bg-[#CE39E0] text-white font-semibold border-0 transition-all duration-200 disabled:opacity-40"
              >
                {submitting ? (
                  <span className="flex items-center gap-2">
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Publicando...
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    <Upload className="w-4 h-4" />
                    Publicar na Loja
                  </span>
                )}
              </Button>
            </div>

            {/* Preview — 2/5 */}
            <div className="lg:col-span-2">
              <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl overflow-hidden sticky top-6">
                {/* Preview header */}
                <div className="px-4 py-3 border-b border-[#2A2D34] flex items-center gap-2">
                  <MessageCircle className="w-4 h-4 text-[#E040FB]" />
                  <span
                    className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    Preview em tempo real
                  </span>
                </div>

                {/* Chat simulation */}
                <div className="bg-[#111214] min-h-[280px]">
                  <ChatPreview
                    imageUrl={imagePreview}
                    name={form.name || "Novo bubble"}
                  />
                </div>

                {/* Nine-slice info */}
                <div className="px-4 py-3 border-t border-[#2A2D34]">
                  <p
                    className="text-[#4B5563] text-xs"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    nine-slice auto-calculado
                  </p>
                  {imageDimensions && (
                    <div
                      className="mt-1.5 grid grid-cols-2 gap-x-3 gap-y-0.5 text-xs"
                      style={{ fontFamily: "'DM Mono', monospace" }}
                    >
                      <span className="text-[#6B7280]">
                        size:{" "}
                        <span className="text-[#9CA3AF]">
                          {imageDimensions.w}×{imageDimensions.h}
                        </span>
                      </span>
                      <span className="text-[#6B7280]">
                        slice:{" "}
                        <span className="text-[#9CA3AF]">
                          {Math.round(imageDimensions.h * (38 / 128))}px
                        </span>
                      </span>
                      <span className="text-[#6B7280]">
                        padding_h:{" "}
                        <span className="text-[#9CA3AF]">20px</span>
                      </span>
                      <span className="text-[#6B7280]">
                        padding_v:{" "}
                        <span className="text-[#9CA3AF]">14px</span>
                      </span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </form>

        {/* ── Lista de bubbles existentes ── */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <div className="w-1 h-5 bg-[#E040FB] rounded-full" />
              <h2 className="text-lg font-bold text-white">
                Bubbles na Loja
              </h2>
              <span
                className="text-[#4B5563] text-sm"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                ({bubbles.length})
              </span>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={loadBubbles}
              className="text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-8 px-2"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </Button>
          </div>

          {loadingBubbles ? (
            <div className="flex items-center justify-center py-16">
              <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
            </div>
          ) : bubbles.length === 0 ? (
            <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-10 text-center">
              <Package className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
              <p className="text-[#4B5563] text-sm">
                Nenhum bubble na loja ainda.
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {bubbles.map((item) => {
                const cfg = item.asset_config as Record<string, unknown>;
                const rarity = (cfg?.rarity as string) ?? "common";
                return (
                  <div
                    key={item.id}
                    className={`bg-[#1C1E22] border rounded-xl overflow-hidden transition-all duration-200 hover:border-[#E040FB]/30 ${
                      item.is_active
                        ? "border-[#2A2D34]"
                        : "border-[#2A2D34] opacity-50"
                    }`}
                  >
                    {/* Left accent bar */}
                    <div
                      className="h-1 w-full"
                      style={{ backgroundColor: RARITY_COLORS[rarity] }}
                    />

                    <div className="p-4">
                      {/* Image */}
                      <div className="w-16 h-16 rounded-lg bg-[#111214] border border-[#2A2D34] mb-3 overflow-hidden flex items-center justify-center">
                        {item.preview_url ? (
                          <img
                            src={item.preview_url}
                            alt={item.name}
                            className="w-full h-full object-contain"
                          />
                        ) : (
                          <ImagePlus className="w-6 h-6 text-[#4B5563]" />
                        )}
                      </div>

                      {/* Name + rarity */}
                      <div className="flex items-start justify-between gap-2 mb-1">
                        <p className="text-white font-semibold text-sm leading-tight">
                          {item.name}
                        </p>
                        <span
                          className="text-[10px] px-1.5 py-0.5 rounded font-medium shrink-0"
                          style={{
                            color: RARITY_COLORS[rarity],
                            backgroundColor: RARITY_COLORS[rarity] + "20",
                            fontFamily: "'DM Mono', monospace",
                          }}
                        >
                          {rarity}
                        </span>
                      </div>

                      {/* Price */}
                      <p
                        className="text-[#9CA3AF] text-xs mb-3"
                        style={{ fontFamily: "'DM Mono', monospace" }}
                      >
                        {item.price_coins} coins
                      </p>

                      {/* Actions */}
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => toggleActive(item)}
                          className={`flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-md transition-colors ${
                            item.is_active
                              ? "bg-green-500/10 text-green-400 hover:bg-green-500/20"
                              : "bg-[#2A2D34] text-[#9CA3AF] hover:bg-[#3A3D44]"
                          }`}
                          style={{ fontFamily: "'DM Mono', monospace" }}
                        >
                          {item.is_active ? (
                            <>
                              <CheckCircle2 className="w-3 h-3" />
                              Ativo
                            </>
                          ) : (
                            <>
                              <AlertCircle className="w-3 h-3" />
                              Inativo
                            </>
                          )}
                        </button>

                        <button
                          onClick={() => deleteBubble(item)}
                          className="ml-auto p-1.5 rounded-md text-[#4B5563] hover:text-red-400 hover:bg-red-500/10 transition-colors"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
