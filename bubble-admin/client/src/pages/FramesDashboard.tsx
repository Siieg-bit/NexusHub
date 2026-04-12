/**
 * FramesDashboard — Gerenciamento de Molduras de Perfil
 * Mesmo padrão visual do BubbleDashboard (Stark Admin Precision)
 * Dark #111214, surface #1C1E22, accent rosa #E040FB
 * DM Sans (títulos) + DM Mono (labels técnicos)
 *
 * Fluxo automatizado:
 *  1. Upload PNG da moldura (overlay transparente)
 *  2. Preencher nome, descrição, preço e raridade
 *  3. Preview em tempo real com avatar simulado
 *  4. Publicar → upload para store-assets/frames/ + insert em store_items (type=avatar_frame)
 *
 * asset_config gerado:
 *  { frame_url, image_url, rarity, frame_style, image_width, image_height }
 */
import { useState, useRef, useCallback, useEffect } from "react";
import { supabase, StoreItem } from "@/lib/supabase";
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
  ImagePlus,
  Package,
  RefreshCw,
  User,
  Frame,
} from "lucide-react";

// ─── Tipos ───────────────────────────────────────────────────────────────────

type FrameForm = {
  name: string;
  description: string;
  priceCoins: number;
  rarity: "common" | "rare" | "epic" | "legendary";
  frameStyle: "default" | "sparkle" | "fire" | "ice" | "neon" | "gold";
  isActive: boolean;
};

const RARITY_COLORS: Record<string, string> = {
  common: "#9CA3AF",
  rare: "#60A5FA",
  epic: "#A78BFA",
  legendary: "#FBBF24",
};

const FRAME_STYLE_LABELS: Record<string, string> = {
  default: "Padrão",
  sparkle: "Sparkle ✨",
  fire: "Fire 🔥",
  ice: "Ice ❄️",
  neon: "Neon 💜",
  gold: "Gold 🏆",
};

// ─── Preview de Avatar com Moldura ───────────────────────────────────────────

function AvatarPreview({
  frameUrl,
  name,
  rarity,
}: {
  frameUrl: string | null;
  name: string;
  rarity: string;
}) {
  const AVATAR_SIZE = 80;
  const FRAME_SIZE = Math.round(AVATAR_SIZE * 1.4); // 1.4× como no app Flutter

  return (
    <div className="flex flex-col items-center gap-5 p-6">
      {/* Preview principal */}
      <div className="flex flex-col items-center gap-3">
        <p
          className="text-[#4B5563] text-xs uppercase tracking-widest"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          Preview — Avatar + Moldura
        </p>

        {/* Stack: avatar + frame overlay */}
        <div
          className="relative flex items-center justify-center"
          style={{ width: FRAME_SIZE, height: FRAME_SIZE }}
        >
          {/* Avatar simulado */}
          <div
            className="rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] border-2 border-[#3A3D44] flex items-center justify-center overflow-hidden"
            style={{ width: AVATAR_SIZE, height: AVATAR_SIZE }}
          >
            <User className="w-10 h-10 text-[#4B5563]" />
          </div>

          {/* Moldura overlay — PNG transparente sobreposto */}
          {frameUrl && (
            <img
              src={frameUrl}
              alt="Frame preview"
              className="absolute inset-0 w-full h-full object-contain pointer-events-none"
              style={{ width: FRAME_SIZE, height: FRAME_SIZE }}
            />
          )}

          {/* Placeholder quando não há moldura */}
          {!frameUrl && (
            <div
              className="absolute inset-0 rounded-full border-4 border-dashed border-[#2A2D34] pointer-events-none"
              style={{ width: FRAME_SIZE, height: FRAME_SIZE }}
            />
          )}
        </div>

        {/* Nome e raridade */}
        <div className="text-center">
          <p className="text-white text-sm font-semibold">
            {name || "Nova Moldura"}
          </p>
          <span
            className="text-[10px] px-2 py-0.5 rounded-full font-medium"
            style={{
              color: RARITY_COLORS[rarity] ?? RARITY_COLORS.common,
              backgroundColor:
                (RARITY_COLORS[rarity] ?? RARITY_COLORS.common) + "20",
              fontFamily: "'DM Mono', monospace",
            }}
          >
            {rarity}
          </span>
        </div>
      </div>

      {/* Exemplos de tamanho */}
      <div className="w-full border-t border-[#2A2D34] pt-4">
        <p
          className="text-[#4B5563] text-xs uppercase tracking-widest mb-3 text-center"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          Tamanhos no App
        </p>
        <div className="flex items-end justify-center gap-6">
          {[
            { label: "Chat", avatarPx: 36, scale: 1.4 },
            { label: "Perfil", avatarPx: 80, scale: 1.4 },
            { label: "Header", avatarPx: 56, scale: 1.4 },
          ].map(({ label, avatarPx, scale }) => {
            const framePx = Math.round(avatarPx * scale);
            return (
              <div key={label} className="flex flex-col items-center gap-1.5">
                <div
                  className="relative flex items-center justify-center"
                  style={{ width: framePx, height: framePx }}
                >
                  <div
                    className="rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] border border-[#3A3D44] flex items-center justify-center"
                    style={{ width: avatarPx, height: avatarPx }}
                  >
                    <User
                      style={{
                        width: avatarPx * 0.55,
                        height: avatarPx * 0.55,
                        color: "#4B5563",
                      }}
                    />
                  </div>
                  {frameUrl && (
                    <img
                      src={frameUrl}
                      alt=""
                      className="absolute inset-0 object-contain pointer-events-none"
                      style={{ width: framePx, height: framePx }}
                    />
                  )}
                </div>
                <p
                  className="text-[#4B5563] text-[10px]"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  {label}
                </p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Info técnica */}
      <div className="w-full border-t border-[#2A2D34] pt-3">
        <p
          className="text-[#4B5563] text-xs"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          overlay PNG transparente
        </p>
        <p
          className="text-[#4B5563] text-xs mt-0.5"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          frame_size = avatar × 1.4
        </p>
        <p
          className="text-[#4B5563] text-xs mt-0.5"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          bucket: store-assets/frames/
        </p>
      </div>
    </div>
  );
}

// ─── Componente principal ─────────────────────────────────────────────────────

export default function FramesDashboard() {
  // Form state
  const [form, setForm] = useState<FrameForm>({
    name: "",
    description: "",
    priceCoins: 200,
    rarity: "common",
    frameStyle: "default",
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

  // Existing frames
  const [frames, setFrames] = useState<StoreItem[]>([]);
  const [loadingFrames, setLoadingFrames] = useState(true);

  // ── Load existing frames ───────────────────────────────────────────────────

  async function loadFrames() {
    setLoadingFrames(true);
    const { data, error } = await supabase
      .from("store_items")
      .select("*")
      .eq("type", "avatar_frame")
      .order("created_at", { ascending: false });

    if (!error && data) setFrames(data as StoreItem[]);
    setLoadingFrames(false);
  }

  useEffect(() => {
    loadFrames();
  }, []);

  // ── Image handling ─────────────────────────────────────────────────────────

  function handleFile(file: File) {
    if (!file.type.startsWith("image/")) {
      toast.error("Arquivo inválido. Envie uma imagem PNG.");
      return;
    }
    if (file.type !== "image/png") {
      toast.warning(
        "Recomendamos PNG com transparência para molduras de perfil."
      );
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
      toast.error("Selecione uma imagem PNG para a moldura.");
      return;
    }
    if (!form.name.trim()) {
      toast.error("Defina um nome para a moldura.");
      return;
    }

    setSubmitting(true);

    try {
      // 1. Upload da imagem para store-assets/frames/
      const ext = imageFile.name.split(".").pop() ?? "png";
      const slug = form.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "_")
        .replace(/^_|_$/g, "");
      const path = `frames/${slug}_${Date.now()}.${ext}`;

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

      const imgW = imageDimensions?.w ?? 512;
      const imgH = imageDimensions?.h ?? 512;

      // 3. Montar asset_config para avatar_frame
      // O app Flutter lê: frame_url, image_url, rarity, frame_style, image_width, image_height
      // O widget AvatarWithFrame renderiza o PNG como overlay 1.4× o tamanho do avatar
      const assetConfig = {
        frame_url: publicUrl,
        image_url: publicUrl,
        rarity: form.rarity,
        frame_style: form.frameStyle,
        image_width: imgW,
        image_height: imgH,
      };

      // 4. Inserir na tabela store_items com type = avatar_frame
      const { error: insertError } = await supabase
        .from("store_items")
        .insert({
          type: "avatar_frame",
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

      toast.success(`"${form.name}" publicada na loja! 🎉`);

      // Reset form
      setForm({
        name: "",
        description: "",
        priceCoins: 200,
        rarity: "common",
        frameStyle: "default",
        isActive: true,
      });
      setImageFile(null);
      setImagePreview(null);
      setImageDimensions(null);

      loadFrames();
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
    setFrames((prev) =>
      prev.map((f) =>
        f.id === item.id ? { ...f, is_active: !f.is_active } : f
      )
    );
    toast.success(
      `"${item.name}" ${!item.is_active ? "ativada" : "desativada"}.`
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  async function deleteFrame(item: StoreItem) {
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
    setFrames((prev) => prev.filter((f) => f.id !== item.id));
    toast.success(`"${item.name}" removida da loja.`);
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <div className="relative z-10 max-w-7xl mx-auto px-6 py-8">
      {/* ── Top: Criar nova moldura ── */}
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-1">
          <div className="w-1 h-5 bg-[#E040FB] rounded-full" />
          <h2 className="text-lg font-bold text-white">
            Criar nova Moldura de Perfil
          </h2>
        </div>
        <p
          className="text-[#9CA3AF] text-sm ml-3"
          style={{ fontFamily: "'DM Mono', monospace" }}
        >
          Envie um PNG transparente. O sistema configura o overlay
          automaticamente (frame = avatar × 1.4).
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
                  {/* Preview com fundo quadriculado para mostrar transparência */}
                  <div
                    className="w-16 h-16 rounded-lg border border-[#2A2D34] overflow-hidden flex items-center justify-center flex-shrink-0"
                    style={{
                      backgroundImage:
                        "linear-gradient(45deg, #2A2D34 25%, transparent 25%), linear-gradient(-45deg, #2A2D34 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #2A2D34 75%), linear-gradient(-45deg, transparent 75%, #2A2D34 75%)",
                      backgroundSize: "8px 8px",
                      backgroundPosition: "0 0, 0 4px, 4px -4px, -4px 0px",
                    }}
                  >
                    <img
                      src={imagePreview}
                      alt="Preview"
                      className="w-full h-full object-contain"
                    />
                  </div>
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
                        imageDimensions.w !== imageDimensions.h && (
                          <span className="text-yellow-400 ml-2">
                            ⚠ Recomendado: quadrado
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
                  <Frame className="w-8 h-8 text-[#4B5563] mx-auto mb-2" />
                  <p className="text-[#9CA3AF] text-sm">
                    Arraste ou clique para enviar
                  </p>
                  <p
                    className="text-[#4B5563] text-xs mt-1"
                    style={{ fontFamily: "'DM Mono', monospace" }}
                  >
                    PNG com transparência · quadrado recomendado
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
                Nome da Moldura *
              </Label>
              <Input
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Ex: Golden Crown, Neon Halo..."
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
                      rarity: e.target.value as FrameForm["rarity"],
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

            {/* Estilo da moldura */}
            <div className="space-y-1.5">
              <Label
                className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Estilo / Efeito
              </Label>
              <select
                value={form.frameStyle}
                onChange={(e) =>
                  setForm({
                    ...form,
                    frameStyle: e.target.value as FrameForm["frameStyle"],
                  })
                }
                className="w-full h-10 rounded-md bg-[#1C1E22] border border-[#2A2D34] text-white px-3 text-sm focus:border-[#E040FB] focus:outline-none"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                {Object.entries(FRAME_STYLE_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </select>
              <p
                className="text-[#4B5563] text-xs"
                style={{ fontFamily: "'DM Mono', monospace" }}
              >
                Salvo em asset_config.frame_style — usado pelo app para efeitos
                especiais
              </p>
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
                <User className="w-4 h-4 text-[#E040FB]" />
                <span
                  className="text-[#9CA3AF] text-xs uppercase tracking-widest"
                  style={{ fontFamily: "'DM Mono', monospace" }}
                >
                  Preview em tempo real
                </span>
              </div>

              {/* Avatar simulation */}
              <div className="bg-[#111214]">
                <AvatarPreview
                  frameUrl={imagePreview}
                  name={form.name}
                  rarity={form.rarity}
                />
              </div>
            </div>
          </div>
        </div>
      </form>

      {/* ── Lista de molduras existentes ── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <div className="w-1 h-5 bg-[#E040FB] rounded-full" />
            <h2 className="text-lg font-bold text-white">
              Molduras na Loja
            </h2>
            <span
              className="text-[#4B5563] text-sm"
              style={{ fontFamily: "'DM Mono', monospace" }}
            >
              ({frames.length})
            </span>
          </div>
          <Button
            variant="ghost"
            size="sm"
            onClick={loadFrames}
            className="text-[#9CA3AF] hover:text-white hover:bg-[#2A2D34] h-8 px-2"
          >
            <RefreshCw className="w-3.5 h-3.5" />
          </Button>
        </div>

        {loadingFrames ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 className="w-6 h-6 text-[#E040FB] animate-spin" />
          </div>
        ) : frames.length === 0 ? (
          <div className="bg-[#1C1E22] border border-[#2A2D34] rounded-xl p-10 text-center">
            <Package className="w-10 h-10 text-[#2A2D34] mx-auto mb-3" />
            <p className="text-[#4B5563] text-sm">
              Nenhuma moldura na loja ainda.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {frames.map((item) => {
              const cfg = item.asset_config as Record<string, unknown>;
              const rarity = (cfg?.rarity as string) ?? "common";
              const frameStyle = (cfg?.frame_style as string) ?? "default";
              const frameUrl =
                (cfg?.frame_url as string) ||
                item.preview_url ||
                null;

              return (
                <div
                  key={item.id}
                  className={`bg-[#1C1E22] border rounded-xl overflow-hidden transition-all duration-200 hover:border-[#E040FB]/30 ${
                    item.is_active
                      ? "border-[#2A2D34]"
                      : "border-[#2A2D34] opacity-50"
                  }`}
                >
                  {/* Top accent bar com cor da raridade */}
                  <div
                    className="h-1 w-full"
                    style={{
                      backgroundColor:
                        RARITY_COLORS[rarity] ?? RARITY_COLORS.common,
                    }}
                  />

                  <div className="p-4">
                    {/* Preview com avatar simulado */}
                    <div className="w-16 h-16 rounded-lg bg-[#111214] border border-[#2A2D34] mb-3 overflow-hidden flex items-center justify-center relative">
                      {/* Avatar mini */}
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#2A2D34] to-[#1C1E22] flex items-center justify-center">
                        <User className="w-5 h-5 text-[#4B5563]" />
                      </div>
                      {/* Frame overlay */}
                      {frameUrl ? (
                        <img
                          src={frameUrl}
                          alt={item.name}
                          className="absolute inset-0 w-full h-full object-contain pointer-events-none"
                        />
                      ) : (
                        <ImagePlus className="w-6 h-6 text-[#4B5563] absolute" />
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
                          color: RARITY_COLORS[rarity] ?? RARITY_COLORS.common,
                          backgroundColor:
                            (RARITY_COLORS[rarity] ?? RARITY_COLORS.common) +
                            "20",
                          fontFamily: "'DM Mono', monospace",
                        }}
                      >
                        {rarity}
                      </span>
                    </div>

                    {/* Style tag */}
                    <p
                      className="text-[#6B7280] text-[10px] mb-1"
                      style={{ fontFamily: "'DM Mono', monospace" }}
                    >
                      {FRAME_STYLE_LABELS[frameStyle] ?? frameStyle}
                    </p>

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
                            Ativa
                          </>
                        ) : (
                          <>
                            <AlertCircle className="w-3 h-3" />
                            Inativa
                          </>
                        )}
                      </button>

                      <button
                        onClick={() => deleteFrame(item)}
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
  );
}
